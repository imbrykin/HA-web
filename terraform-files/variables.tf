variable "cloud_id" {
  description = "ID of the cloud."
  default     = "b1gaiq9iahfd9gh90fdp"
}

variable "folder_net" {
  description = "ID of the folder for networks."
  default     = "b1g8j75i8n1a1rgl367g"
}

variable "folder_nginx" {
  description = "ID of the folder for nginx."
  default     = "b1gpio1c0rklprhlris9"
}

variable "folder_zabbix" {
  description = "ID of the folder for zabbix."
  default     = "b1ggg1qhfnh117p1tse7"
}

variable "folder_elk" {
  description = "ID of the folder for elk."
  default     = "b1gjrmll0on5ut4uha4v"
}

variable "folder_bastion" {
  description = "ID of the folder for bastion."
  default     = "b1g9mfafl1aghlq69tc5"
}

variable "network_bastion_internal" {
  description = "Name of the internal network for Bastion."
  default     = "bastion-internal"
}

variable "subnet_bastion_internal_a" {
  description = "Internal bastion subnet in ru-central1-a."
  default     = "bastion-internal-segment-a"
}

variable "subnet_bastion_internal_b" {
  description = "Internal bastion subnet in ru-central1-b."
  default     = "bastion-internal-segment-b"
}

variable "network_bastion_external" {
  description = "Name of the external network for Bastion."
  default     = "bastion-external"
}

variable "subnet_bastion_external_a" {
  description = "External bastion subnet in ru-central1-a."
  default     = "bastion-external-segment-a"
}

variable "sg_internal_bastion" {
  description = "Security group for internal Bastion."
  default     = "internal-bastion-sg"
}

variable "sg_external_bastion" {
  description = "Security group for external Bastion."
  default     = "external-bastion-sg"
}

variable "network_web_internal" {
  description = "Name of the internal network for Web."
  default     = "web-internal"
}

variable "subnet_web_internal_a" {
  description = "Internal web subnet in ru-central1-a."
  default     = "web-internal-segment-a"
}

variable "subnet_web_internal_b" {
  description = "Internal web subnet in ru-central1-b."
  default     = "web-internal-segment-b"
}

variable "sg_internal_web" {
  description = "Security group for internal Web."
  default     = "internal-web-sg"
}

variable "bastion_image_id" {
  description = "Image ID for the web VMs."
  default     = "fd89a0bj96o8sp88tn6s"
}

variable "bastion_disk_size" {
  description = "Disk size for the web VMs in GB."
  default     = 20
}

variable "web_vm_image_id" {
  description = "Image ID for the web VMs."
  default     = "fd89a0bj96o8sp88tn6s"
}

variable "web_vm_disk_size" {
  description = "Disk size for the web VMs in GB."
  default     = 20
}

variable "ssh_public_key" {
  description = "Public SSH key to access the VMs."
  default     = "~/.ssh/id_rsa.pub"
}

variable "user_password" {
  description = "Password for the user."
  type        = string
  sensitive   = true
}