variable "name" {
  description = "Name used for the load balancer and its target groups (letters, numbers and - only)"
  type        = string
}

variable "vpc_id" {
  description = "The VPC where the target groups are created"
  type        = string
}

variable "subnet_ids" {
  description = "The public subnets where the load balancer is placed (2 different zones)"
  type        = list(string)
}

variable "security_group_id" {
  description = "The security group of the load balancer"
  type        = string
}
