
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

# Bastion Networks and Subnets (existing)
resource "yandex_vpc_network" "bastion_internal" {
  name        = var.network_bastion_internal
  description = "Internal bastion network"
}

resource "yandex_vpc_subnet" "bastion_internal_a" {
  name           = var.subnet_bastion_internal_a
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.bastion_internal.id
  v4_cidr_blocks = ["172.16.0.0/24"]
}

# New Web Internal Network and Subnets
resource "yandex_vpc_network" "web_internal" {
  name        = var.network_web_internal
  description = "Internal web network"
}

resource "yandex_vpc_subnet" "web_internal_a" {
  name           = var.subnet_web_internal_a
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.web_internal.id
  v4_cidr_blocks = ["10.10.0.0/24"]
}

resource "yandex_vpc_subnet" "web_internal_b" {
  name           = var.subnet_web_internal_b
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.web_internal.id
  v4_cidr_blocks = ["10.11.0.0/24"]
}

# Security Group for Web Servers
resource "yandex_vpc_security_group" "internal_web_sg" {
  name        = var.sg_internal_web
  network_id  = yandex_vpc_network.web_internal.id
  description = "Internal security group for Web"

  ingress {
    description       = "SSH-in"
    protocol          = "TCP"
    port              = 22
    predefined_target = "self_security_group"
  }

  ingress {
    description       = "HTTP Healthcheck"
    protocol          = "TCP"
    from_port         = 80
    to_port           = 80
    predefined_target = "self_security_group"
  }

  egress {
    description    = "All-out"
    protocol       = "ALL"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# VM Instances for Web
resource "yandex_compute_instance" "web0" {
  name        = "web0"
  platform_id = "standard-v1"
  zone        = "ru-central1-a"
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
    subnet_id          = yandex_vpc_subnet.web_internal_a.id
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
    subnet_id          = yandex_vpc_subnet.web_internal_b.id
    security_group_ids = [yandex_vpc_security_group.internal_web_sg.id]
  }

  metadata = {
    ssh-keys = "user:${file(var.ssh_public_key)}"
  }
}
