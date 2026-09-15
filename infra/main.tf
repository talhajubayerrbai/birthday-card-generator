terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # bucket, key and region are passed via -backend-config flags at runtime
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# Resolve latest Amazon Linux 2023 AMI
# ---------------------------------------------------------------------------
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# Default VPC & first public subnet
# ---------------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ---------------------------------------------------------------------------
# Security group - open 80 (HTTP) and 22 (SSH) to the world
# ---------------------------------------------------------------------------
resource "aws_security_group" "app" {
  name        = "${var.service_name}-sg"
  description = "HTTP + SSH for ${var.service_name}"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.service_name}-sg"
    Service = var.service_name
  }
}

# ---------------------------------------------------------------------------
# User-data: install Python 3, clone repo, run gunicorn via systemd on :5000
# then redirect port 80 -> 5000 with iptables
# NOTE: heredoc uses no indentation so the systemd unit is written correctly
# ---------------------------------------------------------------------------
locals {
  user_data = <<-USERDATA
#!/bin/bash
set -euxo pipefail
exec > /var/log/userdata.log 2>&1

# System packages
dnf install -y python3 python3-pip git iptables-services

# Redirect port 80 -> 5000 (gunicorn runs as non-root)
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 5000
iptables -t nat -A OUTPUT     -p tcp --dport 80 -j REDIRECT --to-port 5000
service iptables save || true

# Clone the application
APP_DIR=/opt/birthday-card-generator
rm -rf "$APP_DIR"
git clone https://github.com/talhajubayerrbai/birthday-card-generator.git "$APP_DIR"

# Install Python dependencies
pip3 install -r "$APP_DIR/requirements.txt"

# Systemd service unit (no leading whitespace)
cat > /etc/systemd/system/birthday-card.service <<'UNIT'
[Unit]
Description=Birthday Card Generator (gunicorn)
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/opt/birthday-card-generator
Environment=DB_PATH=/opt/birthday-card-generator/cards.db
ExecStart=/usr/local/bin/gunicorn app:app --bind 0.0.0.0:5000 --workers 2
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable birthday-card
systemctl start  birthday-card
USERDATA
}

# ---------------------------------------------------------------------------
# EC2 instance
# ---------------------------------------------------------------------------
resource "aws_instance" "app" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = tolist(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true

  user_data                   = local.user_data
  user_data_replace_on_change = true

  tags = {
    Name    = var.service_name
    Service = var.service_name
  }
}
