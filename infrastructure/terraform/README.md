# CloudMart Terraform

AWS infrastructure for CloudMart, as code.

## Current contents

The files directly in this directory (`versions.tf`, `providers.tf`, `variables.tf`, `main.tf`, `outputs.tf`) are a **Phase 2 bootstrap configuration** — read-only `data` sources only (`aws_caller_identity`, `aws_availability_zones`), no `resource` blocks, kept as a quick way to re-verify AWS connectivity any time. It's separate from `environments/dev/`.

**`environments/dev/`** is where real infrastructure lives, calling two modules:
- **`modules/vpc/`** (Phase 3) — VPC, 2 AZs, 4 subnets, Internet Gateway, route tables. **Deployed**, 13 resources, all free, standing infrastructure. See [docs/networking.md](../../docs/networking.md).
- **`modules/compute/`** (Phase 4) — one `t2.micro` EC2 instance running the backend, no SSH, no inbound security group rules by default, access via SSM only. Deployed, validated, then **destroyed** for cost control (`terraform destroy -target=module.compute`) — currently not running. Module stays in the repo; redeploy any time with a plain `terraform apply` (see [docs/deployment.md](../../docs/deployment.md)). See [docs/decisions/0006](../../docs/decisions/0006-ec2-compute-placement-and-access.md).

## Authentication

Terraform authenticates via the AWS CLI profile named `cloudmart` (`variables.tf` → `aws_profile`, referenced in `providers.tf`). That profile is backed by **AWS IAM Identity Center (SSO)**, not long-lived access keys — see [ADR 0004](../../docs/decisions/0004-aws-authentication-via-iam-identity-center.md). Before running any Terraform command, make sure your session is active:

```bash
aws sso login --profile cloudmart
```

Note: PowerUserAccess (the permission set behind this profile) deliberately excludes IAM management actions. Creating/changing anything under `modules/compute`'s IAM role requires the scoped custom policy described in [ADR 0006](../../docs/decisions/0006-ec2-compute-placement-and-access.md) to be attached to the permission set first.

## Accessing the backend instance (SSM, no SSH)

Requires the `session-manager-plugin` binary (separate from the AWS CLI itself):
```bash
brew install --cask session-manager-plugin
```
Then see [docs/deployment.md](../../docs/deployment.md) for the exact port-forwarding / shell-session commands.

## Layout

```
infrastructure/terraform/
├── versions.tf, providers.tf, variables.tf, main.tf, outputs.tf, terraform.tfvars.example
│                   # Phase 2 bootstrap — connectivity verification only, no resources.
├── environments/
│   └── dev/        # Calls module "vpc" (Phase 3) and module "compute" (Phase 4).
└── modules/
    ├── vpc/         # Phase 3: VPC, subnets, IGW, route tables. Deployed, standing.
    └── compute/     # Phase 4: EC2 backend, SG, IAM role. Deployed, temporary.
```

This project starts with a single `dev` environment (see [environments/](environments/)) to keep cost and complexity down; a `prod` environment is a possible later addition, not a requirement.

## State

No remote backend yet. Local Terraform state is **never** committed to Git (see the root [.gitignore](../../.gitignore)) — it can contain sensitive values. A remote backend (S3 + DynamoDB locking) is planned for Phase 11, once there's enough infrastructure to make state-sharing/locking actually matter.

## Conventions
- Every resource in `environments/dev` is tagged with at least `Project = "cloudmart"` and `Environment = "dev"` via `providers.tf` default_tags, plus a resource-specific `Name` tag.
- No hardcoded secrets or credentials in `.tf` files — variables only, with `*.tfvars` gitignored.
- `terraform fmt` and `terraform validate` clean before committing.
