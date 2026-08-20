import "dotenv/config";
import express from "express";
import cors from "cors";
import productsRoutes from "./routes/products.routes.js";
import healthRoutes from "./routes/health.routes.js";

const app = express();
const port = process.env.PORT || 4000;
const frontendOrigin = process.env.FRONTEND_ORIGIN || "http://localhost:5173";

app.use(cors({ origin: frontendOrigin }));
app.use(express.json());

app.use("/api", healthRoutes);
app.use("/api", productsRoutes);

app.listen(port, () => {
  console.log(`CloudMart API listening on http://localhost:${port}`);
});
