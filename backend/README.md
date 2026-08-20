# CloudMart Backend

Node.js (Express) REST API serving CloudMart's product catalog. No database yet — data is a hardcoded in-memory array — and no auth.

## Run locally

```bash
cp .env.example .env
npm install
npm run dev   # nodemon, restarts on file changes
# or: npm start
```

Serves on `http://localhost:4000`.

## Endpoints

| Method | Path | Returns |
|---|---|---|
| GET | `/api/health` | `{ status: "healthy", timestamp }` — same shape an ALB target group health check will poll in [Phase 5](../docs/ROADMAP.md) |
| GET | `/api/products` | Hardcoded product list (see [src/data/products.js](src/data/products.js)) |

## Configuration

| Variable | Purpose | Default |
|---|---|---|
| `PORT` | Port the server listens on | `4000` |
| `FRONTEND_ORIGIN` | Origin allowed via CORS | `http://localhost:5173` |

## Structure

```
src/
├── index.js                    # express app, CORS, mounts routes, starts listener
├── data/products.js            # hardcoded product catalog
└── routes/
    ├── health.routes.js
    └── products.routes.js
```

In later phases this is deployed to EC2 behind an Application Load Balancer and Auto Scaling Group (see [Phase 4](../docs/ROADMAP.md) and [Phase 5](../docs/ROADMAP.md)), reads product data from RDS instead of a hardcoded array (see [Phase 6](../docs/ROADMAP.md)), and reads its database credentials from Secrets Manager rather than a local `.env` file.

See [docs/decisions/0003-tech-stack-selection.md](../docs/decisions/0003-tech-stack-selection.md) for why Node/Express was chosen.
