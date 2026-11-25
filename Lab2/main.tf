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
  containers_to_spawn = 1
  container_port_start_point = 800
}

module "celian_lab2" {
  source = "git::github.com/Cessouille/clouds-lab2/modules/nginx"
  container_number = 3
}
