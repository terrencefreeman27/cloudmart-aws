# CloudMart frontend hosting — Phase 7.
#
# S3 bucket names are globally unique across ALL AWS accounts, not just
# this one — the account ID is appended to guarantee uniqueness without
# adding a random-suffix provider dependency, reusing a data source
# already established in this project's bootstrap config (Phase 2).
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project}-${var.environment}-frontend-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project}-${var.environment}-frontend"
  }
}

# All four public-access blocks left on (the strictest setting). This is
# safe alongside the CloudFront-only bucket policy in bucket_policy.tf:
# AWS's public-access detection only flags policies granting access to
# "everyone"/"*" — a policy scoped to a specific AWS service principal
# with a SourceArn condition (as ours is) is never considered public, so
# nothing here blocks CloudFront's own access.
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Protects against accidental overwrite/deletion of a deployed build and
# enables rollback to a prior version — negligible extra storage cost at
# this site's scale.
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-S3 (AES256), not SSE-KMS: free, and OAC works fine with it — a
# customer-managed KMS key is only needed for tighter key-management
# requirements this project doesn't have, and has its own small per-request
# cost this design avoids.
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
