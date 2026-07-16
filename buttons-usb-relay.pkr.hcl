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
  output_filename = "output-buttonspi/armbian-buttons-usb-relay.img"
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

  # System configuration (hostname, first-login cleanup, SSH)
  provisioner "shell" {
    inline = [
      # Disable Armbian first-login prompt
      "rm -f /root/.not_logged_in_yet",

      # Set hostname
      "CURRENT_HOSTNAME=$(cat /etc/hostname | tr -d ' \\t\\n\\r')",
      "echo buttons-usb-relay > /etc/hostname",
      "sed -i \"s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\\tbuttons-usb-relay/g\" /etc/hosts",

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
}
