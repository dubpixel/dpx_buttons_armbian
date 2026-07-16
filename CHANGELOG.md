# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
-

---

## [0.4.0] - 2026-07-16

### Added
- **Dynamic hostname:** `dpx-set-hostname.service` sets hostname to `dpx-buttnode-XXXX` (last 4 hex
  chars of primary Ethernet MAC, uppercase) on first boot. Reads MAC from `/sys/class/net/<iface>/type`
  (kernel sysfs, available before network stack starts). Ordered `Before=network.target avahi-daemon.service`
  so avahi reads the correct hostname on first start.
- **`dpx-node-ui` web UI** on port 8080 — pure Python 3 stdlib, zero extra packages.
  Tabs: Status, Hostname, Network, Devices, Nodes.
  - **Hostname:** `hostnamectl` + `/etc/hosts` + avahi reload
  - **Network:** DHCP ↔ static. Works on Armbian with Netplan + systemd-networkd.
    Writes `/etc/systemd/network/09-dpx-<iface>.network` (sorts before Netplan's `10-` wildcard),
    deletes the conflicting `/run/systemd/network/10-netplan-all-eth-interfaces.network`,
    then restarts networkd — the only approach that reliably beats Netplan's DHCP wildcard.
  - **Devices:** USB device list, Stream Deck USB power cycle (unbind/rebind port), Buttons service restart
  - **Nodes:** `avahi-browse _dpx-buttnode._tcp` discovers all other buttnodes on the LAN with links to their UIs
- `avahi-daemon.service` drop-in: `After=network-online.target` so mDNS announces on the correct IP after boot
- `_dpx-buttnode._tcp` mDNS service registration so all units appear in the Nodes tab

### Fixed
- Previous dynamic hostname (`41f433a`) used `After=network-pre.target` + fragile awk — replaced
- `netplan apply` silently returns rc=1 and deletes override files on this Armbian build — bypassed
  entirely by writing directly to `/etc/systemd/network/` and restarting networkd
- Armbian Netplan wildcard `e*` DHCP config alphabetically beats explicit `end0` static config —
  fixed by using `09-` prefix (sorts before Netplan's `10-`) and removing the `/run/` wildcard

---

## [0.3.0] - 2026-07-15

### Added
- Dynamic hostname at first boot: `dpx-buttnode-XXXX` derived from last 4 hex chars of MAC address
- `dpx-set-hostname.service` systemd oneshot service handles hostname assignment
- Secure root password baked in via `ROOT_PASSWORD` GitHub Secret (never in code)
- `ROOT_PASSWORD` secret properly chained through `workflow_call` to Packer build
- `custom-board` free-text input on `armbian-builder.yaml` — build any board not in dropdown
- `publish-release.yaml` workflow — re-publish a release from existing build artifacts without recompiling
- Release tags now include pipeline version: `buttons-usb-relay-X.Y.Z-buildA.B.C`
- `force=true` on release workflow deletes and recreates the same tag; normal runs never overwrite
- Orange Pi Zero 3 added to release matrix
- Full 150+ Armbian board list in manual dispatch dropdown

### Fixed
- Removed all IPv6 disable config (`armbianEnv.txt`, sysctl, NetworkManager) — was breaking DHCP
- Self-referencing board resolve step removed; board now resolved inline in each step
- `PACKER_GITHUB_API_TOKEN` passed to `packer init` to avoid GitHub API rate limit
- `sudo` removed from `compile.sh` call (Armbian rejects being run as root)
- All post-Packer file ops use `sudo`; final `.gz` gets `chown runner:runner` for artifact upload
- YAML heredoc inside `run:` block extracted to `scripts/generate-release-notes.sh`
- Release options array syntax fixed for GitHub Actions `workflow_dispatch`

## [0.2.0] - 2026-07-15

### Added
- SSH enabled by default in image (`root` / `1234`) — no serial cable needed for debugging
- IPv6 disabled system-wide via sysctl; NetworkManager forced to IPv4 DHCP only
- `scripts/generate-release-notes.sh` — extracted from workflow to fix YAML heredoc parse error
- `scripts/upload-mirror.sh` — one-command helper to push new Bitfocus packages to mirror release
- Full 150+ Armbian board list in `workflow_dispatch` dropdown
- Rock Pi S (`rockpi-s`) corrected from wrong ID `rockpis`

### Fixed
- YAML syntax errors in `release-action.yaml` (inline array options, heredoc inside block scalar)
- `sudo mv` / `sudo gzip` / `sudo chown` for root-owned Armbian and Packer build outputs
- Release job now deletes existing tag before recreating (handles force rebuilds cleanly)
- Auto-release matrix switched from Orange Pi Zero to Rock Pi (`rockpi-s`, `rockpi-4b`, `rockpi-4bplus`, `rock-s0`)

## [0.1.0] - 2026-07-15

### Added
- Automated two-stage build pipeline: Armbian base image + HashiCorp Packer chroot customization
- Self-hosted package mirror via GitHub Releases (`buttons-deb-mirror` tag) — no Bitfocus credentials needed in CI
- Matrix builds for Orange Pi Zero family (`orangepizero`, `orangepizero2`, `orangepizero2w`, `orangepizero3`)
- Daily scheduled version check — auto-builds and publishes a GitHub Release when mirror is updated
- `scripts/upload-mirror.sh` — one-command helper to upload new Bitfocus packages to the mirror release
- `scripts/download-buttons.sh` — downloads package from mirror release using built-in `GITHUB_TOKEN`
- `scripts/install-buttons.sh` — installs `.deb` inside Armbian chroot, enables `avahi-daemon` for mDNS discovery
- `buttons-usb-relay.pkr.hcl` — Packer build definition targeting ARM64 Armbian images
- Initial support for Bitfocus Buttons USB Relay Headless v0.1.0-beta.4

---

## Version Guidelines

### Semantic Versioning (MAJOR.MINOR.PATCH)

- **MAJOR**: Breaking changes, incompatible API modifications
- **MINOR**: New features, backwards-compatible additions
- **PATCH**: Bug fixes, documentation updates, typos

### Change Categories

- **Added**: New features or capabilities
- **Changed**: Changes to existing functionality
- **Deprecated**: Features marked for future removal (still working)
- **Removed**: Removed features or functionality
- **Fixed**: Bug fixes
- **Security**: Security patches or vulnerability fixes

### Example Entry Format

```markdown
## [1.2.0] - 2026-03-15

### Added
- New authentication system with JWT tokens
- Export functionality for CSV and JSON formats
- Dark mode toggle in user preferences

### Changed
- Improved database query performance by 40%
- Updated UI library from v2.1 to v3.0

### Fixed
- Fixed memory leak in background worker process
- Corrected timezone handling in date picker component

### Security
- Patched XSS vulnerability in user input validation
```

### Version Comparison Links

Add these at the bottom of the file (replace with your repo owner/name):

```markdown
[Unreleased]: https://github.com/owner/repo/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/owner/repo/releases/tag/v0.1.0
```

---

## Tips for Maintaining This Changelog

1. **Update as you work**: Add entries when making changes, not at release time
2. **Keep it scannable**: Use clear, concise descriptions
3. **Link to issues/PRs**: Include `(#123)` references when relevant
4. **Date format**: Use ISO 8601 (YYYY-MM-DD)
5. **Group by type**: Keep all Added items together, all Fixed items together, etc.
6. **User perspective**: Write what changed for users, not implementation details
7. **Unreleased section**: Keep active changes here, move to version section on release
