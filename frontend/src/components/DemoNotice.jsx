import { CloudCheck } from "@phosphor-icons/react";

export default function DemoNotice() {
  return (
    <div className="demo-notice" role="status">
      <CloudCheck className="demo-notice-icon" size={22} weight="duotone" aria-hidden="true" />
      <p>
        <strong>Demo mode.</strong> You're browsing the static catalog. The API tier is designed but
        not deployed, to keep hosting costs at $0.
      </p>
    </div>
  );
}
