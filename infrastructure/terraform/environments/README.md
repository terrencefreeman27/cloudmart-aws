# Environments

Root Terraform configurations, one per environment. Each subfolder here (e.g. `dev/`) is a deployable configuration — `cd` into it and run `terraform init/plan/apply` — that composes the reusable modules from [../modules/](../modules/) with environment-specific variables.

## `dev/` (Phase 3+)
The only environment so far. Wires in five modules:
- `vpc` (13 resources, deployed, standing, $0/month)
- `compute` (Phase 5 ALB/ASG design — 14 resources, `plan`-validated, deliberately **not deployed**)
- `database` (Phase 6 RDS PostgreSQL design — 5 new resources, `plan`-validated, deliberately **not deployed**)
- `static_site` (Phase 7 S3 + CloudFront — 7 resources, **deployed**, cleanly isolatable via `-target` since it depends on none of the others)
- `monitoring` (Phase 8 — 2 resources active (CloudFront alarm + SNS topic), `plan`-validated, deliberately **not deployed**; 8 more resources gated behind plain booleans, deliberately decoupled from `compute`/`database`'s outputs so referencing them can't accidentally pull those modules into a targeted plan — see [docs/decisions/0010](../../../docs/decisions/0010-phase8-operational-polish.md))

Also defines one root-level resource, `aws_iam_role_policy.backend_read_db_secret`, wiring the compute and database modules together (lets the backend's IAM role read the database's auto-managed secret) without either module reaching into the other.

State lives locally in `dev/terraform.tfstate` (gitignored) and tracks the 13 `vpc` resources plus the 7 `static_site` resources — `compute`, `database`, and `monitoring` have never been applied. **Because of this mixed state, every `plan`/`apply` in this environment must use `-target=<module>` explicitly** — a bare `apply` would also try to create Phase 5/6's still-pending resources. This project's phased build concludes at Phase 8 — no further `module` blocks are planned; see [docs/ROADMAP.md](../../../docs/ROADMAP.md).

`prod/` is a possible later addition, not a given — for a portfolio project, one well-built environment demonstrated clearly is worth more than two half-maintained ones.
