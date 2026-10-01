import { ShoppingBag } from "@phosphor-icons/react";
import Logo from "./Logo.jsx";

export default function Header({ cartCount, bump, onOpenCart }) {
  return (
    <header className="header">
      <div className="header-inner">
        <a className="logo" href="#top" aria-label="CloudMart home">
          <Logo />
          <span>CloudMart</span>
        </a>
        <button
          type="button"
          className="cart-button"
          onClick={onOpenCart}
          aria-label={`Open cart, ${cartCount} ${cartCount === 1 ? "item" : "items"}`}
        >
          <ShoppingBag size={20} weight="bold" aria-hidden="true" />
          <span className="cart-button-label">Cart</span>
          <span key={bump} className={`cart-badge${cartCount === 0 ? " is-empty" : ""}${bump > 0 ? " is-bumping" : ""}`}>
            {cartCount}
          </span>
        </button>
      </div>
    </header>
  );
}
