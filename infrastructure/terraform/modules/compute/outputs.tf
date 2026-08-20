output "instance_id" {
  description = "ID of the backend EC2 instance."
  value       = aws_instance.backend.id
}

output "security_group_id" {
  description = "ID of the backend security group."
  value       = aws_security_group.backend.id
}

output "public_ip" {
  description = "Public IP of the backend instance. Changes on every stop/start — no Elastic IP is used."
  value       = aws_instance.backend.public_ip
}
