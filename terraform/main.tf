provider "docker" {
  host = var.docker_host
}

resource "docker_network" "nginx" {
  name   = "${var.name_prefix}-terraform"
  driver = "bridge"
}

resource "docker_volume" "nginx_html" {
  name = "${var.name_prefix}-nginx-html"
}

resource "docker_image" "nginx" {
  name         = var.nginx_image
  keep_locally = true
}

resource "docker_container" "nginx" {
  name    = "${var.name_prefix}-terraform-nginx"
  image   = docker_image.nginx.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.nginx.name
  }

  ports {
    internal = 80
    external = var.http_port
    ip       = var.bind_ip
  }

  # Docker заполняет новый том стандартной страницей nginx из образа.
  volumes {
    volume_name    = docker_volume.nginx_html.name
    container_path = "/usr/share/nginx/html"
    read_only      = true
  }

  healthcheck {
    test         = ["CMD-SHELL", "wget -q -O /dev/null http://127.0.0.1/ || exit 1"]
    interval     = "10s"
    timeout      = "3s"
    start_period = "5s"
    retries      = 3
  }
}
