terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state, in the shared "directory" student_6_7 of the teacher's bucket.
  # This file is the NETWORK state (student 6). Student 7 has ec2.tfstate next to it.
  # region here = where the bucket is (Paris), not where we deploy.
  backend "s3" {
    bucket         = "terraform-state-w9e85"
    key            = "global/s3/student_6_7/network.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-north-1"
}

# The existing VPC named "Lab5-6", fetched by its name (data source = read only).
# Its CIDR is 192.168.0.0/16, so our subnets are 192.168.<something>.0/24.
data "aws_vpc" "lab" {
  filter {
    name   = "tag:Name"
    values = ["Lab5-6"]
  }
}

# Subnets
# X = 6 and Y = 7 are the "network identifiers":
#   private  192.168.6.0/24
#   public   192.168.7.0/24 and 192.168.107.0/24

# Public subnet in availability zone a.
# map_public_ip_on_launch = what is started here gets a public IP.
resource "aws_subnet" "public_a" {
  vpc_id                  = data.aws_vpc.lab.id
  cidr_block              = "192.168.7.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "student_6_7_Public_a"
  }
}

# Public subnet in availability zone b (a load balancer needs 2 different zones).
resource "aws_subnet" "public_b" {
  vpc_id                  = data.aws_vpc.lab.id
  cidr_block              = "192.168.107.0/24"
  availability_zone       = "eu-north-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "student_6_7_Public_b"
  }
}

# Private subnet: no public IP, so not reachable from the internet.
# It must be in zone a or b: the load balancer only talks to its own zones.
resource "aws_subnet" "private" {
  vpc_id            = data.aws_vpc.lab.id
  cidr_block        = "192.168.6.0/24"
  availability_zone = "eu-north-1a"

  tags = {
    Name = "student_6_7_Private"
  }
}

# Security groups
# The real name has our student numbers in front, because two security groups
# in the same VPC cannot have the same name (other students also create "public").

# public: http and https from the internet. Used by the load balancer.
resource "aws_security_group" "public" {
  name   = "student_6_7_public"
  vpc_id = data.aws_vpc.lab.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "public"
  }
}

# internal: http and https ONLY from things that have the public security group
# (= the load balancer). Used by the instances of student 7.
resource "aws_security_group" "internal" {
  name   = "student_6_7_internal"
  vpc_id = data.aws_vpc.lab.id

  ingress {
    description     = "HTTP from public"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.public.id]
  }

  ingress {
    description     = "HTTPS from public"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.public.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "internal"
  }
}

# Load balancer
# Our module: an application load balancer on the two public subnets.
module "alb" {
  source = "./modules/alb"

  name              = "student-6-7" # no underscore allowed in load balancer names
  vpc_id            = data.aws_vpc.lab.id
  subnet_ids        = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_group_id = aws_security_group.public.id
}

# Outputs
# Saved in network.tfstate. Student 7 reads them from ec2.tfstate
# with a "terraform_remote_state" data source.

output "vpc_id" {
  value = data.aws_vpc.lab.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "public_sg_id" {
  value = aws_security_group.public.id
}

output "internal_sg_id" {
  value = aws_security_group.internal.id
}

# Student 7 attaches the nginx ASG and the tomcat ASG to these.
output "nginx_target_group_arn" {
  value = module.alb.nginx_target_group_arn
}

output "tomcat_target_group_arn" {
  value = module.alb.tomcat_target_group_arn
}

# The address to open in a browser: http://<alb_dns_name>/nginx
output "alb_dns_name" {
  value = module.alb.dns_name
}
