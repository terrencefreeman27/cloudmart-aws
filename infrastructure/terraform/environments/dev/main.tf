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

  project            = var.project
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  subnet_id          = module.vpc.public_subnet_ids[0]
  instance_type      = var.instance_type
  allowed_demo_cidrs = var.allowed_demo_cidrs
}
