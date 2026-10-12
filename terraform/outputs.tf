output "nginx_url" {
  value = "http://${var.server_ip}:${var.http_port}"
}

output "network_name" {
  value = docker_network.nginx.name
}

output "volume_name" {
  value = docker_volume.nginx_html.name
}
