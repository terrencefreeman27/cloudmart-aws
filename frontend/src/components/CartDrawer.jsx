import { useEffect, useRef, useState } from "react";
import { Minus, Plus, ShoppingBag, Trash, X } from "@phosphor-icons/react";
import ProductArt from "./ProductArt.jsx";
import { formatPrice } from "../site.js";

const CLOSE_ANIMATION_MS = 200;

// Native <dialog> + showModal() gives focus trapping, Esc handling, an inert
// page behind it, and focus restoration on close without extra code.
export default function CartDrawer({ open, items, onClose, onSetQuantity }) {
  const dialogRef = useRef(null);
  const [closing, setClosing] = useState(false);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return undefined;

    if (open) {
      setClosing(false);
      if (!dialog.open) dialog.showModal();
      return undefined;
    }
    if (!dialog.open) return undefined;

    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduceMotion) {
      dialog.close();
      return undefined;
    }
    setClosing(true);
    const timer = setTimeout(() => {
      dialog.close();
      setClosing(false);
    }, CLOSE_ANIMATION_MS);
    return () => clearTimeout(timer);
  }, [open]);

  const count = items.reduce((sum, item) => sum + item.quantity, 0);
  const subtotal = items.reduce((sum, item) => sum + item.quantity * item.product.price, 0);

  return (
    <dialog
      ref={dialogRef}
      className={`cart-drawer${closing ? " is-closing" : ""}`}
      aria-labelledby="cart-title"
      onCancel={(event) => {
        event.preventDefault();
        onClose();
      }}
      onClick={(event) => {
        // Clicks on the ::backdrop are dispatched to the <dialog> itself.
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div className="cart-panel">
        <div className="cart-header">
          <h2 id="cart-title">
            Your cart <span className="cart-header-count">{count}</span>
          </h2>
          <button type="button" className="icon-button" onClick={onClose} aria-label="Close cart">
            <X size={20} weight="bold" aria-hidden="true" />
          </button>
        </div>

        {items.length === 0 ? (
          <div className="cart-empty">
            <ShoppingBag size={40} weight="duotone" aria-hidden="true" />
            <p className="cart-empty-title">Your cart is empty</p>
            <p className="cart-empty-text">Add something from the catalog and it will show up here.</p>
            <button type="button" className="btn btn-primary" onClick={onClose}>
              Browse the catalog
            </button>
          </div>
        ) : (
          <>
            <ul className="cart-items">
              {items.map(({ product, quantity }) => (
                <li key={product.id} className="cart-item">
                  <ProductArt product={product} className="cart-item-art" />
                  <div className="cart-item-info">
                    <p className="cart-item-name">{product.name}</p>
                    <p className="cart-item-unit">{formatPrice(product.price)} each</p>
                    <div className="stepper" role="group" aria-label={`Quantity of ${product.name}`}>
                      <button
                        type="button"
                        onClick={() => onSetQuantity(product, quantity - 1)}
                        aria-label={quantity === 1 ? `Remove ${product.name}` : `Decrease quantity of ${product.name}`}
                      >
                        {quantity === 1 ? (
                          <Trash size={14} weight="bold" aria-hidden="true" />
                        ) : (
                          <Minus size={14} weight="bold" aria-hidden="true" />
                        )}
                      </button>
                      <span className="stepper-value" aria-live="polite">
                        {quantity}
                      </span>
                      <button
                        type="button"
                        onClick={() => onSetQuantity(product, quantity + 1)}
                        aria-label={`Increase quantity of ${product.name}`}
                      >
                        <Plus size={14} weight="bold" aria-hidden="true" />
                      </button>
                    </div>
                  </div>
                  <p className="cart-item-total">{formatPrice(product.price * quantity)}</p>
                </li>
              ))}
            </ul>
            <div className="cart-summary">
              <div className="cart-subtotal">
                <span>Subtotal</span>
                <strong>{formatPrice(subtotal)}</strong>
              </div>
              <p className="cart-note">Checkout isn't part of this demo, so nothing is charged.</p>
              <button type="button" className="btn btn-primary btn-block" onClick={onClose}>
                Keep shopping
              </button>
            </div>
          </>
        )}
      </div>
    </dialog>
  );
}
