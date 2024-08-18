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
    # Assigning to a subnet based on the zone
    subnet_id = var.bastion_zone == "ru-central1-a" ? yandex_vpc_subnet.subnet_a.id : yandex_vpc_subnet.subnet_b.id
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
  zone      = element(var.vm_zones, count.index)
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

resource "yandex_lb_target_group" "web_servers_a" {
  name      = "web-target-group-a"
  region_id = "ru-central1"

  target {
    subnet_id = yandex_vpc_subnet.subnet_a.id
    address   = yandex_compute_instance.web[0].network_interface[0].ip_address
  }
}

resource "yandex_lb_target_group" "web_servers_b" {
  name      = "web-target-group-b"
  region_id = "ru-central1"

  target {
    subnet_id = yandex_vpc_subnet.subnet_b.id
    address   = yandex_compute_instance.web[1].network_interface[0].ip_address
  }
}

resource "yandex_lb_network_load_balancer" "lb" {
  name = var.lb_name

  listener {
    name = "http"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.web_servers_a.id
    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.web_servers_b.id
    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}

resource "yandex_alb_http_router" "my_router" {
  name = "my-router"
}

resource "yandex_alb_load_balancer" "alb" {
  name = "my-alb"
  region_id = "ru-central1"
  listener {
    name = "http-listener"
    port = 80
    http {
      router_id = yandex_alb_http_router.my_router.id
    }
  }
}

resource "null_resource" "wait_for_target_group" {
  provisioner "local-exec" {
    command = <<EOT
      while true; do
        if yc load-balancer target-group get --id ${yandex_lb_target_group.web_servers_a.id} > /dev/null 2>&1; then
          echo "Target group is available. Waiting additional 60 seconds..."
          sleep 60
          break
        fi
        echo "Waiting for target group to be fully available..."
        sleep 10
      done
    EOT
  }

  triggers = {
    target_group_id = yandex_lb_target_group.web_servers_a.id
  }
}


resource "yandex_alb_backend_group" "web_backend_group" {
  depends_on = [null_resource.wait_for_target_group]

  name = "web-backend-group"

  http_backend {
    name = "web-backend"
    port = 80
    target_group_ids = [
      yandex_lb_target_group.web_servers_a.id,
      yandex_lb_target_group.web_servers_b.id
    ]
    weight = 1

    healthcheck {
      timeout             = "10s"
      interval            = "2s"
      healthy_threshold   = 3
      unhealthy_threshold = 3

      http_healthcheck {
        path = "/healthz"
      }
    }

    load_balancing_config {
      panic_threshold = 90
    }
  }
}

resource "yandex_alb_virtual_host" "virtual_host" {
  name          = "my-virtual-host"
  http_router_id = yandex_alb_http_router.my_router.id

  route {
    name = "default-route"

    http_route {
      http_match {
        path {
          exact = "/"
        }
      }

      http_route_action {
        backend_group_id = yandex_alb_backend_group.web_backend_group.id
      }
    }
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
  name        = "bastion-daily-snapshot"
  description = "Daily snapshot for bastion instance"
  schedule_policy {
    expression = "0 3 * * *"
  }

  disk_ids = [yandex_compute_instance.bastion.boot_disk[0].disk_id]
  
  snapshot_count = 7
}