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
  zone      = var.zone
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

resource "yandex_compute_instance" "web1" {
  name       = "web1"
  hostname   = "web1.ru-central1-a.internal"
  zone       = "ru-central1-a"

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = var.disk_size
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-2.id
    nat       = true
  }

  resources {
    cores  = var.vm_cores
    memory = var.vm_memory
  }

  metadata = {
    user-data = templatefile("./meta.yml", { index = count.index })
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "yandex_compute_instance" "web2" {
  name       = "web2"
  hostname   = "web2.ru-central1-b.internal"
  zone       = "ru-central1-b"

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = var.disk_size
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = false  # No external IP
  }

  resources {
    cores  = var.vm_cores
    memory = var.vm_memory
  }

  metadata = {
    user-data = templatefile("./meta.yml", { index = 2 })
  }
}

resource "yandex_lb_target_group" "web-servers" {
  name = var.target_group_name

  target {
    subnet_id = yandex_vpc_subnet.subnet.id
    address   = yandex_compute_instance.web1.network_interface[0].ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.subnet.id
    address   = yandex_compute_instance.web2.network_interface[0].ip_address
  }
}

resource "yandex_lb_network_load_balancer" "lb" {
  name = "web-load-balancer"

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