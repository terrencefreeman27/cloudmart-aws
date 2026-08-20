export default function Header({ cartCount }) {
  return (
    <header className="header">
      <div className="header-inner">
        <span className="logo">☁️ CloudMart</span>
        <div className="cart-indicator" aria-label={`${cartCount} items in cart`}>
          🛒 <span>{cartCount}</span>
        </div>
      </div>
    </header>
  );
}
