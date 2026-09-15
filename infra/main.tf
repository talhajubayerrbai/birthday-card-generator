terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
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
# SSH key pair — generated once, stored in state; private key passed to
# the Ansible deploy job via a masked step output.
# ---------------------------------------------------------------------------
resource "tls_private_key" "app" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "app" {
  key_name   = "${var.service_name}-key"
  public_key = tls_private_key.app.public_key_openssh

  tags = {
    Name    = "${var.service_name}-key"
    Service = var.service_name
  }

  lifecycle {
    # Never replace the key pair once created — replacement would lock out
    # any existing instances.
    ignore_changes = [public_key]
  }
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
# Security group — open 80 (HTTP), 5000 (gunicorn direct) and 22 (SSH)
# ---------------------------------------------------------------------------
resource "aws_security_group" "app" {
  name        = "${var.service_name}-sg"
  description = "HTTP + alt-HTTP + SSH for ${var.service_name}"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Gunicorn direct"
    from_port   = 5000
    to_port     = 5000
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
# EC2 instance — NO user_data; Ansible does all app provisioning
# ---------------------------------------------------------------------------
resource "aws_instance" "app" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = tolist(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = aws_key_pair.app.key_name
  associate_public_ip_address = true

  # No user_data — instance boots clean; Ansible deploys the app over SSH.

  tags = {
    Name    = var.service_name
    Service = var.service_name
  }
}
