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
| EC2 (on-demand, running 24/7) | Free Tier: 750 hrs/mo of `t2.micro`/`t3.micro` for 12 months, then ~$7-8/mo per instance | Not deployed. |
| Application Load Balancer | ~$16-20/mo if left running continuously | Not deployed. Torn down between sessions where practical. |
| CloudFront / S3 | Pay-per-use, negligible at portfolio traffic levels | Not deployed. |

## Running estimate

_Current spend from this project: **$0/month.**_

Phase 2 added AWS CLI/Terraform tooling and IAM Identity Center authentication, and ran read-only `data` source lookups against the account (free — `Describe`/`Get`/`List`-style read API calls are never billed).

Phase 3's VPC network is **deployed** (`terraform apply` completed 2026-08-20): 1 VPC, 4 subnets across 2 AZs, 1 Internet Gateway, 3 route tables, 4 route table associations — 13 resources, all free resource types with no hourly or usage charge. Independently verified via `aws ec2 describe-*` calls that no NAT Gateway, Elastic IP, or EC2 instance exists in the account. The only networking resource that costs anything — a NAT Gateway — is not present anywhere in this phase's Terraform, per [ADR 0005](decisions/0005-vpc-network-design.md). Real resource IDs: [networking.md](networking.md).

This table will be updated at the end of each phase with actual/expected monthly cost if resources are left running, plus a reminder of the `terraform destroy` command to zero it back out.
