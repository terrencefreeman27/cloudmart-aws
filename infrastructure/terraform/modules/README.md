# Terraform Modules

Reusable, environment-agnostic building blocks — no hardcoded environment-specific values (those belong in [../environments/](../environments/)).

## `vpc/` (Phase 3)
VPC, public/private subnets across 2 AZs, Internet Gateway, route tables and associations. No security groups (those live with the compute that uses them, from Phase 4) and no NAT Gateway (deliberately deferred — see [docs/decisions/0005](../../../docs/decisions/0005-vpc-network-design.md)). Called from [`environments/dev`](../environments/dev/). See [docs/networking.md](../../../docs/networking.md) for the layout this produces.

## Expected later, as phases land
- `compute/` — Launch template, Auto Scaling Group, ALB, target groups (Phases 4-5)
- `database/` — RDS instance, subnet group, parameter group (Phase 6)
- `static-site/` — S3 bucket + CloudFront distribution (Phase 7)
- `dns/` — Route 53 hosted zone and records (Phase 8)
- `monitoring/` — CloudWatch alarms, dashboards, SNS topics (Phase 10)

Names/boundaries will likely shift as the actual infrastructure is built — this is a starting expectation, not a spec.
