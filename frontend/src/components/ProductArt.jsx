import { Backpack, Drop, Headphones, Keyboard, Lamp, Sneaker } from "@phosphor-icons/react";

// The catalog describes each product with an emoji. Map the known ones to a
// consistent icon set so the art looks the same on every OS; anything new in
// the catalog still renders, falling back to its emoji.
const ICONS = {
  "\u{1F3A7}": Headphones,
  "\u{1F392}": Backpack,
  "\u{1F964}": Drop,
  "⌨": Keyboard,
  "\u{1F45F}": Sneaker,
  "\u{1F4A1}": Lamp,
};

// Backdrop hue per product, like a studio backdrop behind a product shot.
const HUES = [222, 150, 196, 262, 18, 44];

export default function ProductArt({ product, className = "" }) {
  const Icon = ICONS[(product.emoji ?? "").replace(/️/g, "")];
  const hue = HUES[Math.abs(Number(product.id) || 0) % HUES.length];

  return (
    <div className={`product-art ${className}`} style={{ "--tile-h": hue }} aria-hidden="true">
      {Icon ? (
        <Icon className="product-art-icon" weight="duotone" size="1em" />
      ) : (
        <span className="product-art-emoji">{product.emoji}</span>
      )}
    </div>
  );
}
