# CloudMart Operations Runbook

Quick-reference commands for operating CloudMart day-to-day. This is a "how," not a "why" document — for the reasoning behind any of this, see the linked ADRs. All commands assume an active session: `aws sso login --profile cloudmart`.

## Current deployment status (2026-08-20)

| Tier | Status |
|---|---|
| VPC / networking (Phase 3) | ✅ Deployed, standing, $0/month |
| Backend compute (Phase 4/5) | 🟡 Plan-validated only — see [ADR 0007](decisions/0007-phase5-alb-asg-plan-not-deployed.md) |
| Database (Phase 6) | 🟡 Plan-validated only — see [ADR 0008](decisions/0008-phase6-rds-plan-not-deployed.md) |
| Frontend hosting (Phase 7) | ✅ Deployed, live | 
| Monitoring (Phase 8) | 🟡 Plan-validated only (CloudFront alarm ready, not applied) — see [ADR 0010](decisions/0010-phase8-operational-polish.md) |

## 1. Verify the deployed frontend

```bash
cd infrastructure/terraform/environments/dev
curl -s -o /dev/null -w "HTTP %{http_code}\n" "$(terraform output -raw frontend_url)/"
curl -sI "$(terraform output -raw frontend_url)/" | grep -i "x-cache\|content-type"

# Direct S3 access should be blocked (confirms the bucket is still private)
curl -s -o /dev/null -w "S3 direct access: HTTP %{http_code} (expect 403)\n" \
  "https://$(terraform output -raw frontend_bucket_name).s3.us-east-1.amazonaws.com/index.html"
```
Expect `HTTP 200` on the CloudFront URL, `HTTP 403` on direct S3 access.

## 2. Check Terraform state

```bash
cd infrastructure/terraform/environments/dev
terraform state list                 # everything Terraform is tracking
terraform output                     # current output values
terraform plan -target=module.vpc         # confirm no drift on standing infra
terraform plan -target=module.static_site # confirm no drift on the frontend
```
**Never run a bare `terraform plan`/`apply` in this environment without `-target`** — `module.compute` and `module.database` are undeployed but still declared in config, so an untargeted command treats their 19 combined resources as pending work.

## 3. Inspect deployed AWS resources directly (not just Terraform's view)

```bash
# VPC
aws ec2 describe-vpcs --profile cloudmart --vpc-ids "$(cd infrastructure/terraform/environments/dev && terraform output -raw vpc_id)"

# Frontend
aws s3api get-public-access-block --profile cloudmart --bucket "$(cd infrastructure/terraform/environments/dev && terraform output -raw frontend_bucket_name)"
aws cloudfront get-distribution --profile cloudmart --id "$(cd infrastructure/terraform/environments/dev && terraform output -raw frontend_cloudfront_distribution_id)" --query 'Distribution.Status'

# Confirm Phase 5/6 are genuinely absent (not just "Terraform doesn't know about them")
aws ec2 describe-instances --profile cloudmart --query 'Reservations[].Instances[?State.Name!=`terminated`].InstanceId' --output text
aws elbv2 describe-load-balancers --profile cloudmart --query 'LoadBalancers[].LoadBalancerName' --output text
aws rds describe-db-instances --profile cloudmart --query 'DBInstances[].DBInstanceIdentifier' --output text
```
All three "confirm absent" queries should return nothing.

## 4. Redeploy the temporary compute tier (Phase 5)

Only after explicit cost approval — this adds a real per-hour charge (~$0.07/hr, ~$48.57/month if left running; see [ADR 0007](decisions/0007-phase5-alb-asg-plan-not-deployed.md)).

```bash
cd infrastructure/terraform/environments/dev
terraform plan -target=module.compute     # review first
terraform apply -target=module.compute    # NEVER -auto-approve
```
Once applied, wait ~2-3 minutes for the ALB to report `active` and the ASG's instances to pass health checks, then:
```bash
curl "http://$(terraform output -raw alb_dns_name)/api/health"
curl "http://$(terraform output -raw alb_dns_name)/api/products"
```

## 5. Destroy billable components

```bash
cd infrastructure/terraform/environments/dev

# Compute (Phase 5), if deployed
terraform plan -destroy -target=module.compute
terraform destroy -target=module.compute   # NEVER -auto-approve

# Database (Phase 6), if deployed
terraform plan -destroy -target=module.database
terraform destroy -target=module.database  # NEVER -auto-approve
```
Phase 3 (VPC) and Phase 7 (frontend) are not billable in a way that warrants destroying between sessions — VPC has no usage charge ever, and S3/CloudFront have no idle charge (see [docs/cost.md](cost.md)). Destroying Phase 7 is possible (see below) but not something this project's cost model requires.

**To destroy Phase 7 anyway** (e.g. decommissioning the whole project):
```bash
aws s3 rm "s3://$(terraform output -raw frontend_bucket_name)/" --recursive --profile cloudmart  # bucket must be empty first
terraform destroy -target=module.static_site   # NEVER -auto-approve
```

## 6. Troubleshooting

**CloudFront serving stale content after a redeploy:**
```bash
aws cloudfront create-invalidation --profile cloudmart \
  --distribution-id "$(cd infrastructure/terraform/environments/dev && terraform output -raw frontend_cloudfront_distribution_id)" \
  --paths "/*"
```

**CloudFront returning 403/5xx unexpectedly:**
```bash
aws cloudfront get-distribution --profile cloudmart --id <distribution-id> --query 'Distribution.{Status:Status,Enabled:DistributionConfig.Enabled}'
aws s3api get-bucket-policy --profile cloudmart --bucket <bucket-name>   # confirm the OAC policy is still present and points at the right distribution ARN
```
A 403 from CloudFront itself (not S3) after a fresh `apply` usually means the bucket policy's `AWS:SourceArn` condition doesn't match the current distribution — this can happen if the distribution was ever destroyed and recreated without a `terraform apply` picking up the new ARN. Fix: `terraform apply -target=module.static_site` to reconcile.

**SSM session won't start ("TargetNotConnected" or similar):**
```bash
aws ssm describe-instance-information --profile cloudmart --filters "Key=InstanceIds,Values=<instance-id>" --query 'InstanceInformationList[0].PingStatus'
```
- If this returns nothing at all: the instance hasn't finished booting/registering yet (`user_data` takes ~1-2 minutes) — wait and retry.
- If `PingStatus` isn't `Online`: check the instance has the SSM instance profile attached and outbound internet access (it needs its own public IP through the IGW — no NAT Gateway in this design, see [ADR 0006](decisions/0006-ec2-compute-placement-and-access.md)).
- If the `session-manager-plugin` binary is missing locally: `brew install --cask session-manager-plugin`, or see [infrastructure/terraform/README.md](../infrastructure/terraform/README.md) for the sudo-free manual install if the cask fails.

**Terraform state seems stale (outputs don't match reality):**
```bash
terraform apply -refresh-only   # safe — cannot create/modify/destroy resources, only reconciles state and outputs
```
See [ADR 0010](decisions/0010-phase8-operational-polish.md) for why this was needed once already in this project.
