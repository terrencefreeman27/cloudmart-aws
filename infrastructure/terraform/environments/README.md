# Environments

Root Terraform configurations, one per environment. Each subfolder here (e.g. `dev/`) is a deployable configuration — `cd` into it and run `terraform init/plan/apply` — that composes the reusable modules from [../modules/](../modules/) with environment-specific variables.

## `dev/` (Phase 3+)
The only environment so far. Wires in the `vpc` module with the values from [`variables.tf`](dev/variables.tf) (region `us-east-1`, profile `cloudmart`, CIDR `10.0.0.0/16`). **Deployed to AWS** — `terraform apply` completed 2026-08-20, 13 resources, $0/month. State lives locally in `dev/terraform.tfstate` (gitignored). Later phases (compute, database, ...) add more `module` blocks to this same file rather than creating new environments.

`prod/` is a possible later addition, not a given — for a portfolio project, one well-built environment demonstrated clearly is worth more than two half-maintained ones.
