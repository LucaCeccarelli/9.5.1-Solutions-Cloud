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
  ami                         = "ami-092c64119783c2f31"
  instance_type               = "t3.micro"
  subnet_id                   = "subnet-0855fbfcf29f845c3"
  vpc_security_group_ids      = [aws_security_group.ssh.id]
  key_name                    = aws_key_pair.lab3.key_name
  associate_public_ip_address = true

  tags = {
    Name = "lab3"
  }
}

# Printed after apply, so you know where to ssh.
output "public_ip" {
  value = aws_instance.lab3.public_ip
}
