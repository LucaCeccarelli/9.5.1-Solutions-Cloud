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

module "nginx" {
  source = "./modules/nginx"

  image_to_use = "nginx:latest"
  container_memory = "100"
  container_privileged = false
  containers_to_spawn = 3
  container_port_start_point = 800
}

