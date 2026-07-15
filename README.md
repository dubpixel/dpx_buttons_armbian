<!-- Improved compatibility of back to top link: See: https://github.com/othneildrew/Best-README-Template/pull/73 -->
<a id="readme-top"></a>

<!--  *** Thanks for checking out the Best-README-Template. If you have a suggestion that would make this better, please fork the repo and create a pull request or simply open an issue with the tag "enhancement". Don't forget to give the project a star! Thanks again! Now go create something AMAZING! :D -->



<!-- /// d   u   b   p   i   x   e   l  ---  f   o   r   k   ////--v0.5.7 -->
<!--this has additionally been modifed by @dubpixel for hardware use -->
<!--search dpx_buttons_relay_armbian.. search & replace is COMMAND OPTION F -->

<!--this is the version for software -->
<!--todo ** add small product image thats not in a details tag -->
<!--todo ** new software product image? Remove it? -->
<!--igure out how to get the details tag to properly render in jekyll for gihub pages.-->



<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
***
-->
<div align="center">

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![License][license-shield]][license-url]
[![LinkedIn][linkedin-shield]][linkedin-url]
</div>
<!-- PROJECT LOGO -->
<div align="center">
  <a href="https://github.com/dubpixel/dpx_buttons_relay_armbian">
    <img src="images/logo.png" alt="Logo" height="120">
  </a>
<h1 align="center">dpx_buttons_relay_armbian</h1>
<h3 align="center"><i>Flash-ready Armbian images with Bitfocus Buttons USB Relay pre-installed</i></h3>
  <p align="center">
    Automated GitHub Actions build pipeline that produces ready-to-flash <code>.img.gz</code> images
    for ARM single-board computers (Orange Pi Zero, etc.) with
    <a href="https://bitfocus.io/buttons">Bitfocus Buttons USB Relay</a> pre-installed and auto-starting on boot.
    Write the image, plug in your Stream Deck, power on — done.
    <br /><br />
     »  
     <a href="https://github.com/dubpixel/dpx_buttons_relay_armbian/releases"><strong>Download a Release »</strong></a>
     <br />
    <a href="https://github.com/dubpixel/dpx_buttons_relay_armbian/issues/new?labels=bug&template=bug-report---.md">Report Bug</a>
    ·
    <a href="https://github.com/dubpixel/dpx_buttons_relay_armbian/issues/new?labels=enhancement&template=feature-request---.md">Request Feature</a>
    </p>
</div>
   <br />
<!-- TABLE OF CONTENTS -->
<details>
  <summary><h3>Table of Contents</h3></summary>
<ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#reflection">Reflection</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
</ol>
</details>
<!-- ABOUT THE PROJECT -->
<details>
<summary><h3>About The Project</h3></summary>

This project mirrors the architecture of <a href="https://github.com/elliotmatson/companion-satellite-armbian">companion-satellite-armbian</a>
but targets <strong>Bitfocus Buttons USB Relay (headless)</strong> instead of Companion Satellite — making it work on ARM single-board computers that aren't Raspberry Pis.

The build pipeline is fully automated via GitHub Actions:
<ol>
  <li>The Armbian build framework compiles a minimal Ubuntu Noble (24.04) base image for the target board.</li>
  <li>The Bitfocus Buttons USB Relay <code>.tar.gz</code> package is pulled from this repo's <code>buttons-deb-mirror</code> release (maintained manually — no Bitfocus account or secrets needed in CI).</li>
  <li><a href="https://www.packer.io/">HashiCorp Packer</a> (with the <code>arm-image</code> plugin) chroots into the image and installs the <code>.deb</code>, enables the systemd service, sets the hostname to <code>buttons-usb-relay</code>, and removes the first-login prompt.</li>
  <li>The image is zeroed, gzip-compressed, and published as a GitHub Release.</li>
</ol>

A daily scheduled workflow checks whether the mirror release has a version that hasn't been built yet, and automatically triggers a full matrix build if so.

</br>

*author(s): // www.dubpixel.tv  - i@dubpixel.tv*
</br>
</details>
<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Built With

* [Armbian Build Framework](https://github.com/armbian/build) — base Linux image for ARM SBCs
* [HashiCorp Packer](https://www.packer.io/) + [arm-image plugin](https://github.com/solo-io/packer-plugin-arm-image) — chroot image customization
* [GitHub Actions](https://github.com/features/actions) — CI/CD build, scheduling, and release publishing
* [Bitfocus Buttons USB Relay (headless)](https://bitfocus.io/buttons) — the software being installed
<p align="right">(<a href="#readme-top">back to top</a>)</p>
<!-- GETTING STARTED -->

## Getting Started

> **Pick your path:**
> - [**→ I just want to flash a board**](#-path-a--flash-a-pre-built-image) — download, flash, done
> - [**→ Bitfocus released a new version**](#-path-b--update-to-a-new-buttons-version) — one command to update the pipeline
> - [**→ I need a board not in the auto-release list**](#-path-c--build-any-other-board-manually) — manual dispatch for any of 150+ boards

---

### Supported Boards

The following boards are built **automatically** on every new Buttons release and published to [Releases](https://github.com/dubpixel/dpx_buttons_relay_armbian/releases):

| Board | Armbian ID |
|---|---|
| [Rock Pi S](https://wiki.radxa.com/RockpiS) — [buy](https://shop.allnetchina.cn/products/rock-pi-s) | `rockpi-s` |
| [Rock Pi 4B](https://wiki.radxa.com/Rockpi4) | `rockpi-4b` |
| [Rock Pi 4B+](https://wiki.radxa.com/Rockpi4) | `rockpi-4bplus` |
| [Rock Pi S0](https://radxa.com/products/rockpi/s0) | `rock-s0` |

#### Recommended accessories

| Accessory | Board | Why |
|---|---|---|
| [Rock Pi S PoE HAT](https://shop.allnetchina.cn/products/rock-pi-s-poe-hat) | Rock Pi S | Dedicated HAT — cleanest single-cable install |
| [ecoPI S housing](https://shop.allnetchina.cn/products/rock-pi-s-case) | Rock Pi S | Enclosure designed for Rock Pi S |
| [Waveshare PoE Splitter USB-C 2.5A](https://www.waveshare.com/poe-splitter-type-c.htm) | Orange Pi Zero 3 | PoE → USB-C 5V/2.5A, metal case, gigabit |
| [Waveshare PoE Splitter USB-C 5A](https://www.waveshare.com/poe-splitter-25w-type-c.htm) | Orange Pi Zero 3 | Same but 25W — more headroom for heavier loads |

All 150+ [Armbian-supported boards](https://www.armbian.com/download/) are available for one-off manual builds — see [Path C](#-path-c--build-any-other-board-manually).

---

### ✅ Path A — Flash a pre-built image

**What you need:** A microSD card (8 GB min), your Rock Pi board, a Stream Deck.

#### 1. Download the image

Go to [**Releases**](https://github.com/dubpixel/dpx_buttons_relay_armbian/releases) and download the `.img.gz` for your board:

```
rockpi-s-buttons-usb-relay-0.1.0-beta.4.img.gz
```

#### 2. Flash to SD card

**Easiest — [Balena Etcher](https://etcher.balena.io/) (Mac / Windows / Linux):**
1. Open Etcher → **Flash from file** → pick the `.img.gz`
2. Select your SD card
3. Click **Flash** — Etcher handles the `.gz` decompression automatically

**Command line (macOS):**
```bash
# Find your SD card — look for the right size disk
diskutil list

diskutil unmountDisk /dev/diskN
gunzip -c rockpi-s-buttons-usb-relay-0.1.0-beta.4.img.gz \
  | sudo dd of=/dev/rdiskN bs=4m status=progress
diskutil eject /dev/diskN
```

**Command line (Linux):**
```bash
lsblk   # find your SD card device

gunzip -c rockpi-s-buttons-usb-relay-0.1.0-beta.4.img.gz \
  | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

> ⚠️ Triple-check your device path (`/dev/diskN` or `/dev/sdX`). Wrong device = wiped disk.

#### 3. Boot and connect

1. Insert SD card into the Rock Pi
2. Plug in your Stream Deck via USB
3. Plug in ethernet
4. Power on — wait ~30 seconds

**That's it.** Open **Bitfocus Buttons** on your computer — the relay appears automatically under discovered devices. No configuration needed.

> The device hostname is `buttons-usb-relay.local`, port `3040` via mDNS. SSH is **on** — `root` / `1234`.

---

### 🔄 Path B — Update to a new Buttons version

When Bitfocus releases a new version, this is the **entire process**:

#### 1. Download the new package from Bitfocus

Go to [user.bitfocus.io/download](https://user.bitfocus.io/download), log in, and download:
```
bitfocus-buttons-usb-relay-headless_X.Y.Z_arm64.tar.gz
```

#### 2. Upload it to the mirror (one command)

> Requires [GitHub CLI](https://cli.github.com/): `brew install gh` then `gh auth login`

```bash
./scripts/upload-mirror.sh ~/Downloads/bitfocus-buttons-usb-relay-headless_X.Y.Z_arm64.tar.gz
```

This uploads the file to the `buttons-deb-mirror` release in this repo. Done.

#### 3. Let CI do the rest (or trigger immediately)

The daily scheduled check at 06:00 UTC will detect the new version and automatically build all boards and publish a release.

To trigger it **right now** instead of waiting:
```bash
gh workflow run release-action.yaml --repo dubpixel/dpx_buttons_relay_armbian
```

Watch it: **Actions → Release — Buttons USB Relay Images → latest run**

---

### 🛠 Path C — Build any other board manually

Any of the 150+ Armbian-supported boards can be built on demand. The artifact is available for 7 days under the Actions run (not published as a public release).

**Via GitHub web UI:**
1. Go to **Actions → Build Armbian + Buttons USB Relay Image**
2. Click **Run workflow**
3. Pick your board from the dropdown
4. Click **Run workflow**
5. Wait ~45-90 min, then download the `.img.gz` from the run's Artifacts section

**Via terminal:**
```bash
gh workflow run armbian-builder.yaml \
  --repo dubpixel/dpx_buttons_relay_armbian \
  -f armbian-board=orangepizero3
```

Replace `orangepizero3` with any board ID from the [Armbian hardware list](https://www.armbian.com/download/).

---

### ⚙️ Fork and run your own pipeline

1. Fork this repo on GitHub
2. Seed the mirror with the current package:
   ```bash
   ./scripts/upload-mirror.sh ~/Downloads/bitfocus-buttons-usb-relay-headless_0.1.0-beta.4_arm64.tar.gz
   ```
3. Trigger a first build:
   - **Actions → Release — Buttons USB Relay Images → Run workflow → Force: true**
4. Done — updates are fully automated from here

> No GitHub Secrets needed. The pipeline uses only the built-in `GITHUB_TOKEN`.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- USAGE EXAMPLES -->
## Usage

### SSH into the device

SSH is **enabled by default**. As soon as the board is on the network:

```bash
ssh root@buttons-usb-relay.local
# Password: 1234
# Armbian forces a password change on first login
```

If mDNS isn't resolving, find the IP from your router and use that directly.

---

### Check the relay is running

```bash
# Is it running?
systemctl status bitfocus-buttons-usb-relay

# Watch live logs
journalctl -u bitfocus-buttons-usb-relay -f

# Restart it
sudo systemctl restart bitfocus-buttons-usb-relay
```

---

### Connect to a specific Buttons server (client mode)

By default the relay announces itself via mDNS and Buttons discovers it automatically — **no config needed** for most setups.

If your network blocks mDNS (some managed switches do), point the relay directly at your Buttons server:

```bash
sudo nano /etc/default/bitfocus-buttons-usb-relay
```

Add this line:
```
EXTRA_ARGS="-buttonsAddress 192.168.1.10:3000"
```

Then restart:
```bash
sudo systemctl restart bitfocus-buttons-usb-relay
```

---

### Network discovery

The device announces itself as `buttons-usb-relay.local` on port `3040`.

```bash
# Confirm it's on the network
ping buttons-usb-relay.local

# Browse mDNS (from another machine)
avahi-browse -t _buttons._tcp     # Linux
dns-sd -B _buttons._tcp local     # macOS
```
<!-- REFLECTION -->
## Reflection

* what did we learn?
  - _x_
* what do we like/hate?
  - _y_
* what would/could we do differently?
  - _z_

<!-- ROADMAP -->

- [x] Core Armbian + Packer two-stage build pipeline
- [x] Self-hosted package mirror via GitHub Releases (no Bitfocus secrets in CI)
- [x] Matrix builds for Orange Pi Zero family
- [x] Daily automated version check + GitHub Release publishing
- [x] `upload-mirror.sh` helper for one-command package updates
- [ ] Additional board support (Banana Pi M2 Zero, NanoPi R4S, Orange Pi 5)
- [ ] SHA256 checksums attached to each release
- [ ] WiFi pre-configuration support in image (via Armbian `wpa_supplicant` overlay)

See the [open issues](https://github.com/dubpixel/dpx_buttons_relay_armbian/issues) for a full list of proposed features (and known issues).

<!-- CONTRIBUTING -->
## Contributing

_Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**._

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Top contributors:
<a href="https://github.com/dubpixel/dpx_buttons_relay_armbian/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=dubpixel/dpx_buttons_relay_armbian" alt="contrib.rocks image" />
</a>

<!-- LICENSE -->
## License
Distributed under the [LICENSE_TYPE] License. See `LICENSE.txt` for more information.
<!-- CONTACT -->
## Contact

  ### Joshua Fleitell - i@dubpixel.tv

  Project Link: [https://github.com/dubpixel/dpx_buttons_relay_armbian](https://github.com/dubpixel/dpx_buttons_relay_armbian)

<!-- ACKNOWLEDGMENTS -->
## Acknowledgments

* [elliotmatson/companion-satellite-armbian](https://github.com/elliotmatson/companion-satellite-armbian) — architecture and workflow pattern this project is based on
* [Bitfocus](https://bitfocus.io/) — creators of Buttons and Companion
* [Armbian](https://www.armbian.com/) — Linux for ARM SBCs
* [Bitfocus Buttons USB Relay — Official Docs](https://support.bitfocus.io/hc/en-us/articles/33855997471890-Bitfocus-Buttons-USB-Relay-Raspberry-Pi) — source of truth for installation, service management, and configuration

---

<details>
<summary><h3>🔧 How to replicate this pattern for any software</h3></summary>

This project uses a two-stage pipeline to produce flash-ready images for ARM SBCs. Here's the general recipe so you can adapt it for any headless software you want to bake into an Armbian image.

---

#### The pattern

```
GitHub Actions runner (x86)
  └─ 1. Build Armbian base image for target board
  └─ 2. Packer chroots into image via QEMU
       └─ copies your software in
       └─ installs it
       └─ configures it (hostname, services, etc.)
  └─ 3. Compress and publish the image
```

No cross-compilation. No physical board needed. Runs entirely on standard x86 CI runners.

---

#### What you need

- Your software packaged as a `.deb`, or an install script that runs inside a Debian/Ubuntu chroot
- A GitHub repo with Actions enabled
- [HashiCorp Packer](https://www.packer.io/) — free, open source

---

#### Step 1 — Write your Packer HCL file

Create `your-software.pkr.hcl`:

```hcl
packer {
  required_plugins {
    arm-image = {
      version = "0.2.7"
      source  = "github.com/solo-io/arm-image"
    }
  }
}

variable "url"      { type = string }  # path to Armbian .img
variable "deb_path" { type = string }  # path to your .deb

source "arm-image" "armbian" {
  iso_checksum    = "none"
  iso_url         = var.url
  target_image_size = 5000000000        # 5 GB — adjust as needed
  output_filename = "output/image.img"
  qemu_binary     = "qemu-aarch64-static"
  image_mounts    = ["/"]

  # Required for DNS to work inside the chroot
  additional_chroot_mounts = [["bind", "/run/systemd", "/run/systemd"]]
}

build {
  sources = ["source.arm-image.armbian"]

  # Copy your software into the image
  provisioner "file" {
    source      = var.deb_path
    destination = "/tmp/your-software.deb"
  }

  # Copy your install script
  provisioner "file" {
    source      = "scripts/install.sh"
    destination = "/tmp/install.sh"
  }

  # System config (hostname, first-login, SSH)
  provisioner "shell" {
    inline = [
      "rm -f /root/.not_logged_in_yet",
      "echo your-device-name > /etc/hostname",
      "systemctl disable ssh || true",
    ]
  }

  # Install your software (runs as root)
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} su root -c {{ .Path }}"
    inline_shebang  = "/bin/bash -e"
    inline          = ["chmod +x /tmp/install.sh", "/tmp/install.sh"]
  }
}
```

---

#### Step 2 — Write your install script

`scripts/install.sh` runs **inside the chroot** as root. Treat it like a normal Debian post-install script:

```bash
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Install dependencies
apt-get update -q
apt-get install -y --no-install-recommends avahi-daemon libusb-1.0-0

# Install your package
dpkg -i /tmp/your-software.deb || apt-get install -f -y

# Enable services
systemctl enable your-service
systemctl enable avahi-daemon

# Cleanup
apt-get clean
```

---

#### Step 3 — Wire it into GitHub Actions

```yaml
- name: Install QEMU (required for ARM chroot on x86 runners)
  run: sudo apt-get install -y qemu-user-static

- name: Build Armbian base image
  run: |
    git clone --depth=1 https://github.com/armbian/build build
    sudo ./build/compile.sh build \
      BOARD=your-board-id \
      BRANCH=current \
      RELEASE=noble \
      BUILD_MINIMAL=yes \
      KERNEL_CONFIGURE=no \
      COMPRESS_OUTPUTIMAGE=no
    sudo mv build/output/images/*.img build/output/images/armbian.img

- name: Install Packer
  run: |
    wget -qO - https://apt.releases.hashicorp.com/gpg \
      | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
      https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
      | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update -q && sudo apt-get install -y packer

- name: Run Packer
  run: |
    sudo packer init your-software.pkr.hcl
    sudo packer build \
      -var "url=build/output/images/armbian.img" \
      -var "deb_path=path/to/your-software.deb" \
      your-software.pkr.hcl

- name: Compress image
  run: |
    sudo apt-get install -y zerofree
    IMG="output/image.img"
    LOOP=$(sudo losetup -fP --show "$IMG")
    sudo e2fsck -fy "${LOOP}p1" || true
    sudo zerofree "${LOOP}p1"
    sudo losetup -d "$LOOP"
    gzip -n "$IMG"
```

---

#### Key things to know

| Thing | Why it matters |
|---|---|
| `qemu-user-static` must be installed **before** Packer runs | Packer uses it to emulate ARM64 instructions inside the chroot on your x86 runner |
| `additional_chroot_mounts = [["bind", "/run/systemd", "/run/systemd"]]` | Without this, DNS resolution inside the chroot fails and `apt-get` can't reach package servers |
| All `packer` commands need `sudo` | The `arm-image` plugin creates loop devices and bind mounts — root required |
| `sudo mv` the Armbian output | The Armbian build framework runs as root inside Docker, so output files are owned by root |
| `zerofree` before `gzip` | Zeros unused filesystem blocks so the image compresses 3-5x smaller |
| Set `target_image_size` generously | Packer will fail if the image fills up during install. 5 GB is safe for most software |

---

#### Supported boards

Any board in [Armbian's supported hardware list](https://www.armbian.com/download/) works. Look up the board's `BOARD=` ID from the Armbian docs or the [supported boards list](https://github.com/armbian/build/blob/main/config/boards).

</details>

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/dubpixel/dpx_buttons_relay_armbian.svg?style=flat-square
[contributors-url]: https://github.com/dubpixel/dpx_buttons_relay_armbian/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/gdubpixel/dpx_buttons_relay_armbian.svg?style=flat-square
[forks-url]: https://github.com/dubpixel/dpx_buttons_relay_armbian/network/members
[stars-shield]: https://img.shields.io/github/stars/dubpixel/dpx_buttons_relay_armbian.svg?style=flat-square
[stars-url]: https://github.com/dubpixel/dpx_buttons_relay_armbian/stargazers
[issues-shield]: https://img.shields.io/github/issues/dubpixel/dpx_buttons_relay_armbian.svg?style=flat-square
[issues-url]: https://github.com/dubpixel/dpx_buttons_relay_armbian/issues
[license-shield]: https://img.shields.io/github/license/dubpixel/dpx_buttons_relay_armbian.svg?style=flat-square
[license-url]: https://github.com/dubpixel/dpx_buttons_relay_armbian/blob/main/LICENSE.txt
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=flat-square&logo=linkedin&colorB=555
[linkedin-url]: https://linkedin.com/in/jfleitell
[product-front]: images/front.png
[product-rear]: images/rear.png
[product-front-rendering]: images/front_render.png
[product-rear-rendering]: images/rear_render.png
[product-pcbFront]: images/pcb_front.png
[product-pcbRear]: images/pcb_rear.png
[Next.js]: https://img.shields.io/badge/next.js-000000?style=for-the-badge&logo=nextdotjs&logoColor=white
[Next-url]: https://nextjs.org/
[React.js]: https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB
[React-url]: https://reactjs.org/
[Vue.js]: https://img.shields.io/badge/Vue.js-35495E?style=for-the-badge&logo=vuedotjs&logoColor=4FC08D
[Vue-url]: https://vuejs.org/
[Angular.io]: https://img.shields.io/badge/Angular-DD0031?style=for-the-badge&logo=angular&logoColor=white
[Angular-url]: https://angular.io/
[Svelte.dev]: https://img.shields.io/badge/Svelte-4A4A55?style=for-the-badge&logo=svelte&logoColor=FF3E00
[Svelte-url]: https://svelte.dev/
[Laravel.com]: https://img.shields.io/badge/Laravel-FF2D20?style=for-the-badge&logo=laravel&logoColor=white
[Laravel-url]: https://laravel.com
[Bootstrap.com]: https://img.shields.io/badge/Bootstrap-563D7C?style=for-the-badge&logo=bootstrap&logoColor=white
[Bootstrap-url]: https://getbootstrap.com
[JQuery.com]: https://img.shields.io/badge/jQuery-0769AD?style=for-the-badge&logo=jquery&logoColor=white
[JQuery-url]: https://jquery.com 
[KiCad.org]: https://img.shields.io/badge/KiCad-v8.0.6-blue
[KiCad-url]: https://kicad.org 
[Fusion-360]: https://img.shields.io/badge/Fusion360-v4.2.0-green
[Autodesk-url]: https://autodesk.com 
[FastLed.io]: https://img.shields.io/badge/FastLED-v3.9.9-red
[FastLed-url]: https://fastled.io 
