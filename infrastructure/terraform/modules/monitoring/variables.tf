variable "project" {
  description = "Project name, used in resource Name tags and alarm naming."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, prod), used in resource Name tags and alarm naming."
  type        = string
}

variable "notification_email" {
  description = "Email address to subscribe to the alarm SNS topic. Empty by default — no subscription is created, and alarms still work (visible in the CloudWatch console), just without a notification channel. Never hardcode a real email here or in any tracked file; supply it via terraform.tfvars (gitignored) or -var if you want notifications."
  type        = string
  default     = ""
}

# --- CloudFront (always active — the distribution is deployed) ---

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID to alarm on."
  type        = string
}

# --- ALB / ASG / RDS alarms ---
#
# Deliberately plain booleans + plain strings, NOT references to
# module.compute/module.database's outputs. A reference like
# `module.compute.alb_arn_suffix` would create a Terraform dependency
# edge to that entire module — even while its value is null — and a
# `-target=module.monitoring` plan/apply would then try to satisfy that
# dependency by creating module.compute's resources too. Confirmed the
# hard way: an earlier version of this module using module output
# references caused exactly that when plan-tested. Decoupling with plain
# variables means enabling these alarms is a deliberate, explicit action
# taken when Phase 5/6 are actually deployed — flip the boolean and set
# the identifier at that point — never an accidental side effect of
# planning/applying monitoring alone.

variable "enable_alb_alarms" {
  description = "Create the ALB alarms. False until Phase 5 is deployed."
  type        = bool
  default     = false
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch dimensions. Only meaningful when enable_alb_alarms = true."
  type        = string
  default     = ""
}

variable "enable_asg_alarms" {
  description = "Create the ASG/EC2 CPU alarm. False until Phase 5 is deployed."
  type        = bool
  default     = false
}

variable "asg_name" {
  description = "Auto Scaling Group name for CloudWatch dimensions. Only meaningful when enable_asg_alarms = true."
  type        = string
  default     = ""
}

variable "enable_rds_alarms" {
  description = "Create the RDS alarms. False until Phase 6 is deployed."
  type        = bool
  default     = false
}

variable "db_instance_id" {
  description = "RDS instance identifier for CloudWatch dimensions. Only meaningful when enable_rds_alarms = true."
  type        = string
  default     = ""
}
