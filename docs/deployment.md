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

**Critical, as of Phase 7: always use `-target=<module>` on both `plan` and `apply` in this environment.** `environments/dev` now declares `vpc` (deployed), `compute` (Phase 5, NOT deployed), `database` (Phase 6, NOT deployed), `static_site` (Phase 7, deployed), and `monitoring` (Phase 8, partially deployable) in the same configuration. A bare `terraform apply` right now would try to create Phase 5's and Phase 6's still-pending resources (~$64/month combined) alongside anything else — not just whichever single module you intend to change. Always run e.g. `terraform apply -target=module.static_site`, never a bare `apply`, until Phase 5/6 are explicitly approved for deployment too.

For quick reference, see [docs/runbook.md](runbook.md) — day-to-day operational commands (verify, inspect, redeploy, destroy, troubleshoot) live there; this document covers the deeper "how each phase was actually deployed" narrative.

## What's deployed so far

**Phase 3 — VPC networking** (deployed 2026-08-20, standing infrastructure): 1 VPC, 4 subnets across 2 AZs, 1 Internet Gateway, 3 route tables, 4 associations. Full details and resource IDs: [networking.md](networking.md). $0/month cost.

**Phase 4 — Backend compute (historical, superseded)**: a single `t2.micro` EC2 instance + security group + IAM role/instance profile were deployed, verified working (SSM registration, `/api/health`, `/api/products`), then torn down via `terraform destroy -target=module.compute` for cost control on 2026-08-20. See [ADR 0006](decisions/0006-ec2-compute-placement-and-access.md).

**Phase 5 — ALB + Auto Scaling Group (designed, plan-validated, NOT deployed)**: the `compute` module was rewritten into an Application Load Balancer + Target Group + Launch Template + Auto Scaling Group (2 instances across both AZs). `terraform plan` confirms 14 resources, 0 to change, 0 to destroy, zero impact on the Phase 3 VPC — but **no `terraform apply` was run**, deliberately, to keep ongoing cost at $0 (this design costs ~$48.57/month if left running continuously). See [ADR 0007](decisions/0007-phase5-alb-asg-plan-not-deployed.md) for the full design, cost breakdown, and reasoning.

**Phase 6 — RDS PostgreSQL (designed, plan-validated, NOT deployed)**: the new `database` module adds an RDS instance in the Phase 3 private subnets, not publicly accessible, trusted only by the backend's security group, encrypted at rest, master password managed automatically via Secrets Manager (never in this repo or Terraform state). `terraform plan` confirms 5 new resources (19 total, including Phase 5's still-pending 14 — the database depends on Phase 5's backend security group by design), 0 to change, 0 to destroy, zero impact on the Phase 3 VPC — **no `terraform apply` was run**, deliberately (~$15.84/month Single-AZ, ~$31.28/month Multi-AZ if deployed). See [ADR 0008](decisions/0008-phase6-rds-plan-not-deployed.md) for the full design, cost breakdown, and reasoning.

**Phase 7 — S3 + CloudFront frontend hosting (✅ DEPLOYED 2026-08-20)**: the `static-site` module adds a private S3 bucket + CloudFront distribution (Origin Access Control, HTTPS, SPA-routing error responses) for the React/Vite frontend. Independent of the VPC/compute/database tiers entirely. Applied via `terraform apply -target=module.static_site` — `Apply complete! Resources: 7 added, 0 changed, 0 destroyed`, zero impact on the Phase 3 VPC. The built frontend (`npm run build`, 3 files) was uploaded and independently verified: loads over HTTPS with TLS 1.3, edge caching confirmed (`x-cache: Hit from cloudfront` on a repeat request), SPA deep-link routing confirmed (`/products/5` → `200`, not 403/404), and direct S3 access confirmed blocked (`403 AccessDenied` on both the regional-REST and path-style URLs). See [ADR 0009](decisions/0009-phase7-static-site-plan-not-deployed.md) for the full design, cost breakdown, and reasoning.

**Phase 8 — Monitoring, security & operational polish (designed, partially plan-validated, NOT deployed)**: the new `monitoring` module adds a CloudWatch alarm (CloudFront 5xx error rate) + an SNS topic — `terraform plan -target=module.monitoring` confirms 2 resources, 0 to change, 0 to destroy, ~$0/month estimated. Eight more alarms (ALB, ASG, RDS) are fully written but gated `false` until Phase 5/6 deploy — deliberately decoupled from those modules' outputs to avoid a real Terraform dependency-graph hazard found during design (see [ADR 0010](decisions/0010-phase8-operational-polish.md)). **No `terraform apply` was run.** This phase also added a full logging design (documented, nothing enabled), a security/reliability synthesis, and the operational runbook.

**Current deployed AWS footprint: the Phase 3 VPC, plus Phase 7's frontend hosting.** Phases 5, 6, and Phase 8's monitoring remain undeployed — independently confirmed via `aws ec2 describe-instances`, `aws elbv2 describe-load-balancers`, `aws autoscaling describe-auto-scaling-groups`, `aws rds describe-db-instances`, `aws cloudwatch describe-alarms`, and `aws sns list-topics`, all returning empty for this project.

## Verifying the VPC in the AWS Console

1. Sign in to the AWS Console with the same account Terraform used — either via the IAM Identity Center portal (same login `aws sso login` uses) or however you normally access this account.
2. Make sure the region selector (top right) is set to **US East (N. Virginia) `us-east-1`** — resources won't appear if you're looking at the wrong region.
3. **VPC:** go to the **VPC** service → **Your VPCs**. You should see `cloudmart-dev-vpc`, CIDR `10.0.0.0/16`. (Get the exact ID from `terraform output vpc_id` rather than a hardcoded value here — it changes if the environment is ever destroyed and recreated.)
4. **Subnets:** VPC service → **Subnets**, filter by that VPC. You should see 4 subnets: 2 tagged `Tier: public` (`10.0.1.0/24`, `10.0.2.0/24`) and 2 tagged `Tier: private` (`10.0.11.0/24`, `10.0.12.0/24`), one of each pair in `us-east-1a` and one in `us-east-1b`.
5. **Internet Gateway:** VPC service → **Internet Gateways**. You should see `cloudmart-dev-igw`, state `Attached`, attached to the VPC above.
6. **Route tables:** VPC service → **Route Tables**, filter by that VPC. You should see 4 total — 3 with `cloudmart-` names (one public, two private) plus 1 unnamed "main" route table AWS creates automatically for every VPC (not something Terraform manages). Click `cloudmart-dev-public-rt` → **Routes** tab to see the `0.0.0.0/0 → igw-...` route; click either `cloudmart-dev-private-rt-*` → **Routes** tab to see it has *only* the local `10.0.0.0/16` route, confirming no internet path exists yet.
7. To cross-check against Terraform's own record instead of clicking around: `cd infrastructure/terraform/environments/dev && terraform show` prints everything Terraform currently manages and its state, or `terraform output` prints just the output values (VPC ID, subnet IDs, etc.).

## Accessing the backend (Phase 5 design) — not currently deployed

Nothing to access right now — this design (see above) has been `plan`-validated but never applied. Documenting here for when it is deployed.

**Primary access, once deployed: a plain HTTP request to the ALB — no SSM tunnel needed for the app itself**, unlike Phase 4:
```bash
curl http://$(cd infrastructure/terraform/environments/dev && terraform output -raw alb_dns_name)/api/health
curl http://$(cd infrastructure/terraform/environments/dev && terraform output -raw alb_dns_name)/api/products
```
The backend's own security group still has **zero direct inbound rules from the internet** — only from the ALB's security group — so these requests only work because the ALB is doing the forwarding, not because port 4000 is open.

**Shell access to an individual instance (debugging), still SSM-only, no SSH:** the ASG manages instance IDs dynamically, so list them first:
```bash
aws autoscaling describe-auto-scaling-groups --profile cloudmart \
  --auto-scaling-group-names "$(cd infrastructure/terraform/environments/dev && terraform output -raw asg_name)" \
  --query 'AutoScalingGroups[0].Instances[].InstanceId' --output text
aws ssm start-session --profile cloudmart --target <one-of-those-instance-ids>
```
Requires the `session-manager-plugin` binary (`brew install --cask session-manager-plugin` — see [infrastructure/terraform/README.md](../infrastructure/terraform/README.md) if the cask needs `sudo` you can't supply).

## Deploying the frontend — deployed 2026-08-20

The infrastructure and the current build are both live. This is the exact workflow that was run, and the same one to use for any future rebuild/redeploy:

```bash
# 1. Apply the infrastructure (bucket + CloudFront) — already done; re-run only if
#    the static-site module's Terraform ever changes
cd infrastructure/terraform/environments/dev
terraform apply -target=module.static_site   # NEVER a bare apply, NEVER -auto-approve

# 2. Build the frontend
cd ../../../../frontend
npm run build

# 3. Upload the build to the private bucket
aws s3 sync dist/ "s3://$(cd ../infrastructure/terraform/environments/dev && terraform output -raw frontend_bucket_name)/" \
  --profile cloudmart --delete

# 4. Invalidate the CloudFront cache so the new index.html is visible immediately
#    (not needed for the very first upload — there was nothing cached yet — but
#    required for every deploy after that)
aws cloudfront create-invalidation --profile cloudmart \
  --distribution-id "$(cd infrastructure/terraform/environments/dev && terraform output -raw frontend_cloudfront_distribution_id)" \
  --paths "/*"
```

The site is live at `terraform output frontend_url` (an `https://*.cloudfront.net` address — no custom domain this phase). Step 3 uploads directly via the AWS CLI's own credentials, not through the private bucket's CloudFront-only read path — that path is for *serving* the site to visitors, not for deploying to it. Phase 5's backend isn't deployed, so there is no real API URL to build with. A production build treats an unset or `localhost` `VITE_API_BASE_URL` as "no API": it skips the request and serves a static copy of the catalog (the backend's own `backend/src/data/products.js`, bundled as a separate chunk) with a "Demo mode" banner. If a real URL is configured but the request fails, it falls back the same way. Once Phase 5 is deployed, rebuild with `VITE_API_BASE_URL` set to the ALB's DNS name and redeploy; the banner disappears when the API responds.

## Deploying monitoring (Phase 8 design) — not currently deployed

```bash
cd infrastructure/terraform/environments/dev
terraform plan -target=module.monitoring    # preview — expect 2 to add, 0 to change, 0 to destroy
terraform apply -target=module.monitoring   # NEVER a bare apply, NEVER -auto-approve
```
This creates only the SNS topic and the CloudFront 5xx alarm — confirmed via `-target` plan testing to have zero dependency on `module.compute`/`module.database` (an earlier design didn't have this property; see [ADR 0010](decisions/0010-phase8-operational-polish.md)). To also receive email notifications, set `monitoring_notification_email` in your own `terraform.tfvars` (gitignored) before applying — never pass a real email via `-var` on the command line where it could end up in shell history either, prefer the tfvars file.

To enable the ALB/ASG/RDS alarms once Phase 5/6 are deployed, edit the commented-out lines in `environments/dev/main.tf`'s `module "monitoring"` block (flip the relevant `enable_*_alarms` to `true`, wire the matching identifier to the real module output), then `terraform apply -target=module.monitoring` again.

## Tearing down

**Everything (all phases):**
```bash
cd infrastructure/terraform/environments/dev
terraform plan -destroy   # preview what would be removed — always do this first
terraform destroy         # NEVER with -auto-approve
```

**Just the compute module (leaves the Phase 3 VPC standing), if/when Phase 5 is deployed:**
```bash
cd infrastructure/terraform/environments/dev
terraform plan -destroy -target=module.compute   # preview first
terraform destroy -target=module.compute          # NEVER with -auto-approve
```
`-target` is generally discouraged for routine changes (it can mask drift elsewhere), but it's the correct tool for this specific case — nothing else in the configuration depends on `module.compute`, so this cleanly removes the ALB, target group, launch template, ASG (and the 2 instances it manages), security groups, and IAM role/instance profile, and nothing else. This is exactly how Phase 4's earlier single-instance version of this module was torn down after validation on 2026-08-20, independently confirmed via `aws ec2`/`aws iam`, with all 13 Phase 3 resources cross-checked as untouched.

**`module.compute` and `module.database` have never been applied at all**, so there's nothing to destroy for either — `terraform plan` (no `-destroy`) already shows `14 to add` and `5 to add` respectively, which is the correct, expected state for a plan-validated-but-undeployed design, not something to "clean up."

**`module.static_site` (Phase 7) is now deployed**, and is the one module in this project with **no dependency** on any other — S3/CloudFront aren't VPC resources at all. To tear it down later without touching anything else:

```bash
cd infrastructure/terraform/environments/dev

# S3 buckets can't be deleted while non-empty — empty it first
aws s3 rm "s3://$(terraform output -raw frontend_bucket_name)/" --recursive --profile cloudmart

terraform plan -destroy -target=module.static_site   # preview first
terraform destroy -target=module.static_site          # NEVER with -auto-approve
```

This affects only the S3 bucket and its sub-resources, the CloudFront distribution, and the OAC — nothing else, with no risk of touching the VPC, compute, or database tiers even implicitly.

Phase 3's VPC resources are free regardless of how long they run, so there's no cost reason to tear those down between sessions. Phase 7's S3/CloudFront are similarly low-risk to leave running — no idle charge, cost scales only with actual traffic. If Phase 8's monitoring is ever applied, `terraform destroy -target=module.monitoring` removes just the alarm(s) and SNS topic, same pattern as every other targeted teardown in this project.

## Rollback / troubleshooting
See [docs/runbook.md](runbook.md) for concrete troubleshooting commands (CloudFront/SSM failures, stale Terraform state). No real incident has occurred in this project yet — the runbook's troubleshooting section is written from anticipated failure modes and the one real operational issue found during Phase 8 (the stale-output/dependency-graph bug, both documented in [ADR 0010](decisions/0010-phase8-operational-polish.md)), not from a backlog of unresolved problems.
