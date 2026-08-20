# Looked up dynamically rather than hardcoded (e.g. "us-east-1a") because
# not every AWS account has the same set of AZs enabled in a region — some
# older accounts have certain lettered AZs restricted. This is a free,
# read-only API call, same as the connectivity check in Phase 2.
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Exactly 2 AZs, as required — the first two the account has available.
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source = "../../modules/vpc"

  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = local.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "compute" {
  source = "../../modules/compute"

  project       = var.project
  environment   = var.environment
  vpc_id        = module.vpc.vpc_id
  subnet_ids    = module.vpc.public_subnet_ids
  instance_type = var.instance_type
}

module "database" {
  source = "../../modules/database"

  project               = var.project
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  app_security_group_id = module.compute.backend_security_group_id
  multi_az              = var.db_multi_az
}

# Cross-tier permission, wired at the environment level rather than inside
# either module: lets the backend's existing IAM role read the database's
# auto-managed Secrets Manager secret, and nothing else. Neither module
# reaches into the other directly.
resource "aws_iam_role_policy" "backend_read_db_secret" {
  name = "${var.project}-${var.environment}-backend-read-db-secret"
  role = module.compute.ec2_iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = module.database.master_user_secret_arn
    }]
  })
}

# Independent of vpc/compute/database entirely — S3 and CloudFront aren't
# VPC resources at all, unlike every other module so far.
module "static_site" {
  source = "../../modules/static-site"

  project     = var.project
  environment = var.environment
}

# Phase 8. Only the CloudFront alarm is active today. The ALB/ASG/RDS
# alarms are OFF (enable_*_alarms = false) and deliberately NOT wired to
# module.compute/module.database's outputs at all — even referencing
# those outputs (while false) would create a Terraform dependency edge to
# those whole modules, and `-target=module.monitoring` would then try to
# satisfy it by creating their resources too. Confirmed the hard way
# during design. When Phase 5/6 are actually deployed, this block gets a
# deliberate follow-up edit: flip the relevant enable_*_alarms to true and
# set the matching identifier to the real module output — not automatic.
module "monitoring" {
  source = "../../modules/monitoring"

  project                    = var.project
  environment                = var.environment
  cloudfront_distribution_id = module.static_site.cloudfront_distribution_id
  notification_email         = var.monitoring_notification_email

  # enable_alb_alarms = true / alb_arn_suffix = module.compute.alb_arn_suffix   # after Phase 5 is deployed
  # enable_asg_alarms = true / asg_name       = module.compute.asg_name         # after Phase 5 is deployed
  # enable_rds_alarms = true / db_instance_id = module.database.db_instance_id # after Phase 6 is deployed
}
