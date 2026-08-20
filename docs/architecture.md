# CloudMart Architecture

> This is a living document. It reflects the architecture **as currently built**, not the end goal — see [ROADMAP.md](ROADMAP.md) for what's planned but not yet implemented.

## Current state (Phase 4 — compute validated, then torn down)

- **Phase 2 (local tooling + auth, no AWS resources):** AWS CLI v2 + Terraform 1.15 installed; authentication via AWS IAM Identity Center (SSO) — `aws sso login --profile cloudmart` — no long-lived IAM access keys. See [ADR 0004](decisions/0004-aws-authentication-via-iam-identity-center.md). A connectivity-check-only Terraform config at `infrastructure/terraform/` (zero `resource` blocks) confirms Terraform can reach the account.
- **Phase 3 (deployed, standing infrastructure):** `infrastructure/terraform/modules/vpc/` created CloudMart's network foundation — 13 resources. All free; **$0/month with nothing else attached.** Full layout and CIDR plan: [networking.md](networking.md). Design reasoning: [ADR 0005](decisions/0005-vpc-network-design.md).
- **Phase 4 (deployed, validated, and intentionally torn down — 2026-08-20):** `infrastructure/terraform/modules/compute/` added a single `t2.micro` EC2 instance running the Express backend, in the existing public subnet, with **no SSH and no inbound security group rule of any kind by default** — access was via AWS Systems Manager (Session Manager / port forwarding) only. Design reasoning: [ADR 0006](decisions/0006-ec2-compute-placement-and-access.md).
  - **Validated while running:** instance reached `running` state, registered with SSM (`PingStatus: Online`), security group confirmed to have zero ingress rules, and both `GET /api/health` and `GET /api/products` returned correct responses through an SSM port-forwarding tunnel.
  - **Then destroyed for cost control**, via `terraform destroy -target=module.compute` — this is the intended lifecycle for this module, not a rollback. Independently confirmed via `aws ec2`/`aws iam` (not just Terraform's own report): instance `terminated`, security group and IAM role/instance-profile all return `NotFound`, the root EBS volume no longer exists, and the auto-assigned public IP is no longer associated with anything. The Phase 3 VPC (all 13 resources) was independently re-verified as untouched throughout. Full before/after detail: [cost.md](cost.md), [deployment.md](deployment.md).
  - **The module stays in the repo, ready to redeploy.** A `terraform plan` right now correctly shows `5 to add` (not `0 to add`) — that's expected: `-target` removed the real infrastructure and its state entries, but the `module "compute"` block is still declared in `environments/dev/main.tf` on purpose, so a future `terraform apply` recreates it (new instance ID, new IP, fresh `user_data` boot) without editing any code.
  - **Operational note:** applying the IAM role initially failed — the `cloudmart` profile's PowerUserAccess permission set deliberately excludes IAM management actions (a built-in anti-privilege-escalation guardrail). Resolved by attaching a narrowly-scoped custom policy to that permission set rather than widening it. Full story in [ADR 0006](decisions/0006-ec2-compute-placement-and-access.md).

Real AWS resource IDs (VPC ID, subnet IDs, etc.) aren't hardcoded in this document — they're ephemeral (they change every time this environment is destroyed and recreated) and account-specific, so a static value here would go stale and adds no teaching value a reader can act on. Get the current ones anytime with:

```bash
cd infrastructure/terraform/environments/dev && terraform output
```

Terraform state for this environment lives in `infrastructure/terraform/environments/dev/terraform.tfstate` — local only, gitignored (never committed), since it can contain sensitive resource details. A remote backend is planned for Phase 11.

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
| `frontend/` served by Vite dev server | Static build deployed to S3, distributed via CloudFront | 7 |
| `backend/` Express server on a fixed port | Same Express app, running on EC2 instances behind an ALB, managed by an Auto Scaling Group | 4-5 |
| `GET /api/health` | ALB target group health check endpoint | 5 |
| Hardcoded `products.js` array | Amazon RDS-backed product table | 6 |
| `VITE_API_BASE_URL` env var | Points at the ALB/CloudFront domain instead of `localhost:4000` | 7-8 |
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
                                                │  │  (ALB, NAT if any)│  │
                                                │  ├──────────────────┤  │
                                                │  │ Private subnets   │  │
                                                │  │  EC2 (ASG) ──────┼──┼── Secrets Manager
                                                │  │  RDS              │  │
                                                │  └──────────────────┘  │
                                                └─────────────────────────┘

     Cross-cutting: IAM (least privilege) · Security Groups · CloudWatch (metrics/alarms/logs)
```

This diagram will be replaced with a real rendered diagram (see [../diagrams/README.md](../diagrams/README.md)) once compute is standing infrastructure rather than a temporary validation deployment (Phase 5). An ASCII-level VPC/subnet diagram of what's actually deployed exists in [networking.md](networking.md).

## Design principles

1. **Security first** — private subnets for data/compute where possible, least-privilege IAM, no secrets in code or Git.
2. **High availability where it's cheap, discussed where it isn't** — multi-AZ subnet layout always; Multi-AZ RDS and NAT Gateways are cost/availability trade-offs that get called out explicitly rather than defaulted on.
3. **Everything as code** — Terraform is the source of truth; the AWS console is for reading, not changing.
4. **Cost-aware by default** — see [cost.md](cost.md).
5. **Explainable** — every service earns an ADR in [decisions/](decisions/) before it's added.

## Phase-by-phase log

| Phase | Status | Summary |
|---|---|---|
| 0 — Scaffolding | ✅ Done | Repo structure, docs, license |
| 1 — Local app | ✅ Done | React/Vite storefront + Express API running locally, no AWS |
| 2 — AWS foundations | ✅ Done | AWS CLI + Terraform installed, IAM Identity Center (SSO) auth, connectivity-only Terraform bootstrap |
| 3 — Networking | ✅ Deployed | VPC + 4 subnets + IGW + 3 route tables live in AWS, 13 resources, $0/month |
| 4 — Compute | ✅ Validated, then destroyed | t2.micro backend deployed, SSM-only access confirmed working, intentionally torn down for cost control — module ready to redeploy |
| 5 — Load balancing & ASG | ⬜ Not started | |
| 6 — Database | ⬜ Not started | |
| 7 — Static assets & CDN | ⬜ Not started | |
| 8 — DNS | ⬜ Not started | |
| 9 — Security hardening | ⬜ Not started | |
| 10 — Monitoring | ⬜ Not started | |
| 11 — Terraform cleanup | ⬜ Not started | |
| 12 — Docs & polish | ⬜ Not started | |
