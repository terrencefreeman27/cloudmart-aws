variable "project" {
  description = "Project name, used in resource Name tags."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, prod), used in resource Name tags."
  type        = string
}

variable "vpc_id" {
  description = "VPC to launch the ALB, Auto Scaling Group, and security groups into."
  type        = string
}

variable "subnet_ids" {
  description = "Public subnets for the ALB and Auto Scaling Group — must span at least 2 AZs and route to an Internet Gateway (no NAT Gateway is used, so instances need their own outbound path)."
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type for backend instances. Smallest practical for a small Node/Express API."
  type        = string
  default     = "t2.micro"
}

variable "app_port" {
  description = "TCP port the Express backend listens on."
  type        = number
  default     = 4000
}

variable "health_check_path" {
  description = "Path the target group polls to determine instance health."
  type        = string
  default     = "/api/health"
}

variable "desired_capacity" {
  description = "Number of backend instances to run, fixed (no dynamic scaling policies in this phase, to keep cost predictable)."
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum backend instances."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum backend instances."
  type        = number
  default     = 2
}

variable "repo_url" {
  description = "Git URL each instance clones the application from at boot."
  type        = string
  default     = "https://github.com/terrencefreeman27/cloudmart-aws.git"
}

variable "repo_branch" {
  description = "Git branch to clone."
  type        = string
  default     = "main"
}
