# 0005 - VPC network design: per-AZ private route tables, no NAT Gateway yet

**Status:** Accepted
**Date:** 2026-08-20
**SAA-C03 domain(s):** Design Resilient Architectures (networking, HA); Cost Optimization

## Context
Phase 3 needs a VPC foundation that's genuinely free to run, spans two Availability Zones for future high availability, and doesn't need to be restructured when later phases (EC2 in Phase 4, NAT Gateway whenever it's actually needed) build on top of it.

## Decision
- One VPC (`10.0.0.0/16`), two AZs, one public + one private subnet per AZ (four subnets total).
- **One shared public route table** for both public subnets (`0.0.0.0/0 → Internet Gateway`) — both subnets need the identical rule.
- **Two private route tables, one per AZ**, each currently empty except the automatic local route. No shared private route table.
- **No NAT Gateway.** Private subnets have no outbound internet path at all right now.
- Availability Zones are resolved dynamically via `data "aws_availability_zones"`, not hardcoded as `"us-east-1a"`/`"us-east-1b"` literals.

## Alternatives considered
- **One shared private route table for both AZs:** simpler (one fewer resource), and until a NAT Gateway exists, functionally identical to two empty tables. Rejected anyway: when a NAT Gateway is added per-AZ for fault tolerance (the standard HA pattern — a NAT Gateway is itself a single point of failure per AZ), each AZ's private subnet needs to route to *its own* AZ's NAT Gateway. A shared table can't express "AZ A's subnet uses NAT A, AZ B's subnet uses NAT B" — it would require re-associating subnets to new per-AZ tables at that point anyway. Building the per-AZ split now costs nothing (route tables are free) and avoids that later rework.
- **NAT Gateway now, so subnets are "complete":** rejected — it costs ~$32-38/month per NAT Gateway and nothing in the VPC yet needs outbound internet (no EC2, no RDS exist until Phases 4 and 6). Paying for capability with zero current consumers contradicts the project's cost-awareness goal. Revisited explicitly, with cost called out, once Phase 4 or 6 actually needs it.
- **Hardcoded AZ names:** simpler to read, but not portable — AWS deliberately randomizes the mapping from AZ *name* (e.g. `us-east-1a`) to physical AZ *identity* per account, partly to spread load. A hardcoded name could also fail outright in accounts where that specific lettered AZ is restricted (common on older accounts). A data source lookup costs nothing and removes the assumption entirely.

## Consequences
- Private subnets currently cannot reach the internet at all (not even for OS package updates) — acceptable because nothing is deployed into them yet. This will matter starting Phase 4/6 and gets solved either by a NAT Gateway (cost-flagged, likely Phase 4 or later) or, for RDS-only-in-Phase-6, may not be needed at all if RDS never needs outbound internet access.
- Two extra (free) route table resources exist compared to the simplest possible design — a small complexity cost paid once, in exchange for not having to re-associate subnets later.
- 13 resources total in this phase, all with $0 AWS cost.
