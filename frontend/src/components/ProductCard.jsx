export default function ProductCard({ product, onAddToCart }) {
  return (
    <div className="product-card">
      <div className="product-image-placeholder" aria-hidden="true">
        <span>{product.emoji}</span>
      </div>
      <div className="product-body">
        <h3>{product.name}</h3>
        <p className="product-description">{product.description}</p>
        <div className="product-footer">
          <span className="product-price">${product.price.toFixed(2)}</span>
          <button onClick={() => onAddToCart(product)}>Add to cart</button>
        </div>
      </div>
    </div>
  );
}
