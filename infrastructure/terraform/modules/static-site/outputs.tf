output "bucket_name" {
  description = "Name of the S3 bucket holding the frontend build. Private — not directly browsable."
  value       = aws_s3_bucket.frontend.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.frontend.arn
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution — needed for cache invalidations after a future deploy."
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain_name" {
  description = "CloudFront's default domain. The public HTTPS URL for the frontend, once assets are uploaded, is https://<value>."
  value       = aws_cloudfront_distribution.frontend.domain_name
}
