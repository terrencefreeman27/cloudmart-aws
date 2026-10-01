// Simple geometric mark, shared with public/favicon.svg.
export default function Logo() {
  return (
    <svg className="logo-mark" viewBox="0 0 32 32" width="28" height="28" aria-hidden="true">
      <rect width="32" height="32" rx="9" fill="var(--ink)" />
      <circle cx="20" cy="12" r="6" fill="var(--accent)" />
      <rect x="7" y="19" width="18" height="5" rx="2.5" fill="var(--ink-contrast)" />
    </svg>
  );
}
