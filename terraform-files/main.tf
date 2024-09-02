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

resource "yandex_vpc_subnet" "bastion_internal_b" {
  name           = var.subnet_bastion_internal_b
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.bastion_internal.id
  v4_cidr_blocks = ["172.17.0.0/24"]
}

resource "yandex_vpc_network" "bastion_external" {
  name        = var.network_bastion_external
  description = "External bastion network"
}

resource "yandex_vpc_subnet" "bastion_external_a" {
  name           = var.subnet_bastion_external_a
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.bastion_external.id
  v4_cidr_blocks = ["172.16.1.0/24"]
}

resource "yandex_vpc_security_group" "internal_bastion_sg" {
  name        = var.sg_internal_bastion
  network_id  = yandex_vpc_network.bastion_internal.id
  description = "Internal security group for Bastion"

  ingress {
    description    = "SSH-in"
    protocol       = "TCP"
    to_port          = ["22"]
    security_group_id = yandex_vpc_security_group.internal_bastion_sg.id
  }

  ingress {
    description = "L7"
    protocol    = "TCP"
    to_port       = ["80", "443", "30080"]
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "ICMP allow"
    protocol       = "ICMP"
    security_group_id = yandex_vpc_security_group.internal_bastion_sg.id
  }

  egress {
    description = "All-out"
    protocol    = "ANY"
    to_port       = ["0-65535"]
    v4_cidr_blocks= ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "external_bastion_sg" {
  name        = var.sg_external_bastion
  network_id  = yandex_vpc_network.bastion_external.id
  description = "External security group for Bastion"

  ingress {
    description = "SSH-in"
    protocol    = "TCP"
    to_port       = ["22"]
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All-out"
    protocol    = "ANY"
    to_port       = ["0-65535"]
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance" "bastion" {
  name       = "bastion"
  zone       = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.bastion_image_id
      size     = var.bastion_disk_size
    }
  }

  network_interface {
    subnet_id           = yandex_vpc_subnet.bastion_internal_a.id
    nat                 = false
    security_group_ids  = [yandex_vpc_security_group.internal_bastion_sg.id]
    ipv4_address        = "172.16.0.254"
  }

  network_interface {
    subnet_id           = yandex_vpc_subnet.bastion_external_a.id
    nat                 = true
    security_group_ids  = [yandex_vpc_security_group.external_bastion_sg.id]
  }

  metadata = {
    ssh-keys = "user:${file(var.ssh_public_key)}"
    user-data = templatefile("./meta.yml", {
      hostname = "bastion",
      password = var.user_password
    })
  }
}