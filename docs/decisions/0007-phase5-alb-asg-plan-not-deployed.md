# 0007 - Phase 5 ALB + Auto Scaling Group: designed and plan-validated, not deployed

**Status:** Accepted
**Date:** 2026-08-20
**SAA-C03 domain(s):** Design High-Performing Architectures; Design Resilient Architectures; Cost Optimization

## Context
Phase 5's goal was to evolve CloudMart from Phase 4's single, temporary EC2 instance into a highly-available application tier: an Application Load Balancer in front of an Auto Scaling Group running 2 instances across both AZs. Unlike Phases 3 and 4, this phase was scoped from the start as design-and-plan-only — the priority stated for this phase was keeping ongoing AWS cost at $0 and not intentionally creating billable infrastructure, which this design (~$0.0675/hr, ~$48.57/month if left running) does not satisfy for standing infrastructure the way Phase 3's VPC does.

## Decision
The ALB/ASG architecture is fully designed, written in Terraform (`infrastructure/terraform/modules/compute/`), and verified via `terraform fmt`, `terraform validate`, and `terraform plan` — the plan cleanly shows 14 resources to add, 0 to change, 0 to destroy, with zero impact on the Phase 3 VPC. **It was deliberately never applied.** No `terraform apply` was run at any point in this phase.

## The planned architecture

```
                   Internet
                  │  HTTP :80
                       ▼
   ┌──────────────────────────────────────┐
   │ Application Load Balancer            │
   │ (spans both public subnets)          │
   │ SG: inbound 80 from 0.0.0.0/0 only;  │
   │ outbound only to backend SG on :4000 │
   └──────────────────────────────────────┘
                   │  :4000
                       ▼
       ┌───────────────────────────────┐
       │ Target Group                  │
       │ health check: GET /api/health │
       └───────────────────────────────┘
                       │
          ┬────────────┴────────────┬
          ▼                         ▼
┌───────────────────┐     ┌───────────────────┐
│ EC2 (us-east-1a)  │     │ EC2 (us-east-1b)  │
│ t2.micro          │     │ t2.micro          │
│ Backend SG: :4000 │     │ Backend SG: :4000 │
│ from ALB SG only  │     │ from ALB SG only  │
└───────────────────┘     └───────────────────┘
```

Both instances are managed by one **Auto Scaling Group** (`desired = min = max = 2`, fixed — no dynamic scaling policies this phase, to keep cost predictable), launched from a shared **Launch Template** (AMI looked up dynamically via SSM parameter, same pattern as Phase 3/4; IAM instance profile scoped to `AmazonSSMManagedInstanceCore` only, same as Phase 4 — no SSH, no key pair). The **Target Group** health-checks `GET /api/health` (the endpoint built in Phase 1) every 30s; the ASG uses `health_check_type = "ELB"` so it reacts to that same check, not just basic EC2 status.

## The 14 Terraform resources this plan proposes

| # | Resource | Purpose |
|---|---|---|
| 1 | `aws_security_group.alb` | ALB's security group (empty by itself — rules below) |
| 2 | `aws_vpc_security_group_ingress_rule.alb_http_from_internet` | ALB: allow `0.0.0.0/0` on port 80 only |
| 3 | `aws_vpc_security_group_egress_rule.alb_to_backend` | ALB: outbound restricted to backend SG on port 4000 only |
| 4 | `aws_security_group.backend` | Backend's security group (empty by itself — rules below) |
| 5 | `aws_vpc_security_group_ingress_rule.backend_from_alb` | Backend: allow port 4000 **only from the ALB's security group**, never a CIDR |
| 6 | `aws_vpc_security_group_egress_rule.backend_all_outbound` | Backend: all outbound (still needed — no NAT Gateway, instances use their own public IP via the existing IGW) |
| 7 | `aws_iam_role.ec2_ssm` | Instance role, same SSM-only approach as Phase 4 |
| 8 | `aws_iam_role_policy_attachment.ec2_ssm` | Attaches exactly `AmazonSSMManagedInstanceCore` |
| 9 | `aws_iam_instance_profile.ec2_ssm` | Wraps the role for EC2 |
| 10 | `aws_launch_template.backend` | AMI, instance type, security group, IAM profile, user_data, IMDSv2 required |
| 11 | `aws_lb_target_group.backend` | Health-checks `/api/health`, port 4000 |
| 12 | `aws_lb.main` | The Application Load Balancer, internet-facing, spans both public subnets |
| 13 | `aws_lb_listener.http` | Port 80 → forwards to the target group |
| 14 | `aws_autoscaling_group.backend` | desired=min=max=2, one instance per AZ, ELB health checks |

Two real EC2 instances would be launched by the ASG on `apply` — they don't appear as separate lines above because the ASG manages them dynamically at the AWS API level, not as individually Terraform-tracked resources. Both are counted in the cost estimate below regardless.

## Estimated cost if deployed

| | Rate | 2-hour validation | 30 days continuous |
|---|---|---|---|
| ALB (base) | $0.0225/hr | | |
| ALB public IPs (2 AZ nodes) | $0.005/hr × 2 | | |
| ALB LCU (usage-based) | $0.008/LCU-hr | negligible at low traffic | |
| EC2 (2× `t2.micro`) | $0.0116/hr × 2 | | |
| EC2 public IPs (2×) | $0.005/hr × 2 | | |
| EBS (2× 8GB gp3) | ~$0.0009/hr × 2 | | |
| **Total** | **~$0.0675/hr** | **~$0.13** | **~$48.57** |

Not assumed to be offset by AWS Free Tier — public IPv4 charges are never covered by Free Tier regardless of account age, and running 2 simultaneous `t2.micro` instances consumes the 750-hour/month free-tier pool twice as fast as one.

## Why we intentionally chose not to deploy it
This phase's explicit priority was $0 ongoing cost and avoiding intentionally creating billable infrastructure — a direct contrast with Phase 4, where a short paid validation window (~13¢ for 2 hours) was judged worth it. The difference here: Phase 5's design is fully verifiable through `terraform plan` alone (resource graph, security group rules, health check configuration, and dependency structure are all visible and correct without applying), and the $48.57/month figure for continuous operation is a meaningfully larger standing commitment than Phase 4's single-instance validation. Given the stated priority, keeping this as a **plan-validated, documented design** — provably correct, ready to deploy on demand, zero cost until that decision is made — was judged the better trade-off than paying even a small amount to watch it run once.

## How this improves availability compared to Phase 4
Phase 4 was one instance, one AZ, no redundancy, and reachable only via an authenticated SSM tunnel to a specific (frequently-changing) instance IP — a single point of failure in every sense. This design adds: a stable public entry point decoupled from any instance (the ALB's DNS name), two instances spread across two Availability Zones, and automatic detection-and-replacement of a failed instance via the ASG + target group health checks — see the failure scenarios below.

## Expected failure behavior

**One EC2 instance fails:** the target group's health check (30s interval, 3 consecutive failures to mark unhealthy) detects it within roughly 60–90 seconds. The ALB immediately stops routing new requests to that instance — the surviving instance keeps serving traffic uninterrupted. The ASG (using `health_check_type = "ELB"`, not just EC2 status) independently sees the same unhealthy status, terminates the instance, and launches a replacement from the Launch Template in the same subnet. The new instance boots, runs its `user_data` bootstrap, passes its first health check, and rejoins the target group automatically. No manual intervention anywhere in this sequence.

**An entire Availability Zone fails:** the ALB itself is a multi-AZ service (one node per subnet/AZ it's given), so losing an AZ doesn't take down the load balancer — only the capacity in that AZ. Traffic continues routing to the surviving AZ's instance via the target group. The ASG attempts to maintain its desired count of 2; if the failed AZ is genuinely unavailable, it typically runs at reduced capacity in the healthy AZ until that AZ recovers, rather than being stuck entirely. The application stays reachable throughout — only capacity is temporarily halved.

## Subnet placement
Both the ALB **and the backend instances** are placed in the Phase 3 **public** subnets — `environments/dev/main.tf` passes `subnet_ids = module.vpc.public_subnet_ids` to the module, which uses that one list for both `aws_lb.main.subnets` and `aws_autoscaling_group.backend.vpc_zone_identifier`. This is a cost decision, not an oversight: the VPC has no NAT Gateway (~$32+/month each, ~$65+/month for the per-AZ pair a highly-available design needs), and the instances need outbound internet at boot (`git clone`, `npm install`) and for SSM. With `map_public_ip_on_launch = true` on the public subnets, each instance gets its own public IP and reaches the internet through the Internet Gateway.

Being in a public subnet does not make the instances reachable: the only inbound rule on the backend security group is the app port from the ALB's security group (below). No SSH, no key pair, no CIDR-based rule.

**Production upgrade (documented, not built):** move the instances into the private subnets and give them outbound access via one NAT Gateway per AZ (the per-AZ private route tables from [ADR 0005](0005-vpc-network-design.md) exist for exactly this), or avoid NAT entirely with VPC interface endpoints for SSM/Secrets Manager, an S3 gateway endpoint, and a pre-baked AMI so boot doesn't need the public internet. The ALB stays in the public subnets either way.

**HTTP only:** the ALB has a single HTTP :80 listener (`aws_lb_listener.http`). An HTTPS :443 listener needs an ACM certificate, which needs a custom domain this project doesn't have. Custom domain + ACM + HTTPS listener (with :80 redirecting to :443) is also a documented production upgrade.

## Security group design
Backend port 4000 is reachable **exclusively** from the ALB's security group (`aws_vpc_security_group_ingress_rule.backend_from_alb`, referencing `aws_security_group.alb.id` — not a CIDR block). There is no path to port 4000 from the public internet, from any other resource in the VPC, or from anywhere else — only from something that is itself inside the ALB's security group. The only CIDR-based public ingress in this entire design is port 80 on the ALB itself, exactly as instructed. Implementation detail: every rule uses the standalone `aws_vpc_security_group_ingress_rule`/`egress_rule` resources rather than inline blocks, specifically because the ALB and backend security groups reference each other (a circular reference inline blocks can't express cleanly) and because AWS's Terraform provider warns against mixing inline and standalone rules on the same security group.

## Consequences
- CloudMart's actual deployed AWS footprint remains exactly the Phase 3 VPC (13 resources, $0/month) — Phase 5 added $0 in AWS charges.
- The `modules/compute` Terraform is fully written, formatted, validated, and plan-verified — deploying it later requires no design work, just `terraform apply` and the explicit cost approval that implies.
- This is a deliberate departure from Phase 4's pattern (deploy → validate → destroy) — worth being able to explain in an interview as a judgment call, not an oversight: not every phase needs to be run live to prove the design is sound.
