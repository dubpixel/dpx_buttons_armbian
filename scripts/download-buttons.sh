#!/usr/bin/env bash
# download-buttons.sh
# Downloads the Bitfocus Buttons USB Relay package from the repo's
# GitHub mirror release (tagged 'buttons-deb-mirror').
#
# No Bitfocus credentials needed — uses GITHUB_TOKEN (auto-injected in Actions).
#
# Outputs:
#   $ARTIFACTS_DIR/bitfocus-buttons-usb-relay-headless.deb
#   $ARTIFACTS_DIR/buttons-version.txt

set -euo pipefail

MIRROR_TAG="buttons-deb-mirror"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-artifacts}"

mkdir -p "$ARTIFACTS_DIR"

echo "==> Fetching package from mirror release: ${MIRROR_TAG}"

# Download the .tar.gz asset from the mirror release
gh release download "$MIRROR_TAG" \
    --repo "${GITHUB_REPOSITORY}" \
    --pattern "*.tar.gz" \
    --dir "$ARTIFACTS_DIR" \
    --clobber

TARBALL=$(ls "$ARTIFACTS_DIR"/*.tar.gz | head -1)
echo "==> Downloaded: $(basename "$TARBALL") ($(du -sh "$TARBALL" | cut -f1))"

# Parse version from filename:
#   bitfocus-buttons-usb-relay-headless_0.1.0-beta.4_arm64.tar.gz -> 0.1.0-beta.4
VERSION=$(basename "$TARBALL" _arm64.tar.gz | sed 's/.*_//')
echo "==> Version: ${VERSION}"

# Extract the .deb from the tarball (one level of directory nesting)
TMPEXTRACT=$(mktemp -d)
tar -xzf "$TARBALL" -C "$TMPEXTRACT"
DEB=$(find "$TMPEXTRACT" -name "*.deb" | head -1)

if [[ -z "$DEB" ]]; then
    echo "ERROR: No .deb found inside $(basename "$TARBALL")"
    exit 1
fi

echo "==> Extracted: $(basename "$DEB")"

# Normalize to a fixed name so Packer always finds it at the same path
cp "$DEB" "$ARTIFACTS_DIR/bitfocus-buttons-usb-relay-headless.deb"
rm -rf "$TMPEXTRACT" "$TARBALL"

echo "$VERSION" > "$ARTIFACTS_DIR/buttons-version.txt"
echo "==> Done — artifacts/buttons-version.txt: ${VERSION}"
