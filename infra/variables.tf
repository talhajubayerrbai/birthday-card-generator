variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "service_name" {
  description = "Name tag applied to all resources"
  type        = string
  default     = "birthday-card-generator"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  description = "Port gunicorn listens on inside the instance"
  type        = number
  default     = 5000
}
