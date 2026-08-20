# CloudMart Terraform

AWS infrastructure for CloudMart, as code.

## Current contents

The files directly in this directory (`versions.tf`, `providers.tf`, `variables.tf`, `main.tf`, `outputs.tf`) are a **Phase 2 bootstrap configuration** — read-only `data` sources only (`aws_caller_identity`, `aws_availability_zones`), no `resource` blocks, kept as a quick way to re-verify AWS connectivity any time. It's separate from `environments/dev/`.

**`environments/dev/`** (Phase 3) is where real infrastructure lives: it calls **`modules/vpc/`** to define a VPC, 2 AZs, 4 subnets, an Internet Gateway, and route tables. **Deployed to AWS** (`terraform apply`, 2026-08-20) — 13 resources, all free. See [docs/networking.md](../../docs/networking.md) for the layout and live resource IDs.

## Authentication

Terraform authenticates via the AWS CLI profile named `cloudmart` (`variables.tf` → `aws_profile`, referenced in `providers.tf`). That profile is backed by **AWS IAM Identity Center (SSO)**, not long-lived access keys — see [ADR 0004](../../docs/decisions/0004-aws-authentication-via-iam-identity-center.md). Before running any Terraform command, make sure your session is active:

```bash
aws sso login --profile cloudmart
```

## Layout

```
infrastructure/terraform/
├── versions.tf, providers.tf, variables.tf, main.tf, outputs.tf, terraform.tfvars.example
│                   # Phase 2 bootstrap — connectivity verification only, no resources.
├── environments/
│   └── dev/        # Phase 3: calls module "vpc". Deployed to AWS.
└── modules/
    └── vpc/         # Phase 3: VPC, subnets, IGW, route tables. Reusable, no resources
                     # created directly — only instantiated when a root module calls it.
```

This project starts with a single `dev` environment (see [environments/](environments/)) to keep cost and complexity down; a `prod` environment is a possible later addition, not a requirement.

## State

No remote backend yet. Local Terraform state is **never** committed to Git (see the root [.gitignore](../../.gitignore)) — it can contain sensitive values. A remote backend (S3 + DynamoDB locking) is planned for Phase 11, once there's enough infrastructure to make state-sharing/locking actually matter.

## Conventions
- Every resource in `environments/dev` is tagged with at least `Project = "cloudmart"` and `Environment = "dev"` via `providers.tf` default_tags, plus a resource-specific `Name` tag.
- No hardcoded secrets or credentials in `.tf` files — variables only, with `*.tfvars` gitignored.
- `terraform fmt` and `terraform validate` clean before committing.
