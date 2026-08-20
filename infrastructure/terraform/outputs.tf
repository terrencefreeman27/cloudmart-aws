output "aws_account_id" {
  description = "AWS account ID Terraform is currently authenticated against — confirms you're pointed at the right account."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_caller_arn" {
  description = "IAM identity (user or role) Terraform is currently using."
  value       = data.aws_caller_identity.current.arn
}

output "configured_region" {
  description = "AWS region this configuration is set to operate in."
  value       = var.aws_region
}

output "available_azs" {
  description = "Availability Zones available in the configured region (Phase 3 will spread the VPC across two of these)."
  value       = data.aws_availability_zones.available.names
}
