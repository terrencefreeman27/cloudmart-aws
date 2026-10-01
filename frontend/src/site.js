// Static site-level constants shared by several components.
export const REPO_URL = "https://github.com/terrencefreeman27/cloudmart-aws";

export function formatPrice(value) {
  return `$${value.toFixed(2)}`;
}
