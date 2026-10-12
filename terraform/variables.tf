variable "vm_host" {
  description = "IP или DNS-имя VM с Docker Engine (подготовлена Ansible-плейбуком setup_host.yml)"
  type        = string
}

variable "ssh_port" {
  description = "SSH-порт VM"
  type        = number
  default     = 22
}

variable "docker_ssh_user" {
  description = "Пользователь на VM для доступа к Docker (только группа docker, без sudo)"
  type        = string
  default     = "terraform"
}

variable "ssh_private_key_path" {
  description = "Путь к приватному SSH-ключу"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "network_name" {
  description = "Имя отдельной Docker-сети для nginx"
  type        = string
  default     = "tf-web-net"
}

variable "network_subnet" {
  description = "Подсеть Docker-сети (не должна пересекаться с сетями Compose)"
  type        = string
  default     = "172.30.0.0/24"
}

variable "volume_name" {
  description = "Имя Docker-тома с контентом nginx"
  type        = string
  default     = "tf-web-content"
}

variable "nginx_image" {
  description = "Образ nginx (с фиксированной версией)"
  type        = string
  default     = "nginx:1.27-alpine"
}

variable "container_name" {
  description = "Имя контейнера nginx"
  type        = string
  default     = "tf-nginx"
}

variable "external_port" {
  description = "Нестандартный порт хоста, на котором nginx отвечает по HTTP"
  type        = number
  default     = 8081

  validation {
    condition     = var.external_port >= 1024 && var.external_port <= 65535 && !contains([8080], var.external_port)
    error_message = "Порт должен быть нестандартным (1024–65535); 80/443 и 8080 не используем."
  }
}
