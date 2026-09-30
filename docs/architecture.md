# CloudMart Architecture

> This is a living document. It reflects the architecture **as currently built**, not the end goal — see [ROADMAP.md](ROADMAP.md) for what's planned but not yet implemented.

## Current state (Phase 8 — operational polish: monitoring, security, reliability documented; runbook added)

**Deployed AWS footprint right now: the Phase 3 VPC (13 resources, $0/month, standing) plus the Phase 7 frontend hosting (7 resources, usage-based, deployed 2026-08-20).** Phases 5, 6, and 8's monitoring remain undeployed — Phase 8 is a documentation and design phase, not a deployment one. CloudMart is portfolio-ready as of this phase; see the "What remains" section at the end of this document for the honest gap list.

- **Phase 2 (local tooling + auth, no AWS resources):** AWS CLI v2 + Terraform 1.15 installed; authentication via AWS IAM Identity Center (SSO) — `aws sso login --profile cloudmart` — no long-lived IAM access keys. See [ADR 0004](decisions/0004-aws-authentication-via-iam-identity-center.md). A connectivity-check-only Terraform config at `infrastructure/terraform/` (zero `resource` blocks) confirms Terraform can reach the account.
- **Phase 3 — ✅ deployed, standing infrastructure, $0/month:** `infrastructure/terraform/modules/vpc/` created CloudMart's network foundation — 13 resources, all free resource types, no hourly or usage charge regardless of runtime. Full layout and CIDR plan: [networking.md](networking.md). Design reasoning: [ADR 0005](decisions/0005-vpc-network-design.md).
- **Phase 4 — ✅ deployed, validated, then intentionally destroyed (2026-08-20):** a single `t2.micro` EC2 instance running the Express backend was deployed into the Phase 3 public subnet, no SSH, no inbound security group rule by default, access via SSM only. Validated while running (SSM registration, `/api/health`, `/api/products` all confirmed), then torn down via `terraform destroy -target=module.compute` for cost control — independently confirmed gone via `aws ec2`/`aws iam`. Design reasoning: [ADR 0006](decisions/0006-ec2-compute-placement-and-access.md). **Note:** the code that implemented this specific single-instance design was subsequently replaced by the Phase 5 rewrite of `modules/compute` described below.
- **Phase 5 — 🟡 PLAN-VALIDATED ONLY — NOT DEPLOYED DUE TO COST CONTROL:** `infrastructure/terraform/modules/compute/` was rewritten from Phase 4's single instance into an Application Load Balancer + Auto Scaling Group (2 instances across both AZs). **Both the ALB and the instances are placed in the Phase 3 _public_ subnets** (`subnet_ids = module.vpc.public_subnet_ids` in `environments/dev/main.tf`): there is no NAT Gateway, so the instances use their own public IP through the Internet Gateway for outbound traffic (boot-time `git clone`/`npm install`, SSM). They accept no inbound traffic except the app port from the ALB's security group. Moving the instances into the private subnets behind a NAT Gateway (or VPC endpoints for SSM/S3 plus a pre-baked AMI so boot doesn't need the internet) is the documented production upgrade. Design, cost estimate, and reasoning: [ADR 0007](decisions/0007-phase5-alb-asg-plan-not-deployed.md).
- **Phase 6 — 🟡 PLAN-VALIDATED ONLY — NOT DEPLOYED DUE TO COST CONTROL:** `infrastructure/terraform/modules/database/` adds an RDS PostgreSQL instance in the Phase 3 private subnets — not publicly accessible, trusted only by the backend's security group, encrypted at rest, 7-day automated backups, master password managed automatically by AWS via Secrets Manager (never in Terraform state or this repo). Design, cost estimate, and reasoning: [ADR 0008](decisions/0008-phase6-rds-plan-not-deployed.md).
- **Phase 7 — ✅ DEPLOYED (2026-08-20):** `infrastructure/terraform/modules/static-site/` — private S3 bucket + CloudFront distribution (Origin Access Control, HTTPS via CloudFront's default certificate, SPA-routing error responses) for the React/Vite frontend. Applied via `terraform apply -target=module.static_site` (never a bare `apply`, to avoid also deploying Phases 5/6) — `Apply complete! Resources: 7 added, 0 changed, 0 destroyed.` Independently verified, not just Terraform's own report: bucket exists with all four public-access blocks `true`; bucket policy grants read access only to the CloudFront service principal, scoped to this exact distribution's ARN; direct S3 access (both regional-REST and path-style URLs) returns `403 AccessDenied`; CloudFront distribution status `Deployed`; the built frontend (`npm run build`, 3 files, content-hashed JS/CSS) was uploaded and confirmed loading over HTTPS (TLS 1.3, `HTTP/2 200`); a repeat request showed `x-cache: Hit from cloudfront`, confirming caching; a deep-link path (`/products/5`) returned `200` via the SPA-routing fallback, not a 403/404. Zero impact on the Phase 3 VPC, and Phases 5/6 remain entirely undeployed. Full architecture, cost estimate, and reasoning: [ADR 0009](decisions/0009-phase7-static-site-plan-not-deployed.md).
- **Phase 8 — 🟡 DESIGNED, PARTIALLY PLAN-VALIDATED, NOT DEPLOYED:** `infrastructure/terraform/modules/monitoring/` adds one active CloudWatch alarm (CloudFront 5xx error rate) + an SNS topic — `terraform plan -target=module.monitoring` confirms 2 resources, 0 to change, 0 to destroy, ~$0/month estimated (within CloudWatch's always-free 10-alarm allowance). Eight more alarms (ALB, ASG, RDS) are fully written but gated `false` until Phase 5/6 deploy. **Not applied this phase** — awaiting separate approval like every other resource in this project. Full monitoring/logging/security/reliability/cost synthesis: this document (below), [docs/security.md](security.md), [docs/cost.md](cost.md); day-to-day operations: [docs/runbook.md](runbook.md). Design reasoning, including a real Terraform dependency-graph bug found and fixed during this phase: [ADR 0010](decisions/0010-phase8-operational-polish.md).

Real AWS resource IDs (VPC ID, subnet IDs, etc.) aren't hardcoded in this document — they're ephemeral (they change every time this environment is destroyed and recreated) and account-specific, so a static value here would go stale and adds no teaching value a reader can act on. Get the current ones anytime with:

```bash
cd infrastructure/terraform/environments/dev && terraform output
```

Terraform state for this environment lives in `infrastructure/terraform/environments/dev/terraform.tfstate` — local only, gitignored (never committed), since it can contain sensitive resource details. A remote backend (S3 + DynamoDB locking) would matter with multiple operators — deliberately not built for this single-person project; see [ROADMAP.md](ROADMAP.md) "Beyond Phase 8."

The application itself, from Phase 1, is unchanged — still running entirely on localhost:

- **Frontend:** React + Vite SPA (`frontend/`) on `http://localhost:5173`. Fetches products from the backend on load, renders a product grid, and tracks a client-side cart count. No routing, no state management library — a single `App.jsx` component tree is enough for this scope.
- **Backend:** Express REST API (`backend/`) on `http://localhost:4000`, exposing `GET /api/products` (hardcoded in-memory data) and `GET /api/health`. No database.
- **Coupling:** the frontend reads the backend's base URL from `VITE_API_BASE_URL` (a Vite env var), not a hardcoded address — so retargeting it at a real AWS endpoint later is a config change. CORS is enabled on the backend for the frontend's origin, configurable via `FRONTEND_ORIGIN`.

This local split is intentionally shaped like the target AWS split: the frontend maps to S3 + CloudFront (static assets), the backend maps to EC2 behind an ALB (compute). See [ROADMAP.md](ROADMAP.md) Phase 1 and the "local → AWS mapping" table below.

This document will be updated at the end of every phase with:

- What was added this phase and why
- An updated architecture diagram (see [../diagrams/](../diagrams/))
- Any deviations from the original plan, and why

### Local → AWS mapping

| Local (Phase 1) | Eventually becomes | Phase |
|---|---|---|
| `frontend/` served by Vite dev server | ✅ Static build deployed to S3, distributed via CloudFront (Phase 7 — live) | 7 |
| `backend/` Express server on a fixed port | Same Express app, running on EC2 instances behind an ALB, managed by an Auto Scaling Group (Phase 5 design plan-validated, not deployed) | 4-5 |
| `GET /api/health` | ALB target group health check endpoint | 5 |
| Hardcoded `products.js` array | Amazon RDS-backed product table | 6 |
| `VITE_API_BASE_URL` env var | No backend is deployed yet to point at. A production build treats an unset or `localhost` value as "no API" and serves a static copy of the catalog (the backend's own `products.js`, bundled) with a "Demo mode" banner instead of an error. Will be repointed at the ALB's DNS name and rebuilt once Phase 5 is actually applied. | 7-8 |
| `FRONTEND_ORIGIN` CORS config | Revisited once frontend and backend sit behind CloudFront/ALB — may become same-origin | 7 |
| Backend `.env` (local secrets) | AWS Secrets Manager | 6 |

## Target architecture (end state)

```
                              ┌─────────────────────┐
                              │      Route 53        │
                              └──────────┬───────────┘
                                         │
                          ┌──────────────┴──────────────┐
                          │                              │
                 ┌────────▼────────┐           ┌─────────▼─────────┐
                 │   CloudFront     │           │   Application      │
                 │   (frontend CDN) │           │   Load Balancer     │
                 └────────┬────────┘           └─────────┬─────────┘
                          │                               │
                 ┌────────▼────────┐          ┌───────────▼────────────┐
                 │   S3 (static     │          │   VPC (2 AZs)          │
                 │   frontend)      │          │  ┌──────────────────┐  │
                 └──────────────────┘          │  │ Public subnets    │  │
                                                │  │  ALB              │  │
                                                │  │  EC2 (ASG) ──────┼──┼── Secrets Manager
                                                │  │  (inbound: ALB SG │  │
                                                │  │   only; no NAT)   │  │
                                                │  ├──────────────────┤  │
                                                │  │ Private subnets   │  │
                                                │  │  RDS              │  │
                                                │  └──────────────────┘  │
                                                └─────────────────────────┘

     Cross-cutting: IAM (least privilege) · Security Groups · CloudWatch (metrics/alarms/logs)
```

EC2 sits in the public subnets because the design has no NAT Gateway (cost) — see the Phase 5 entry above; moving the instances into the private subnets behind a NAT Gateway (or VPC endpoints for SSM/S3 plus a pre-baked AMI so boot doesn't need the internet) is the documented production upgrade. This diagram will be replaced with a real rendered diagram (see [../diagrams/README.md](../diagrams/README.md)) once compute is actually deployed as standing infrastructure, not just plan-validated. An ASCII-level VPC/subnet diagram of what's actually deployed exists in [networking.md](networking.md); an ASCII-level diagram of the plan-validated-but-not-deployed ALB/ASG design exists in [ADR 0007](decisions/0007-phase5-alb-asg-plan-not-deployed.md).

## Design principles

1. **Security first** — private subnets for data/compute where possible, least-privilege IAM, no secrets in code or Git.
2. **High availability where it's cheap, discussed where it isn't** — multi-AZ subnet layout always; Multi-AZ RDS and NAT Gateways are cost/availability trade-offs that get called out explicitly rather than defaulted on.
3. **Everything as code** — Terraform is the source of truth; the AWS console is for reading, not changing.
4. **Cost-aware by default** — see [cost.md](cost.md).
5. **Explainable** — every service earns an ADR in [decisions/](decisions/) before it's added.

## Monitoring & observability

*(Phase 8 — one alarm active, rest designed; see [ADR 0010](decisions/0010-phase8-operational-polish.md) for the full reasoning)*

**Metrics that matter, per tier:**

| Tier | Key CloudWatch metrics | Status |
|---|---|---|
| CloudFront | `5xxErrorRate`, `4xxErrorRate`, `Requests`, `BytesDownloaded` — all free standard metrics, no opt-in needed | `5xxErrorRate` alarm designed and plan-validated (2 resources: alarm + SNS topic), ~$0/mo, **not yet applied** |
| ALB | `HTTPCode_ELB_5XX_Count`, `HTTPCode_Target_5XX_Count`, `UnHealthyHostCount`, `TargetResponseTime`, `RequestCount` | 3 alarms designed, inert until Phase 5 deploys |
| Auto Scaling Group | `CPUUtilization` (aggregated across the ASG's instances via the `AutoScalingGroupName` dimension — not per-instance, since instances are ephemeral), `GroupInServiceInstances` vs `GroupDesiredCapacity` | 1 alarm designed (CPU), inert until Phase 5 deploys |
| RDS | `CPUUtilization`, `FreeStorageSpace`, `DatabaseConnections`, `ReadLatency`/`WriteLatency`, `FreeableMemory` | 3 alarms designed (CPU, storage, connections), inert until Phase 6 deploys |

**Why these specific alarms and not others:** each one answers a concrete "what would I actually want paged for" question — ALB 5xx and unhealthy-host alarms catch the failure scenarios described below as they happen; RDS storage and connection alarms catch problems *before* they become outright outages (a full disk or exhausted connection pool fails ungracefully); CPU alarms on both ASG and RDS are early-capacity-warning signals, not just incident response. Deliberately excluded for now: anything requiring CloudFront's paid "additional metrics" tier, and dashboards (CloudWatch dashboards cost $3/month each beyond the first 3 free — not worth it for a project with one alarm currently active).

## Reliability

**Health checks:** the target group polls `GET /api/health` every 30s (2 consecutive successes to mark healthy, 3 consecutive failures to mark unhealthy) — the same endpoint built in Phase 1. The ASG uses `health_check_type = "ELB"`, so it reacts to *that* check, not just basic EC2 status — meaning an OS that's fine but a Node process that's crashed still gets correctly detected and the instance replaced.

**What happens if one EC2 instance fails:** detected within ~60-90s by the target group; the ALB stops routing to it immediately (the surviving instance keeps serving traffic uninterrupted); the ASG independently terminates it and launches a replacement from the Launch Template, which boots, runs its `user_data`, passes its first health check, and rejoins the target group automatically. No manual intervention anywhere in this sequence.

**What happens if an entire Availability Zone fails:** the ALB itself is multi-AZ (one node per subnet/AZ it's given), so losing an AZ doesn't take down the load balancer, only the capacity in that AZ. Traffic continues routing to the surviving AZ's instance. The ASG attempts to maintain its desired count of 2; if the failed AZ is genuinely unavailable, it typically runs at reduced capacity in the healthy AZ until that AZ recovers, rather than being stuck entirely.

**Multi-AZ (RDS):** not enabled by default (`var.db_multi_az = false`) — a deliberate cost/availability trade-off, not an oversight. If enabled, RDS maintains a synchronous standby in a second AZ and automatically fails over on primary failure, typically within 60-120 seconds, with the DB endpoint's DNS automatically repointed so the application's connection string never changes. Cost: roughly doubles the RDS bill (see [docs/cost.md](cost.md)).

**Backups:** 7-day automated backup retention with point-in-time recovery designed for Phase 6 (independent of the Multi-AZ decision — backups protect against *data* problems, Multi-AZ protects against *availability* problems; a real production system needs both).

**RTO / RPO considerations** (Recovery Time Objective / Recovery Point Objective — how long an outage lasts, and how much data could be lost):

| Scenario | RTO | RPO |
|---|---|---|
| One EC2 instance fails (ASG active) | ~60-90s (health check detection) + instance boot time (~1-2 min) | 0 — no data lives on the instance itself |
| One AZ fails (ALB + ASG spanning 2 AZs) | Near-zero for the app (surviving AZ keeps serving); ASG restores full capacity once the AZ recovers or a replacement launches elsewhere | 0 |
| RDS primary fails, Multi-AZ enabled | ~60-120s (automatic failover) | Near-zero (synchronous replication — no data loss on failover) |
| RDS primary fails, Single-AZ (current default) | Until a new instance is provisioned and restored from the latest automated backup — could be many minutes, no automatic failover | Up to the automated backup's point-in-time recovery granularity (effectively seconds, given continuous transaction log shipping) — but the *time to restore* is the real gap here, not data loss |
| Accidental data deletion/corruption | Time to identify the issue + restore-to-point-in-time duration (scales with DB size) | Near-zero — point-in-time recovery can target any second within the 7-day retention window |

The Single-AZ RDS row is the honest gap in the current design: acceptable for a learning project with no real users, explicitly not acceptable for production, which is exactly why Multi-AZ is documented as the flip-a-variable upgrade path rather than silently defaulted on.

## Phase-by-phase log

| Phase | Status | Summary |
|---|---|---|
| 0 — Scaffolding | ✅ Done | Repo structure, docs, license |
| 1 — Local app | ✅ Done | React/Vite storefront + Express API running locally, no AWS |
| 2 — AWS foundations | ✅ Done | AWS CLI + Terraform installed, IAM Identity Center (SSO) auth, connectivity-only Terraform bootstrap |
| 3 — Networking | ✅ Deployed | VPC + 4 subnets + IGW + 3 route tables live in AWS, 13 resources, $0/month |
| 4 — Compute | ✅ Validated, then destroyed | t2.micro backend deployed, SSM-only access confirmed working, intentionally torn down for cost control — superseded by the Phase 5 rewrite |
| 5 — Load balancing & ASG | 🟡 Plan-validated only, not deployed | 14 resources verified via `terraform plan` ($0 to change, $0 to destroy), deliberately not applied — cost-control decision, see ADR 0007 |
| 6 — Database | 🟡 Plan-validated only, not deployed | RDS PostgreSQL designed (private-only, encrypted, SG-trust, 7-day backups), 5 new resources verified via `terraform plan`, deliberately not applied — cost-control decision, see ADR 0008 |
| 7 — Static assets & CDN | ✅ Deployed | Private S3 + CloudFront + OAC live, frontend build uploaded, HTTPS/caching/SPA-routing all independently verified, 7 resources, usage-based cost only — see ADR 0009 |
| 8 — DNS | ⬜ Not started | |
| 9 — Security hardening | ⬜ Not started | |
| 10 — Monitoring | ⬜ Not started | |
| 11 — Terraform cleanup | ⬜ Not started | |
| 12 — Docs & polish | ⬜ Not started | |
