import { PrismaClient } from "@prisma/client";

// Instance unique partagée par toute l'application (évite l'épuisement
// des connexions Postgres en environnement de développement avec hot-reload).
export const prisma = new PrismaClient();
