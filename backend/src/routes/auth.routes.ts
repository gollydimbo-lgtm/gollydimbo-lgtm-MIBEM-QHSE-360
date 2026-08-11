import { Router } from "express";
import { prisma } from "../lib/prisma.js";
import {
  generateRefreshToken,
  hashRefreshToken,
  signAccessToken,
  verifyPassword,
} from "../lib/auth.js";
import { loginSchema, refreshSchema } from "../validation/schemas.js";

export const authRouter = Router();

authRouter.post("/login", async (req, res) => {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  const { email, password } = parsed.data;

  const user = await prisma.user.findUnique({ where: { email }, include: { employee: true } });
  if (!user || !user.isActive) {
    return res.status(401).json({ message: "Identifiants invalides" });
  }

  const valid = await verifyPassword(password, user.passwordHash);
  if (!valid) {
    return res.status(401).json({ message: "Identifiants invalides" });
  }

  const accessToken = signAccessToken({ sub: user.id, employeeId: user.employeeId, role: user.role });
  const { token: refreshToken, hash, expiresAt } = generateRefreshToken();

  await prisma.refreshToken.create({ data: { userId: user.id, tokenHash: hash, expiresAt } });

  res.json({
    accessToken,
    refreshToken,
    user: {
      id: user.id,
      email: user.email,
      role: user.role,
      employee: { id: user.employee.id, firstName: user.employee.firstName, lastName: user.employee.lastName },
    },
  });
});

authRouter.post("/refresh", async (req, res) => {
  const parsed = refreshSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide" });
  }

  const tokenHash = hashRefreshToken(parsed.data.refreshToken);
  const stored = await prisma.refreshToken.findFirst({
    where: { tokenHash, revokedAt: null, expiresAt: { gt: new Date() } },
    include: { user: true },
  });

  if (!stored || !stored.user.isActive) {
    return res.status(401).json({ message: "Refresh token invalide ou expiré" });
  }

  const accessToken = signAccessToken({
    sub: stored.user.id,
    employeeId: stored.user.employeeId,
    role: stored.user.role,
  });

  res.json({ accessToken });
});

authRouter.post("/logout", async (req, res) => {
  const parsed = refreshSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide" });
  }
  const tokenHash = hashRefreshToken(parsed.data.refreshToken);
  await prisma.refreshToken.updateMany({
    where: { tokenHash, revokedAt: null },
    data: { revokedAt: new Date() },
  });
  res.status(204).send();
});
