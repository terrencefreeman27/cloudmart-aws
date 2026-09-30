const REQUEST_TIMEOUT_MS = 5000;

// In a production build (the S3 + CloudFront deploy), a missing or loopback
// URL can only mean "no API is deployed" — a visitor's browser has no
// CloudMart backend on its own localhost. Skip the request entirely rather
// than fire a doomed (and, in some browsers, permission-prompting) fetch at
// localhost. Local dev keeps the localhost default so the real API is used.
function resolveApiBaseUrl() {
  const configured = import.meta.env.VITE_API_BASE_URL;
  if (import.meta.env.DEV) {
    return configured || "http://localhost:4000";
  }
  if (!configured || /^https?:\/\/(localhost|127\.0\.0\.1)(:|\/|$)/.test(configured)) {
    return null;
  }
  return configured;
}

const API_BASE_URL = resolveApiBaseUrl();

async function fetchFromApi() {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const response = await fetch(`${API_BASE_URL}/api/products`, { signal: controller.signal });
    if (!response.ok) {
      throw new Error(`Failed to fetch products: ${response.status}`);
    }
    return await response.json();
  } finally {
    clearTimeout(timeout);
  }
}

// Same file the backend serves from GET /api/products — one source of truth,
// loaded as a separate chunk only when the API is unavailable.
async function loadStaticCatalog() {
  const { products } = await import("@backend-data/products.js");
  return products;
}

// Resolves to { products, source: "api" | "static" }. Falls back to the
// bundled static catalog when no API is configured or the request fails.
export async function fetchProducts() {
  if (API_BASE_URL) {
    try {
      return { products: await fetchFromApi(), source: "api" };
    } catch (error) {
      console.warn("CloudMart API unavailable, using the static catalog:", error.message);
    }
  }
  return { products: await loadStaticCatalog(), source: "static" };
}
