#!/usr/bin/env bash
# install-buttons.sh
# Runs inside the Armbian image chroot via Packer.
# Installs the Bitfocus Buttons USB Relay headless .deb that was
# copied to /tmp/ by the Packer file provisioner, then installs:
#   - dpx-set-hostname.service  (sets dpx-buttnode-XXXX hostname on first boot)
#   - dpx-buttnode-ui.service   (device config web UI on port 8080)

set -euo pipefail

DEB="/tmp/bitfocus-buttons-usb-relay-headless.deb"

echo "==> Installing Bitfocus Buttons USB Relay (build: ${BUTTONS_BUILD:-unknown})"

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

# Verify avahi (mDNS) is enabled so Buttons can discover this relay
systemctl enable avahi-daemon || true

# ── Dynamic hostname (dpx-buttnode-XXXX) ──────────────────────────────────────
# Install the set-hostname script that was copied into the image by Packer.
# Reads MAC from /sys/class/net (sysfs — always available at boot, before any
# network stack starts) and sets hostname once. Marker file prevents re-runs.
echo "==> Installing dpx-set-hostname"

install -m 0755 /tmp/dpx-set-hostname.sh /usr/local/bin/dpx-set-hostname.sh

cat > /etc/systemd/system/dpx-set-hostname.service << 'UNIT'
[Unit]
Description=Set unique hostname from device MAC address (dpx-buttnode-XXXX)
Documentation=https://github.com/dubpixel/dpx_buttnode
After=local-fs.target
Before=network.target avahi-daemon.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/dpx-set-hostname.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

systemctl enable dpx-set-hostname.service
echo "==> dpx-set-hostname.service: enabled"

# ── dpx-buttnode-ui (device config web UI on port 8080) ─────────────────────
echo "==> Installing dpx-buttnode-ui"

install -m 0755 /tmp/dpx-buttnode-ui.py /usr/local/bin/dpx-buttnode-ui.py
install -m 0644 /tmp/fav_icon.png     /usr/local/bin/fav_icon.png

cat > /etc/systemd/system/dpx-buttnode-ui.service << 'UNIT'
[Unit]
Description=DPX Buttnode UI — device configuration web interface (port 8080)
Documentation=https://github.com/dubpixel/dpx_buttnode
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/dpx-buttnode-ui.py
Restart=on-failure
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
UNIT

systemctl enable dpx-buttnode-ui.service
echo "==> dpx-buttnode-ui.service: enabled (port 8080)"

# ── Advertise dpx-buttnode-ui via mDNS (_dpx-buttnode._tcp) ─────────────────
# This allows `avahi-browse _dpx-buttnode._tcp` to discover all units on the LAN
# and powers the Nodes tab in the web UI.
echo "==> Registering _dpx-buttnode._tcp mDNS service"

mkdir -p /etc/avahi/services
cat > /etc/avahi/services/dpx-buttnode-ui.service << 'XML'
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">DPX Buttnode %h</name>
  <service>
    <type>_dpx-buttnode._tcp</type>
    <port>8080</port>
  </service>
</service-group>
XML
echo "==> mDNS service registered"

# ── avahi: wait for network-online before starting ────────────────────────────
# Without this, avahi starts before networkd has assigned a static IP and
# announces the wrong address (or no address), breaking .local resolution.
echo "==> Configuring avahi to wait for network-online"
mkdir -p /etc/systemd/system/avahi-daemon.service.d
cat > /etc/systemd/system/avahi-daemon.service.d/wait-for-network.conf << 'UNIT'
[Unit]
After=network-online.target
Wants=network-online.target
UNIT

# ── Clean up ───────────────────────────────────────────────────────────────────
rm -f "$DEB"
apt-get clean

echo "==> Bitfocus Buttons USB Relay installed successfully"
systemctl is-enabled bitfocus-buttons-usb-relay.service && echo "==> Service: enabled"
