# Environments

Root Terraform configurations, one per environment. Each subfolder here (e.g. `dev/`) is a deployable configuration — `cd` into it and run `terraform init/plan/apply` — that composes the reusable modules from [../modules/](../modules/) with environment-specific variables.

## `dev/` (Phase 3+)
The only environment so far. Wires in the `vpc` module (13 resources, deployed, standing, $0/month) and the `compute` module (5 resources — deployed, validated, then destroyed for cost control; redeployed on demand with `terraform apply`, no code changes needed) with the values from [`variables.tf`](dev/variables.tf). State lives locally in `dev/terraform.tfstate` (gitignored). Later phases (database, ...) add more `module` blocks to this same file rather than creating new environments.

`prod/` is a possible later addition, not a given — for a portfolio project, one well-built environment demonstrated clearly is worth more than two half-maintained ones.
