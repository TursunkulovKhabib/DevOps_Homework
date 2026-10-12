variable "network_name" {
  type = string
}

variable "network_subnet" {
  type = string
}

variable "volume_name" {
  type = string
}

variable "image" {
  type = string
}

variable "container_name" {
  type = string
}

variable "external_port" {
  type = number
}

variable "index_html" {
  description = "Содержимое index.html, которое кладётся в том"
  type        = string
}
