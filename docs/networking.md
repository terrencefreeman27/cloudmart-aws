# Networking

CloudMart's network foundation, built in Phase 3 via `infrastructure/terraform/modules/vpc/` (reusable module) and `infrastructure/terraform/environments/dev/` (the root config that calls it with real values). **Deployed to AWS** on 2026-08-20 (`terraform apply`, `us-east-1`) — `Apply complete! Resources: 13 added, 0 changed, 0 destroyed.` Independently verified via `aws ec2 describe-vpcs`/`describe-subnets`/`describe-internet-gateways`/`describe-route-tables`, not just Terraform's own output.

## Resource inventory

| Resource | Count |
|---|---|
| VPC | 1 |
| Internet Gateway | 1 |
| Public subnets (one per AZ) | 2 |
| Private subnets (one per AZ) | 2 |
| Public route table | 1 |
| Private route tables (one per AZ) | 2 |

Real AWS resource IDs (`vpc-...`, `subnet-...`, `rtb-...`) aren't published here — they're specific to this AWS account and this exact deployment, they change every time the environment is destroyed and recreated, and they don't add anything a reader could verify or reuse. The source of truth for current IDs is Terraform's own output, not a static doc:

```bash
cd infrastructure/terraform/environments/dev && terraform output
```

Note: the VPC also has a 4th route table AWS creates automatically for every VPC (its "main"/default route table) — that one isn't managed by Terraform, has no subnets explicitly associated with it, and isn't part of the 13 resources this project created.

## Layout

```
VPC: cloudmart-dev-vpc — 10.0.0.0/16 (us-east-1)

┌───────────────────────────────────────────────────────────────────┐
│ AZ: us-east-1a                    AZ: us-east-1b                  │
│ ┌─────────────────────────────┐   ┌─────────────────────────────┐ │
│ │ Public subnet               │   │ Public subnet               │ │
│ │ 10.0.1.0/24                 │   │ 10.0.2.0/24                 │ │
│ │ -> public-rt -> IGW         │   │ -> public-rt -> IGW         │ │
│ └─────────────────────────────┘   └─────────────────────────────┘ │
│                                                                   │
│ ┌─────────────────────────────┐   ┌─────────────────────────────┐ │
│ │ Private subnet              │   │ Private subnet              │ │
│ │ 10.0.11.0/24                │   │ 10.0.12.0/24                │ │
│ │ -> private-rt-1a (local)    │   │ -> private-rt-1b (local)    │ │
│ └─────────────────────────────┘   └─────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────┘
                                  │
                          Internet Gateway
                                  │
                              Internet
```

## CIDR plan

| Resource | CIDR | AZ | Usable IPs |
|---|---|---|---|
| VPC | `10.0.0.0/16` | (spans both) | 65,536 |
| Public subnet A | `10.0.1.0/24` | us-east-1a | 251 |
| Public subnet B | `10.0.2.0/24` | us-east-1b | 251 |
| Private subnet A | `10.0.11.0/24` | us-east-1a | 251 |
| Private subnet B | `10.0.12.0/24` | us-east-1b | 251 |

Public subnets use `.1.x`/`.2.x`, private use `.11.x`/`.12.x` — the gap is deliberate, leaving room to add more subnet tiers later (e.g. a dedicated `.21.x`/`.22.x` database tier) without renumbering anything that already exists. Each `/24` reserves 5 AWS-reserved addresses (network, VPC router, DNS, future use, broadcast), leaving 251 usable — plenty for this project's scale.

AZs are **not hardcoded** as `us-east-1a`/`us-east-1b` in the Terraform code; they're looked up at plan time via `data "aws_availability_zones" "available"` and the first two are selected. This plan run resolved to `us-east-1a` and `us-east-1b`, but the code would adapt automatically in an account where those specific letters aren't available (AWS actually maps AZ *names* to different physical locations per account, specifically to spread load evenly — hardcoding a letter isn't portable across accounts).

## Route tables

| Route table | Associated subnet(s) | Routes |
|---|---|---|
| `public-rt` (shared) | Both public subnets | `10.0.0.0/16 → local` (automatic), `0.0.0.0/0 → Internet Gateway` |
| `private-rt-us-east-1a` | Private subnet A | `10.0.0.0/16 → local` (automatic) only |
| `private-rt-us-east-1b` | Private subnet B | `10.0.0.0/16 → local` (automatic) only |

Both public subnets share one route table since they need an identical rule. Private subnets each get their **own** route table, per AZ, even though right now both are empty except the automatic local route — this anticipates per-AZ NAT Gateways in a later phase (each AZ's outbound route should point at *that AZ's own* NAT Gateway, not a shared one, so a NAT Gateway failure in one AZ doesn't take down the other AZ's outbound internet access). Structuring it this way now means adding NAT later is "add one route to two existing tables," not "restructure route table associations."

**Private subnets currently have no path to the internet at all** — this is intentional, not a bug. There's nothing in them yet that needs it. See [ADR 0005](decisions/0005-vpc-network-design.md) and [cost.md](cost.md) for the NAT Gateway trade-off.

## What's NOT built
- NAT Gateway (would give private subnets outbound internet — has an hourly cost; not present anywhere in this project's Terraform, deliberately — see [docs/cost.md](cost.md))
- Security groups (arrived with the compute that uses them — see [ADR 0006](decisions/0006-ec2-compute-placement-and-access.md))
- Network ACLs (default NACL allows all traffic; a custom one is a real production-hardening item, deliberately not pursued — see [docs/security.md](security.md) "Production hardening checklist")
- VPC Flow Logs (deliberately not enabled — see [docs/security.md](security.md), consistent with the Phase 8 decision not to enable logging without an active traffic/debugging need)
