# Networking

CloudMart's network foundation, built in Phase 3 via `infrastructure/terraform/modules/vpc/` (reusable module) and `infrastructure/terraform/environments/dev/` (the root config that calls it with real values). **Deployed to AWS** on 2026-08-20 (`terraform apply`, account `937485903165`, `us-east-1`) — `Apply complete! Resources: 13 added, 0 changed, 0 destroyed.` Independently verified via `aws ec2 describe-vpcs`/`describe-subnets`/`describe-internet-gateways`/`describe-route-tables`, not just Terraform's own output.

## Deployed resource IDs

| Resource | ID |
|---|---|
| VPC | `vpc-0a82438460af02b05` |
| Internet Gateway | `igw-0953cfd024cea3a2b` |
| Public subnet (us-east-1a) | `subnet-04837a778fb2d3acf` |
| Public subnet (us-east-1b) | `subnet-060de850a2e9e39b5` |
| Private subnet (us-east-1a) | `subnet-05e43ab7674bd7594` |
| Private subnet (us-east-1b) | `subnet-06dee9395e05c4ce8` |
| Public route table | `rtb-08f403594e70d14f6` |
| Private route table (us-east-1a) | `rtb-0698ef93a0b5af115` |
| Private route table (us-east-1b) | `rtb-0d2beaf2baabc584b` |

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

## What's NOT built yet
- NAT Gateway (would give private subnets outbound internet — has an hourly cost, deferred until something in a private subnet actually needs it)
- Security groups (Phase 4, once EC2 exists — a security group with nothing attached has no purpose)
- Network ACLs (default NACL allows all traffic; a custom one is a possible Phase 9 hardening item, not required for a functioning VPC)
- VPC Flow Logs (monitoring, Phase 10)
