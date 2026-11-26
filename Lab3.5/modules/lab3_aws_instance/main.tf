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

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"] # Amazon's official AMI owner ID

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}


data "aws_subnets" "default_subnets" {
 filter {
  name = "vpc-id"
  values = ["vpc-01b6138c71cc82aba"]
 }
}

data "aws_subnet" "public_subnet" {
 id = data.aws_subnets.default_subnets.ids[0] // this will fetch first subnet
}

# Uploads your PUBLIC ssh key to AWS so the instance lets you log in with it.
resource "aws_key_pair" "lab3" {
  key_name_prefix = "lab3-"
  public_key      = file("~/.ssh/id_ed25519.pub")
}

# Firewall for the instance, created inside the existing VPC.
resource "aws_security_group" "ssh" {
  name_prefix = "lab3-ssh-"
  vpc_id      = "vpc-01b6138c71cc82aba"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # open to the internet; replace with "YOUR.IP/32" to restrict
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# The EC2 instance itself, placed in the existing subnet.
resource "aws_instance" "lab3" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.ssh.id]
  key_name                    = aws_key_pair.lab3.key_name
  associate_public_ip_address = true

  tags = {
    Name = var.instance_name
  }
}

# Printed after apply, so you know where to ssh.
output "public_ip" {
  value = aws_instance.lab3.public_ip
}

output "public_dns" {
  value = aws_instance.lab3.public_dns
}
