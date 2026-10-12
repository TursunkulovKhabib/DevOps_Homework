# Провайдер управляет Docker на VM через SSH: локально запускается
# `ssh <user>@<host> docker system dial-stdio`. Отдельный пользователь
# terraform состоит только в группе docker — ни sudo, ни пароля у него нет.
provider "docker" {
  host = "ssh://${var.docker_ssh_user}@${var.vm_host}:${var.ssh_port}"

  # ControlMaster: все запросы провайдера идут через одно SSH-соединение.
  # Без этого провайдер открывает соединение на каждый ресурс и упирается
  # в rate-limit ufw на порту 22 (6 подключений за 30 с) -> "Connection refused".
  ssh_opts = [
    "-i", pathexpand(var.ssh_private_key_path),
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "BatchMode=yes",
    "-o", "ControlMaster=auto",
    "-o", "ControlPath=/tmp/tf-docker-%r@%h-%p",
    "-o", "ControlPersist=120",
  ]
}
