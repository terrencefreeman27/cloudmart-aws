# Terraform Modules

Reusable, environment-agnostic building blocks — no hardcoded environment-specific values (those belong in [../environments/](../environments/)).

## `vpc/` (Phase 3) — deployed, standing
VPC, public/private subnets across 2 AZs, Internet Gateway, route tables and associations. No security groups (those live with the compute that uses them) and no NAT Gateway (deliberately deferred — see [docs/decisions/0005](../../../docs/decisions/0005-vpc-network-design.md)). Called from [`environments/dev`](../environments/dev/). See [docs/networking.md](../../../docs/networking.md) for the layout this produces.

## `compute/` (Phase 4) — validated, currently destroyed
One `t2.micro` EC2 instance running the backend, in the Phase 3 public subnet. No key pair, no SSH, no inbound security group rule by default — access via AWS Systems Manager only (port forwarding or shell session), IAM-gated rather than network-gated. IAM role scoped to exactly `AmazonSSMManagedInstanceCore`. Deployed and validated 2026-08-20, then destroyed the same day (`terraform destroy -target=module.compute`) since it's the first resource in this project with a real per-hour cost — not left running between sessions. The module stays here, ready to redeploy with a plain `terraform apply`. See [docs/decisions/0006](../../../docs/decisions/0006-ec2-compute-placement-and-access.md).

## Expected later, as phases land
- Launch template + Auto Scaling Group + ALB + target groups, likely refactoring `compute/` rather than a new module (Phase 5)
- `database/` — RDS instance, subnet group, parameter group (Phase 6)
- `static-site/` — S3 bucket + CloudFront distribution (Phase 7)
- `dns/` — Route 53 hosted zone and records (Phase 8)
- `monitoring/` — CloudWatch alarms, dashboards, SNS topics (Phase 10)

Names/boundaries will likely shift as the actual infrastructure is built — this is a starting expectation, not a spec.
