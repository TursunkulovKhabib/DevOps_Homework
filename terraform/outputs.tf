output "url" {
  description = "Адрес nginx"
  value       = "http://${var.vm_host}:${var.external_port}"
}

output "network_id" {
  value = module.nginx_web.network_id
}

output "volume_name" {
  value = module.nginx_web.volume_name
}

output "container_name" {
  value = module.nginx_web.container_name
}
