# Этап 2 (вариант с docker-провайдером): nginx в собственной новой сети
# с подключённым томом, доступный по HTTP на нестандартном порту.
# Ресурсы описаны в модуле modules/nginx_web.
module "nginx_web" {
  source = "./modules/nginx_web"

  network_name   = var.network_name
  network_subnet = var.network_subnet
  volume_name    = var.volume_name
  image          = var.nginx_image
  container_name = var.container_name
  external_port  = var.external_port
  index_html = templatefile("${path.module}/templates/index.html.tftpl", {
    network = var.network_name
    volume  = var.volume_name
    port    = var.external_port
  })
}
