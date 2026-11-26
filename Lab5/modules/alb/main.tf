terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# The application load balancer, open to the internet, on the public subnets.
resource "aws_lb" "alb" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = [var.security_group_id]
}

# A target group = a list of instances the load balancer can send traffic to.
# They are empty here: the ASGs of student 7 register their instances in them.
resource "aws_lb_target_group" "nginx" {
  name     = "${var.name}-nginx"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group" "tomcat" {
  name     = "${var.name}-tomcat"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

# The listener: the load balancer listens on port 80.
# If no rule below matches the path, it answers 404.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Use /nginx or /tomcat"
      status_code  = "404"
    }
  }
}

# Rule: path /nginx -> nginx target group.
resource "aws_lb_listener_rule" "nginx" {
  listener_arn = aws_lb_listener.http.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx.arn
  }

  condition {
    path_pattern {
      values = ["/nginx", "/nginx/*"]
    }
  }
}

# Rule: path /tomcat -> tomcat target group.
resource "aws_lb_listener_rule" "tomcat" {
  listener_arn = aws_lb_listener.http.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tomcat.arn
  }

  condition {
    path_pattern {
      values = ["/tomcat", "/tomcat/*"]
    }
  }
}

output "dns_name" {
  value = aws_lb.alb.dns_name
}

output "nginx_target_group_arn" {
  value = aws_lb_target_group.nginx.arn
}

output "tomcat_target_group_arn" {
  value = aws_lb_target_group.tomcat.arn
}
