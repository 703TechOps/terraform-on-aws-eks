# Terraform Settings Block
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      #version = "~> 6.4" # Optional but recommended in production
    }
  }
}

# Provider Block
provider "aws" {
  profile = "default" # AWS Credentials Profile configured on your local desktop terminal  $HOME/.aws/credentials
  region  = "us-east-1"
}

# Security Group Block (Opens Port 80 for HTTP)
resource "aws_security_group" "web_sg" {
  name        = "allow-http-traffic"
  description = "Allow inbound HTTP traffic on port 80"

  # Inbound Rules
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allows anyone on the internet to visit the site
  }

  # Outbound Rules (Required to download httpd packages during boot)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allows all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Resource Block
resource "aws_instance" "ec2demo" {
  ami           = "ami-00e801948462f718a" # Amazon Linux in us-east-1
  instance_type = "t3.micro"

  # Link your existing AWS Key Pair here
  key_name      = "703demo-keypair"

  # Attach the newly created security group to this instance
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Sets the hostname, installs Apache, and writes the custom index.html file
  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname my-custom-hostname
              
              # Install Apache Web Server
              dnf update -y
              dnf install -y httpd
              
              # Start Apache and enable it to start on system boot
              systemctl start httpd
              systemctl enable httpd
              
              # Write the custom HTML content
              echo "welcome to AK world" > /var/www/html/index.html
              EOF

  # Sets the display name in the AWS Console
  tags = {
    Name = "AK-hostname"
  }
}
