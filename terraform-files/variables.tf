variable "cloud_id" {
  description = "ID вашего облака в Yandex.Cloud"
  type        = string
}

variable "folder_id" {
  description = "ID папки в Yandex.Cloud"
  type        = string
}

variable "zone" {
  description = "Зона доступности. Например: ru-central1-a"
  type        = string
  default     = "ru-central1-a"
}

variable "v4_cidr_blocks" {
  description = "CIDR блоки для вашей подсети. Например: 192.168.100.0/24"
  type        = list(string)
  default     = ["192.168.100.0/24"]
}

variable "vm_count" {
  description = "Количество создаваемых VM. Например: 2"
  type        = number
  default     = 2
}

variable "image_id" {
  description = "ID образа для VM. Например (Debian в YC): fd8s17cfki4sd4l6oa59"
  type        = string
  default     = "fd8s17cfki4sd4l6oa59"
}

variable "disk_size" {
  description = "Размер диска для VM (в ГБ). 5 ГБ по умолчанию."
  type        = number
  default     = 5
}

variable "vm_cores" {
  description = "Количество ядер для каждой VM (2 по умолчанию)"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "Объем памяти для каждой VM (в ГБ). 2 ГБ по умолчанию."
  type        = number
  default     = 2
}

variable "network_name" {
  description = "Имя сети. Например: network2"
  type        = string
  default     = "network2"
}

variable "subnet_name" {
  description = "Имя подсети. Например: subnet2"
  type        = string
  default     = "subnet2"
}

variable "lb_name" {
  description = "Имя сетевого балансировщика. Например: lb-1"
  type        = string
  default     = "lb-1"
}

variable "target_group_name" {
  description = "Имя target group для сетевого балансировщика нагрузки. Например: testgroup1"
  type        = string
  default     = "testgroup1"
}
