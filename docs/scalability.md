# Scalability, High Availability & Fault Tolerance

This document explains how CloudMart handles growth and failure, and the reasoning behind each choice. Filled in incrementally as phases in [ROADMAP.md](ROADMAP.md) land.

## High availability
*(Phase 3, 5, 6)*
- The VPC spans two Availability Zones from the start, even before there's a second instance to put in the second AZ — so the network layout never has to be redesigned later.
- The Application Load Balancer and Auto Scaling Group both operate across both AZs, so the loss of a single AZ doesn't take the app down.
- RDS Multi-AZ is a deliberate, cost-flagged upgrade decision (roughly doubles RDS cost) rather than a default — see [cost.md](cost.md).

## Scalability
*(Phase 5)*
- The backend scales horizontally via an Auto Scaling Group behind the ALB, using CPU-based (or request-count-based) scaling policies rather than a single fixed-size instance.
- The frontend is a static SPA served from S3/CloudFront, which scales independently of the backend with effectively no capacity planning needed.
- The database is the most likely bottleneck at scale; read replicas and connection pooling are discussed as future work rather than built, to keep cost and complexity proportional to a portfolio project.

## Fault tolerance
*(Phase 5, 6, 10)*
- ALB health checks remove unhealthy instances from rotation automatically; the ASG replaces them.
- CloudWatch alarms (Phase 10) provide visibility into failures before they become outages.
- Infrastructure is fully defined in Terraform, so recovery from a bad deploy or a destroyed environment is "re-apply," not "rebuild by hand."

## Explicitly out of scope
- Multi-region failover — significant added cost and complexity for a learning project; worth discussing as a "how would you extend this" interview answer rather than building.
