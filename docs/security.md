# Security Considerations

This document tracks the security posture of CloudMart as it's built, and the reasoning behind it. It gets filled in incrementally — each section is populated when the corresponding phase (see [ROADMAP.md](ROADMAP.md)) is implemented.

## Identity & access management
*(Phase 2, 9)*
- No use of the AWS root account for day-to-day work.
- **CLI/Terraform authentication uses AWS IAM Identity Center (SSO), not long-lived IAM access keys.** Running `aws sso login --profile cloudmart` opens a browser-based login and exchanges it for short-lived, auto-expiring temporary credentials (cached locally, never committed anywhere). Terraform's AWS provider references the `cloudmart` profile by name only — see [providers.tf](../infrastructure/terraform/providers.tf) — and has no awareness of how that profile authenticates. This eliminates the entire risk class of a long-lived secret key sitting in a config file waiting to be leaked. See [ADR 0004](decisions/0004-aws-authentication-via-iam-identity-center.md).
- The `cloudmart` profile assumes an IAM Identity Center permission set (`PowerUserAccess`) — broad, but time-boxed to the session rather than permanent, and revocable centrally from Identity Center without rotating any key.
- **PowerUserAccess deliberately excludes IAM management** — confirmed the hard way in Phase 4, when creating the backend's EC2 instance role failed with `AccessDenied` on `iam:CreateRole`. This is an intentional AWS guardrail: it stops a "power user" from self-escalating to admin by creating a new role with `AdministratorAccess` and attaching it to something they control. Resolved by attaching a narrowly-scoped custom policy to the permission set — role/instance-profile management limited to `cloudmart-*`-named resources, `AttachRolePolicy` limited by condition to only the `AmazonSSMManagedInstanceCore` ARN, `PassRole` limited by condition to `iam:PassedToService = ec2.amazonaws.com` — rather than widening the whole permission set to something broader. Full writeup: [ADR 0006](decisions/0006-ec2-compute-placement-and-access.md).
- EC2 instances use IAM instance roles for AWS API access — never long-lived access keys baked into the instance. The Phase 4 backend's role is scoped to exactly `AmazonSSMManagedInstanceCore`, nothing else.
- Principle of least privilege applied to every policy, documented per-resource as it's created.

## Network isolation
*(Phase 3, 4, 6)*
- Compute and data resources that don't need to be internet-facing live in private subnets.
- Security groups are scoped by reference to other security groups (e.g. "allow from the ALB's security group") rather than broad CIDR ranges wherever possible.
- **Phase 4's backend EC2 instance has zero inbound security group rules by default** — it sits in a public subnet (a deliberate, documented Phase 4 trade-off, see [ADR 0006](decisions/0006-ec2-compute-placement-and-access.md)), but nothing is open to the internet on any port, including SSH. Access is exclusively via AWS Systems Manager (Session Manager shell, or port forwarding for the app itself), which is IAM-gated rather than network-gated. An opt-in variable exists to add a single scoped ingress rule for temporary direct access, but it defaults to empty and is never committed with a real value. Phase 5's ALB will be the only public-facing entry point going forward.

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
