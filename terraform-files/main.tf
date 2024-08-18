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

resource "yandex_vpc_subnet" "subnet-2" {
  name           = var.subnet_name
  zone           = var.zone
  network_id     = yandex_vpc_network.central-1-network.id
  v4_cidr_blocks = [var.v4_cidr_blocks]
}

resource "yandex_lb_network_load_balancer" "lb-1" {
  name = var.lb_name
  deletion_protection = false
  
  listener {
    name = "my-lb1"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  attached_target_group {
    target_group_id = yandex_lb_target_group.testgroup1.id
    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}

resource "yandex_lb_target_group" "testgroup1" {
  name = var.target_group_name
  
  dynamic "target" {
    for_each = yandex_compute_instance.vm
    content {
      subnet_id = yandex_vpc_subnet.subnet-2.id
      address   = target.value.network_interface[0].ip_address
    }
  }
}

resource "yandex_compute_instance" "vm" {
  count = var.vm_count
  name  = "vm${count.index}"
  hostname = "example${count.index}.ru-central1-${element(["a", "b", "c"], count.index)}.internal"

  zone = element(["ru-central1-a", "ru-central1-b", "ru-central1-c"], count.index)

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

resource "yandex_compute_snapshot_schedule" "daily_snapshot" {
  name       = "daily-snapshot"
  disk_ids   = [for disk in yandex_compute_instance.vm : disk.boot_disk.0.disk_id]
  schedule   = "0 3 * * *"
  retention_policy {
    snapshot_count = 7
  }
}