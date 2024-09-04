terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_bastion
}

resource "yandex_vpc_network" "default" {
  name = "default-network"
}

resource "yandex_vpc_subnet" "default" {
  name           = "default-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.default.id
  v4_cidr_blocks = ["10.0.0.0/24"]
}

resource "yandex_compute_instance" "test-vm" {
  name        = "test-vm"
  platform_id = "standard-v1"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.bastion_image_id
      size     = var.bastion_disk_size
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.default.id
    nat       = true
  }

  metadata = {
    user-data = <<-EOT
      #cloud-config
      users:
        - name: user
          groups: sudo
          shell: /bin/bash
          sudo: 'ALL=(ALL) NOPASSWD:ALL'
      EOT
    ssh-keys = "user:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCwUweG4AAWSkzixxuXdWaTsZv24jr/kBjFYrIhPe3mNrbLd8mC/eoEKEP3nhxNP+JLklvSr2YZUl2Ywh8/3xApW1e97p3qbC2AqRG17vMyPyzogLeSECRYzN8C+gO2kHi5OGXjnvjR4TjyZj2+a1fQYlylhURxOTNa8YgRC96hgT0Fn+yOJtxf7qMInVa6ZZ25OFCNCmRFo6WQdV2JkNlfHE7BmD1WGz1lHUPQlMob8z7nWbIDo1gYcFJjOj0ROjCPltIQFwR7ZTrvtujq1KtbCHbxFnycRS7LexmDGCDdzMRzMNotAxti3sAjIbHySh7KvgClUOV6cVqcXxGyR0kZ brykinivan@yandex.cloud"
    serial_port_enable = "true"
  }

}
