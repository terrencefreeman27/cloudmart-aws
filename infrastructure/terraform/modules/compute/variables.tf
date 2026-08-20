variable "project" {
  description = "Project name, used in resource Name tags."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, prod), used in resource Name tags."
  type        = string
}

variable "vpc_id" {
  description = "VPC to launch the instance and security group into."
  type        = string
}

variable "subnet_id" {
  description = "Public subnet to launch the instance into (must route to an Internet Gateway)."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type. Smallest practical for a small Node/Express API."
  type        = string
  default     = "t2.micro"
}

variable "app_port" {
  description = "TCP port the Express backend listens on."
  type        = number
  default     = 4000
}

variable "repo_url" {
  description = "Git URL the instance clones the application from at boot."
  type        = string
  default     = "https://github.com/terrencefreeman27/cloudmart-aws.git"
}

variable "repo_branch" {
  description = "Git branch to clone."
  type        = string
  default     = "main"
}

variable "allowed_demo_cidrs" {
  description = "CIDRs allowed to reach the app port directly. Empty by default (no ingress rule at all — use SSM port forwarding instead). Only set this via terraform.tfvars (gitignored) or -var at apply time — never commit a real IP here."
  type        = list(string)
  default     = []
}
