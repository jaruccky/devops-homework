variable "docker_host" {
  description = "Docker API через Unix socket или SSH; открытый TCP API не используется."
  type        = string
  default     = "ssh://deployer@111.88.162.109:22"
}

variable "name_prefix" {
  description = "Префикс ресурсов задания."
  type        = string
  default     = "devops-hw1"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}$", var.name_prefix))
    error_message = "Префикс должен содержать строчные латинские буквы, цифры и дефисы."
  }
}

variable "nginx_image" {
  description = "Версионированный образ nginx; для полной фиксации можно указать digest."
  type        = string
  default     = "nginx:1.28-alpine"
}

variable "http_port" {
  description = "Нестандартный HTTP-порт Terraform nginx."
  type        = number
  default     = 8080
  validation {
    condition     = var.http_port >= 1024 && var.http_port <= 65535 && floor(var.http_port) == var.http_port
    error_message = "Нужен целый нестандартный порт в диапазоне 1024–65535."
  }
}

variable "bind_ip" {
  description = "Адрес публикации HTTP-порта на Docker-хосте."
  type        = string
  default     = "0.0.0.0"
}

variable "server_ip" {
  description = "Адрес хоста для URL проверки."
  type        = string
  default     = "111.88.162.109"
}
