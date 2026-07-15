#!/usr/bin/env bash
# generate-release-notes.sh
# Writes a GitHub Release markdown body to /tmp/release-notes.md
#
# Usage: bash scripts/generate-release-notes.sh <version> <assets-dir>
#
# Example: bash scripts/generate-release-notes.sh 0.1.0-beta.4 release-assets

set -euo pipefail

VERSION="${1:?Usage: $0 <version> <assets-dir>}"
ASSETS_DIR="${2:?Usage: $0 <version> <assets-dir>}"
OUT="/tmp/release-notes.md"

# Build board list from .img.gz filenames
BOARD_LIST=""
for f in "$ASSETS_DIR"/*.img.gz; do
    [ -f "$f" ] || continue
    BOARD=$(basename "$f" | sed 's/-buttons-usb-relay-.*//')
    FILE=$(basename "$f")
    BOARD_LIST="${BOARD_LIST}- \`${BOARD}\` — \`${FILE}\`
"
done

cat > "$OUT" << ENDOFNOTES
## Bitfocus Buttons USB Relay ${VERSION}

Flash-ready Armbian images with [Bitfocus Buttons USB Relay](https://bitfocus.io/buttons) (headless) pre-installed.
Plug in your Stream Deck, power on — the relay is already running.

### Boards included
${BOARD_LIST}
### Flash it
\`\`\`bash
# macOS / Linux
gunzip -c <image>.img.gz | sudo dd of=/dev/sdX bs=4M status=progress
\`\`\`
Or use [Balena Etcher](https://etcher.balena.io/) — it reads \`.gz\` directly, no extraction needed.

### First boot
1. Insert SD card, connect Stream Deck via USB, power on
2. \`bitfocus-buttons-usb-relay\` starts automatically and announces itself via mDNS on port \`3040\`
3. Open **Bitfocus Buttons** — relay appears under discovered devices automatically

### Troubleshoot (SSH in)
\`\`\`bash
systemctl status bitfocus-buttons-usb-relay
journalctl -u bitfocus-buttons-usb-relay -f
\`\`\`
ENDOFNOTES

echo "==> Release notes written to ${OUT}"
