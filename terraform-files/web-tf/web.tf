
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


# Existing configuration is kept

# 1. DNS Zone Configuration
resource "yandex_dns_zone" "internal_cloud" {
  name             = "internal-cloud"
  description      = "Internal DNS for cloud"
  private_networks = [yandex_vpc_subnet.bastion_internal_a.id, yandex_vpc_subnet.bastion_internal_b.id, yandex_vpc_subnet.bastion_external_a.id] 
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

# # 3. Reserved Public IP
# resource "yandex_vpc_address" "public_ip" {
#   description        = "Reserved Public IP for load balancer"
#   name               = "l7-pub"
#   external_ipv4_address {
#     zone_id = "ru-central1-a"
#   }
# }

# Backend group
resource "yandex_lb_target_group" "web_backend_group" {
  name = "web-backend-group"

  target {
    address    = "172.17.0.10"
    subnet_id  = yandex_vpc_subnet.bastion_internal_b.id
  }

  target {
    address    = "172.16.0.10"
    subnet_id  = yandex_vpc_subnet.bastion_internal_a.id
  }

  healthcheck {
    name = "http-healthcheck"
    http_options {
      path = "/"
    }
    port = 80
  }
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
        backend_group_id = yandex_lb_target_group.web_backend_group.id
        timeout          = "5s"
      }
    }
  }
}

# 4. Application Load Balancer
resource "yandex_lb_network_load_balancer" "l7_web" {
  name        = "l7-web"
  description = "L7 web balancer"
  type        = "external"
  
  listener {
    name = "http-listener"
    port = 80
    protocol = "HTTP"
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.l7_tg.id
  }

  allocation_policy {
    zone_ids = ["ru-central1-a", "ru-central1-b"]
  }

  # Other related settings omitted for brevity
}

# 5. NAT Gateway
resource "yandex_vpc_nat_gateway" "nat_gw" {
  name        = "nat-gw"
  description = "NAT gateway for web hosts"
  network_id  = yandex_vpc_network.bastion_internal.id
  subnet_ids  = [yandex_vpc_subnet.bastion_internal_a.id, yandex_vpc_subnet.bastion_internal_b.id]
}

# 6. Routing Table
resource "yandex_vpc_route_table" "web_routing_table" {
  name        = "web-routing-table"
  description = "Routing table of NAT-gw for web hosts"
  network_id  = yandex_vpc_network.bastion_internal.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_nat       = yandex_vpc_nat_gateway.nat_gw.id
  }
}

# Subnets to apply the routing table
resource "yandex_vpc_subnet_route_table_attachment" "bastion_internal_a_route" {
  subnet_id    = yandex_vpc_subnet.bastion_internal_a.id
  route_table_id = yandex_vpc_route_table.web_routing_table.id
}

resource "yandex_vpc_subnet_route_table_attachment" "bastion_internal_b_route" {
  subnet_id    = yandex_vpc_subnet.bastion_internal_b.id
  route_table_id = yandex_vpc_route_table.web_routing_table.id
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
    subnet_id          = yandex_vpc_subnet.web_internal_b.id
    security_group_ids = [yandex_vpc_security_group.internal_web_sg.id]
  }

  metadata = {
    ssh-keys = "user:${file(var.ssh_public_key)}"
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