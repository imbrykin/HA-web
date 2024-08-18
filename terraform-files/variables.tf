variable "cloud_id" {
  description = "Yandex Cloud ID"
  default     = "b1g2445ompelboq61fkg"
}

variable "folder_id" {
  description = "Folder ID in Yandex.Cloud. Example: b1g43omr5aea4kut7i6f"
  default     = "b1gfoungdr8tuo6k9lhp"
  type        = string
}

variable "zone" {
  description = "Zone. Example: ru-central1-a or ru-central1-b or ru-central1-d"
  default     = "ru-central1-a"
  type        = string
}

variable "vm_count" {
  description = "Number of VMs. Example: 3"
  default     = 2
  type        = number
}

variable "image_id" {
  description = "ISO ID for VM. Example (Centos in YC): fd8u8nticc6r76lvj1jo"
  default     = "fd8u8nticc6r76lvj1jo"
  type        = string
}

variable "disk_size" {
  description = "Disk size for VM (в ГБ). Example: 10"
  default     = 20
  type        = number
}

variable "vm_cores" {
  description = "Number of CPU cores for each VM. Example: 2"
  default     = 2
  type        = number
}

variable "vm_memory" {
  description = "Total memory for each VM (GB). Example: 2"
  default     = 4
  type        = number
}

variable "network_name" {
  description = "Name of the network"
  default     = "central-1-network"
}

variable "subnet_name" {
  description = "Name of the subnet"
  default     = "subnet"
}

variable "v4_cidr_blocks" {
  description = "CIDR blocks for the subnet"
  default     = "10.0.0.0/24"
}

variable "lb_name" {
  description = "Name of network balancer. Example: lb-1"
  default     = "my-load-balancer"
  type        = string
}

variable "target_group_name" {
  description = "Name of the target group for the load balancerа. Example: hanginx1"
  default     = "web-servers-target-group"
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

variable "vm_zones" {
  description = "Zones for VMs"
  default     = ["ru-central1-a", "ru-central1-b"]
}

variable "ssh_public_key" {
  description = "Public SSH key to access the VMs"
  default     = "~/.ssh/id_rsa.pub"
}

variable "user_password" {
  description = "Password for the user"
  type        = string
  sensitive   = true
}