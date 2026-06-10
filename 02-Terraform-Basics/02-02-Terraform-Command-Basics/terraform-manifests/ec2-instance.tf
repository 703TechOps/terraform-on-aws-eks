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

# Resource Block
resource "aws_instance" "ec2demo" {
  ami           = "ami-00e801948462f718a" # Amazon Linux in us-east-1, update as per your region
  instance_type = "t3.micro"

  # Link your existing AWS Key Pair here
  key_name      = "703demo-keypair"

  # Sets the hostname, installs Apache, and writes the custom index.html file
  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname c2-demo-terraform"
              
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
    Name = "ec2-demo-terraform"
  }
}
