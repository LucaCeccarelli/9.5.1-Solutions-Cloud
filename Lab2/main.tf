module "nginx" {
  source = "./modules/nginx"

  image_to_use = "nginx:latest"
  container_memory = "100"
  container_privileged = false
  containers_to_spawn = 3
  container_port_start_point = 800
}
