# Architecture Decision Records (ADRs)

Each significant decision in CloudMart gets a short ADR: what was decided, why, and what alternatives were considered. This is what makes the architecture defensible in an interview — not just "I used an ALB" but "I used an ALB because X, and I considered Y and Z."

Numbered sequentially, never renumbered or deleted — a superseded decision gets a new ADR that says so, rather than editing history.

## Template

```markdown
# NNNN - Short title

**Status:** Proposed | Accepted | Superseded by NNNN
**Date:** YYYY-MM-DD
**SAA-C03 domain(s):** ...

## Context
What problem are we solving? What constraints matter (cost, learning goals, etc.)?

## Decision
What did we decide to do?

## Alternatives considered
What else could we have done, and why didn't we?

## Consequences
What does this make easier or harder later? Any cost/security/complexity trade-offs?
```

## Index

| ADR | Title |
|---|---|
| [0001](0001-use-terraform-for-infrastructure.md) | Use Terraform for infrastructure as code |
| [0002](0002-phased-incremental-build-approach.md) | Build incrementally, in explained phases |
| [0003](0003-tech-stack-selection.md) | Application tech stack selection |
| [0004](0004-aws-authentication-via-iam-identity-center.md) | AWS authentication via IAM Identity Center (SSO), not access keys |
| [0005](0005-vpc-network-design.md) | VPC network design: per-AZ private route tables, no NAT Gateway yet |
| [0006](0006-ec2-compute-placement-and-access.md) | EC2 compute placement: public subnet, SSM-only access, no inbound rules by default |
