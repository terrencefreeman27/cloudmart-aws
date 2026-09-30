# CloudMart Frontend

React + Vite single-page application: a small storefront showing a product grid with an add-to-cart button and a cart count in the header. No routing, no auth, no state library — just `useState`/`useEffect`, sized to the app's actual complexity.

## Run locally

```bash
cp .env.example .env
npm install
npm run dev
```

Serves on `http://localhost:5173`. With the [backend](../backend/) running (default `http://localhost:4000`), products come from the real API. Without it, the app falls back to a static catalog and shows a "Demo mode" banner (see below).

## Configuration

| Variable | Purpose | Default |
|---|---|---|
| `VITE_API_BASE_URL` | Base URL of the CloudMart API | `http://localhost:4000` |

Vite only exposes env vars prefixed `VITE_` to client code — see [src/api/client.js](src/api/client.js).

## Static catalog fallback (demo mode)

The deployed site has no backend (Phase 5 is plan-validated, not deployed), so `fetchProducts()` falls back to a static catalog instead of showing an error:

- **Production build** (`npm run build`): an unset or `localhost`/`127.0.0.1` `VITE_API_BASE_URL` means "no API deployed", so no request is made at all. Any other URL is tried first (5-second timeout).
- **Dev server** (`npm run dev`): always tries the API first (default `http://localhost:4000`).
- If there's no API or the request fails, products are loaded from `backend/src/data/products.js` — the same file the API serves, imported through the `@backend-data` alias in [vite.config.js](vite.config.js), so there is one source of truth rather than a copy. It's emitted as its own small chunk, fetched only when the fallback is used. A "Demo mode" banner tells the visitor the data is static.

## Structure

```
src/
├── main.jsx              # React entry point
├── App.jsx                # top-level state: products, cart count, load status
├── api/client.js          # fetch wrapper reading VITE_API_BASE_URL, with static-catalog fallback
├── components/
│   ├── Header.jsx         # logo + cart count
│   ├── ProductGrid.jsx
│   └── ProductCard.jsx    # name, price, description, emoji placeholder image, add-to-cart
└── index.css
```

In later phases this is built (`npm run build`) into static assets deployed to S3 and served through CloudFront — see [Phase 7](../docs/ROADMAP.md).
