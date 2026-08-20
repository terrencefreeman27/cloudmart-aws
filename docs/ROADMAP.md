# CloudMart Build Roadmap

CloudMart is built in phases. Each phase adds one coherent piece of the architecture, is preceded by an explanation of the AWS services involved (what/why/alternatives/exam mapping), and — where it introduces any non-trivial AWS cost — a warning before anything gets provisioned.

Nothing here is final; phases may be re-ordered or split as the project progresses, but this is the intended path.

## Phase 0 — Project scaffolding *(current)*
Repository structure, documentation skeleton, `.gitignore`, license. No AWS resources. ✅

## Phase 1 — Local application ✅ Done
Build the minimal CloudMart app: React/Vite frontend, Node/Express backend, a couple of product endpoints and a simple cart flow, running entirely locally (no AWS). The goal is just enough app to be worth deploying — this project is not meant to become a full e-commerce platform.

## Phase 2 — AWS & Terraform foundations ✅ Done
AWS CLI and Terraform installed locally; authentication to AWS set up via **IAM Identity Center (SSO)** — short-lived temporary credentials via `aws sso login`, no long-lived IAM access keys (see [ADR 0004](decisions/0004-aws-authentication-via-iam-identity-center.md)). A minimal Terraform configuration in `infrastructure/terraform/` (provider, region/profile variables, and two read-only data sources — `aws_caller_identity` and `aws_availability_zones`) proves Terraform can reach the account, with zero `resource` blocks — so `plan` cannot create, change, or destroy anything. *SAA domains: Security, IAM, Identity Federation.*

*Deferred, not forgotten:* AWS Budgets + a billing alarm (visibility into spend before any billable resource exists) are worth setting up before Phase 4 introduces the first resource with a real per-hour cost (EC2). Not done in Phase 2 since it wasn't in this phase's agreed scope — flagged as a good candidate for the start of Phase 3 or 4.

## Phase 3 — Networking foundation ✅ Deployed
VPC across two Availability Zones, public and private subnets (one of each per AZ), Internet Gateway, one shared public route table, and one private route table per AZ — all in Terraform, via a reusable `modules/vpc` called from `environments/dev`. 13 resources, all free. Deliberately **no NAT Gateway** (it has an hourly cost, and nothing yet needs outbound internet from a private subnet) and **no security groups yet** (a security group with nothing attached to it doesn't do anything useful — those arrive in Phase 4 alongside the first EC2 instance). Full layout: [networking.md](networking.md); design reasoning: [ADR 0005](decisions/0005-vpc-network-design.md). *SAA domains: Networking, High Availability.*

## Phase 4 — Compute (single instance) ✅ Deployed, validated, torn down
One `t2.micro` EC2 instance running the backend, deployed via Terraform (`modules/compute`) into the Phase 3 public subnet. Revised mid-phase from the original "security group + key pair" plan to something stricter: **no key pair, no SSH, and no inbound security group rule by default at all** — access via AWS Systems Manager Session Manager / port forwarding only, IAM-gated rather than network-gated. Validated: instance running, registered with SSM, `GET /api/health` and `GET /api/products` both confirmed reachable through an SSM tunnel, zero ingress rules confirmed. Then **intentionally destroyed** (`terraform destroy -target=module.compute`) the same day for cost control, once validated — independently confirmed gone via `aws ec2`/`aws iam`, with the Phase 3 VPC confirmed untouched throughout. The `compute` module remains in the repo, ready to redeploy without code changes whenever a later phase needs it running again. Design reasoning: [ADR 0006](decisions/0006-ec2-compute-placement-and-access.md). *SAA domains: Compute, Security Groups, IAM (Session Manager, permission boundaries).*

## Phase 5 — Load balancing & Auto Scaling
Application Load Balancer + target group + Auto Scaling Group + launch template, spread across both AZs, with health checks. This is where "high availability" becomes real. *SAA domains: Elasticity, High Availability, Fault Tolerance.*

## Phase 6 — Database
Amazon RDS in private subnets (single-AZ to start — Multi-AZ is a flagged, opt-in cost upgrade discussed explicitly before enabling), credentials stored in Secrets Manager rather than app config. *SAA domains: Databases, Secrets Management.*

## Phase 7 — Static assets & CDN
Move the React frontend to S3 static website hosting + CloudFront distribution, decoupling static delivery from the backend compute. *SAA domains: Storage, Content Delivery, Caching.*

## Phase 8 — DNS
Route 53 hosted zone and a real (or subdomain) domain name pointing at CloudFront/ALB. *SAA domains: DNS, Routing policies.* (Has a small fixed monthly cost for the hosted zone — flagged before creating it.)

## Phase 9 — Security hardening
IAM instance roles (no long-lived credentials on EC2), tightened security group rules, review of least-privilege across the board, optional discussion of AWS WAF (cost flagged, likely deferred). *SAA domains: Security, IAM.*

## Phase 10 — Monitoring & observability
CloudWatch metrics, alarms (CPU, health checks, budget), a simple dashboard, log aggregation, SNS notifications. *SAA domains: Monitoring, Operational Excellence.*

## Phase 11 — Terraform cleanup & remote state
Refactor Terraform into clean reusable modules, move state to an S3 backend with DynamoDB locking, formalize the `environments/dev` structure (and optionally `prod`). *SAA domains: Infrastructure as Code best practices.*

## Phase 12 — Documentation, diagram & polish
Finalize the architecture diagram, fill in ADRs retroactively where needed, write teardown/destroy instructions, double check nothing costly is left running, polish the README for recruiters/interviewers.

---

**Out of scope (for now):** containers/EKS/ECS, CI/CD pipelines, multi-region, WAF/Shield, serverless (Lambda) rewrite. These are natural "v2" extensions once the core VPC → ALB → ASG → RDS → S3/CloudFront → Route 53 architecture is solid, and are worth mentioning as "future work" in interviews rather than building now.
