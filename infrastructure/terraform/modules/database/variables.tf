variable "project" {
  description = "Project name, used in resource Name tags."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, prod), used in resource Name tags."
  type        = string
}

variable "vpc_id" {
  description = "VPC to launch the database and its security group into."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the DB subnet group — must span at least 2 AZs. Phase 3's private subnets satisfy this."
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Security group of the application tier allowed to reach the database (module.compute's backend security group) — the database trusts this group, never a CIDR."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version. Verify against currently AWS-supported versions (aws rds describe-db-engine-versions --engine postgres --profile cloudmart) before actual deployment — AWS periodically deprecates minor versions."
  type        = string
  default     = "16.4"
}

variable "instance_class" {
  description = "RDS instance class. db.t3.micro is the smallest practical, Free-Tier-eligible size."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Storage in GB. 20 is the RDS PostgreSQL minimum and the Free Tier storage allowance."
  type        = number
  default     = 20
}

variable "storage_type" {
  description = "EBS storage type backing the database."
  type        = string
  default     = "gp3"
}

variable "multi_az" {
  description = "Enable a synchronous standby in a second AZ with automatic failover. Roughly doubles instance + storage cost. Left false by default for cost control — see docs/decisions/0008. Flip to true only with explicit approval to actually pay for it."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Days of automated backups / point-in-time recovery window. 7 is a reasonable production-appropriate default, independent of the multi_az decision."
  type        = number
  default     = 7
}

variable "db_name" {
  description = "Initial database name created on the instance."
  type        = string
  default     = "cloudmart"
}

variable "master_username" {
  description = "Master username. The password is never set here — see manage_master_user_password in rds.tf."
  type        = string
  default     = "cloudmart_admin"
}

variable "port" {
  description = "PostgreSQL port."
  type        = number
  default     = 5432
}

variable "deletion_protection" {
  description = "Left false by default — this project intentionally destroys/redeploys infrastructure between sessions for cost control (see docs/deployment.md). Would be true for a real production deployment holding real data."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Left true by default for this learning/dev context (no real customer data yet). A real production deployment would set this false and provide final_snapshot_identifier."
  type        = bool
  default     = true
}
