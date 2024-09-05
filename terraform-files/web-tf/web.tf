
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

# VM Instances for Web
resource "yandex_compute_instance" "web1" {
  name        = "web1"
  zone        = "ru-central1-a"
  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = var.web_vm_image_id
      size     = var.web_vm_disk_size
      type     = "network-ssd"
    }
  }
  network_interface {
    subnet_id          = yandex_vpc_subnet.web_internal_b.id
    security_group_ids = [yandex_vpc_security_group.internal_web_sg.id]
  }

  metadata = {
    ssh-keys = "user:${file(var.ssh_public_key)}"
  }
}

resource "yandex_compute_instance" "web1" {
  name        = "web1"
  platform_id = "standard-v1"
  zone        = "ru-central1-b"
  resources {
    cores  = 2
    memory = 4
  }
  boot_disk {
    initialize_params {
      image_id = var.web_vm_image_id
      size     = var.web_vm_disk_size
    }
  }
  network_interface {
    subnet_id           = yandex_vpc_subnet.bastion_internal_a.id
    nat                 = false
    security_group_ids  = [yandex_vpc_security_group.internal_bastion_sg.id]
    ip_address          = "172.16.0.254"
  }

  network_interface {
    subnet_id           = yandex_vpc_subnet.bastion_external_a.id
    nat                 = false
    security_group_ids  = [yandex_vpc_security_group.external_bastion_sg.id]
    ip_address          = "172.16.1.254"
  }  

  metadata = {
    user-data = templatefile("./meta.yml", {})
    serial-port-enable = "1"
  }
}
