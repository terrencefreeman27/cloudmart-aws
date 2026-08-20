# 0004 - AWS authentication via IAM Identity Center (SSO), not access keys

**Status:** Accepted
**Date:** 2026-08-20
**SAA-C03 domain(s):** Design Secure Architectures (IAM); Security best practices

## Context
Terraform (and the AWS CLI generally) needs to authenticate as some AWS identity to run `plan`/`apply`. The two mainstream options for a human operator are: an IAM user with long-lived programmatic access keys stored in `~/.aws/credentials`, or AWS IAM Identity Center (successor to AWS SSO) issuing short-lived temporary credentials via browser-based login.

## Decision
CloudMart uses **AWS IAM Identity Center**. `aws sso login --profile cloudmart` performs a browser login and caches short-lived, auto-expiring temporary credentials under `~/.aws/sso/cache`. The `cloudmart` CLI profile assumes the `PowerUserAccess` permission set through this flow. No IAM user access keys exist for this project.

Terraform itself is unaffected by this choice — `providers.tf` references `profile = var.aws_profile` ("cloudmart") and has no idea whether that profile resolves to static keys or an SSO session. This is what makes the switch a documentation update, not a code change.

## Alternatives considered
- **IAM user + long-lived access keys** (the original plan for this phase): simpler to set up with a brand-new personal AWS account, but the credentials don't expire on their own — a leaked key stays valid until someone notices and manually rotates it. This is the class of mistake behind a large share of real-world "surprise $10,000 AWS bill" stories (leaked keys used for crypto-mining).
- **IAM role assumed via `AssumeRole` with keys from another account:** unnecessary complexity for a single-account personal project.

## Consequences
- Sessions expire (commonly after a few hours, depending on Identity Center configuration), so `aws sso login --profile cloudmart` needs to be re-run periodically — a minor recurring step, not a one-time setup.
- No secret ever needs to be typed into a chat session, pasted into a file, or stored indefinitely on disk — there is nothing long-lived to accidentally commit to Git in the first place, which is a stronger guarantee than "we remembered to `.gitignore` it."
- `PowerUserAccess` is broad (though it excludes IAM/account-management actions, unlike `AdministratorAccess`) — still a single-user sandbox account trade-off, same reasoning as noted for the account's general IAM posture, not a least-privilege policy.
- Interview-relevant: this is the authentication pattern AWS itself now recommends for human users, distinct from the machine-to-machine pattern (IAM roles with no credentials at all, e.g. an EC2 instance profile) used for the application's own AWS access in later phases.
