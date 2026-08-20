variable "aws_region" {
  description = "AWS region CloudMart infrastructure is deployed into."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile Terraform authenticates with (backed by IAM Identity Center SSO — see docs/decisions/0004)."
  type        = string
  default     = "cloudmart"
}

variable "project" {
  description = "Project name, applied as a tag to every resource."
  type        = string
  default     = "cloudmart"
}

variable "environment" {
  description = "Environment name for this root configuration."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for the backend server. t2.micro is the smallest practical size and the one AWS Free Tier covers in us-east-1 (t3.micro is not Free Tier eligible here)."
  type        = string
  default     = "t2.micro"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for the database (synchronous standby, automatic failover, roughly doubles RDS cost). False by default for cost control — see docs/decisions/0008. Only flip this with explicit approval to pay for it."
  type        = bool
  default     = false
}

variable "monitoring_notification_email" {
  description = "Email to subscribe to the CloudWatch alarm SNS topic. Empty by default — no subscription is created. Never set a real value here; override via terraform.tfvars (gitignored) or -var only."
  type        = string
  default     = ""
}
