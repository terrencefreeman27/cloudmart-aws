# CloudMart Architecture

> This is a living document. It reflects the architecture **as currently built**, not the end goal — see [ROADMAP.md](ROADMAP.md) for what's planned but not yet implemented.

## Current state (Phase 3 — VPC deployed)

**The Phase 3 VPC now exists in AWS** (account `937485903165`, `us-east-1`), applied via `terraform apply` on 2026-08-20. No other AWS resources exist — no EC2, no NAT Gateway, no load balancer, no database.

- **Phase 2 (local tooling + auth, no AWS resources):** AWS CLI v2 + Terraform 1.15 installed; authentication via AWS IAM Identity Center (SSO) — `aws sso login --profile cloudmart` — no long-lived IAM access keys. See [ADR 0004](decisions/0004-aws-authentication-via-iam-identity-center.md). A connectivity-check-only Terraform config at `infrastructure/terraform/` (zero `resource` blocks) confirms Terraform can reach the account.
- **Phase 3 (deployed):** `infrastructure/terraform/modules/vpc/` (reusable module) called from `infrastructure/terraform/environments/dev/` created CloudMart's network foundation — 13 resources, `Apply complete! Resources: 13 added, 0 changed, 0 destroyed.` All free; **$0/month with nothing else attached.** Full layout, CIDR plan, and real resource IDs: [networking.md](networking.md). Design reasoning: [ADR 0005](decisions/0005-vpc-network-design.md).

| Resource | ID |
|---|---|
| VPC | `vpc-0a82438460af02b05` |
| Internet Gateway | `igw-0953cfd024cea3a2b` |
| Public subnet (us-east-1a) | `subnet-04837a778fb2d3acf` |
| Public subnet (us-east-1b) | `subnet-060de850a2e9e39b5` |
| Private subnet (us-east-1a) | `subnet-05e43ab7674bd7594` |
| Private subnet (us-east-1b) | `subnet-06dee9395e05c4ce8` |

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

This diagram will be replaced with a real rendered diagram (see [../diagrams/README.md](../diagrams/README.md)) once compute is added in Phase 4. An ASCII-level VPC/subnet diagram of what's actually deployed exists in [networking.md](networking.md).

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
| 3 — Networking | ✅ Deployed | VPC + 4 subnets + IGW + 3 route tables live in AWS (`vpc-0a82438460af02b05`), 13 resources, $0/month |
| 4 — Compute | ⬜ Not started | |
| 5 — Load balancing & ASG | ⬜ Not started | |
| 6 — Database | ⬜ Not started | |
| 7 — Static assets & CDN | ⬜ Not started | |
| 8 — DNS | ⬜ Not started | |
| 9 — Security hardening | ⬜ Not started | |
| 10 — Monitoring | ⬜ Not started | |
| 11 — Terraform cleanup | ⬜ Not started | |
| 12 — Docs & polish | ⬜ Not started | |
