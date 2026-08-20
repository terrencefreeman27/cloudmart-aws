# Cost Considerations

CloudMart is a self-funded learning project, so cost awareness is treated as a first-class design constraint, not an afterthought. This document tracks cost-driving decisions and a running estimate.

## Ground rules
- Nothing with a meaningful recurring cost gets provisioned without being called out first, specifically: **NAT Gateways, Multi-AZ RDS, always-on EC2 instances, Route 53 hosted zones, and anything else outside AWS Free Tier**.
- Prefer Free Tier eligible resources (`t2.micro`/`t3.micro` EC2, `db.t3.micro` / `db.t4g.micro` RDS single-AZ) during active development.
- Everything is destroyable via `terraform destroy` — infrastructure is not left running between work sessions once a phase is validated, unless there's a specific reason to keep it up (e.g. taking screenshots for the portfolio).
- **AWS Budgets + a billing alarm were never set up** — flagged as "deferred, not forgotten" back in Phase 2 and never revisited before now. Honest gap, not an oversight hidden from this document: the first two AWS Budgets are free, and this would have been a genuinely low-effort, zero-cost safety net. Listed explicitly in the portfolio-readiness gap list at the end of this project's Phase 8 report as the one concrete, easy leftover item.

## Known cost drivers (flagged in advance)

| Resource | Approx. cost | Status |
|---|---|---|
| NAT Gateway | ~$0.045/hr + data processing (~$32+/mo if left running) | Not deployed, and not present in the Phase 3 Terraform at all. Private subnets have no outbound internet — revisited explicitly, with cost called out, once something in a private subnet actually needs it (Phase 4+). |
| RDS (`db.t3.micro`, Single-AZ) | ~$0.018/hr instance + ~$2.30/mo storage (20GB gp3) + ~$0.40/mo Secrets Manager ≈ **~$15.84/mo** | **Designed for Phase 6, `plan`-validated, deliberately NOT deployed.** See below and [ADR 0008](decisions/0008-phase6-rds-plan-not-deployed.md). |
| RDS Multi-AZ upgrade | Roughly 2× Single-AZ instance + storage ≈ **~$31.28/mo** total | Not deployed. `var.db_multi_az` defaults to `false`; documented as the production upgrade path, not enabled. |
| Route 53 hosted zone | $0.50/mo per zone | Not deployed. Flagged again at Phase 8. |
| EC2 (on-demand, `t2.micro`) | $0.0116/hr — Free Tier: 750 hrs/mo for 12 months, then ~$8.35/mo if run continuously | Phase 4: deployed, validated, then **destroyed** 2026-08-20. Phase 5 (2× `t2.micro` via ASG): designed, `plan`-validated, **not deployed** — see below. |
| Public IPv4 (auto-assigned, no EIP) | $0.005/hr per address while attached to a running resource, **$0 while stopped/not deployed** — never covered by Free Tier | Phase 4's was released on termination — confirmed via `aws ec2 describe-network-interfaces`. Phase 5 would add 2 more (one per instance) plus 2 more for the ALB's AZ nodes — none exist, since Phase 5 isn't deployed. |
| EBS root volume (8 GB gp3) | ~$0.000877/hr (~$0.64/mo) per volume — continues while *stopped*, stops only on *terminate* | Phase 4's was deleted on termination — confirmed via `aws ec2 describe-volumes` returning `InvalidVolume.NotFound`. Phase 5 would add 2 more — none exist. |
| Application Load Balancer | $0.0225/hr base + ~$0.01/hr for its 2 AZ nodes' public IPs + usage-based LCU (negligible at low traffic) — ~$48.57/mo total design if left running continuously | **Designed for Phase 5, `plan`-validated, deliberately NOT deployed.** See below and [ADR 0007](decisions/0007-phase5-alb-asg-plan-not-deployed.md). |
| CloudFront / S3 (frontend hosting) | 100% usage-based, **no idle/base hourly charge** — effectively $0/mo at near-zero traffic, ~$0.14/mo at ~1,000 pageviews/mo, ~$1.36/mo at ~10,000 pageviews/mo | **✅ Deployed 2026-08-20.** Frontend build live and independently verified over HTTPS. See below and [ADR 0009](decisions/0009-phase7-static-site-plan-not-deployed.md). |
| Secrets Manager (RDS-managed master password) | ~$0.40/mo flat + negligible per-call cost | **Designed for Phase 6 via `manage_master_user_password = true`**, `plan`-validated, deliberately NOT deployed — no secret exists until `apply` runs. |
| CloudWatch alarms | Always-free tier covers 10 alarm-metrics/month (perpetual, not just 12-month); $0.10/alarm/month beyond that | **Designed for Phase 8** (`modules/monitoring`) — 1 alarm (CloudFront 5xx) genuinely deployable now at ~$0/mo (well within the free 10), 8 more (ALB/ASG/RDS) inert until Phase 5/6 deploy. `plan`-validated, **not applied**. See [ADR 0010](decisions/0010-phase8-operational-polish.md). |
| SNS topic + email subscription | Topic: always free. Email delivery: 1,000/month free, then $2/100,000 | **Designed for Phase 8**, not applied. No email is hardcoded anywhere in this repo — subscription is opt-in via a gitignored `terraform.tfvars` value only. |

## Running estimate

Phase 2 added AWS CLI/Terraform tooling and IAM Identity Center authentication, and ran read-only `data` source lookups against the account (free — `Describe`/`Get`/`List`-style read API calls are never billed).

Phase 3's VPC network is **deployed and standing**: 1 VPC, 4 subnets across 2 AZs, 1 Internet Gateway, 3 route tables, 4 route table associations — 13 resources, all free resource types with no hourly or usage charge, regardless of how long they exist. Real resource IDs: [networking.md](networking.md).

Phase 4's compute (`t2.micro` + its public IP + its EBS volume) was the project's **first cost that accrues with time**:

| Duration | Cost (not Free Tier) | Cost (Free Tier covers compute+EBS) |
|---|---|---|
| 1 hour | ~$0.0175 | ~$0.005 (public IP only) |
| 2 hours | ~$0.035 | ~$0.010 |
| 24 hours | ~$0.42 | ~$0.12 |
| 30 days continuous | ~$12.59 | ~$3.60 |

It was deployed, validated (SSM registration, `/api/health`, `/api/products` all confirmed working), and then **intentionally destroyed the same day** via `terraform destroy -target=module.compute` — exactly the lifecycle this table exists to justify, not an exception to it. Independently confirmed via `aws ec2`/`aws iam` (not just Terraform's report): instance terminated, security group and IAM role/instance-profile gone, EBS volume gone, public IP released.

**Phase 5** rewrote that same `compute` module into an ALB + Auto Scaling Group (2 instances across both AZs) — a meaningfully larger standing cost than Phase 4's single instance:

| Duration | Cost if deployed |
|---|---|
| 2-hour validation | ~$0.13 |
| 24 hours | ~$1.62 |
| 30 days continuous | ~$48.57 |

Unlike Phase 4, **this phase was deliberately never applied.** `terraform plan` confirms the design is correct (14 resources, 0 to change, 0 to destroy, zero impact on Phase 3), but the explicit priority for this phase was $0 ongoing cost — not even a short paid validation window. Full reasoning: [ADR 0007](decisions/0007-phase5-alb-asg-plan-not-deployed.md).

**Phase 6** adds an RDS PostgreSQL instance (`modules/database`) in the Phase 3 private subnets — a meaningfully heavier standing cost than either prior phase, and one where "stop it between sessions for free" doesn't work the same way it does for EC2 (a stopped RDS instance still incurs storage charges, and AWS auto-restarts a stopped instance after 7 days regardless):

| | Single-AZ | Multi-AZ |
|---|---|---|
| **Monthly cost if deployed** | **~$15.84** | **~$31.28** |

**PLAN-VALIDATED ONLY — NOT DEPLOYED DUE TO COST CONTROL.** `terraform plan` confirms 19 resources total to add (14 of those are Phase 5's still-pending resources — Phase 6's database depends on Phase 5's backend security group by design, so the two can't be cleanly isolated in one plan; 5 are new this phase), 0 to change, 0 to destroy, zero impact on the Phase 3 VPC. Full reasoning: [ADR 0008](decisions/0008-phase6-rds-plan-not-deployed.md).

**Phase 7 — DEPLOYED 2026-08-20.** A private S3 bucket + CloudFront distribution (`modules/static-site`) for the React/Vite frontend, applied via `terraform apply -target=module.static_site` — the cheapest phase by far, and a genuinely different cost shape from every prior phase:

| | Zero traffic | 1,000 pageviews/mo | 10,000 pageviews/mo |
|---|---|---|---|
| **Monthly cost** | **effectively $0.00** | **~$0.14** | **~$1.36** |

Unlike EC2, ALB, RDS, and NAT, **S3 and CloudFront have no idle or base hourly charge at all** — cost is 100% usage-based, confirmed both by code review (no capacity/provisioned-throughput settings anywhere in the module) and by the absence of any fixed component in AWS's own pricing for these two services. `Apply complete! Resources: 7 added, 0 changed, 0 destroyed.` The frontend build (3 files, content-hashed JS/CSS) is live and independently verified: HTTPS (TLS 1.3), caching (`x-cache: Hit from cloudfront` on repeat requests), SPA routing (a deep link returns `200` via the custom error response, not 403/404), and direct S3 access confirmed blocked (`403 AccessDenied` on both regional and path-style URLs). Full reasoning: [ADR 0009](decisions/0009-phase7-static-site-plan-not-deployed.md).

**Phase 8** adds a monitoring module (`modules/monitoring`) with 1 alarm active (CloudFront 5xx error rate) + an SNS topic — `terraform plan -target=module.monitoring` confirms 2 resources, 0 to change, 0 to destroy, ~$0/month (well within CloudWatch's always-free 10-alarm allowance). **Not applied** — held for separate approval, same discipline as every other resource in this project regardless of how small the estimated cost. Full logging design (application/ALB/RDS/CloudFront) is documented but nothing is enabled — see [docs/architecture.md](architecture.md) and [docs/security.md](security.md).

**Current CloudMart AWS spend: Phase 3 VPC ($0/month, standing) + Phase 7 frontend hosting (usage-based, effectively $0/month at current near-zero traffic).** Phases 5, 6, and Phase 8's monitoring remain undeployed, adding **$0** — confirmed independently via `aws ec2 describe-instances`, `aws elbv2 describe-load-balancers`, `aws autoscaling describe-auto-scaling-groups`, `aws rds describe-db-instances`, and (for monitoring) `aws cloudwatch describe-alarms` / `aws sns list-topics`, all returning empty for this project. Every undeployed module stays in the repo, fully validated and ready — deploying any of them later requires no further design work, just `terraform apply -target=<module>` and the explicit cost approval that implies. **Important operational note:** any future `apply` in this environment must continue to use `-target` for whichever module is actually being deployed — a bare `terraform apply` would now also try to create Phase 5, 6, and part of Phase 8's still-pending resources.

## Cost-controls summary (Phase 8)

The full, final picture — every resource type this project has designed, whether it has a fixed charge, and its actual current deployment status:

| Resource | Charge type | Currently deployed? |
|---|---|---|
| VPC, subnets, Internet Gateway, route tables (Phase 3) | **Free** — no fixed or usage charge, ever | ✅ Yes, standing |
| S3 bucket + CloudFront distribution (Phase 7) | **Usage-based** — no fixed/idle charge | ✅ Yes, live |
| EC2 instance(s), ALB, ASG (Phase 4/5) | **Fixed hourly**, whether idle or busy | ❌ No — Phase 4 destroyed after validation; Phase 5 never applied |
| Public IPv4 addresses (EC2/ALB) | **Fixed hourly**, per address, while attached | ❌ No — none currently allocated to this project |
| RDS instance + storage (Phase 6) | **Fixed hourly** (instance) + **usage-based** (storage) | ❌ No — never applied |
| Secrets Manager secret (Phase 6) | **Fixed monthly** ($0.40) | ❌ No — created automatically only if/when the RDS instance is, never independently |
| NAT Gateway | **Fixed hourly** | ❌ No — not present anywhere in this project's Terraform at all |
| CloudWatch alarms + SNS topic (Phase 8) | 1 alarm: **free** (within always-free tier). 8 more: same, once enabled | 🟡 Designed, `plan`-validated, not applied |
| Route 53 hosted zone | **Fixed monthly** ($0.50) | ❌ No — never pursued (see [ROADMAP.md](ROADMAP.md) "Beyond Phase 8") |

**How this project avoids unnecessary spend, as a general pattern, not just a list:** every resource with a fixed hourly or monthly charge went through the same lifecycle — designed in Terraform, `plan`-verified for correctness and exact cost, and left undeployed pending a separate, explicit approval — except where a short, cheap, time-boxed validation window was judged worth it (Phase 4's ~13¢ EC2 validation, immediately destroyed after). Nothing with a recurring charge has ever been left running "by default" or "to see how it goes."

This table will be updated at the end of each phase with actual/expected monthly cost if resources are left running, plus a reminder of the `terraform destroy` command to zero it back out.
