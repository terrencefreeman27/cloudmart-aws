variable "aws_region" {
  description = "AWS region CloudMart infrastructure is deployed into."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile Terraform authenticates with (see ~/.aws/credentials). Never hardcode actual credentials here."
  type        = string
  default     = "cloudmart"
}

variable "project" {
  description = "Project name, applied as a tag to every resource for cost tracking and identification."
  type        = string
  default     = "cloudmart"
}
