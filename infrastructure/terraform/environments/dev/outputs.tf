output "vpc_id" {
  description = "ID of the CloudMart dev VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = module.vpc.vpc_cidr
}

output "availability_zones" {
  description = "Availability Zones used by this environment."
  value       = module.vpc.availability_zones
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = module.vpc.private_subnet_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = module.vpc.internet_gateway_id
}

output "backend_instance_id" {
  description = "ID of the backend EC2 instance."
  value       = module.compute.instance_id
}

output "backend_public_ip" {
  description = "Public IP of the backend instance. Changes on every stop/start — no Elastic IP is used."
  value       = module.compute.public_ip
}

output "backend_security_group_id" {
  description = "ID of the backend security group."
  value       = module.compute.security_group_id
}
