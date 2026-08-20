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

output "alb_dns_name" {
  description = "Public URL for the CloudMart backend: http://<value>. Stable across instance replacements, unlike Phase 4's per-restart-changing instance IP."
  value       = module.compute.alb_dns_name
}

output "target_group_arn" {
  description = "ARN of the backend target group."
  value       = module.compute.target_group_arn
}

output "asg_name" {
  description = "Name of the backend Auto Scaling Group."
  value       = module.compute.asg_name
}

output "alb_security_group_id" {
  description = "ID of the ALB security group."
  value       = module.compute.alb_security_group_id
}

output "backend_security_group_id" {
  description = "ID of the backend security group."
  value       = module.compute.backend_security_group_id
}

output "db_endpoint" {
  description = "Database connection endpoint (host:port). Known only after apply."
  value       = module.database.db_endpoint
}

output "db_security_group_id" {
  description = "ID of the database security group."
  value       = module.database.db_security_group_id
}

output "db_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the database master password — AWS-managed, the password itself is never in Terraform state or this repo."
  value       = module.database.master_user_secret_arn
}

output "frontend_bucket_name" {
  description = "Private S3 bucket holding the frontend build — not directly browsable, CloudFront-only access."
  value       = module.static_site.bucket_name
}

output "frontend_cloudfront_distribution_id" {
  description = "CloudFront distribution ID — needed for cache invalidations after a future deploy."
  value       = module.static_site.cloudfront_distribution_id
}

output "frontend_url" {
  description = "Public HTTPS URL for the live frontend."
  value       = "https://${module.static_site.cloudfront_domain_name}"
}

output "alarm_sns_topic_arn" {
  description = "ARN of the CloudWatch alarm notification topic."
  value       = module.monitoring.sns_topic_arn
}

output "active_alarm_count" {
  description = "How many CloudWatch alarms actually exist right now — the rest are designed but inert until Phase 5/6 are deployed."
  value       = module.monitoring.active_alarm_count
}
