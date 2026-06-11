# Terraform Settings Block
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

# Input Variables Block
variable "custom_hostname" {
  type        = string
  description = "The base hostname prefix for the EC2 instances"
}

variable "instance_count" {
  type        = number
  description = "Number of EC2 instances to deploy across different AZs"
}

# Provider Block
provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

# Data Sources to automatically discover Default VPC networks
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Security Group Block
resource "aws_security_group" "web_sg" {
  name        = "allow-http-traffic"
  description = "Allow inbound HTTP traffic on port 80"

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "house"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["108.56.142.211/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Resource Block using Count for Multi-AZ deployment
resource "aws_instance" "ec2demo" {
  count         = var.instance_count
  ami           = "ami-00e801948462f718a" # Amazon Linux in us-east-1
  instance_type = "t3.micro"
  key_name      = "703demo-keypair"

  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname ${var.custom_hostname}-${count.index}
              
              dnf update -y
              dnf install -y httpd
              systemctl start httpd
              systemctl enable httpd
              
              echo "welcome to AK world from server ${count.index}" > /var/www/html/index.html
              EOF

  tags = {
    Name = "${var.custom_hostname}-${count.index}"
  }
}

# 1. The Application Load Balancer
resource "aws_lb" "demo_alb" {
  name               = "demo-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = data.aws_subnets.default.ids # Deploys ALB across your default public subnets

  tags = {
    Name = "demo-alb"
  }
}

# 2. ALB Target Group (Directs traffic to the EC2 instances)
resource "aws_lb_target_group" "demo_tg" {
  name     = "demo-alb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    port                = "80"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
}

# 3. ALB Listener (Listens on port 80 and forwards to Target Group)
resource "aws_lb_listener" "demo_listener" {
  load_balancer_arn = aws_lb.demo_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demo_tg.arn
  }
}

# 4. Target Group Attachment Loop (Attaches all created instances to the ALB)
resource "aws_lb_target_group_attachment" "demo_attachment" {
  count            = var.instance_count
  target_group_arn = aws_lb_target_group.demo_tg.arn
  target_id        = aws_instance.ec2demo[count.index].id
  port             = 80
}

# 5. Output Block to print the final website link
output "alb_dns_name" {
  value       = "http://${aws_lb.demo_alb.dns_name}"
  description = "The public URL to open your load-balanced website"
}
