# CloudMart Documentation

This folder holds the "why," not just the "what." Code and Terraform show what was built; these docs explain the reasoning, so the architecture can be defended in an interview, not just described.

| File | Contents |
|---|---|
| [ROADMAP.md](ROADMAP.md) | The phased build plan for the whole project |
| [architecture.md](architecture.md) | Current-state architecture overview, updated as each phase ships |
| [networking.md](networking.md) | VPC/subnet/route table layout, CIDR plan |
| [decisions/](decisions/) | Architecture Decision Records (ADRs) — one file per significant decision |
| [security.md](security.md) | IAM, network isolation, secrets management, security group design |
| [scalability.md](scalability.md) | High availability, fault tolerance, and scaling strategy |
| [cost.md](cost.md) | Cost-aware design choices and a running cost estimate |
| [deployment.md](deployment.md) | How to deploy CloudMart, and how to tear it down |

Most of these files are skeletons right now (Phase 0) and get filled in as the corresponding phase of [ROADMAP.md](ROADMAP.md) is completed.
