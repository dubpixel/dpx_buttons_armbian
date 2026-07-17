#!/usr/bin/env bash
# install-satellite.sh
# Runs inside the Armbian image chroot via Packer.
# Installs Companion Satellite (headless) using the official install script,
# then disables it by default. Mode switching is handled by dpx-buttnode-ui.
#
# Satellite service name: satellite
# Satellite REST API:     http://localhost:9999/api/config
# Satellite config file:  /boot/satellite-config (COMPANION_IP= / COMPANION_PORT=)

set -euo pipefail

echo "==> Installing Companion Satellite (headless, stable build)"

# Download the official install script to a temp file (avoids curl|bash anti-pattern)
curl -fsSL \
    https://raw.githubusercontent.com/bitfocus/companion-satellite/main/pi-image/install.sh \
    -o /tmp/satellite-official-install.sh

chmod +x /tmp/satellite-official-install.sh

# Run official install — builds from source inside the chroot.
# Requires internet access (provided by Packer's /run/systemd bind mount).
# Sets SATELLITE_BUILD=stable to pin to the latest stable release.
export SATELLITE_BUILD="stable"
/tmp/satellite-official-install.sh

rm -f /tmp/satellite-official-install.sh

echo "==> Companion Satellite installed"

# ── Disable by default ────────────────────────────────────────────────────────
# Only one of buttons/satellite runs at a time. Default mode is Buttons.
# dpx-buttnode-ui Mode tab handles enable/disable at runtime.
systemctl disable satellite
echo "==> satellite.service: installed but DISABLED (default mode: buttons)"

# ── Write mode persistence file ───────────────────────────────────────────────
echo "buttons" > /etc/dpx-mode
echo "==> /etc/dpx-mode: buttons (default)"

# ── Verify install ────────────────────────────────────────────────────────────
if [ -d "/opt/companion-satellite" ]; then
    echo "==> Companion Satellite: OK (/opt/companion-satellite exists)"
else
    echo "==> WARNING: /opt/companion-satellite not found — satellite may not have installed correctly"
    echo "==> Run 'sudo satellite-update' on the device to recover"
fi

systemctl is-enabled satellite.service 2>/dev/null && echo "==> Service: enabled (unexpected)" \
    || echo "==> Service: disabled (correct)"
