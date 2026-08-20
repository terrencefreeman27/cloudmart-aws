# 0001 - Use Terraform for infrastructure as code

**Status:** Accepted
**Date:** 2026-08-20
**SAA-C03 domain(s):** Design Resilient Architectures; Design High-Performing Architectures (IaC is cross-cutting)

## Context
CloudMart's AWS resources need to be reproducible, reviewable, and destroyable without hunting through the console. As a portfolio project, the infrastructure definitions are also part of what's being shown off — a hiring manager can read the Terraform and see exactly what was built and how, without needing AWS console access.

## Decision
All AWS infrastructure is defined in Terraform (HCL), organized under `infrastructure/terraform/`, with reusable modules and per-environment root configurations. No long-lived resource is created by hand in the console; the console is used for verification, not authorship.

## Alternatives considered
- **AWS Console (ClickOps):** Fastest to learn individual services in isolation, but not reproducible, not reviewable in a PR, and not representative of how infrastructure is actually managed in industry.
- **AWS CloudFormation / CDK:** Valid AWS-native alternative and worth knowing, but Terraform is more widely used across employers (multi-cloud relevant) and is what's specifically requested for this project.
- **Pulumi:** Similar reasoning to CDK — less common in AWS-focused job postings than Terraform/CloudFormation.

## Consequences
- Requires learning Terraform state management (and eventually a remote backend — see Phase 11) alongside AWS itself, which is more upfront effort than clicking through the console.
- Every resource is destroyable with `terraform destroy`, which directly supports the cost-control goal of not leaving billable resources running between sessions.
- Terraform state can contain sensitive values; state files are never committed to Git (see [.gitignore](../../.gitignore)) and a remote backend with encryption is planned before state holds anything sensitive.
