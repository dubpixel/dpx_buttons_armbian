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

variable "root_password" {
  type      = string
  default   = ""
  sensitive = true
  description = "Root password to set in the image. Leave blank to use Armbian default (1234 + forced change)."
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

      # Set placeholder hostname — dpx-set-hostname.service will replace
      # it with dpx-buttnode-XXXX (MAC-derived) on first boot
      "echo dpx-buttnode > /etc/hostname",
      "sed -i 's/127.0.1.1.*/127.0.1.1\tdpx-buttnode/g' /etc/hosts",

      # SSH enabled for remote access and debugging
      "systemctl enable ssh || true",
    ]
  }

  # Install Bitfocus Buttons USB Relay (runs as root)
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} su root -c {{ .Path }}"
    inline_shebang  = "/bin/bash -e"
    environment_vars = [
      "BUTTONS_BUILD=${var.build}",
      "ROOT_PASSWORD=${var.root_password}",
    ]
    inline = [
      "chmod +x /tmp/install-buttons.sh",
      "/tmp/install-buttons.sh"
    ]
  }
}
