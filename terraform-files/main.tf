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
  folder_id = var.folder_id
}

resource "yandex_vpc_network" "central-1-network" {
  name = var.network_name
}

resource "yandex_vpc_subnet" "subnet" {
  name           = var.subnet_name
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.central-1-network.id
  v4_cidr_blocks = [var.v4_cidr_blocks]
}

resource "yandex_compute_instance" "bastion" {
  name       = var.bastion_name
  zone       = var.bastion_zone
  hostname   = "${var.bastion_name}.ru-central1.internal"

  boot_disk {
    initialize_params {
      image_id = var.bastion_image_id
      size     = var.bastion_disk_size
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  resources {
    cores  = 2
    memory = 2
  }

  metadata = {
    ssh-keys = "root:${file("/root/.ssh/id_rsa.pub")}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "yandex_compute_instance" "web" {
  count     = length(var.vm_zones)
  name      = "web${count.index + 1}"
  zone      = var.vm_zones[count.index]
  hostname  = "web${count.index + 1}.ru-central1-${element(["a", "b"], count.index)}.internal"

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = var.disk_size
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = false
  }

  resources {
    cores  = var.vm_cores
    memory = var.vm_memory
  }

  metadata = {
    ssh-keys = "root:${file("/root/.ssh/id_rsa.pub")}"
    user-data = templatefile("./meta.yml", {
      password = var.user_password
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "yandex_lb_target_group" "web-servers" {
  name = var.target_group_name

  dynamic "target" {
    for_each = yandex_compute_instance.web
    content {
      subnet_id = yandex_vpc_subnet.subnet.id
      address   = target.value.network_interface[0].ip_address
    }
  }
}

resource "yandex_lb_network_load_balancer" "lb" {
  name               = var.lb_name

  listener {
    name = "http"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.web-servers.id
    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}

resource "yandex_lb_http_router" "http_router" {
  name           = "http-router"
  load_balancer_id = yandex_lb_network_load_balancer.lb.id
  route {
    http {
      name        = "default"
      http_router = "http-router"
      backend_group_id = yandex_lb_target_group.web-servers.id
    }
  }
}

resource "yandex_compute_snapshot_schedule" "daily_snapshot" {
  name       = "daily-snapshot"
  disk_ids   = [for disk in yandex_compute_instance.vm : disk.boot_disk.0.disk_id]
  schedule   = "0 3 * * *"
  retention_policy {
    snapshot_count = 7
  }
}