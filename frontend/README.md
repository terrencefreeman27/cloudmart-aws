# CloudMart Frontend

React + Vite single-page application: a small storefront showing a product grid with an add-to-cart button and a cart count in the header. No routing, no auth, no state library — just `useState`/`useEffect`, sized to the app's actual complexity.

## Run locally

```bash
cp .env.example .env
npm install
npm run dev
```

Serves on `http://localhost:5173`. Requires the [backend](../backend/) running (default `http://localhost:4000`) for the product grid to load.

## Configuration

| Variable | Purpose | Default |
|---|---|---|
| `VITE_API_BASE_URL` | Base URL of the CloudMart API | `http://localhost:4000` |

Vite only exposes env vars prefixed `VITE_` to client code — see [src/api/client.js](src/api/client.js).

## Structure

```
src/
├── main.jsx              # React entry point
├── App.jsx                # top-level state: products, cart count, load status
├── api/client.js          # fetch wrapper reading VITE_API_BASE_URL
├── components/
│   ├── Header.jsx         # logo + cart count
│   ├── ProductGrid.jsx
│   └── ProductCard.jsx    # name, price, description, emoji placeholder image, add-to-cart
└── index.css
```

In later phases this is built (`npm run build`) into static assets deployed to S3 and served through CloudFront — see [Phase 7](../docs/ROADMAP.md).
