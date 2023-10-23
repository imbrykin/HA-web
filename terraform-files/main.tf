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

resource "yandex_vpc_subnet" "subnet-2" {
  count          = var.use_existing_network ? 0 : 1
  name           = var.subnet_name
  zone           = var.zone
  network_id     = var.use_existing_network ? var.existing_network_id : yandex_vpc_network.central-1-network[0].id
  v4_cidr_blocks = var.use_existing_network ? [] : [var.v4_cidr_blocks]
}

resource "yandex_lb_target_group" "testgroup1" {
  name = var.target_group_name
  
  dynamic "target" {
    for_each = yandex_compute_instance.vm
    content {
      subnet_id = var.use_existing_network ? var.existing_network_id : yandex_vpc_subnet.subnet-2[0].id
      address   = target.value.network_interface[0].ip_address
    }
  }
}

resource "yandex_compute_instance" "vm" {
  count = var.vm_count
  name  = "vm${count.index}"

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = var.disk_size
    }
  }

  network_interface {
    subnet_id = var.use_existing_network ? var.existing_network_id : yandex_vpc_subnet.subnet-2[0].id
    nat       = false
  }

  resources {
    cores  = var.vm_cores
    memory = var.vm_memory
  }

  metadata = {
    user-data = templatefile("./meta.yml", { index = count.index })
  }
}