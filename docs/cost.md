# Cost Considerations

CloudMart is a self-funded learning project, so cost awareness is treated as a first-class design constraint, not an afterthought. This document tracks cost-driving decisions and a running estimate.

## Ground rules
- Nothing with a meaningful recurring cost gets provisioned without being called out first, specifically: **NAT Gateways, Multi-AZ RDS, always-on EC2 instances, Route 53 hosted zones, and anything else outside AWS Free Tier**.
- Prefer Free Tier eligible resources (`t2.micro`/`t3.micro` EC2, `db.t3.micro` / `db.t4g.micro` RDS single-AZ) during active development.
- Everything is destroyable via `terraform destroy` — infrastructure is not left running between work sessions once a phase is validated, unless there's a specific reason to keep it up (e.g. taking screenshots for the portfolio).
- AWS Budgets + a billing alarm are planned before Phase 4 introduces the first per-hour-billed resource (EC2), so a mistake surfaces immediately instead of at the end of the month. Not yet set up as of Phase 2 — see [ROADMAP.md](ROADMAP.md).

## Known cost drivers (flagged in advance)

| Resource | Approx. cost | Status |
|---|---|---|
| NAT Gateway | ~$0.045/hr + data processing (~$32+/mo if left running) | Not deployed, and not present in the Phase 3 Terraform at all. Private subnets have no outbound internet — revisited explicitly, with cost called out, once something in a private subnet actually needs it (Phase 4+). |
| RDS Multi-AZ | Roughly 2x single-AZ RDS cost | Not deployed. Phase 6 defaults to single-AZ. |
| Route 53 hosted zone | $0.50/mo per zone | Not deployed. Flagged again at Phase 8. |
| EC2 (on-demand, `t2.micro`) | $0.0116/hr — Free Tier: 750 hrs/mo for 12 months, then ~$8.35/mo if run continuously | Deployed, validated, then **destroyed** 2026-08-20 (see below). Module stays in the repo, redeployed on demand for future phases. |
| Public IPv4 (auto-assigned, no EIP) | $0.005/hr while running, **$0 while stopped** — never covered by Free Tier | Released back to AWS's pool on termination — confirmed via `aws ec2 describe-network-interfaces`. |
| EBS root volume (8 GB gp3) | ~$0.000877/hr (~$0.64/mo) — continues while *stopped*, stops only on *terminate* | Deleted on termination (`delete_on_termination = true`) — confirmed via `aws ec2 describe-volumes` returning `InvalidVolume.NotFound`. |
| Application Load Balancer | ~$16-20/mo if left running continuously | Not deployed. Torn down between sessions where practical. |
| CloudFront / S3 | Pay-per-use, negligible at portfolio traffic levels | Not deployed. |

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

**Current CloudMart AWS spend: $0/month.** Only the Phase 3 VPC (free resource types, standing) remains deployed. The `compute` module stays in the repo and gets redeployed the same way whenever a future phase needs it — no code changes required, just `terraform apply`.

This table will be updated at the end of each phase with actual/expected monthly cost if resources are left running, plus a reminder of the `terraform destroy` command to zero it back out.
