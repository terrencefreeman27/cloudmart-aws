variable "project" {
  description = "Project name, used in resource Name tags and the bucket name."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, prod), used in resource Name tags and the bucket name."
  type        = string
}

variable "price_class" {
  description = "CloudFront price class. PriceClass_100 = US/Canada/Europe edge locations only (cheapest). PriceClass_All = every edge location worldwide (priciest, best global performance). Defaults to the cheapest option — upgrade explicitly if global reach is actually needed."
  type        = string
  default     = "PriceClass_100"
}
