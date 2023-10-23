variable "cloud_id" {
  description = "ID вашего облака в Yandex.Cloud. Например: b1g2445ompelboq61fkg"
  type        = string
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
  description = "ID образа для VM. Например (Debian в YC): fd8s17cfki4sd4l6oa59"
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

//Нужно раскомментировать для создания новой сети и подсети. Тоже самое сделать в main.tf

//variable "v4_cidr_blocks" {
//  description = "CIDR блок для вашей подсети. Например: 192.168.1.0/24"
//  type        = string
//}

variable "v4_cidr_blocks" {
  description = "CIDR блок для вашей подсети. Например: 192.168.1.0/24"
  type        = string
  default     = "" # Установите значение по умолчанию как пустую строку, если не хотите задавать это значение каждый раз.
}

variable "existing_subnet_id" {
  description = "ID существующей подсети. Эту переменную следует задавать только в том случае, если будет использована существующая подсеть."
  type        = string
  default     = "" # Установите значение по умолчанию как пустую строку, если не хотите задавать это значение каждый раз.
}

variable "network_name" {
  description = "Имя сети. Например: network2"
  type        = string
}

variable "subnet_name" {
  description = "Имя подсети. Например: subnet2"
  type        = string
}

variable "use_existing_network" {
  description = "Использовать существующую сеть или нет? Введите true или false"
  type        = bool
}

variable "existing_network_id" {
  description = "ID существующей сети. Эту переменную следует задавать только в том случае, если будет использована существующая подсеть. Например: enp5gv5qt53unvd3io2t"
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