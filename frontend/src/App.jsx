import { useEffect, useState } from "react";
import Header from "./components/Header.jsx";
import ProductGrid from "./components/ProductGrid.jsx";
import { fetchProducts } from "./api/client.js";

export default function App() {
  const [products, setProducts] = useState([]);
  const [cartCount, setCartCount] = useState(0);
  const [status, setStatus] = useState("loading");
  const [source, setSource] = useState(null);

  useEffect(() => {
    fetchProducts()
      .then((result) => {
        setProducts(result.products);
        setSource(result.source);
        setStatus("ready");
      })
      .catch(() => setStatus("error"));
  }, []);

  function handleAddToCart() {
    setCartCount((count) => count + 1);
  }

  return (
    <div className="app">
      <Header cartCount={cartCount} />
      <main className="main">
        <h1>Shop CloudMart</h1>
        <p className="subtitle">A small storefront, built to learn AWS architecture.</p>

        {source === "static" && (
          <p className="demo-banner" role="status">
            <strong>Demo mode</strong> — static catalog. The API tier is designed but not
            deployed to keep costs at $0.
          </p>
        )}

        {status === "loading" && <p>Loading products…</p>}
        {status === "error" && <p className="error">Couldn't load the product catalog.</p>}
        {status === "ready" && <ProductGrid products={products} onAddToCart={handleAddToCart} />}
      </main>
    </div>
  );
}
