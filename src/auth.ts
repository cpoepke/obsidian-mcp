import type { Request, Response, NextFunction } from "express";

export function createAuthMiddleware(apiKey: string) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const authHeader = req.headers.authorization;
    if (!authHeader || authHeader !== `Bearer ${apiKey}`) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }
    next();
  };
}
