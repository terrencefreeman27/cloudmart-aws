import { CloudArrowDown, GithubLogo, HardDrives, SpinnerGap } from "@phosphor-icons/react";
import { REPO_URL } from "../site.js";

const SOURCES = {
  api: { Icon: HardDrives, label: "CloudMart API", detail: "GET /api/products" },
  static: { Icon: CloudArrowDown, label: "Static catalog", detail: "S3 + CloudFront" },
  pending: { Icon: SpinnerGap, label: "Checking the API", detail: "" },
};

export default function SiteFooter({ source }) {
  const { Icon, label, detail } = SOURCES[source] ?? SOURCES.pending;

  return (
    <footer className="site-footer">
      <div className="footer-inner">
        <div className="source-strip" aria-live="polite">
          <span className={`source-icon source-icon-${source ?? "pending"}`}>
            <Icon size={18} weight="bold" aria-hidden="true" />
          </span>
          <span className="source-text">
            <span className="source-label">Catalog served by</span>{" "}
            <strong>{label}</strong>
            {detail && <code className="source-detail">{detail}</code>}
          </span>
        </div>
        <a className="footer-link" href={REPO_URL} target="_blank" rel="noreferrer">
          <GithubLogo size={18} weight="bold" aria-hidden="true" />
          View source
        </a>
      </div>
      <p className="footer-note">
        CloudMart is an AWS architecture portfolio project. No real orders are taken.
      </p>
    </footer>
  );
}
