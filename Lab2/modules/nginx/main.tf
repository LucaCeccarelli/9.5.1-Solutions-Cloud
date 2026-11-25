terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "4.7.0"
    }
  }
}

# Create a NGINX ressource 
resource "docker_image" "nginx" {
  name = var.image_to_use
}

resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  count = var.containers_to_spawn
  name  = "nginx-${count.index}"
  ports {
    internal = 80
    external = var.container_port_start_point + count.index
  }
  command = [
    "sh", "-c",
    "sed -i \"s|</body>|<p>Hostname: $(hostname)</p></body>|\" /usr/share/nginx/html/index.html && exec nginx -g 'daemon off;'"
  ]
  memory     = var.container_memory
  privileged = var.container_privileged
}

