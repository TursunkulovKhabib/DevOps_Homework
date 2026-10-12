terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

# Новая изолированная bridge-сеть только для этого nginx
resource "docker_network" "this" {
  name   = var.network_name
  driver = "bridge"

  # gateway задан явно: иначе Docker назначает его сам, и при следующем
  # plan Terraform видит расхождение и хочет пересоздать сеть
  ipam_config {
    subnet  = var.network_subnet
    gateway = cidrhost(var.network_subnet, 1)
  }
}

# Именованный том: контент переживает пересоздание контейнера
resource "docker_volume" "content" {
  name = var.volume_name
}

resource "docker_image" "nginx" {
  name         = var.image
  keep_locally = true # не удалять образ с хоста при destroy
}

resource "docker_container" "nginx" {
  name    = var.container_name
  image   = docker_image.nginx.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.this.id
  }

  # Нестандартный порт хоста -> 80 внутри контейнера
  ports {
    internal = 80
    external = var.external_port
    protocol = "tcp"
  }

  volumes {
    volume_name    = docker_volume.content.name
    container_path = "/usr/share/nginx/html"
    read_only      = false
  }

  # Совпадает с /etc/docker/daemon.json (роль Ansible docker). Если не указать,
  # Docker подставит их сам, а провайдер увидит дрейф и пересоздаст контейнер.
  log_driver = "json-file"
  log_opts = {
    "max-size" = "10m"
    "max-file" = "3"
  }

  # Файл копируется в контейнер до старта и попадает в смонтированный том
  upload {
    file    = "/usr/share/nginx/html/index.html"
    content = var.index_html
  }

  healthcheck {
    test     = ["CMD", "wget", "-q", "--spider", "http://127.0.0.1/"]
    interval = "10s"
    timeout  = "3s"
    retries  = 3
  }
}
