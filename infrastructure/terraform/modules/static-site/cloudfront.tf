# Looked up rather than hardcoded — same reasoning as the AMI/AZ lookups
# elsewhere in this project: AWS-managed cache policy IDs are stable but
# looking them up by name avoids ever hardcoding a UUID. Free, read-only.
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project}-${var.environment}-frontend-oac"
  description                       = "OAC for the CloudMart frontend S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = var.price_class
  comment             = "${var.project}-${var.environment} frontend"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = local.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  # React Router (client-side routing): S3 has no object at e.g.
  # /products/5, so it returns 403/404 — rewrite both to /index.html with
  # a 200 so the SPA's own router can render the right view. Without this,
  # every deep link and every page refresh on a non-root route breaks.
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # No custom domain this phase (no Route 53, no purchased domain, per
  # cost-control rules) — CloudFront's own default certificate is free
  # and requires no setup.
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.project}-${var.environment}-frontend-cdn"
  }
}

locals {
  origin_id = "${var.project}-${var.environment}-frontend-s3-origin"
}
