import { useCallback, useEffect, useState } from "react";
import Header from "./components/Header.jsx";
import Hero from "./components/Hero.jsx";
import ProductGrid, { ProductGridSkeleton } from "./components/ProductGrid.jsx";
import DemoNotice from "./components/DemoNotice.jsx";
import CartDrawer from "./components/CartDrawer.jsx";
import SiteFooter from "./components/SiteFooter.jsx";
import { fetchProducts } from "./api/client.js";

export default function App() {
  const [products, setProducts] = useState([]);
  const [status, setStatus] = useState("loading");
  const [source, setSource] = useState(null);
  // Cart lines keyed by product id: { [id]: { product, quantity } }.
  const [cart, setCart] = useState({});
  const [cartOpen, setCartOpen] = useState(false);
  const [bump, setBump] = useState(0);
  const [announcement, setAnnouncement] = useState("");

  const loadProducts = useCallback(() => {
    setStatus("loading");
    fetchProducts()
      .then((result) => {
        setProducts(result.products);
        setSource(result.source);
        setStatus("ready");
      })
      .catch(() => setStatus("error"));
  }, []);

  useEffect(loadProducts, [loadProducts]);

  function setQuantity(product, quantity) {
    setCart((current) => {
      const next = { ...current };
      if (quantity <= 0) {
        delete next[product.id];
      } else {
        next[product.id] = { product, quantity };
      }
      return next;
    });
  }

  function handleAddToCart(product) {
    setCart((current) => ({
      ...current,
      [product.id]: { product, quantity: (current[product.id]?.quantity ?? 0) + 1 },
    }));
    setBump((n) => n + 1);
    setAnnouncement(`${product.name} added to cart`);
  }

  const cartItems = Object.values(cart);
  const cartCount = cartItems.reduce((sum, item) => sum + item.quantity, 0);

  return (
    <div className="app" id="top">
      <a className="skip-link" href="#catalog">
        Skip to catalog
      </a>
      <Header cartCount={cartCount} bump={bump} onOpenCart={() => setCartOpen(true)} />

      <main className="main">
        <Hero products={products} />

        <section id="catalog" className="catalog" aria-labelledby="catalog-title" tabIndex={-1}>
          <div className="catalog-header">
            <h2 id="catalog-title">The catalog</h2>
            {status === "ready" && (
              <p className="catalog-count">
                {products.length} {products.length === 1 ? "product" : "products"}
              </p>
            )}
          </div>

          {source === "static" && <DemoNotice />}

          {status === "loading" && (
            <>
              <p className="visually-hidden" role="status">
                Loading products…
              </p>
              <ProductGridSkeleton />
            </>
          )}
          {status === "error" && (
            <div className="load-error" role="alert">
              <p>Couldn't load the product catalog.</p>
              <button type="button" className="btn btn-ghost" onClick={loadProducts}>
                Try again
              </button>
            </div>
          )}
          {status === "ready" && <ProductGrid products={products} onAddToCart={handleAddToCart} />}
        </section>
      </main>

      <SiteFooter source={status === "loading" ? null : source} />

      <CartDrawer
        open={cartOpen}
        items={cartItems}
        onClose={() => setCartOpen(false)}
        onSetQuantity={setQuantity}
      />

      <p className="visually-hidden" aria-live="polite">
        {announcement}
      </p>
    </div>
  );
}
