# 0008 - Phase 6 RDS PostgreSQL: designed and plan-validated, not deployed

**Status:** Accepted
**Date:** 2026-08-20
**SAA-C03 domain(s):** Design Resilient Architectures (databases); Design Secure Architectures (data protection, secrets); Cost Optimization

## Context
Phase 6's goal was to design CloudMart's database tier — Amazon RDS for PostgreSQL, private-subnet-only, trusted only by the backend's security group — while preserving the project's $0 ongoing AWS cost. Like Phase 5, this phase was explicitly scoped as design-and-plan-only from the outset, not deploy-and-validate like Phase 4.

## Decision
The database tier is fully designed in Terraform (`infrastructure/terraform/modules/database/`), wired into `environments/dev`, and verified via `terraform fmt`, `terraform validate`, and `terraform plan`. **It was never applied.** No `terraform apply` was run.

## Architecture

- **Engine:** PostgreSQL, `db.t3.micro`, 20 GB gp3 storage (the RDS PostgreSQL minimum).
- **Placement:** a DB subnet group spanning both of Phase 3's private subnets (both AZs) — required for RDS regardless of Multi-AZ, since RDS reserves the right to relocate the instance across AZs in that group during maintenance.
- **Network isolation:** `publicly_accessible = false` — no public IP, no path from the internet under any circumstance. The database's security group has exactly one rule: PostgreSQL (5432) from the backend's security group, referenced by ID, never a CIDR — and **zero egress rules**, since RDS doesn't need to initiate outbound connections for core functionality (a stricter default than the backend's own security group, which does need outbound access).
- **Encryption at rest:** enabled (`storage_encrypted = true`, default AWS-managed KMS key, no extra cost) — set at creation, since it cannot be added retroactively.
- **Backups:** 7-day automated backup retention with point-in-time recovery, a production-appropriate default independent of the Multi-AZ decision below.
- **Credentials:** `manage_master_user_password = true` — AWS generates and stores the master password in a Secrets Manager secret it creates and manages automatically. Neither this Terraform code nor its state file ever contains the password. A scoped IAM policy (`aws_iam_role_policy.backend_read_db_secret`, defined at the `environments/dev` level so neither the compute nor database module reaches into the other) grants the backend's existing SSM-only instance role permission to read exactly that one secret and nothing else.
- **Multi-AZ:** **not enabled** (`multi_az = false`, exposed as `var.db_multi_az`, defaulting to `false` in `environments/dev/variables.tf`). Documented as the clear production upgrade path — a single variable flip away — rather than defaulted on, per the cost decision below.

## The 5 new resources this phase adds

| Resource | Purpose |
|---|---|
| `module.database.aws_db_subnet_group.main` | Tells RDS which private subnets (both AZs) it may use |
| `module.database.aws_security_group.db` | Database's security group (empty by itself — rule below) |
| `module.database.aws_vpc_security_group_ingress_rule.db_from_backend` | PostgreSQL from the backend's security group only |
| `module.database.aws_db_instance.postgres` | The RDS instance itself |
| `aws_iam_role_policy.backend_read_db_secret` (root level) | Lets the backend's IAM role read the DB's auto-managed secret — nothing else |

`terraform plan` shows **19 to add** in total, not 5 — because Phase 5's ALB/Auto Scaling Group (14 resources) was also never applied (see [ADR 0007](0007-phase5-alb-asg-plan-not-deployed.md)), and Phase 6's database genuinely depends on Phase 5's backend security group by design (that dependency is the whole point of the security-group-trust model). The two phases can't be meaningfully isolated in a single plan — targeting `module.database` alone would still pull in Phase 5's security group as a dependency. **0 to change, 0 to destroy** — the Phase 3 VPC (13 resources) is completely untouched, confirmed by zero `module.vpc` create/change/destroy lines anywhere in the plan.

## Estimated cost if deployed

| | Single-AZ | Multi-AZ |
|---|---|---|
| RDS instance (`db.t3.micro`) | ~$13.14/mo | ~$26.28/mo |
| Storage (20 GB gp3) | ~$2.30/mo | ~$4.60/mo |
| Backup storage | $0 (within the free allowance equal to DB size, at this allocation) | $0 (likely) |
| Secrets Manager (managed master password) | ~$0.40/mo | ~$0.40/mo |
| Public IPv4 | **$0** — not publicly accessible | $0 |
| **Total** | **~$15.84/mo** | **~$31.28/mo** |

Not assumed Free-Tier-covered in the totals above. If the account is within its first 12 months, RDS Free Tier separately covers 750 hours/month of `db.t3.micro` Single-AZ plus 20 GB storage and 20 GB backups — reducing Single-AZ to roughly just the $0.40/month Secrets Manager charge (never Free-Tier-eligible). Multi-AZ is never Free-Tier-eligible regardless of account age.

## Why we intentionally chose not to deploy it
Same reasoning as Phase 5 ([ADR 0007](0007-phase5-alb-asg-plan-not-deployed.md)): the stated priority for this phase was $0 ongoing cost, not a short paid validation window like Phase 4's. RDS is also a meaningfully heavier commitment than Phase 5's compute — ~$15.84-31.28/month is a real standing cost, and unlike EC2 there's no "stop it for free between sessions" option for RDS in the same way (a stopped RDS instance still incurs storage charges, and AWS auto-starts a stopped instance after 7 days regardless). Keeping this as a plan-validated, documented design was judged the correct trade-off given the explicit cost-control priority stated for this phase.

## Alternatives considered
- **Aurora PostgreSQL (Serverless v2):** genuinely interesting for a cost-conscious design — Aurora Serverless can scale to near-zero capacity during idle periods, which could make "leave it running" more viable than standard RDS. Not chosen for this phase to keep the design aligned with the SAA exam's RDS-focused terminology and mental model (subnet groups, Multi-AZ vs Single-AZ, automated backups) before introducing Aurora's different scaling/pricing model as a later comparison point.
- **Self-managed PostgreSQL on EC2:** rejected — reinvents patching, backup automation, and failover that RDS provides natively, for no cost advantage significant enough to justify the operational burden.

## Consequences
- CloudMart's actual deployed AWS footprint remains exactly the Phase 3 VPC (13 resources, $0/month) — Phase 6 added $0 in AWS charges.
- The `modules/database` Terraform is fully written, formatted, validated, and plan-verified — deploying it later requires no further design work, just `terraform apply` and the explicit cost approval that implies.
- The backend's IAM role now has a defined (but currently inert, since the database doesn't exist) permission to read the future database secret — visible in the plan as `aws_iam_role_policy.backend_read_db_secret`, costing nothing regardless of deployment state, since IAM policies are always free.
