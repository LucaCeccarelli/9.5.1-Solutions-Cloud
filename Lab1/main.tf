terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "4.7.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}


# Create a NGINX ressource 
resource "docker_image" "nginx" {
  name         = "nginx:latest"
}

resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "tutorial"
  ports {
    internal = 80
    external = 8000
  }
  command = [
    "sh", "-c",
    "sed -i \"s|</body>|<p>Hostname: $(hostname)</p></body>|\" /usr/share/nginx/html/index.html && exec nginx -g 'daemon off;'"
  ]
}

