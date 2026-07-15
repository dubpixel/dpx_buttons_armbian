#!/usr/bin/env bash
# install-buttons.sh
# Runs inside the Armbian image chroot via Packer.
# Installs the Bitfocus Buttons USB Relay headless .deb that was
# copied to /tmp/ by the Packer file provisioner.

set -euo pipefail

DEB="/tmp/bitfocus-buttons-usb-relay-headless.deb"

# ── Root password ─────────────────────────────────────────────────────────────
# Set from ROOT_PASSWORD env var (injected via GitHub Secret, never in code).
# Falls back to Armbian default (1234 + forced change on first login) if unset.
if [[ -n "${ROOT_PASSWORD:-}" ]]; then
    echo "root:${ROOT_PASSWORD}" | chpasswd
    # Lock out the forced-change flag so login goes straight in
    chage -d 99999 root 2>/dev/null || true
    echo "==> Root password set from secret"
else
    echo "==> No ROOT_PASSWORD set — using Armbian default (1234, forced change on first login)"
fi

# Ensure dpkg/apt is in a clean state inside the chroot
export DEBIAN_FRONTEND=noninteractive

# Pre-install dependencies that the .deb may require
apt-get update -q
apt-get install -y --no-install-recommends \
    libusb-1.0-0 \
    libudev1 \
    avahi-daemon \
    avahi-utils

# Install the package
dpkg -i "$DEB" || apt-get install -f -y

# Verify the service unit was registered
if ! systemctl list-unit-files bitfocus-buttons-usb-relay.service | grep -q enabled; then
    # The .deb postinst should have enabled it; ensure it is
    systemctl enable bitfocus-buttons-usb-relay.service
fi

# ── Dynamic hostname (set at first boot from MAC address) ─────────────────────
# Can't do this at build time — no hardware, no MAC. A oneshot systemd service
# reads the primary NIC MAC on first boot and sets: dpx-buttnode-XXXX
# where XXXX = last 4 hex chars of the MAC (unique per device).

cat > /usr/local/bin/dpx-set-hostname.sh << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

MARKER="/var/lib/dpx-hostname-set"
[ -f "$MARKER" ] && exit 0

# Find first non-loopback ethernet interface
IFACE=$(ip link show \
    | awk '/^[0-9]+: (eth|end|enp|ens|enx)[^:]+/{iface=$2} /link\/ether/{print iface; exit}' \
    | tr -d ':')

if [[ -z "$IFACE" ]]; then
    # Fallback: any interface with a MAC
    IFACE=$(ip link show | awk '/link\/ether/{print prev} {prev=$2}' | head -1 | tr -d ':')
fi

MAC=$(cat "/sys/class/net/${IFACE}/address" 2>/dev/null || echo "")
if [[ -z "$MAC" ]]; then
    echo "dpx-set-hostname: no MAC found, keeping default"
    touch "$MARKER"; exit 0
fi

# Last 4 hex chars of MAC (last 2 octets)
SUFFIX=$(echo "$MAC" | tr -d ':' | rev | cut -c1-4 | rev)
NEW_HOSTNAME="dpx-buttnode-${SUFFIX}"

hostnamectl set-hostname "$NEW_HOSTNAME"
sed -i "s/127\.0\.1\.1.*/127.0.1.1\t${NEW_HOSTNAME}/" /etc/hosts
systemctl restart avahi-daemon 2>/dev/null || true

touch "$MARKER"
echo "dpx-set-hostname: hostname → $NEW_HOSTNAME"
SCRIPT

chmod +x /usr/local/bin/dpx-set-hostname.sh

cat > /etc/systemd/system/dpx-set-hostname.service << 'UNIT'
[Unit]
Description=Set unique hostname from device MAC address
After=network-pre.target
Before=avahi-daemon.service network.target
ConditionPathExists=!/var/lib/dpx-hostname-set

[Service]
Type=oneshot
ExecStart=/usr/local/bin/dpx-set-hostname.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT

systemctl enable dpx-set-hostname.service

# Verify avahi (mDNS) is enabled so Buttons can discover this relay
systemctl enable avahi-daemon || true

# ── Force IPv4 only ───────────────────────────────────────────────────────────
# Disable IPv6 at the kernel level via boot args — most reliable method on Armbian.
# sysctl alone fires too late; link-local fe80:: gets assigned before it runs.
if [ -f /boot/armbianEnv.txt ]; then
    if grep -q "^extraargs=" /boot/armbianEnv.txt; then
        # Append to existing extraargs line
        sed -i 's/^extraargs=.*/& ipv6.disable=1/' /boot/armbianEnv.txt
    else
        echo "extraargs=ipv6.disable=1" >> /boot/armbianEnv.txt
    fi
    echo "==> IPv6 disabled via kernel cmdline (armbianEnv.txt)"
else
    # Fallback: sysctl for non-Armbian boards
    cat > /etc/sysctl.d/99-disable-ipv6.conf << 'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    echo "==> IPv6 disabled via sysctl (fallback)"
fi

# NetworkManager: IPv4 DHCP only
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/ipv4-only.conf << 'EOF'
[connection]
ipv6.method=disabled
EOF

# Clean up
rm -f "$DEB"
apt-get clean

echo "==> Bitfocus Buttons USB Relay installed successfully"
systemctl is-enabled bitfocus-buttons-usb-relay.service && echo "==> Service: enabled"
