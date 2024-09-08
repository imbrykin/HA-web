variable "cloud_id" {
  description = "ID of the cloud."
  default     = "b1gaiq9iahfd9gh90fdp"
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

variable "subnet_bastion_internal_d" {
  description = "Internal bastion subnet in ru-central1-d."
  default     = "bastion-internal-segment-d"
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