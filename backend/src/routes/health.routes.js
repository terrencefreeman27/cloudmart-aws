import { Router } from "express";

const router = Router();

// Deliberately simple and fast — this is the same shape of endpoint an
// AWS ALB target group health check will poll in a later phase.
router.get("/health", (req, res) => {
  res.json({ status: "healthy", timestamp: new Date().toISOString() });
});

export default router;
