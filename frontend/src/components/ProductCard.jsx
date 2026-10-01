import { useEffect, useState } from "react";
import { Check, Plus } from "@phosphor-icons/react";
import ProductArt from "./ProductArt.jsx";
import { formatPrice } from "../site.js";

const ADDED_FEEDBACK_MS = 1400;

export default function ProductCard({ product, index, onAddToCart }) {
  const [added, setAdded] = useState(false);

  useEffect(() => {
    if (!added) return undefined;
    const timer = setTimeout(() => setAdded(false), ADDED_FEEDBACK_MS);
    return () => clearTimeout(timer);
  }, [added]);

  function handleClick() {
    onAddToCart(product);
    setAdded(true);
  }

  return (
    <article className="product-card" style={{ "--i": index }}>
      <ProductArt product={product} className="product-card-art" />
      <div className="product-body">
        <h3 className="product-name">{product.name}</h3>
        <p className="product-description">{product.description}</p>
      </div>
      <div className="product-footer">
        <span className="product-price">{formatPrice(product.price)}</span>
        <button
          type="button"
          className={`btn btn-add${added ? " is-added" : ""}`}
          onClick={handleClick}
          aria-label={`Add ${product.name} to cart`}
        >
          {added ? (
            <Check size={16} weight="bold" aria-hidden="true" />
          ) : (
            <Plus size={16} weight="bold" aria-hidden="true" />
          )}
          <span aria-hidden="true">{added ? "Added" : "Add"}</span>
        </button>
      </div>
    </article>
  );
}
