# 0002 - Build incrementally, in explained phases

**Status:** Accepted
**Date:** 2026-08-20
**SAA-C03 domain(s):** Cross-cutting — this is a learning-process decision, not an architecture one

## Context
The end-state architecture (VPC, ALB, ASG, RDS, S3/CloudFront, Route 53, IAM, Secrets Manager, CloudWatch, all in Terraform) is a lot to absorb at once for someone coming from a software development background rather than infrastructure. Building it all in one pass would produce working infrastructure but poor understanding — which defeats the purpose, since the goal is to be able to explain every piece in an interview.

## Decision
CloudMart is built in explicit phases (see [ROADMAP.md](../ROADMAP.md)), each scoped to one architectural concern. Before any AWS service is introduced, its purpose, alternatives, and relevant SAA-C03 exam domain are explained first. Each phase updates [architecture.md](../architecture.md) and, where relevant, gets its own ADR.

## Alternatives considered
- **Build the full target architecture up front via a single large Terraform apply:** faster to a "finished" state, but much weaker for learning retention and interview readiness — the whole point of this project.
- **Follow a pre-built reference architecture / tutorial verbatim:** would produce a working system faster, but decisions wouldn't be genuinely understood or defensible, and the ADRs would be hollow.

## Consequences
- Slower path to a fully deployed production architecture.
- Much stronger ability to explain *why* each piece exists, not just that it exists — which is the actual goal for interviews.
- Documentation stays close to reality throughout, since it's written phase-by-phase rather than reconstructed at the end.
