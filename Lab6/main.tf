terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # Used only to generate the database password.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Remote state of student 6 (database part). Student 7 has bastion.tfstate next to it.
  # region here = where the bucket is (Paris), not where we deploy.
  backend "s3" {
    bucket         = "terraform-state-w9e85"
    key            = "global/s3/student_6_7/network_rds.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-north-1"
}

# The security group of the bastion, created by student 7.
# STEP 1: leave it empty, the database is created with no access rule.
# STEP 3: paste the ID given by student 7 (sg-...) here, then terraform apply again.
variable "bastion_sg_id" {
  description = "ID of the bastion security group of student 7"
  type        = string
  default     = "sg-024bccc9c9ac2c145"
}

# The existing VPC named "Lab5-6", fetched by its name.
data "aws_vpc" "lab" {
  filter {
    name   = "tag:Name"
    values = ["Lab5-6"]
  }
}

# Subnets
# Lab 5 was destroyed, so this state creates the subnets again (same names and CIDR).
#   private  192.168.6.0/24 and 192.168.106.0/24  (the database)
#   public   192.168.7.0/24                       (the bastion of student 7)

# RDS refuses a database with private subnets in only one zone, so we need two.
resource "aws_subnet" "private_a" {
  vpc_id            = data.aws_vpc.lab.id
  cidr_block        = "192.168.6.0/24"
  availability_zone = "eu-north-1a"

  tags = {
    Name = "student_6_7_Private_a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = data.aws_vpc.lab.id
  cidr_block        = "192.168.106.0/24"
  availability_zone = "eu-north-1b"

  tags = {
    Name = "student_6_7_Private_b"
  }
}

# Public subnet: student 7 fetches it by its name and puts the bastion in it.
resource "aws_subnet" "public_a" {
  vpc_id                  = data.aws_vpc.lab.id
  cidr_block              = "192.168.7.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "student_6_7_Public_a"
  }
}

# Security group of the database
# No rule inside: the rule is a separate resource below, so it can be added later.
resource "aws_security_group" "rds" {
  name   = "student_6_7_rds"
  vpc_id = data.aws_vpc.lab.id

  tags = {
    Name = "student_6_7_rds"
  }
}

# PostgreSQL (port 5432) ONLY from the bastion security group.
# count = 0 while bastion_sg_id is empty (step 1), 1 once it is filled (step 3).
resource "aws_vpc_security_group_ingress_rule" "postgres_from_bastion" {
  count = var.bastion_sg_id == "" ? 0 : 1

  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = var.bastion_sg_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "PostgreSQL from bastion"
}

# Database
# The list of subnets where RDS is allowed to put the database.
resource "aws_db_subnet_group" "db" {
  name       = "student-6-7-db"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

# Random password, so it is never written in the code.
# No special characters: RDS refuses some of them.
resource "random_password" "db" {
  length  = 20
  special = false
}

resource "aws_db_instance" "db" {
  identifier        = "student-6-7-db"
  engine            = "postgres"
  engine_version    = "14" # the lab says 14.7, but RDS no longer offers it: "14" = newest 14.x
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "labdb"
  username = "labadmin"
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Without this, terraform destroy fails because RDS wants a final backup.
  skip_final_snapshot = true
}

# Parameter Store
# The bastion of student 7 reads these to connect to the database.
resource "aws_ssm_parameter" "username" {
  name  = "/lab6/db/student_6_7/username"
  type  = "String"
  value = aws_db_instance.db.username
}

# SecureString = stored encrypted.
resource "aws_ssm_parameter" "password" {
  name  = "/lab6/db/student_6_7/password"
  type  = "SecureString"
  value = random_password.db.result
}

resource "aws_ssm_parameter" "name" {
  name  = "/lab6/db/student_6_7/name"
  type  = "String"
  value = aws_db_instance.db.db_name
}

# address = the host name only, without ":5432".
resource "aws_ssm_parameter" "endpoint" {
  name  = "/lab6/db/student_6_7/endpoint"
  type  = "String"
  value = aws_db_instance.db.address
}

# Outputs
output "rds_sg_id" {
  value = aws_security_group.rds.id
}

output "rds_endpoint" {
  value = aws_db_instance.db.address
}

output "public_subnet_id" {
  value = aws_subnet.public_a.id
}
