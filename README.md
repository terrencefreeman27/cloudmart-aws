# CloudMart

**CloudMart** is a small e-commerce application used as a vehicle to build and document a production-style AWS architecture — designed while studying for the AWS Certified Solutions Architect – Associate (SAA-C03) exam.

The application itself is intentionally simple. The point of this project is the **infrastructure**: a highly available, secure, cost-aware AWS environment provisioned with Terraform, built up one AWS service at a time, with every decision documented and explained.

> 🚧 **Status:** Phase 3 complete — VPC network (2 AZs, public/private subnets, Internet Gateway, route tables) **deployed to AWS** (13 resources, $0/month). See [ROADMAP.md](docs/ROADMAP.md) for the build plan and [networking.md](docs/networking.md) for the live resource IDs.

## Why this project exists

I come from a software development background and I'm moving toward Solutions Architect / Solutions Engineer / Sales Engineer / cloud-focused roles. This repository is both:

1. A structured way to learn AWS architecture hands-on while preparing for the SAA-C03 certification, and
2. A portfolio piece that demonstrates I can design, build, secure, and document real AWS infrastructure — not just pass a multiple-choice exam.

Every AWS service added to this project is preceded by an explanation of *what it does, why CloudMart needs it, what the alternatives were, and which SAA exam domain it maps to* — captured in [docs/decisions/](docs/decisions/) as lightweight Architecture Decision Records (ADRs).

## Target architecture

The production architecture is being built incrementally toward:

- **Networking:** VPC spanning multiple Availability Zones, public + private subnets, Internet Gateway, route tables, security groups
- **Compute:** EC2 behind an Application Load Balancer, Auto Scaling Group
- **Data:** Amazon RDS (relational database), Secrets Manager for credentials
- **Content delivery:** S3 for static assets, CloudFront as CDN
- **DNS:** Route 53
- **Identity & security:** IAM least-privilege roles/policies, Secrets Manager, Security Groups
- **Observability:** CloudWatch metrics, alarms, dashboards, logs
- **Infrastructure as Code:** 100% Terraform — no manual console changes to long-lived resources

Design priorities, in order: **security → high availability / fault tolerance → cost awareness → scalability → simplicity**. See [docs/architecture.md](docs/architecture.md) for the living architecture overview and [docs/cost.md](docs/cost.md) for what this project actually costs to run.

A visual architecture diagram will be added to [diagrams/](diagrams/) as the networking and compute layers are built.

## Tech stack

| Layer | Choice | Notes |
|---|---|---|
| Frontend | React + Vite | Built as a static SPA — deployable to S3/CloudFront |
| Backend | Node.js (Express) | Simple REST API, deployable to EC2 behind an ALB |
| Infrastructure | Terraform | All AWS resources defined as code |
| CI/CD | TBD | Considered in a later phase |
| Version control | Git / GitHub | This repository |

See [docs/decisions/0003-tech-stack-selection.md](docs/decisions/0003-tech-stack-selection.md) for the reasoning.

## Repository structure

```
cloudmart-aws/
├── frontend/                # React + Vite SPA
├── backend/                 # Node.js/Express API
├── infrastructure/
│   └── terraform/
│       ├── environments/    # Root modules per environment (e.g. dev)
│       └── modules/         # Reusable Terraform modules (vpc, compute, rds, ...)
├── docs/                    # Architecture, security, cost, deployment docs + ADRs
├── diagrams/                # Architecture diagrams
├── README.md                # You are here
└── .gitignore
```

## Documentation

| Doc | Purpose |
|---|---|
| [docs/ROADMAP.md](docs/ROADMAP.md) | Phased build plan for the whole project |
| [docs/architecture.md](docs/architecture.md) | Architecture overview, updated as each phase lands |
| [docs/decisions/](docs/decisions/) | ADRs — why each significant decision was made |
| [docs/security.md](docs/security.md) | Security considerations (IAM, network isolation, secrets) |
| [docs/scalability.md](docs/scalability.md) | High availability, fault tolerance, scaling strategy |
| [docs/cost.md](docs/cost.md) | Cost-aware design choices and estimated spend |
| [docs/deployment.md](docs/deployment.md) | How to deploy this project (and how to tear it down) |

## Cost awareness

This is a self-funded learning project. Every phase explicitly calls out any resource with a meaningful cost (NAT Gateways, Multi-AZ RDS, always-on EC2, etc.) before it's provisioned, and [docs/cost.md](docs/cost.md) tracks the running estimate. Nothing expensive is deployed silently, and the project favors free-tier-eligible, on-demand, and easily-destroyable resources.

## Local development

Two services, run separately (no Docker):

```bash
# Terminal 1 — backend (http://localhost:4000)
cd backend
cp .env.example .env
npm install
npm run dev

# Terminal 2 — frontend (http://localhost:5173)
cd frontend
cp .env.example .env
npm install
npm run dev
```

Then open `http://localhost:5173`. See [backend/README.md](backend/README.md) and [frontend/README.md](frontend/README.md) for details.

## License

MIT — see [LICENSE](LICENSE).

## Author

Terrence Freemane
