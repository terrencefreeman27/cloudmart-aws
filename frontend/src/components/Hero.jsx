import { ArrowRight, GithubLogo } from "@phosphor-icons/react";
import ProductArt from "./ProductArt.jsx";
import { REPO_URL } from "../site.js";

export default function Hero({ products }) {
  const featured = products.slice(0, 3);

  return (
    <section className="hero" aria-labelledby="hero-title">
      <div className="hero-copy">
        <h1 id="hero-title" className="hero-title">
          Everyday gear, <span className="hero-accent">built on AWS.</span>
        </h1>
        <p className="hero-subtitle">
          A small storefront, built to learn AWS architecture. Browse the catalog, fill a cart, then
          read how it's put together.
        </p>
        <div className="hero-actions">
          <a className="btn btn-primary" href="#catalog">
            Shop the catalog
            <ArrowRight size={18} weight="bold" aria-hidden="true" />
          </a>
          <a className="btn btn-ghost" href={REPO_URL} target="_blank" rel="noreferrer">
            <GithubLogo size={18} weight="bold" aria-hidden="true" />
            View source
          </a>
        </div>
      </div>

      <div className="hero-visual" aria-hidden="true">
        {featured.length === 3
          ? featured.map((product, i) => (
              <ProductArt key={product.id} product={product} className={`hero-tile hero-tile-${i + 1}`} />
            ))
          : [1, 2, 3].map((n) => <div key={n} className={`hero-tile hero-tile-${n} skeleton`} />)}
      </div>
    </section>
  );
}
