# 0009 - Phase 7 S3 + CloudFront frontend hosting: designed and plan-validated, not deployed

**Status:** Accepted
**Date:** 2026-08-20
**SAA-C03 domain(s):** Design High-Performing Architectures (content delivery, caching); Design Secure Architectures (private origin access); Cost Optimization

## Context
Phase 7's goal was to design production-style static hosting for the React/Vite frontend — private S3 bucket, CloudFront in front of it via Origin Access Control, HTTPS, SPA routing support — while preserving CloudMart's $0 ongoing AWS cost. Following the pattern set by Phases 5 and 6, this phase was explicitly scoped as design-and-plan-only from the outset.

## Decision
The frontend hosting tier is fully designed in Terraform (`infrastructure/terraform/modules/static-site/`), wired into `environments/dev`, and verified via `terraform fmt`, `terraform validate`, and `terraform plan`. **It was never applied**, and **no frontend assets were uploaded** — this phase is infrastructure only.

## Architecture

- **S3 bucket:** private (all four public-access blocks enabled), versioned, SSE-S3 encrypted, named with the account ID appended for the required global-uniqueness guarantee.
- **CloudFront distribution:** internet-facing, HTTPS via CloudFront's default certificate (no custom domain this phase — no Route 53, no purchased domain, no ACM certificate, per the explicit cost-control rules for this phase), the AWS-managed `Managed-CachingOptimized` cache policy, gzip/brotli compression enabled.
- **Origin Access Control (OAC):** the modern (2022+) mechanism — CloudFront signs every request to S3 with SigV4; the bucket policy grants `s3:GetObject` to the CloudFront service principal only, further scoped by a `AWS:SourceArn` condition to this exact distribution's ARN, not "any CloudFront distribution." The bucket has no other reader.
- **SPA routing:** custom error responses rewrite both 403 and 404 (what S3 returns for a client-side route like `/products/5` that has no literal object) to `/index.html` with a `200`, letting React Router take over.
- **Price class:** `PriceClass_100` (US/Canada/Europe edge locations only) — the cheapest option, exposed as `var.price_class` for an easy upgrade to `PriceClass_All` if global reach is ever actually needed.

Independent of every other module in this project: S3 and CloudFront aren't VPC resources at all, unlike the VPC/compute/database tiers built in Phases 3, 5, and 6.

## The 7 new resources this phase adds

| Resource | Purpose |
|---|---|
| `aws_s3_bucket.frontend` | The private bucket holding the build |
| `aws_s3_bucket_public_access_block.frontend` | All four public-access blocks enabled |
| `aws_s3_bucket_versioning.frontend` | Rollback protection |
| `aws_s3_bucket_server_side_encryption_configuration.frontend` | SSE-S3 (AES256), free |
| `aws_cloudfront_origin_access_control.frontend` | The OAC itself |
| `aws_cloudfront_distribution.frontend` | The CDN, HTTPS, SPA error handling |
| `aws_s3_bucket_policy.frontend` | Grants read access to this exact distribution only |

Unlike Phase 6 (whose database genuinely depends on Phase 5's backend security group), this module has **zero dependency** on `module.compute` or `module.database` — `terraform plan -target=module.static_site` cleanly shows **7 to add, 0 to change, 0 to destroy** in isolation. The full (untargeted) plan shows **26 to add** — 19 of those are Phase 5 and 6's still-pending resources, unrelated to this phase's own scope. **0 to change, 0 to destroy** either way — the Phase 3 VPC (13 resources) remains completely untouched, confirmed by zero `module.vpc` create/change/destroy lines in either plan.

## Estimated cost if deployed

| | Near-zero traffic | Small demo (~1,000 pageviews/mo) |
|---|---|---|
| S3 storage (~5MB build) | ~$0.0001/mo | ~$0.0001/mo |
| S3 + CloudFront requests | ~$0.00 | ~$0.02/mo |
| CloudFront data transfer | ~$0.00 | ~$0.13/mo |
| Public IPv4 | $0 — CloudFront/S3 use shared AWS edge infrastructure, not per-resource allocated public IPs | $0 |
| **Total** | **effectively $0.00/mo** | **~$0.14/mo** |

Not assumed Free-Tier-covered above. Worth naming explicitly: unlike every other phase in this project (EC2, ALB, NAT, RDS), **S3 and CloudFront have no idle or base hourly charge at all** — cost here is 100% usage-based, a genuinely different cost shape from the compute/database tiers.

## PLAN-VALIDATED ONLY — NOT DEPLOYED UNTIL COST REVIEW
Consistent with Phases 5 and 6: no `terraform apply` was run, no frontend assets were uploaded, no Route 53 hosted zone or domain was purchased, no ACM certificate was created. This is the cheapest phase so far by a wide margin (no idle charge, sub-$1/month even at demo-level traffic) — but the instruction for this phase was still an explicit deploy-only-after-review gate, which this ADR and the accompanying plan output satisfy without needing to actually spend anything to prove the design is correct.

## Alternatives considered
- **S3 static website hosting (public bucket, no CloudFront):** rejected — no HTTPS, no CDN caching, no custom-domain support without extra plumbing, and requires the bucket itself to be public, which contradicts this project's private-by-default posture applied to every other resource so far.
- **Origin Access Identity (OAI) instead of OAC:** OAI is the older (pre-2022) mechanism for the same goal; OAC is its AWS-recommended successor with better SSE-KMS support and is what AWS now documents as the default choice for new distributions.

## Consequences
- CloudMart's actual deployed AWS footprint remains exactly the Phase 3 VPC (13 resources, $0/month) — Phase 7 added $0 in AWS charges.
- The `modules/static-site` Terraform is fully written, formatted, validated, and plan-verified — deploying it later requires no further design work, just `terraform apply`, followed by an actual asset upload (`aws s3 sync frontend/dist/ s3://<bucket>/`) and a cache invalidation, neither of which is in scope for this phase.
- The frontend's `VITE_API_BASE_URL` (currently pointing at `localhost:4000`, per Phase 1) still needs to be repointed at the backend's real public address once both the frontend and backend are actually deployed together — that wiring is future work, not part of this phase's infrastructure-only scope.
