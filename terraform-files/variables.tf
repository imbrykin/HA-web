variable "cloud_id" {
  description = "Yandex Cloud ID"
  default     = "b1g2445ompelboq61fkg"
}

variable "folder_id" {
  description = "ID папки в Yandex.Cloud. Например: b1g43omr5aea4kut7i6f"
  type        = string
}

variable "zone" {
  description = "Зона доступности. Например: ru-central1-a или ru-central1-b или ru-central1-c"
  type        = string
}

variable "vm_count" {
  description = "Количество создаваемых VM. Например: 3"
  type        = number
}

variable "image_id" {
  description = "ID образа для VM. Например (Centos в YC): fd8u8nticc6r76lvj1jo"
  type        = string
}

variable "disk_size" {
  description = "Размер диска для VM (в ГБ). Например: 10"
  type        = number
}

variable "vm_cores" {
  description = "Количество ядер для каждой VM. Например: 2"
  type        = number
}

variable "vm_memory" {
  description = "Объем памяти для каждой VM (в ГБ). Например: 2"
  type        = number
}

variable "v4_cidr_blocks" {
  description = "CIDR блок для вашей подсети. Например: 192.168.1.0/24"
  type        = string
}

variable "network_name" {
  description = "Имя сети. Например: network2"
  type        = string
}

variable "subnet_name" {
  description = "Имя подсети. Например: subnet2"
  type        = string
}

variable "lb_name" {
  description = "Имя сетевого балансировщика. Например: lb-1"
  type        = string
}

variable "target_group_name" {
  description = "Имя target group для сетевого балансировщика нагрузки. Например: hanginx1"
  type        = string
}

variable "bastion_name" {
  description = "Name of the bastion host"
  default     = "bastion"
}

variable "bastion_image_id" {
  description = "Image ID for the bastion host"
  default     = "fd8u8nticc6r76lvj1jo"
}

variable "bastion_disk_size" {
  description = "Disk size for the bastion host in GB"
  default     = 10
}

variable "bastion_zone" {
  description = "Zone where bastion will be deployed"
  default     = "ru-central1-a"
}
