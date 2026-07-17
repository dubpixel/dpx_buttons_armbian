packer {
  required_plugins {
    arm-image = {
      version = "0.2.7"
      source  = "github.com/solo-io/arm-image"
    }
  }
}

variable "url" {
  type    = string
  default = ""
}

variable "build" {
  type    = string
  default = "latest"
}

variable "deb_path" {
  type    = string
  default = "artifacts/bitfocus-buttons-usb-relay-headless.deb"
  description = "Local path to the downloaded .deb package, relative to the build root"
}

source "arm-image" "armbian" {
  iso_checksum    = "none"
  iso_url         = var.url
  target_image_size = 5000000000
  output_filename = "output-dpx-buttnode/armbian-dpx-buttnode.img"
  qemu_binary     = "qemu-aarch64-static"
  image_mounts    = ["/"]

  # Needed for DNS to work inside the chroot on newer Armbian images
  additional_chroot_mounts = [["bind", "/run/systemd", "/run/systemd"]]
}

build {
  sources = ["source.arm-image.armbian"]

  # Copy the pre-downloaded .deb into the image
  provisioner "file" {
    source      = var.deb_path
    destination = "/tmp/bitfocus-buttons-usb-relay-headless.deb"
  }

  # Copy the install script into the image
  provisioner "file" {
    source      = "scripts/install-buttons.sh"
    destination = "/tmp/install-buttons.sh"
  }

  # Copy the dynamic-hostname script (installed to /usr/local/bin by install-buttons.sh)
  provisioner "file" {
    source      = "scripts/dpx-set-hostname.sh"
    destination = "/tmp/dpx-set-hostname.sh"
  }

  # Copy the device config web UI (installed to /usr/local/bin by install-buttons.sh)
  provisioner "file" {
    source      = "src/dpx-buttnode-ui/dpx-buttnode-ui.py"
    destination = "/tmp/dpx-buttnode-ui.py"
  }

  # System configuration (hostname, first-login cleanup, SSH)
  provisioner "shell" {
    inline = [
      # Disable Armbian first-login prompt
      "rm -f /root/.not_logged_in_yet",

      # Set a placeholder hostname — dpx-set-hostname.service replaces this
      # with dpx-buttnode-XXXX (MAC-derived) on first boot.
      "echo dpx-buttnode > /etc/hostname",
      "sed -i \"s/127.0.1.1.*/127.0.1.1\\tdpx-buttnode/\" /etc/hosts || true",

      # SSH enabled for remote access and debugging
      # Login: root / 1234  (Armbian forces a password change on first login)
      "systemctl enable ssh || true",
    ]
  }

  # Install Bitfocus Buttons USB Relay (runs as root)
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} su root -c {{ .Path }}"
    inline_shebang  = "/bin/bash -e"
    inline = [
      "export BUTTONS_BUILD=${var.build}",
      "chmod +x /tmp/install-buttons.sh",
      "/tmp/install-buttons.sh"
    ]
  }

  # Copy the Companion Satellite install script into the image
  provisioner "file" {
    source      = "scripts/install-satellite.sh"
    destination = "/tmp/install-satellite.sh"
  }

  # Install Companion Satellite (headless, stable build — runs as root)
  # Downloads from GitHub inside the chroot; requires internet access.
  # Installs but leaves disabled by default (dpx-buttnode-ui Mode tab activates it).
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} su root -c {{ .Path }}"
    inline_shebang  = "/bin/bash -e"
    inline = [
      "chmod +x /tmp/install-satellite.sh",
      "/tmp/install-satellite.sh"
    ]
  }
}
