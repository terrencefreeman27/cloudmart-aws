import ProductCard from "./ProductCard.jsx";

export default function ProductGrid({ products, onAddToCart }) {
  return (
    <div className="product-grid">
      {products.map((product, index) => (
        <ProductCard key={product.id} product={product} index={index} onAddToCart={onAddToCart} />
      ))}
    </div>
  );
}

export function ProductGridSkeleton({ count = 6 }) {
  return (
    <div className="product-grid" aria-hidden="true">
      {Array.from({ length: count }, (_, i) => (
        <div key={i} className="product-card product-card-skeleton">
          <div className="product-card-art skeleton" />
          <div className="skeleton skeleton-line" />
          <div className="skeleton skeleton-line skeleton-line-short" />
        </div>
      ))}
    </div>
  );
}
