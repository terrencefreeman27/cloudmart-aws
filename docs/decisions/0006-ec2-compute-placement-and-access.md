# 0006 - EC2 compute placement: public subnet, SSM-only access, no inbound rules by default

**Status:** Accepted
**Date:** 2026-08-20
**SAA-C03 domain(s):** Design Secure Architectures; Design High-Performing Architectures (compute); Security

## Context
Phase 4 needed to run the Express backend on EC2. Three placements were considered: (1) public subnet with a public IP, (2) private subnet behind an ALB with NAT Gateway egress, (3) private subnet with no NAT. Constraints: no NAT Gateway, no ALB, no RDS, no Elastic IP, no ongoing charge beyond the instance itself, and the backend must not be permanently exposed to the whole internet.

## Decision
- **Placement:** public subnet (built in Phase 3), single `t2.micro` instance, Amazon Linux 2023.
- **No SSH.** No key pair is created at all. Shell access, if needed, is via AWS Systems Manager Session Manager, gated entirely by IAM.
- **No inbound security group rule by default.** The app port (4000) is not opened to `0.0.0.0/0`. Primary access is **SSM port forwarding** (`aws ssm start-session ... --document-name AWS-StartPortForwardingSession`), which tunnels a local port to the instance's port 4000 over the existing IAM-authenticated SSM channel — zero inbound ports open, ever.
- **Optional, explicit opt-in for direct access:** `var.allowed_demo_cidrs` (empty by default) can add a single scoped ingress rule if temporary direct access is wanted — never defaults to open, and the value is never hardcoded into a tracked file (see the variable's description in `modules/compute/variables.tf`).
- **IMDSv2 required** (`http_tokens = "required"`) — free, closes a known SSRF-to-credential-theft path.
- Instance role is scoped to exactly the `AmazonSSMManagedInstanceCore` managed policy — nothing else.

## Alternatives considered
- **Private subnet + ALB + NAT (the "real" production pattern):** rejected for this phase specifically because it was explicitly out of budget (~$50-60/mo minimum for NAT + ALB) and the ALB itself is excluded from this phase's scope. Phase 5 later added the ALB and Auto Scaling Group, but still **without** a NAT Gateway — its instances stay in the public subnets, locked to ALB-only inbound (see [ADR 0007](0007-phase5-alb-asg-plan-not-deployed.md)). Private subnets + NAT remains the production upgrade, not something this project builds.
- **Private subnet, no NAT:** rejected as impractical for a phase that needs to actually be reachable and updatable — with no NAT and no paid Interface VPC Endpoints, there's no path in or out at all beyond S3-reachable services, which doesn't fit a Node/Express app that needs `npm install` and needs to be demoed.
- **Public subnet + SSH + security group open to `0.0.0.0/0` on the app port (the "typical tutorial" version of option 1):** rejected after the first design pass — the user asked explicitly for the backend not to be permanently exposed. Revised to the SSM-only, zero-inbound-rule design in this ADR.

## An operational lesson worth recording
Applying this design's IAM role/instance-profile resources initially failed: the `cloudmart` AWS CLI profile uses IAM Identity Center's **PowerUserAccess** permission set, which deliberately excludes IAM management actions (`iam:CreateRole`, etc.) — a built-in AWS guardrail against a "power user" self-escalating to admin by creating a role and attaching `AdministratorAccess` to it. Resolved by attaching a narrowly-scoped inline policy to the permission set — `iam:CreateRole`/`CreateInstanceProfile`/etc. limited to `cloudmart-*`-named resources, `AttachRolePolicy` limited by condition to only the `AmazonSSMManagedInstanceCore` ARN, and `PassRole` limited by condition to `iam:PassedToService = ec2.amazonaws.com` — rather than widening the whole permission set. This is itself a demonstration of least-privilege IAM policy design: grant exactly the missing capability, conditioned as tightly as the use case allows, not a blanket escalation.

A second, purely operational snag: IAM Identity Center permission set edits don't take effect until the permission set is explicitly **reprovisioned** to the account, and locally cached STS credentials (`~/.aws/cli/cache/`) can continue reflecting the old permission set until refreshed — a full `aws sso logout` + `aws sso login` was needed before the new permissions were visible.

## Consequences
- The instance cannot be reached by URL/browser by default — appropriate for a temporary validation deployment, not for a persistent public demo link. Phase 5's ALB is what makes a stable public link appropriate.
- Every access requires an active AWS SSO session and either an SSM shell session or an SSM port-forwarding tunnel — more friction than SSH, in exchange for zero open inbound ports and no key material to manage.
- This deployment is treated as temporary: stopped or destroyed between validation sessions rather than left running, per [cost.md](../cost.md).
