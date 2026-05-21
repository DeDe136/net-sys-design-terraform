packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1.2"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "ami_prefix" {
  type    = string
  default = "prod-web-portal"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "web_portal" {
  ami_name      = "${var.ami_prefix}-${local.timestamp}"
  instance_type = "t3.micro"
  region        = var.aws_region

  # Use Amazon Linux 2 base image
  source_ami_filter {
    filters = {
      name                = "amzn2-ami-hvm-*-x86_64-gp2"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }

  tags = {
    Name        = "${var.ami_prefix}-image"
    Environment = "production"
    ManagedBy   = "packer"
  }

  ami_tags = {
    Name        = "${var.ami_prefix}-image"
    Environment = "production"
    ManagedBy   = "packer"
  }

  run_tags = {
    Name = "${var.ami_prefix}-build"
  }
}

build {
  name = "web-portal-ami"
  sources = [
    "source.amazon-ebs.web_portal"
  ]

  # Update system packages
  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "echo '[STEP 1] Updating system packages...'",
      "yum update -y",
      "echo '[STEP 1] ✓ Complete'"
    ]
  }

  # Install Nginx
  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "echo '[STEP 2] Installing Nginx...'",
      "yum install -y nginx",
      "echo '[STEP 2] ✓ Complete'"
    ]
  }

  # Create web content directory
  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "mkdir -p /var/www/html",
      "chown -R nginx:nginx /var/www/html"
    ]
  }

  # Copy HTML index file
  provisioner "file" {
    source      = "${path.root}/index.html"
    destination = "/tmp/index.html"
  }

  # Copy Nginx configuration
  provisioner "file" {
    source      = "${path.root}/web-portal.conf"
    destination = "/tmp/web-portal.conf"
  }

  # Move files and set permissions
  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "echo '[STEP 3] Configuring Nginx...'",
      "mv /tmp/index.html /var/www/html/index.html",
      "chown nginx:nginx /var/www/html/index.html",
      "chmod 644 /var/www/html/index.html",
      "mv /tmp/web-portal.conf /etc/nginx/conf.d/web-portal.conf",
      "chown root:root /etc/nginx/conf.d/web-portal.conf",
      "chmod 644 /etc/nginx/conf.d/web-portal.conf",
      "echo '[STEP 3] ✓ Complete'"
    ]
  }

  # Test Nginx configuration
  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "echo '[STEP 4] Testing Nginx configuration...'",
      "nginx -t",
      "echo '[STEP 4] ✓ Complete'"
    ]
  }

  # Enable Nginx to start on boot
  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "echo '[STEP 5] Enabling Nginx service...'",
      "systemctl enable nginx",
      "echo '[STEP 5] ✓ Complete'"
    ]
  }

  # Create log files for monitoring
  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "touch /var/log/nginx-startup.log",
      "chown nginx:nginx /var/log/nginx-startup.log"
    ]
  }

  # Cleanup
  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "echo '[CLEANUP] Cleaning up...'",
      "yum clean all",
      "rm -rf /tmp/*",
      "echo '[CLEANUP] ✓ Complete'",
      "echo '[BUILD] Custom AMI is ready!'"
    ]
  }
}
