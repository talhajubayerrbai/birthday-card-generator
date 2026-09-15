output "public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.app.public_ip
}

output "public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = aws_instance.app.public_dns
}

output "url" {
  description = "HTTP URL of the birthday card generator"
  value       = "http://${aws_instance.app.public_dns}"
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "ssh_private_key" {
  description = "Private key for SSH access (sensitive — never logged)"
  value       = tls_private_key.app.private_key_pem
  sensitive   = true
}

output "key_name" {
  description = "Name of the AWS key pair"
  value       = aws_key_pair.app.key_name
}
