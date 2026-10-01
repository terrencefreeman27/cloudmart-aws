import React from "react";
import ReactDOM from "react-dom/client";
// Self-hosted fonts: bundled into the build, no runtime third-party requests.
import "@fontsource-variable/geist";
import "@fontsource-variable/geist-mono";
import App from "./App.jsx";
import "./index.css";

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
