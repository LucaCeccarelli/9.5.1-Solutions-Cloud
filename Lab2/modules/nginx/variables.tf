# Variables
variable "image_to_use" {
  description = "The image to use"
  type        = string
  default     = "nginx:latest"
}

variable "container_memory" {
  description = "Container memory"
  type        = number
  # In MBs
  default = 100
  
  validation {
    condition     = var.container_memory >= 0
    error_message = "container_memory must be 0 or greater."
  }
}

variable "container_privileged" {
  description = "Privileged container"
  type        = bool
  default     = false
}

variable "containers_to_spawn" {
  description = "Names of the containers to spawn"
  type        = number
  default     = 1
}

variable "container_port_start_point" {
  description = "Container port starting point"
  type        = number
  default     = 8000
}
