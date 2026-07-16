#!/usr/bin/env python3
"""
dpx-node-ui — DPX device configuration web interface
Installed: /usr/local/bin/dpx-node-ui.py
Service:   dpx-node-ui.service
Port:      8080

Zero external dependencies — uses Python 3 stdlib only.
"""

import http.server
import os
import re
import socket
import subprocess
import urllib.parse
import urllib.request
from pathlib import Path

PORT = 8080
HOSTNAME_MARKER = "/var/lib/dpx-hostname-set"
BUTTONS_API    = "http://localhost:3040"
NETWORKD_DIR   = Path("/etc/systemd/network")
DPX_NET_FILE   = NETWORKD_DIR / "10-dpx-eth.network"

# ── System helpers ─────────────────────────────────────────────────────────────

def run(cmd):
    """Run a command list, return (stdout, stderr, returncode).
    Returns ("" , "command not found", 127) if the binary doesn't exist.
    """
    try:
        r = subprocess.run(cmd, capture_output=True, text=True)
        return r.stdout.strip(), r.stderr.strip(), r.returncode
    except FileNotFoundError:
        return "", f"command not found: {cmd[0]}", 127


def get_hostname():
    return socket.gethostname()


def get_mac():
    """Return MAC of first real Ethernet interface (sysfs, always available)."""
    for p in sorted(Path("/sys/class/net").iterdir()):
        t_f = p / "type"
        a_f = p / "address"
        if not t_f.exists() or not a_f.exists():
            continue
        if t_f.read_text().strip() != "1":
            continue
        addr = a_f.read_text().strip()
        if re.match(r"^[0-9a-f]{2}(:[0-9a-f]{2}){5}$", addr) and addr != "00:00:00:00:00:00":
            return addr
    return "unknown"


def get_ip():
    out, _, _ = run(["ip", "-4", "addr", "show", "scope", "global"])
    m = re.search(r"inet\s+(\d+\.\d+\.\d+\.\d+)/", out)
    return m.group(1) if m else "unknown"


def svc_active(name):
    _, _, rc = run(["systemctl", "is-active", "--quiet", name])
    return rc == 0


def nmcli_available():
    _, _, rc = run(["nmcli", "--version"])
    return rc == 0


def networkd_active():
    _, _, rc = run(["systemctl", "is-active", "--quiet", "systemd-networkd"])
    return rc == 0


def get_primary_iface():
    """First real Ethernet interface name from sysfs."""
    for p in sorted(Path("/sys/class/net").iterdir()):
        t_f = p / "type"; a_f = p / "address"
        if not t_f.exists() or not a_f.exists(): continue
        if t_f.read_text().strip() != "1": continue
        addr = a_f.read_text().strip()
        if re.match(r"^[0-9a-f]{2}(:[0-9a-f]{2}){5}$", addr) and addr != "00:00:00:00:00:00":
            return p.name
    return "eth0"


def get_net_info():
    """Return dict: nmcli, networkd (bools), mode, iface, ip_cidr, gateway, dns."""
    iface = get_primary_iface()
    info  = {"nmcli": False, "networkd": False, "iface": iface,
             "mode": "dhcp", "ip_cidr": get_ip() + "/24",
             "gateway": "", "dns": "8.8.8.8"}

    if nmcli_available():
        info["nmcli"] = True
        out, _, rc = run(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"])
        if rc != 0: return info
        conn = ""
        for line in out.splitlines():
            parts = line.split(":")
            if len(parts) >= 2 and "ethernet" in parts[1].lower():
                conn = parts[0]; break
        if not conn: return info
        info["conn"] = conn
        out2, _, _ = run(["nmcli", "-t", "-f",
                          "ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns",
                          "connection", "show", conn])
        for line in out2.splitlines():
            k, _, v = line.partition(":")
            if k == "ipv4.method" and v == "manual": info["mode"] = "static"
            elif k == "ipv4.addresses" and v: info["ip_cidr"] = v
            elif k == "ipv4.gateway": info["gateway"] = v
            elif k == "ipv4.dns" and v: info["dns"] = v.split(",")[0]
        return info

    if networkd_active():
        info["networkd"] = True
        # Read DPX-managed networkd file if present; otherwise assume DHCP
        if DPX_NET_FILE.exists():
            txt = DPX_NET_FILE.read_text()
            if re.search(r"^\s*DHCP\s*=\s*(yes|ipv4)", txt, re.M | re.I):
                info["mode"] = "dhcp"
            else:
                info["mode"] = "static"
                m = re.search(r"^\s*Address\s*=\s*(\S+)",  txt, re.M); info["ip_cidr"]  = m.group(1) if m else info["ip_cidr"]
                m = re.search(r"^\s*Gateway\s*=\s*(\S+)", txt, re.M); info["gateway"] = m.group(1) if m else ""
                m = re.search(r"^\s*DNS\s*=\s*(\S+)",     txt, re.M); info["dns"]     = m.group(1) if m else "8.8.8.8"
        return info

    return info


def write_networkd_config(iface, mode, ip_cidr=None, gateway=None, dns="8.8.8.8"):
    """Write /etc/systemd/network/10-dpx-eth.network and reload networkd."""
    NETWORKD_DIR.mkdir(parents=True, exist_ok=True)
    if mode == "dhcp":
        content = f"[Match]\nName={iface}\n\n[Network]\nDHCP=yes\n"
    else:
        content = (f"[Match]\nName={iface}\n\n"
                   f"[Network]\nAddress={ip_cidr}\nGateway={gateway}\nDNS={dns}\n")
    DPX_NET_FILE.write_text(content)
    run(["networkctl", "reload"])


def get_usb_devices():
    out, _, _ = run(["lsusb"])
    return [l for l in out.splitlines() if l.strip()]


def buttons_reachable():
    """TCP-level check that Buttons is listening on port 3040."""
    import socket as _sock
    try:
        s = _sock.create_connection(("127.0.0.1", 3040), timeout=2)
        s.close()
        return True
    except OSError:
        return False


def discover_buttnodes():
    """Return list of dpx-buttnode instances found via avahi-browse.
    Requires avahi-daemon running and the _dpx-buttnode._tcp service registered.
    Each entry: {hostname, addr, port, is_self}
    """
    # -p parseable, -t terminate when done, -r resolve addresses
    out, _, rc = run(["avahi-browse", "-p", "-t", "-r", "_dpx-buttnode._tcp"])
    if rc != 0:
        return []
    me   = get_hostname().lower()
    seen = set()
    nodes = []
    for line in out.splitlines():
        if not line.startswith("="):
            continue
        parts = line.split(";")
        if len(parts) < 9:
            continue
        proto    = parts[2]   # IPv4 / IPv6
        hostname = parts[6].rstrip(".")
        addr     = parts[7]
        port     = parts[8]
        if proto != "IPv4" or hostname in seen:
            continue
        seen.add(hostname)
        nodes.append({"hostname": hostname, "addr": addr,
                      "port": port, "is_self": hostname.lower() == me})
    return sorted(nodes, key=lambda n: (not n["is_self"], n["hostname"]))


def validate_hostname(name):
    return bool(name and len(name) <= 63 and
                re.match(r"^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?$", name))


def validate_ip(ip):
    parts = ip.split(".")
    return len(parts) == 4 and all(p.isdigit() and 0 <= int(p) <= 255 for p in parts)


def esc(s):
    """Minimal HTML escaping for user-visible values."""
    return (str(s)
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;"))


# ── CSS ────────────────────────────────────────────────────────────────────────

CSS = """
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#0f1117;color:#e1e4e8;min-height:100vh}
a{color:#388bfd;text-decoration:none}
.hdr{background:#161b22;border-bottom:1px solid #30363d;padding:14px 24px;display:flex;align-items:center;gap:10px}
.hdr h1{font-size:17px;font-weight:700;color:#f0f6ff;letter-spacing:-.3px}
.tag{background:#1f6feb;color:#fff;font-size:10px;padding:2px 8px;border-radius:12px;font-weight:700;letter-spacing:.3px}
.nav{background:#161b22;border-bottom:1px solid #21262d;padding:0 24px;display:flex;gap:2px;overflow-x:auto}
.nav a{display:inline-block;padding:10px 14px;font-size:13px;color:#8b949e;border-bottom:2px solid transparent;white-space:nowrap}
.nav a.on,.nav a:hover{color:#f0f6ff;border-bottom-color:#1f6feb}
.wrap{max-width:880px;margin:0 auto;padding:24px 16px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(155px,1fr));gap:10px;margin-bottom:20px}
.card{background:#161b22;border:1px solid #30363d;border-radius:8px;padding:14px}
.lbl{font-size:10px;color:#8b949e;text-transform:uppercase;letter-spacing:.5px;margin-bottom:5px}
.val{font-size:17px;font-weight:700;color:#f0f6ff;font-family:ui-monospace,monospace;word-break:break-all}
.val.on{color:#3fb950}.val.off{color:#f85149}
.sec{background:#161b22;border:1px solid #30363d;border-radius:8px;padding:20px;margin-bottom:14px}
.sec h2{font-size:12px;font-weight:700;color:#8b949e;text-transform:uppercase;letter-spacing:.6px;margin-bottom:14px;padding-bottom:10px;border-bottom:1px solid #21262d}
.row{margin-bottom:12px}
.row label{display:block;font-size:12px;color:#8b949e;margin-bottom:4px}
input[type=text]{width:100%;background:#0d1117;border:1px solid #30363d;border-radius:6px;padding:8px 12px;color:#f0f6ff;font-size:14px;font-family:ui-monospace,monospace}
input[type=text]:focus{outline:none;border-color:#1f6feb;box-shadow:0 0 0 3px #1f6feb22}
.btn{background:#21262d;border:1px solid #30363d;color:#f0f6ff;padding:8px 16px;border-radius:6px;font-size:13px;cursor:pointer;display:inline-block;margin-right:6px;font-family:inherit}
.btn-p{background:#1f6feb;border-color:#1f6feb}.btn-p:hover{background:#388bfd}
.btn-w{background:#9e6a03;border-color:#9e6a03}.btn-w:hover{background:#b07d12}
.alert{padding:10px 14px;border-radius:6px;font-size:13px;margin-bottom:16px;line-height:1.5}
.a-ok{background:#0d2a1a;border:1px solid #3fb950;color:#3fb950}
.a-err{background:#2a0d0d;border:1px solid #f85149;color:#f85149}
.a-warn{background:#2a1d00;border:1px solid #9e6a03;color:#d4a017}
.radios{display:flex;gap:16px;margin-bottom:14px}
.radios label{display:flex;align-items:center;gap:6px;cursor:pointer;font-size:14px}
.usb{list-style:none}
.usb li{font-family:ui-monospace,monospace;font-size:12px;color:#8b949e;padding:5px 0;border-bottom:1px solid #21262d}
.usb li:last-child{border:none}
.badge{display:inline-block;font-size:11px;padding:2px 8px;border-radius:10px;font-weight:600}
.badge-on{background:#0d2a1a;color:#3fb950}.badge-off{background:#21262d;color:#8b949e}
code{background:#21262d;padding:2px 6px;border-radius:4px;font-size:12px;font-family:ui-monospace,monospace}
.note{font-size:12px;color:#8b949e;line-height:1.6;margin-bottom:14px}
"""

# ── Page template ──────────────────────────────────────────────────────────────

def page(content, tab="status", alert="", alert_cls="a-ok"):
    hostname = esc(get_hostname())
    al = (f'<div class="alert {alert_cls}">{alert}</div>' if alert else "")
    tabs = [
        ("status",   "/",         "Status"),
        ("hostname", "/hostname", "Hostname"),
        ("network",  "/network",  "Network"),
        ("devices",  "/devices",  "Devices"),
        ("nodes",    "/nodes",    "Nodes"),
    ]
    nav = "".join(
        f'<a href="{u}" class="{"on" if t == tab else ""}">{n}</a>'
        for t, u, n in tabs
    )
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{hostname} — dpx-node-ui</title>
<style>{CSS}</style>
</head>
<body>
<div class="hdr"><h1>⬡ {hostname}</h1><span class="tag">dpx-node-ui</span></div>
<nav class="nav">{nav}</nav>
<div class="wrap">{al}{content}</div>
</body>
</html>"""


# ── Page renderers ─────────────────────────────────────────────────────────────

def render_status(alert="", alert_cls="a-ok"):
    ip      = esc(get_ip())
    mac     = esc(get_mac())
    host    = esc(get_hostname())
    bs      = svc_active("bitfocus-buttons-usb-relay")
    av      = svc_active("avahi-daemon")
    net     = get_net_info()
    usb     = get_usb_devices()

    grid = f"""
<div class="grid">
  <div class="card"><div class="lbl">Hostname</div>
    <div class="val" style="font-size:13px">{host}</div></div>
  <div class="card"><div class="lbl">IP Address</div>
    <div class="val">{ip}</div></div>
  <div class="card"><div class="lbl">MAC</div>
    <div class="val" style="font-size:12px">{mac}</div></div>
  <div class="card"><div class="lbl">Network</div>
    <div class="val" style="font-size:14px">{esc(net['mode']).upper()}</div></div>
  <div class="card"><div class="lbl">Buttons</div>
    <div class="val {'on' if bs else 'off'}">{'active' if bs else 'inactive'}</div></div>
  <div class="card"><div class="lbl">mDNS</div>
    <div class="val {'on' if av else 'off'}">{'active' if av else 'inactive'}</div></div>
</div>
<div class="sec"><h2>USB Devices</h2>
  <ul class="usb">
    {''.join(f'<li>{esc(d)}</li>' for d in usb) if usb else '<li style="color:#8b949e">No USB devices detected</li>'}
  </ul>
</div>"""
    return page(grid, "status", alert, alert_cls)


def render_hostname(val="", alert="", alert_cls="a-ok"):
    cur  = esc(get_hostname())
    disp = esc(val) if val else cur
    body = f"""
<div class="sec"><h2>Change Hostname</h2>
  <p class="note">
    Current hostname: <code>{cur}</code><br>
    mDNS address: <code>{cur}.local</code><br>
    The new hostname is applied immediately and persists across reboots.
  </p>
  <form method="POST" action="/hostname">
    <div class="row">
      <label>New hostname (letters, numbers, hyphens — no spaces)</label>
      <input type="text" name="hostname" value="{disp}"
             placeholder="dpx-buttnode-XXXX"
             pattern="[a-zA-Z0-9][a-zA-Z0-9\\-]{{0,62}}" required>
    </div>
    <button type="submit" class="btn btn-p">Apply</button>
    <a href="/" class="btn">Cancel</a>
  </form>
</div>"""
    return page(body, "hostname", alert, alert_cls)


def render_network(alert="", alert_cls="a-ok"):
    net = get_net_info()

    if not net["nmcli"] and not net["networkd"]:
        body = f"""
<div class="sec"><h2>Network Settings</h2>
  <div class="alert a-warn">
    Network manager not detected.<br>
    Current IP: <code>{esc(net['ip_cidr'])}</code>
  </div>
  <a href="/" class="btn">Back</a>
</div>"""
        return page(body, "network", alert, alert_cls)

    sv      = "" if net["mode"] == "static" else 'style="display:none"'
    backend = (f'<p class="note">Using <code>systemd-networkd</code> — '
               f'writes to <code>{DPX_NET_FILE}</code></p>'
               if net["networkd"] else "")
    body = f"""
<div class="sec"><h2>Network Settings</h2>
  {backend}
  <div class="alert a-warn" style="margin-bottom:14px">
    ⚠ Do not disable IPv6 — it breaks DHCP on Armbian.
  </div>
  <form method="POST" action="/network">
    <div class="radios">
      <label><input type="radio" name="mode" value="dhcp"
               {"checked" if net["mode"] != "static" else ""}
               onchange="tog(this)"> DHCP (automatic)</label>
      <label><input type="radio" name="mode" value="static"
               {"checked" if net["mode"] == "static" else ""}
               onchange="tog(this)"> Static IP</label>
    </div>
    <div id="sf" {sv}>
      <div class="row"><label>IP / prefix (e.g. 192.168.1.100/24)</label>
        <input type="text" name="ip" value="{esc(net['ip_cidr'])}" placeholder="192.168.1.100/24"></div>
      <div class="row"><label>Default gateway</label>
        <input type="text" name="gateway" value="{esc(net['gateway'])}" placeholder="192.168.1.1"></div>
      <div class="row"><label>DNS server</label>
        <input type="text" name="dns" value="{esc(net['dns'])}" placeholder="8.8.8.8"></div>
    </div>
    <button type="submit" class="btn btn-p">Apply</button>
    <a href="/" class="btn">Cancel</a>
  </form>
</div>
<script>function tog(e){{document.getElementById('sf').style.display=e.value==='static'?'':'none'}}</script>"""
    return page(body, "network", alert, alert_cls)


def render_devices(alert="", alert_cls="a-ok"):
    usb    = get_usb_devices()
    api_ok = buttons_reachable()
    badge  = (
        '<span class="badge badge-on">● listening on :3040</span>'
        if api_ok else
        '<span class="badge badge-off">○ not reachable on :3040</span>'
    )
    body = f"""
<div class="sec"><h2>Connected USB Devices</h2>
  <ul class="usb">
    {''.join(f'<li>{esc(d)}</li>' for d in usb) if usb else '<li style="color:#8b949e">No USB devices detected</li>'}
  </ul>
</div>
<div class="sec"><h2>Buttons Service</h2>
  <p class="note">
    bitfocus-buttons-usb-relay {badge}<br>
    Restart the service to reset the Stream Deck connection
    (useful if the deck is unresponsive or showing the wrong page).
  </p>
  <form method="POST" action="/restart-buttons" style="display:inline">
    <button type="submit" class="btn btn-w">↺ Restart Buttons</button>
  </form>
  <a href="/" class="btn">Back</a>
</div>"""
    return page(body, "devices", alert, alert_cls)


def render_nodes(alert="", alert_cls="a-ok"):
    nodes = discover_buttnodes()
    me    = get_hostname()
    rows  = ""
    for n in nodes:
        self_tag = (
            ' <span class="badge badge-on" style="font-size:9px;vertical-align:middle">THIS NODE</span>'
            if n["is_self"] else ""
        )
        border = "#1f6feb" if n["is_self"] else "#30363d"
        action = (
            '<span style="color:#8b949e;font-size:12px">this device</span>'
            if n["is_self"] else
            f'<a href="http://{esc(n["addr"])}:{esc(n["port"])}/" '
            f'class="btn btn-p" style="font-size:12px" target="_blank">Open UI →</a>'
        )
        rows += f"""
<div style="background:#161b22;border:1px solid {border};border-radius:8px;padding:14px;
            margin-bottom:10px;display:flex;align-items:center;justify-content:space-between;gap:12px">
  <div>
    <div style="font-weight:700;color:#f0f6ff;margin-bottom:3px">
      {esc(n['hostname'])}{self_tag}</div>
    <div style="font-size:12px;color:#8b949e;font-family:ui-monospace,monospace">{esc(n['addr'])}</div>
  </div>
  {action}
</div>"""

    if not rows:
        rows = '<p class="note">No dpx-buttnodes found on this network.<br>Make sure avahi-daemon is running on all units.</p>'

    body = f"""
<div class="sec"><h2>Nodes on This Network</h2>
  {rows}
  <div style="margin-top:14px">
    <a href="/nodes" class="btn">↺ Rescan</a>
    <a href="/" class="btn">Back</a>
  </div>
</div>"""
    return page(body, "nodes", alert, alert_cls)


# ── Request handler ────────────────────────────────────────────────────────────

class Handler(http.server.BaseHTTPRequestHandler):

    def log_message(self, fmt, *args):
        pass  # suppress per-request noise in journal

    def html(self, body, code=200):
        b = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(b)))
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(b)

    def redir(self, loc):
        self.send_response(303)
        self.send_header("Location", loc)
        self.end_headers()

    def read_post(self):
        n = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(n).decode("utf-8", errors="replace")
        params = urllib.parse.parse_qs(raw, keep_blank_values=True)
        return {k: v[0].strip() for k, v in params.items()}

    # ── GET ────────────────────────────────────────────────────────────────

    def do_GET(self):
        path = self.path.split("?")[0]
        qs   = dict(urllib.parse.parse_qsl(self.path.partition("?")[2]))

        # Resolve alert from redirect query string
        alert, alert_cls = "", "a-ok"
        ok_msgs = {
            "hostname": "✓ Hostname updated — mDNS will reflect the change within a few seconds",
            "network":  "✓ Network settings applied",
            "restart":  "✓ Buttons service restarted",
        }
        err_msgs = {
            "api":     "✗ Buttons API did not respond — is bitfocus-buttons-usb-relay running?",
            "invalid": "✗ Invalid input",
        }
        if "ok" in qs:
            alert = ok_msgs.get(qs["ok"], "✓ Done")
        elif "err" in qs:
            alert     = err_msgs.get(qs["err"], "✗ An error occurred")
            alert_cls = "a-err"

        if path == "/":
            self.html(render_status(alert, alert_cls))
        elif path == "/hostname":
            self.html(render_hostname(alert=alert, alert_cls=alert_cls))
        elif path == "/network":
            self.html(render_network(alert, alert_cls))
        elif path == "/devices":
            self.html(render_devices(alert, alert_cls))
        elif path == "/nodes":
            self.html(render_nodes(alert, alert_cls))
        else:
            self.html("<html><body><h1>Not found</h1></body></html>", 404)

    # ── POST ───────────────────────────────────────────────────────────────

    def do_POST(self):
        params = self.read_post()
        path   = self.path.split("?")[0]

        # ── /hostname ──────────────────────────────────────────────────────
        if path == "/hostname":
            name = params.get("hostname", "")
            if not validate_hostname(name):
                self.html(render_hostname(
                    val=name,
                    alert="✗ Invalid hostname — use letters, numbers, and hyphens only",
                    alert_cls="a-err",
                ))
                return

            _, err, rc = run(["hostnamectl", "set-hostname", "--static", name])
            if rc != 0:
                self.html(render_hostname(
                    val=name,
                    alert=f"✗ hostnamectl failed: {esc(err)}",
                    alert_cls="a-err",
                ))
                return

            # Write /etc/hostname explicitly for belt-and-suspenders
            Path("/etc/hostname").write_text(name + "\n")

            # Update 127.0.1.1 line in /etc/hosts
            hosts = Path("/etc/hosts").read_text()
            hosts = re.sub(
                r"^127\.0\.1\.1\s+\S+",
                f"127.0.1.1\t{name}",
                hosts,
                flags=re.MULTILINE,
            )
            if "127.0.1.1" not in hosts:
                hosts += f"\n127.0.1.1\t{name}\n"
            Path("/etc/hosts").write_text(hosts)

            # Prevent dpx-set-hostname.service from overwriting on next boot
            Path(HOSTNAME_MARKER).touch()

            # Tell avahi about the new name
            run(["systemctl", "reload-or-restart", "avahi-daemon"])

            self.redir("/?ok=hostname")

        # ── /network ───────────────────────────────────────────────────────
        elif path == "/network":
            net  = get_net_info()
            mode = params.get("mode", "dhcp")

            if net["networkd"]:
                iface = net.get("iface", get_primary_iface())
                if mode == "dhcp":
                    write_networkd_config(iface, "dhcp")
                    self.redir("/?ok=network")
                    return
                ip_cidr = params.get("ip", "")
                gw      = params.get("gateway", "")
                dns     = params.get("dns", "8.8.8.8")
                if not validate_ip(ip_cidr.split("/")[0]) or not validate_ip(gw):
                    self.html(render_network("✗ Invalid IP address or gateway", "a-err"))
                    return
                write_networkd_config(iface, "static", ip_cidr, gw, dns)
                self.redir("/?ok=network")
                return

            # nmcli path
            out, _, _ = run(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"])
            conn = ""
            for line in out.splitlines():
                parts = line.split(":")
                if len(parts) >= 2 and "ethernet" in parts[1].lower():
                    conn = parts[0]
                    break

            if not conn:
                self.html(render_network(
                    alert="✗ No active Ethernet connection found — is the cable plugged in?",
                    alert_cls="a-err",
                ))
                return

            if mode == "dhcp":
                run(["nmcli", "connection", "modify", conn,
                     "ipv4.method", "auto",
                     "ipv4.addresses", "",
                     "ipv4.gateway",  "",
                     "ipv4.dns",      ""])
            elif mode == "static":
                ip_cidr = params.get("ip", "")
                gw      = params.get("gateway", "")
                dns     = params.get("dns", "8.8.8.8")
                ip_only = ip_cidr.split("/")[0]
                if not validate_ip(ip_only) or not validate_ip(gw):
                    self.html(render_network(
                        alert="✗ Invalid IP address or gateway",
                        alert_cls="a-err",
                    ))
                    return
                run(["nmcli", "connection", "modify", conn,
                     "ipv4.method",    "manual",
                     "ipv4.addresses", ip_cidr,
                     "ipv4.gateway",   gw,
                     "ipv4.dns",       dns])
            else:
                self.redir("/?err=invalid")
                return

            run(["nmcli", "connection", "up", conn])
            self.redir("/?ok=network")

        # ── /identify ──────────────────────────────────────────────────────
        elif p == "/restart-buttons":
            _, err, rc = run(["systemctl", "restart", "bitfocus-buttons-usb-relay"])
            if rc != 0:
                self.html(render_devices(alert=f"✗ restart failed: {esc(err)}", alert_cls="a-err"))
                return
            self.redir("/devices?ok=restart")

        else:
            self.html("<html><body><h1>Not found</h1></body></html>", 404)


# ── Main ───────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"dpx-node-ui listening on :{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
