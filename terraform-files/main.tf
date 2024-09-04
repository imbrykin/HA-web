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
    description       = "SSH-in"
    protocol          = "TCP"
    port              = 22
    predefined_target = "self_security_group"
  }

  ingress {
    description    = "L7-80"
    protocol       = "TCP"
    from_port      = 80
    to_port        = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "L7-443"
    protocol       = "TCP"
    from_port      = 443
    to_port        = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "L7-30080"
    protocol       = "TCP"
    from_port      = 30080
    to_port        = 30080
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description       = "ICMP allow"
    protocol          = "ICMP"
    predefined_target = "self_security_group"
  }

  egress {
    description    = "All-out"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "external_bastion_sg" {
  name        = var.sg_external_bastion
  network_id  = yandex_vpc_network.bastion_external.id
  description = "External security group for Bastion"

  ingress {
    description = "SSH-in"
    protocol    = "TCP"
    port       = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All-out"
    protocol    = "ANY"
    from_port   = 0
    to_port     = 65535
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
      type     = "network-ssd"
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
    nat                 = true
    security_group_ids  = [yandex_vpc_security_group.external_bastion_sg.id]
  }

  metadata = {
    user-data = templatefile("./meta.yml", {})
    serial-port-enable = "1"
  }
}