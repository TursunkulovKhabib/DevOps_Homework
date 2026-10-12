output "network_id" {
  value = docker_network.this.id
}

output "volume_name" {
  value = docker_volume.content.name
}

output "container_name" {
  value = docker_container.nginx.name
}
