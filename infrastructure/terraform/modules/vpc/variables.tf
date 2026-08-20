variable "project" {
  description = "Project name, used in resource Name tags."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, prod), used in resource Name tags."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability Zones to spread subnets across. Length must match public_subnet_cidrs and private_subnet_cidrs."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ, in the same order as availability_zones."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ, in the same order as availability_zones."
  type        = list(string)
}
