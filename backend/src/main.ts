import express from "express";
import cors from "cors";
import path from "node:path";
import swaggerUi from "swagger-ui-express";
import { prisma } from "./lib/prisma.js";
import { authenticate } from "./middleware/authenticate.js";
import { authRouter } from "./routes/auth.routes.js";
import { controlTemplatesRouter } from "./routes/controlTemplates.routes.js";
import { referenceRouter } from "./routes/reference.routes.js";
import { controlsRouter } from "./routes/controls.routes.js";
import { nonConformitiesRouter } from "./routes/nonConformities.routes.js";
import { actionsRouter } from "./routes/actions.routes.js";
import { risksRouter } from "./routes/risks.routes.js";
import { safetyEventsRouter } from "./routes/safetyEvents.routes.js";
import { attachmentsRouter } from "./routes/attachments.routes.js";
import { dashboardRouter } from "./routes/dashboard.routes.js";
import { startOverdueActionsJob } from "./jobs/overdueActions.job.js";
import { swaggerDocument } from "./swagger.js";

const app = express();

app.use(cors());
app.use(express.json({ limit: "10mb" }));

// Fichiers uploadés (photos terrain) servis statiquement.
app.use("/uploads", express.static(path.resolve(process.cwd(), process.env.UPLOAD_DIR ?? "uploads")));

app.use("/docs", swaggerUi.serve, swaggerUi.setup(swaggerDocument));

app.get("/health", async (_req, res) => {
  await prisma.$queryRaw`SELECT 1`;
  res.json({ status: "ok", service: "mibem-qhse-api", version: "2.0.0", time: new Date().toISOString() });
});

// Authentification — publique
app.use("/api/auth", authRouter);

// Lecture de checklist — nécessite d'être connecté mais pas de rôle particulier
app.use("/api/control-templates", authenticate, controlTemplatesRouter);
app.use("/api/reference-data", authenticate, referenceRouter);

// Cœur métier — nécessite d'être connecté
app.use("/api/controls", authenticate, controlsRouter);
app.use("/api/non-conformities", authenticate, nonConformitiesRouter);
app.use("/api/actions", authenticate, actionsRouter);
app.use("/api/risks", authenticate, risksRouter);
app.use("/api/safety-events", authenticate, safetyEventsRouter);
app.use("/api/attachments", authenticate, attachmentsRouter);
app.use("/api/dashboard", authenticate, dashboardRouter);

// Gestionnaire d'erreurs générique — évite qu'une exception non prévue
// ne fasse fuiter la stack trace vers le client.
app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err);
  res.status(500).json({ message: "Erreur interne du serveur" });
});

const port = Number(process.env.PORT ?? 3000);
app.listen(port, () => {
  console.log(`MIBEM QHSE API v2 running on http://localhost:${port}`);
  startOverdueActionsJob();
});
