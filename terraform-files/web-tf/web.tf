
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

# NAT Gateway
resource "yandex_vpc_gateway" "natgw" {
  name        = "natgw"
  description = "NAT gateway for web hosts"
  shared_egress_gateway {}
  network_id  = yandex_vpc_network.bastion_internal.id
  subnet_ids  = [
    yandex_vpc_subnet.bastion_internal_a.id,
    yandex_vpc_subnet.bastion_internal_b.id
  ]
}

# Routing Table
resource "yandex_vpc_route_table" "web_routing_table" {
  name        = "web-routing-table"
  description = "Routing table of NAT-gateway for web hosts"
  network_id  = yandex_vpc_network.bastion_internal.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.natgw.id
  }
}

resource "yandex_dns_zone" "internal_cloud" {
  name             = "internal-cloud"
  description      = "Internal DNS for cloud"
  private_networks = [yandex_vpc_network.bastion_internal.id]
  zone             = "internal-cloud."
  public           = false
  labels = {
    environment = "internal"
  }
}

# 2. DNS A Records

resource "yandex_dns_recordset" "web1" {
  zone_id = yandex_dns_zone.internal_cloud.id
  name    = "web1.internal-cloud."
  type    = "A"
  ttl     = 600
  data    = ["172.17.0.10"]
}

resource "yandex_dns_recordset" "web2" {
  zone_id = yandex_dns_zone.internal_cloud.id
  name    = "web2.internal-cloud."
  type    = "A"
  ttl     = 600
  data    = ["172.16.0.10"]
}

resource "yandex_dns_recordset" "bastion" {
  zone_id = yandex_dns_zone.internal_cloud.id
  name    = "bastion.internal-cloud."
  type    = "A"
  ttl     = 600
  data    = ["172.16.0.254"]
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
    ip_address          = "172.16.1.254"
  }  

  metadata = {
    user-data = templatefile("./meta_bastion.yml", {
      private_key = file("/root/.ssh/id_rsa")
    })
    serial-port-enable = "1"
  }
}

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
    subnet_id          = yandex_vpc_subnet.bastion_internal_a.id
    security_group_ids = [yandex_vpc_security_group.internal_bastion_sg.id]
    nat                 = false
    ip_address          = "172.16.0.10"
  }

  metadata = {
    user-data = templatefile("./meta.yml", {
      private_key = file("/root/.ssh/id_rsa")
    })
    serial-port-enable = "1"
  }
}

resource "yandex_compute_instance" "web2" {
  name        = "web2"
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
    subnet_id           = yandex_vpc_subnet.bastion_internal_b.id
    nat                 = false
    security_group_ids  = [yandex_vpc_security_group.internal_bastion_sg.id]
    ip_address          = "172.17.0.10"
  }

  metadata = {
    user-data = templatefile("./meta.yml", {
      private_key = file("/root/.ssh/id_rsa")
    })
    serial-port-enable = "1"
  }
}

# Target host group for ALB
resource "yandex_alb_target_group" "web_alb_target_group" {
  name           = "web-alb-target-group"

  target {
    subnet_id    = yandex_vpc_subnet.bastion_internal_a.id
    ip_address   = "172.16.0.10"
  }

  target {
    subnet_id    = yandex_vpc_subnet.bastion_internal_b.id
    ip_address   = "172.17.0.10"
  }

}

# Backend group for ALB
resource "yandex_alb_backend_group" "web_alb_backend_group" {
  name                     = "web-alb-backend-group"
  session_affinity {
    connection {
      source_ip = true
    }
  }
  http_backend {
    name                   = "web-alb-http-backend-group"
    weight                 = 1
    port                   = 80
    target_group_ids       = ["${yandex_alb_target_group.web_alb_target_group.id}"]
    load_balancing_config {
      panic_threshold      = 20
    }
    healthcheck {
      timeout              = "5s"
      interval             = "2s"
      http_healthcheck {
        path  = "/"
      }
    }
  }
  depends_on = [yandex_compute_instance.web2]
}

# HTTP Router Configuration
resource "yandex_alb_http_router" "http_router_web" {
  name = "http-router-web"
  labels = {
    environment = "internal"
  }
}

# Virtual Host Configuration
resource "yandex_alb_virtual_host" "web_virtual_host" {
  name            = "web-virtual-host"
  http_router_id  = yandex_alb_http_router.http_router_web.id 
  route {
    name = "web-route"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web_alb_backend_group.id
        timeout          = "5s"
      }
    }
  }
  depends_on = [yandex_alb_backend_group.web_alb_backend_group]
}

resource "yandex_alb_load_balancer" "web_l7_bal" {
  name        = "web-l7-bal"
  network_id  = yandex_vpc_network.bastion_internal.id
  security_group_ids = [yandex_vpc_security_group.internal_bastion_sg.id]

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.bastion_internal_a.id
    }
  }

  listener {
    name = "l7-web-lb"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.http_router_web.id
      }
    }
  }

  log_options {
    discard_rule {
      http_codes       = [100, 101, 200, 201, 300, 301, 400, 404, 500, 502] 
      grpc_codes       = ["NOT_FOUND", "RESOURCE_EXHAUSTED"]
      discard_percent  = 75
    }
  }
}
