import { useEffect, useState } from "react";
import Header from "./components/Header.jsx";
import ProductGrid from "./components/ProductGrid.jsx";
import { fetchProducts } from "./api/client.js";

export default function App() {
  const [products, setProducts] = useState([]);
  const [cartCount, setCartCount] = useState(0);
  const [status, setStatus] = useState("loading");

  useEffect(() => {
    fetchProducts()
      .then((data) => {
        setProducts(data);
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

        {status === "loading" && <p>Loading products…</p>}
        {status === "error" && (
          <p className="error">
            Couldn't reach the CloudMart API. Is the backend running on the configured
            VITE_API_BASE_URL?
          </p>
        )}
        {status === "ready" && <ProductGrid products={products} onAddToCart={handleAddToCart} />}
      </main>
    </div>
  );
}
