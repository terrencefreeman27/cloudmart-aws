# 0010 - Phase 8 operational polish: monitoring scope, logging deferral, and a Terraform dependency-graph lesson

**Status:** Accepted
**Date:** 2026-08-20
**SAA-C03 domain(s):** Monitoring, Troubleshooting, and Remediation; Design Resilient Architectures; Cost Optimization

## Context
Phase 8's goal was to add the final operational layer — monitoring, logging, and a runbook — to make CloudMart portfolio-complete, without breaking the project's near-$0 cost posture. Unlike Phases 3/4/7 (real infrastructure) or 5/6 (fully-designed-but-undeployed), Phase 8 needed a mixed answer: some monitoring is genuinely deployable today at effectively $0 (CloudFront is live), while the most valuable monitoring (EC2/ALB/ASG/RDS) targets resources that don't exist yet.

## Decision

**Monitoring:** a new `modules/monitoring` was built with one alarm active today (CloudFront 5xx error rate, backed by an SNS topic) and eight more (ALB ×3, ASG ×1, RDS ×3, i.e. all the alarms that make sense for Phase 5/6) fully written but gated behind plain boolean variables defaulting to `false`. `terraform plan -target=module.monitoring` confirms exactly 2 resources (the SNS topic + the CloudFront alarm), 0 to change, 0 to destroy, with zero impact on any other module. **Not applied this phase** — left for a separate, explicit approval, consistent with every prior phase's pattern, even though the estimated cost is $0 (CloudWatch's always-free tier covers 10 alarm-metrics/month; SNS's free tier covers far more notification volume than a portfolio project generates).

**Logging:** documented in full (application logs, ALB access logs, RDS logs, CloudFront logs — destinations, retention, cost) but **nothing enabled**. Reasoning: application and RDS logs have nothing to log yet (Phase 5/6 undeployed); ALB access logs are the same; CloudFront logging (to S3) is the one option that's technically available today, but enabling it now for near-zero traffic provides no real signal at meaningful cost-review overhead — deferred to whenever traffic or debugging actually warrants it.

## A real lesson from this phase, worth recording on its own merits
While designing the monitoring module, an early version wired its ALB/ASG/RDS alarm variables directly to `module.compute`/`module.database`'s outputs (e.g. `alb_arn_suffix = module.compute.alb_arn_suffix`), gating each alarm's `count` on whether that output was `null`. This looked safe — those outputs *are* `null` today (confirmed after the stale-output cleanup one turn prior) — but running `terraform plan -target=module.monitoring` against it actually planned to **create all 11 of `module.compute`'s and `module.database`'s resources**, not just the 2 monitoring resources intended.

**Why:** referencing `module.compute.X` in another module's variable creates a Terraform dependency edge to the entire upstream module, regardless of the referenced value. When you `-target` something that depends on a module with resources declared in config but absent from state, Terraform doesn't use the stale state value for that reference — it tries to plan the upstream module's creation to produce a concrete value, because from Terraform's perspective, satisfying the dependency correctly requires that module to actually exist. `-target`'s own documentation warns it "may not represent all the changes requested," but this went further: it silently *expanded* the blast radius of an intentionally narrow-scoped command.

**Fix:** decoupled the monitoring module from any reference to `module.compute`/`module.database` entirely. It now takes plain `bool` toggles (`enable_alb_alarms`, etc.) and plain `string` identifiers, with no module-output references at all while those toggles are `false`. Enabling real ALB/ASG/RDS monitoring once Phase 5/6 deploy is now a deliberate two-line edit in `environments/dev/main.tf` (flip the boolean, wire the real output) — not something that can happen as a side effect of planning something else.

## Why this matters beyond this one bug
This is a real, general Terraform hazard, not a CloudMart-specific quirk: **any module that references another module's output — even a currently-null one — is implicitly coupled to that module's full resource graph for `-target` purposes.** Every cross-module reference in this project (`module.database`'s `app_security_group_id`, the root-level `aws_iam_role_policy.backend_read_db_secret`) has this property, and it's *correct* there, because those resources are semantically meant to depend on their upstream module and can't meaningfully exist without it. The bug here was applying that same coupling to something — monitoring — that's specifically supposed to be independently useful. The general rule: if a module should remain deployable in isolation regardless of what else exists, its variables must never reference another module's output, only plain values the caller supplies explicitly.

## Consequences
- CloudMart's actual deployed AWS footprint is unchanged by this phase — Phase 8 has added $0 in AWS charges; nothing was applied.
- The monitoring module is genuinely ready for a low-risk, separately-approved `terraform apply -target=module.monitoring` (2 resources, ~$0/month) whenever desired, independent of whether Phase 5/6 ever get deployed.
- The full production-relevant alarm set (ALB, ASG, RDS) is designed, plan-validated, and ready — activating it later is a two-line config change per resource, not a redesign.
