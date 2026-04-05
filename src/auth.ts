import type { Request, Response, NextFunction } from "express";
import { timingSafeEqual } from "node:crypto";

export function createAuthMiddleware(apiKey: string) {
  const expected = Buffer.from(`Bearer ${apiKey}`);

  return (req: Request, res: Response, next: NextFunction): void => {
    const authHeader = req.headers.authorization;
    if (!authHeader) {
      res.status(401).set("WWW-Authenticate", "Bearer").json({ error: "Unauthorized" });
      return;
    }

    const provided = Buffer.from(authHeader);
    if (provided.length !== expected.length || !timingSafeEqual(provided, expected)) {
      res.status(401).set("WWW-Authenticate", "Bearer").json({ error: "Unauthorized" });
      return;
    }

    next();
  };
}
