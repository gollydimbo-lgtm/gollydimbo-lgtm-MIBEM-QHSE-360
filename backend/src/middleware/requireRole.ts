import type { NextFunction, Request, Response } from "express";
import type { UserRole } from "@prisma/client";

/**
 * Autorise uniquement les rôles listés. À utiliser après `authenticate`.
 * Ex : requireRole("QHSE_MANAGER", "ADMIN")
 */
export function requireRole(...roles: UserRole[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({ message: "Authentification requise" });
    }
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ message: "Rôle insuffisant pour cette action" });
    }
    next();
  };
}
