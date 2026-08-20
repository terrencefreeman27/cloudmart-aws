# CloudMart Terraform

AWS infrastructure for CloudMart, as code.

## Current contents

The files directly in this directory (`versions.tf`, `providers.tf`, `variables.tf`, `main.tf`, `outputs.tf`) are a **Phase 2 bootstrap configuration** — read-only `data` sources only (`aws_caller_identity`, `aws_availability_zones`), no `resource` blocks, kept as a quick way to re-verify AWS connectivity any time. It's separate from `environments/dev/`.

**`environments/dev/`** wires together five modules — two deployed, three deliberately not:
- **`modules/vpc/`** (Phase 3) — VPC, 2 AZs, 4 subnets, Internet Gateway, route tables. **Deployed**, 13 resources, all free, standing infrastructure. See [docs/networking.md](../../docs/networking.md).
- **`modules/compute/`** (Phase 5) — Application Load Balancer + Target Group + Launch Template + Auto Scaling Group (2 `t2.micro` instances across both AZs), backend security group scoped to the ALB only. `terraform plan` confirms 14 resources, 0 to change, 0 to destroy — **but this was deliberately never applied**, to keep ongoing AWS cost at $0. (Phase 4's earlier single-instance version of this module was deployed, validated, and destroyed before being rewritten — see [docs/decisions/0006](../../docs/decisions/0006-ec2-compute-placement-and-access.md).) Full Phase 5 design and cost reasoning: [docs/decisions/0007](../../docs/decisions/0007-phase5-alb-asg-plan-not-deployed.md).
- **`modules/database/`** (Phase 6) — RDS for PostgreSQL in the Phase 3 private subnets, not publicly accessible, trusted only by the backend's security group, encrypted at rest, master password managed automatically via Secrets Manager. `terraform plan` confirms 5 new resources — **also deliberately never applied**, same cost-control reasoning as Phase 5. Full Phase 6 design and cost reasoning: [docs/decisions/0008](../../docs/decisions/0008-phase6-rds-plan-not-deployed.md).
- **`modules/static-site/`** (Phase 7) — private S3 bucket + CloudFront distribution (Origin Access Control, HTTPS, SPA routing) for the React/Vite frontend. **Deployed** via `terraform apply -target=module.static_site` (7 resources, 0 to change, 0 to destroy), with **zero dependency** on any other module — S3/CloudFront aren't VPC resources, so this was applied without touching `compute` or `database`. Frontend build uploaded and live. Full Phase 7 design, deployment verification, and cost reasoning: [docs/decisions/0009](../../docs/decisions/0009-phase7-static-site-plan-not-deployed.md).
- **`modules/monitoring/`** (Phase 8) — CloudWatch alarms + SNS topic. 1 alarm (CloudFront 5xx) is active and deployable at ~$0/month (2 resources, `plan`-validated, **not applied**); 8 more (ALB/ASG/RDS) are gated behind plain booleans, deliberately decoupled from `compute`/`database`'s outputs to avoid a real dependency-graph hazard found during design. Full Phase 8 design and reasoning: [docs/decisions/0010](../../docs/decisions/0010-phase8-operational-polish.md).

**Because `compute`/`database`/`monitoring` are (mostly) undeployed while `vpc`/`static_site` are deployed in the same configuration, every `plan`/`apply` here must use `-target=<module>` explicitly — a bare `apply` would also try to create Phase 5/6's pending resources.** This project's phased build concludes at Phase 8 — see [docs/ROADMAP.md](../../docs/ROADMAP.md) "Beyond Phase 8" for what was deliberately not pursued further.

## Authentication

Terraform authenticates via the AWS CLI profile named `cloudmart` (`variables.tf` → `aws_profile`, referenced in `providers.tf`). That profile is backed by **AWS IAM Identity Center (SSO)**, not long-lived access keys — see [ADR 0004](../../docs/decisions/0004-aws-authentication-via-iam-identity-center.md). Before running any Terraform command, make sure your session is active:

```bash
aws sso login --profile cloudmart
```

Note: PowerUserAccess (the permission set behind this profile) deliberately excludes IAM management actions. Creating/changing anything under `modules/compute`'s IAM role (or the root-level `aws_iam_role_policy.backend_read_db_secret`) requires the scoped custom policy described in [ADR 0006](../../docs/decisions/0006-ec2-compute-placement-and-access.md) to be attached to the permission set first.

## Accessing the backend (SSM, no SSH)

Not currently deployed — Phase 5's `modules/compute` is plan-validated only, not applied (see above). If/when it is deployed, this still requires the `session-manager-plugin` binary (separate from the AWS CLI itself):
```bash
brew install --cask session-manager-plugin
```
See [docs/deployment.md](../../docs/deployment.md) for the exact commands once deployed.

## Accessing the frontend

Live now: `terraform output frontend_url` — a plain HTTPS request, no SSM, no VPN, no special access needed (it's a public CDN by design). See [docs/deployment.md](../../docs/deployment.md) for the build/upload/invalidate workflow used to deploy it and to redeploy future changes.

## Layout

```
infrastructure/terraform/
├── versions.tf, providers.tf, variables.tf, main.tf, outputs.tf, terraform.tfvars.example
│                   # Phase 2 bootstrap — connectivity verification only, no resources.
├── environments/
│   └── dev/        # Calls "vpc" (3), "compute" (5), "database" (6), "static_site" (7), "monitoring" (8).
└── modules/
    ├── vpc/         # Phase 3: VPC, subnets, IGW, route tables. Deployed, standing.
    ├── compute/     # Phase 5: ALB + ASG + launch template. Plan-validated, NOT deployed.
    ├── database/    # Phase 6: RDS PostgreSQL + subnet group + SG. Plan-validated, NOT deployed.
    ├── static-site/ # Phase 7: S3 + CloudFront + OAC. Deployed.
    └── monitoring/  # Phase 8: CloudWatch alarms + SNS. 2/10 resources plan-validated (not applied), 8 inert.
```

This project starts with a single `dev` environment (see [environments/](environments/)) to keep cost and complexity down; a `prod` environment is a possible later addition, not a requirement.

## State

No remote backend. Local Terraform state is **never** committed to Git (see the root [.gitignore](../../.gitignore)) — it can contain sensitive values. A remote backend (S3 + DynamoDB locking) would matter once there's more than one operator — deliberately not built for this single-person project; see [docs/ROADMAP.md](../../docs/ROADMAP.md) "Beyond Phase 8."

## Conventions
- Every resource in `environments/dev` is tagged with at least `Project = "cloudmart"` and `Environment = "dev"` via `providers.tf` default_tags, plus a resource-specific `Name` tag.
- No hardcoded secrets or credentials in `.tf` files — variables only, with `*.tfvars` gitignored.
- `terraform fmt` and `terraform validate` clean before committing.
