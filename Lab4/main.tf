terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state: instead of keeping terraform.tfstate on your laptop,
  # Terraform stores it in the S3 bucket given by the teacher.
  # The DynamoDB table is a lock, so two people can't apply at the same time.
  # STEP 2 of the lab: uncomment this block
  # then run: terraform init -migrate-state
  backend "s3" {
    bucket         = "terraform-state-w9e85"
    key            = "global/s3/student_6/terraform.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-north-1"
}

# Min and max number of instances in the AutoScaling Group.
# No default: the values come from fr.tfvars or de.tfvars (-var-file=...).
variable "asg_min" {
  description = "Minimum number of instances in the ASG"
  type        = number
}

variable "asg_max" {
  description = "Maximum number of instances in the ASG"
  type        = number
}

# Lookups instead of hardcoded IDs: IDs are different in every region,
# so we ask AWS for them. This way the code works in eu-west-3 AND eu-north-1.

# Latest Amazon Linux 2 image in the current region (same as Lab 3.5).
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# The default VPC of the current region, and its subnets.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Uploads your PUBLIC ssh key to AWS so the instances let you log in with it.
resource "aws_key_pair" "lab4" {
  key_name_prefix = "lab4-"
  public_key      = file("~/.ssh/id_ed25519.pub")
}

# Firewall for the instances, created inside the existing VPC.
resource "aws_security_group" "ssh" {
  name_prefix = "lab4-ssh-"
  vpc_id      = data.aws_vpc.default.id

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

# The "recipe" of an instance: same settings as the aws_instance of Lab 3.
# The ASG uses this recipe every time it needs to start a new instance.
# terraform.workspace = name of the current workspace (france / germany).
resource "aws_launch_template" "lab4" {
  name_prefix   = "lab4-${terraform.workspace}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro" # t2 does not exist in eu-north-1
  key_name      = aws_key_pair.lab4.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ssh.id]
  }
}

# The AutoScaling Group: keeps between asg_min and asg_max instances running.
# It replaces the single aws_instance of Lab 3.
resource "aws_autoscaling_group" "lab4" {
  name_prefix         = "lab4-${terraform.workspace}-"
  min_size            = var.asg_min
  max_size            = var.asg_max
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.lab4.id
    version = "$Latest"
  }

  # Name given to every instance started by the ASG.
  tag {
    key                 = "Name"
    value               = "lab4-${terraform.workspace}"
    propagate_at_launch = true
  }
}

# Printed after apply, so you can find the ASG in the AWS console.
output "asg_name" {
  value = aws_autoscaling_group.lab4.name
}
