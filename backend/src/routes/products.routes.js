import { Router } from "express";
import { products } from "../data/products.js";

const router = Router();

router.get("/products", (req, res) => {
  res.json(products);
});

export default router;
