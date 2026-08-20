# Security Considerations

This document tracks the security posture of CloudMart as it's built, and the reasoning behind it. It gets filled in incrementally — each section is populated when the corresponding phase (see [ROADMAP.md](ROADMAP.md)) is implemented.

## Identity & access management
*(Phase 2, 9)*
- No use of the AWS root account for day-to-day work.
- **CLI/Terraform authentication uses AWS IAM Identity Center (SSO), not long-lived IAM access keys.** Running `aws sso login --profile cloudmart` opens a browser-based login and exchanges it for short-lived, auto-expiring temporary credentials (cached locally, never committed anywhere). Terraform's AWS provider references the `cloudmart` profile by name only — see [providers.tf](../infrastructure/terraform/providers.tf) — and has no awareness of how that profile authenticates. This eliminates the entire risk class of a long-lived secret key sitting in a config file waiting to be leaked. See [ADR 0004](decisions/0004-aws-authentication-via-iam-identity-center.md).
- The `cloudmart` profile assumes an IAM Identity Center permission set (`PowerUserAccess`) — broad, but time-boxed to the session rather than permanent, and revocable centrally from Identity Center without rotating any key.
- EC2 instances use IAM instance roles for AWS API access — never long-lived access keys baked into the instance.
- Principle of least privilege applied to every policy, documented per-resource as it's created.

## Network isolation
*(Phase 3, 4, 6)*
- Compute and data resources that don't need to be internet-facing live in private subnets.
- Security groups are scoped by reference to other security groups (e.g. "allow from the ALB's security group") rather than broad CIDR ranges wherever possible.
- Only the ALB (and, temporarily in early phases, a single EC2 instance for learning purposes) is reachable from the public internet.

## Secrets management
*(Phase 6)*
- Database credentials and any other secrets live in AWS Secrets Manager, not in environment files, Terraform variables committed to Git, or application code.
- `.gitignore` blocks `.env*`, `*.tfvars`, and common credential file patterns — see the repo root [.gitignore](../.gitignore).

## Data protection
*(Phase 6, 7)*
- RDS storage encryption at rest.
- S3 bucket for frontend assets is not publicly writable; public read access (if any) is scoped narrowly and reviewed against using CloudFront + Origin Access Control instead of a public bucket.

## Future considerations (not in current scope)
- AWS WAF in front of CloudFront/ALB — has a cost, evaluated in Phase 9 but likely deferred.
- AWS Config / Security Hub for continuous compliance monitoring — good talking point for interviews, out of scope for this project's budget.
