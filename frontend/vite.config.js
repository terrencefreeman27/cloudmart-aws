import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// The static fallback catalog is the backend's own data file, not a copy —
// see src/api/client.js.
const backendData = fileURLToPath(new URL("../backend/src/data", import.meta.url));

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@backend-data": backendData,
    },
  },
  server: {
    port: 5173,
    fs: {
      // Let the dev server serve the one backend directory imported above.
      allow: [".", backendData],
    },
  },
});
