terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-3"
}

module "lab3_aws_instance" {
  source = "./modules/lab3_aws_instance"

  instance_type = "t2.micro"
  instance_name = "lab3"

}

output "public_ip" {
  description = "Public IP of the instance"
  value       = module.lab3_aws_instance.public_ip
}

output "public_dns" {
  description = "Public DNS name of the instance"
  value       = module.lab3_aws_instance.public_dns
}