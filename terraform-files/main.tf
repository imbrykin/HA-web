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

resource "yandex_vpc_subnet" "subnet_a" {
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.central-1-network.id
  v4_cidr_blocks = ["10.0.0.0/24"]
}

resource "yandex_vpc_subnet" "subnet_b" {
  name           = "subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.central-1-network.id
  v4_cidr_blocks = ["10.0.1.0/24"]
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
    user-data = templatefile("./meta.yml", {
      hostname = var.bastion_name,
      password = var.user_password
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "yandex_compute_instance" "web" {
  count     = length(var.vm_zones)
  name      = "web${count.index + 1}"
  zone      = element(["ru-central1-a", "ru-central1-b"], count.index)
  hostname  = "web${count.index + 1}.ru-central1-${element(["a", "b"], count.index)}.internal"

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = var.disk_size
    }
  }

  network_interface {
    subnet_id = element([yandex_vpc_subnet.subnet_a.id, yandex_vpc_subnet.subnet_b.id], count.index)
    nat       = false
  }

  resources {
    cores  = var.vm_cores
    memory = var.vm_memory
  }

  metadata = {
    ssh-keys = "root:${file("/root/.ssh/id_rsa.pub")}"
    user-data = templatefile("./meta.yml", {
      hostname = "web${count.index + 1}",
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
      subnet_id = yandex_vpc_subnet.subnet_a.id
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

resource "yandex_alb_http_router" "tf-router" {
  name = "http-router"
  labels = {
    tf-label    = "tf-label-value"
    empty-label = ""
  }
}

resource "yandex_alb_virtual_host" "virtual-host" {
  name           = "virtual-hosts"
  http_router_id = yandex_alb_http_router.tf-router.id

  route {
    name = "default-route"
    http_route {
      http_route_action {
        backend_group_id = yandex_lb_target_group.web_servers.id
        timeout          = "60s"
      }
    }
  }

  route_options {
    security_profile_id = "security-profile"
  }
}

resource "yandex_compute_snapshot_schedule" "web_daily_snapshot" {
  name       = "daily-snapshot-web"
  disk_ids   = [for disk in yandex_compute_instance.web : disk.boot_disk[0].disk_id]  # Corrected access to disk_id
  snapshot_count = 7

  schedule_policy {
    expression = "0 3 * * *"
  }
}  

resource "yandex_compute_snapshot_schedule" "bastion_daily_snapshot" {
  name       = "daily-snapshot_bastion"
  disk_ids   = [for disk in yandex_compute_instance.bastion : disk.boot_disk[0].disk_id]  # Accessing single instance
  snapshot_count = 7

  schedule_policy {
    expression = "0 3 * * *"
  }
}