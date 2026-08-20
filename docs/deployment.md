# Deployment

## Prerequisites
- AWS CLI v2 and Terraform >= 1.9 installed locally (see [infrastructure/terraform/README.md](../infrastructure/terraform/README.md) for install commands).
- An active AWS IAM Identity Center (SSO) session: `aws sso login --profile cloudmart`. See [ADR 0004](decisions/0004-aws-authentication-via-iam-identity-center.md).

## Provisioning infrastructure

Each environment under `infrastructure/terraform/environments/` is a separate Terraform root:

```bash
cd infrastructure/terraform/environments/dev
terraform init      # downloads providers/modules, no AWS calls
terraform fmt        # canonical formatting, no AWS calls
terraform validate   # syntax/type checking, no AWS calls
terraform plan        # shows proposed changes — the only safe way to preview
terraform apply       # NEVER with -auto-approve — always review the plan it re-prints first
```

`terraform.tfvars.example` in each environment documents the expected variables; copy it to `terraform.tfvars` to override defaults (that file is gitignored).

## What's deployed so far

**Phase 3 — VPC networking** (deployed 2026-08-20, `environments/dev`): 1 VPC, 4 subnets across 2 AZs, 1 Internet Gateway, 3 route tables, 4 associations. Full details and resource IDs: [networking.md](networking.md). $0/month cost.

## Verifying the VPC in the AWS Console

1. Sign in to the AWS Console with the same account Terraform used (account `937485903165`) — either via the IAM Identity Center portal (same login `aws sso login` uses) or however you normally access this account.
2. Make sure the region selector (top right) is set to **US East (N. Virginia) `us-east-1`** — resources won't appear if you're looking at the wrong region.
3. **VPC:** go to the **VPC** service → **Your VPCs**. You should see `cloudmart-dev-vpc`, CIDR `10.0.0.0/16`, ID `vpc-0a82438460af02b05`.
4. **Subnets:** VPC service → **Subnets**, filter by that VPC ID. You should see 4 subnets: 2 tagged `Tier: public` (`10.0.1.0/24`, `10.0.2.0/24`) and 2 tagged `Tier: private` (`10.0.11.0/24`, `10.0.12.0/24`), one of each pair in `us-east-1a` and one in `us-east-1b`.
5. **Internet Gateway:** VPC service → **Internet Gateways**. You should see `cloudmart-dev-igw`, state `Attached`, attached to the VPC above.
6. **Route tables:** VPC service → **Route Tables**, filter by that VPC ID. You should see 4 total — 3 with `cloudmart-` names (one public, two private) plus 1 unnamed "main" route table AWS creates automatically for every VPC (not something Terraform manages). Click `cloudmart-dev-public-rt` → **Routes** tab to see the `0.0.0.0/0 → igw-...` route; click either `cloudmart-dev-private-rt-*` → **Routes** tab to see it has *only* the local `10.0.0.0/16` route, confirming no internet path exists yet.
7. To cross-check against Terraform's own record instead of clicking around: `cd infrastructure/terraform/environments/dev && terraform show` prints everything Terraform currently manages and its state, or `terraform output` prints just the output values (VPC ID, subnet IDs, etc.).

## Tearing down

```bash
cd infrastructure/terraform/environments/dev
terraform plan -destroy   # preview what would be removed — always do this first
terraform destroy         # NEVER with -auto-approve
```

Not needed right now — every resource currently deployed is free regardless of how long it runs. This becomes relevant once a phase adds something billable (EC2, NAT Gateway, etc.) that shouldn't be left running between work sessions.

## Rollback / troubleshooting
Not yet needed — no rollback has occurred. This section will document real incidents if/when they happen, rather than hypothetical ones.
