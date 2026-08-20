# 0003 - Application tech stack selection

**Status:** Accepted
**Date:** 2026-08-20
**SAA-C03 domain(s):** Design High-Performing Architectures (compute/content-delivery split)

## Context
CloudMart needs a frontend and backend simple enough that the application isn't the focus, but realistic enough to justify the target AWS architecture (a static frontend suited to S3/CloudFront, and a backend suited to EC2/ALB/ASG rather than something that would push toward a serverless architecture instead).

## Decision
- **Frontend:** React + Vite, built as a static single-page application. This maps naturally to S3 + CloudFront (Phase 7) and requires no server-side rendering infrastructure.
- **Backend:** Node.js with Express, a plain REST API. This maps naturally to EC2 + ALB + Auto Scaling Group (Phases 4-5), which is where most of the SAA-relevant compute/networking concepts live.

## Alternatives considered
- **Next.js (SSR) frontend:** Would need a Node server rather than static hosting, muddying the "frontend = S3/CloudFront, backend = EC2/ALB" split that makes the architecture easy to explain.
- **Serverless backend (Lambda + API Gateway):** A legitimate and increasingly common AWS pattern, but it sidesteps EC2, ALB, Auto Scaling Groups, and Security Groups — exactly the compute/networking concepts this project exists to practice. Worth mentioning as a "how would you do this differently" discussion point in interviews, not the primary build.
- **Python/Django or Java/Spring backend:** Either would work architecturally the same way; Node.js was chosen to keep the whole stack in JavaScript/TypeScript, minimizing language-context-switching so the focus stays on infrastructure rather than backend framework learning.

## Consequences
- The application layer stays intentionally thin — enough product/cart endpoints to be a believable e-commerce app, not a feature-complete one.
- The frontend/backend split cleanly maps to two different AWS delivery mechanisms (CDN-served static assets vs. load-balanced compute), which is good for demonstrating range in an interview.
