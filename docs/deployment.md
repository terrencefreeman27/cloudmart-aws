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

**Phase 3 — VPC networking** (deployed 2026-08-20, standing infrastructure): 1 VPC, 4 subnets across 2 AZs, 1 Internet Gateway, 3 route tables, 4 associations. Full details and resource IDs: [networking.md](networking.md). $0/month cost.

**Phase 4 — Backend compute** (deployed, validated, and **destroyed** 2026-08-20 — currently NOT deployed): 1 `t2.micro` EC2 instance + security group + IAM role/instance profile were created, verified working (SSM registration, `/api/health`, `/api/products`), then torn down via `terraform destroy -target=module.compute` for cost control. See [ADR 0006](decisions/0006-ec2-compute-placement-and-access.md), the SSM access section below (for the next time it's deployed), and "Tearing down." The Phase 3 VPC was independently confirmed untouched.

## Verifying the VPC in the AWS Console

1. Sign in to the AWS Console with the same account Terraform used — either via the IAM Identity Center portal (same login `aws sso login` uses) or however you normally access this account.
2. Make sure the region selector (top right) is set to **US East (N. Virginia) `us-east-1`** — resources won't appear if you're looking at the wrong region.
3. **VPC:** go to the **VPC** service → **Your VPCs**. You should see `cloudmart-dev-vpc`, CIDR `10.0.0.0/16`. (Get the exact ID from `terraform output vpc_id` rather than a hardcoded value here — it changes if the environment is ever destroyed and recreated.)
4. **Subnets:** VPC service → **Subnets**, filter by that VPC. You should see 4 subnets: 2 tagged `Tier: public` (`10.0.1.0/24`, `10.0.2.0/24`) and 2 tagged `Tier: private` (`10.0.11.0/24`, `10.0.12.0/24`), one of each pair in `us-east-1a` and one in `us-east-1b`.
5. **Internet Gateway:** VPC service → **Internet Gateways**. You should see `cloudmart-dev-igw`, state `Attached`, attached to the VPC above.
6. **Route tables:** VPC service → **Route Tables**, filter by that VPC. You should see 4 total — 3 with `cloudmart-` names (one public, two private) plus 1 unnamed "main" route table AWS creates automatically for every VPC (not something Terraform manages). Click `cloudmart-dev-public-rt` → **Routes** tab to see the `0.0.0.0/0 → igw-...` route; click either `cloudmart-dev-private-rt-*` → **Routes** tab to see it has *only* the local `10.0.0.0/16` route, confirming no internet path exists yet.
7. To cross-check against Terraform's own record instead of clicking around: `cd infrastructure/terraform/environments/dev && terraform show` prints everything Terraform currently manages and its state, or `terraform output` prints just the output values (VPC ID, subnet IDs, etc.).

## Accessing the backend (Phase 4) — SSM only, no SSH, no open ports

Not currently deployed — this instance is destroyed as of 2026-08-20 (see above). Redeploy it with `terraform apply` in `environments/dev` (recreates from the same `modules/compute` config, no code changes needed), then use the commands below.

The backend EC2 instance has **zero inbound security group rules**. There is no URL to browse to. Access is exclusively through AWS Systems Manager, which requires the `session-manager-plugin` binary installed locally alongside the AWS CLI (a separate download — `brew install --cask session-manager-plugin`, or see [infrastructure/terraform/README.md](../infrastructure/terraform/README.md)).

**Port forward the API to your machine:**
```bash
aws ssm start-session --profile cloudmart \
  --target <instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["4000"],"localPortNumber":["4000"]}'
```
Leave that running, then in another terminal: `curl http://localhost:4000/api/health` / `curl http://localhost:4000/api/products`. Ctrl+C the session when done — check `lsof -i :4000` afterward if you want to confirm the local port was actually released.

**Get a shell on the instance instead:**
```bash
aws ssm start-session --profile cloudmart --target <instance-id>
```

Get `<instance-id>` from `terraform output backend_instance_id`.

## Tearing down

**Everything (all phases):**
```bash
cd infrastructure/terraform/environments/dev
terraform plan -destroy   # preview what would be removed — always do this first
terraform destroy         # NEVER with -auto-approve
```

**Just the Phase 4 compute (leaves the Phase 3 VPC standing):**
```bash
cd infrastructure/terraform/environments/dev
terraform plan -destroy -target=module.compute   # preview first
terraform destroy -target=module.compute          # NEVER with -auto-approve
```
`-target` is generally discouraged for routine changes (it can mask drift elsewhere), but it's the correct tool for this specific case — nothing else in the configuration depends on `module.compute`, so this cleanly removes exactly the instance, its security group, and its IAM role/instance profile, and nothing else. This is exactly how Phase 4 was torn down after validation on 2026-08-20, independently confirmed via `aws ec2`/`aws iam` and cross-checked that all 13 Phase 3 resources remained. Since `module "compute"` stays declared in `main.tf`, `terraform plan` afterward correctly shows `5 to add` (not `0 to add`) — that's expected, not a problem: it means "redeploy whenever needed" via a plain `terraform apply`, no code changes required.

**Just stopping, without destroying (shorter breaks):**
```bash
aws ec2 stop-instances --profile cloudmart --instance-ids <instance-id>
```
Drops compute + public-IP billing to $0 immediately; the small EBS volume charge continues until the instance is destroyed outright (see [cost.md](cost.md)). The instance keeps its Terraform-managed identity — `terraform apply` later needs no changes to bring it back, just `aws ec2 start-instances` (note: it gets a **new** public IP on start, since no Elastic IP is used).

Phase 3's VPC resources are free regardless of how long they run, so there's no cost reason to tear those down between sessions — only Phase 4's compute needs this discipline.

## Rollback / troubleshooting
Not yet needed — no rollback has occurred. This section will document real incidents if/when they happen, rather than hypothetical ones.
