#!/usr/bin/env bash
# install-buttons.sh
# Runs inside the Armbian image chroot via Packer.
# Installs the Bitfocus Buttons USB Relay headless .deb that was
# copied to /tmp/ by the Packer file provisioner.

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

# Clean up
rm -f "$DEB"
apt-get clean

echo "==> Bitfocus Buttons USB Relay installed successfully"
systemctl is-enabled bitfocus-buttons-usb-relay.service && echo "==> Service: enabled"
