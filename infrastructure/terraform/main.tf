# Phase 2: connectivity verification only. These are read-only data sources —
# they query AWS but create nothing and have no cost. No application
# infrastructure (VPC, EC2, RDS, etc.) is defined yet; that starts in Phase 3.

# Confirms Terraform can authenticate to AWS at all, and tells us exactly
# which account/identity it's authenticated as.
data "aws_caller_identity" "current" {}

# Confirms Terraform can also call a regional (not just global IAM/STS) API,
# and doubles as a preview of the Availability Zones Phase 3's VPC will use.
data "aws_availability_zones" "available" {
  state = "available"
}
