import { Router } from "express";
import multer from "multer";
import path from "node:path";
import fs from "node:fs";
import type { Prisma } from "@prisma/client";
import { prisma } from "../lib/prisma.js";
import { attachmentMetaSchema } from "../validation/schemas.js";

export const attachmentsRouter = Router();

const UPLOAD_DIR = process.env.UPLOAD_DIR ?? path.resolve(process.cwd(), "uploads");
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, UPLOAD_DIR),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname) || ".jpg";
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`);
  },
});

// 15 Mo max : suffisant pour une photo terrain compressée côté mobile.
const upload = multer({ storage, limits: { fileSize: 15 * 1024 * 1024 } });

const OWNER_FIELD: Record<string, "controlId" | "controlResultId" | "nonConformityId" | "actionId" | "riskId" | "safetyEventId"> = {
  CONTROL: "controlId",
  CONTROL_RESULT: "controlResultId",
  NON_CONFORMITY: "nonConformityId",
  ACTION: "actionId",
  RISK: "riskId",
  SAFETY_EVENT: "safetyEventId",
};

/**
 * Upload multipart : champ fichier "file" + champ texte "meta" contenant le
 * JSON validé par attachmentMetaSchema (ownerType, ownerId, gps, etc.).
 * Le fichier est servi statiquement ensuite via /uploads/<nom>.
 */
attachmentsRouter.post("/", upload.single("file"), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ message: "Fichier manquant (champ 'file')" });
  }

  let meta;
  try {
    meta = attachmentMetaSchema.parse(JSON.parse(req.body.meta ?? "{}"));
  } catch (err) {
    fs.unlink(req.file.path, () => {});
    return res.status(400).json({ message: "Métadonnées invalides", errors: err instanceof Error ? err.message : err });
  }

  const ownerField = OWNER_FIELD[meta.ownerType];

  // Champ FK dynamique (controlId / controlResultId / nonConformityId / actionId)
  // construit séparément : la clé calculée empêcherait sinon Prisma de
  // vérifier statiquement la forme exacte de l'objet `data`.
  const ownerData: Record<string, string> = { [ownerField]: meta.ownerId };

  const attachment = await prisma.attachment.create({
    data: {
      ownerType: meta.ownerType,
      fileUrl: `/uploads/${req.file.filename}`,
      fileType: "PHOTO",
      mimeType: req.file.mimetype,
      latitude: meta.latitude,
      longitude: meta.longitude,
      deviceId: meta.deviceId,
      clientLocalId: meta.clientLocalId,
      capturedAt: meta.capturedAt ? new Date(meta.capturedAt) : undefined,
      ...ownerData,
    } as Prisma.AttachmentUncheckedCreateInput,
  });

  res.status(201).json(attachment);
});

attachmentsRouter.get("/", async (req, res) => {
  const { ownerType, ownerId } = req.query;
  if (typeof ownerType !== "string" || typeof ownerId !== "string" || !OWNER_FIELD[ownerType]) {
    return res.status(400).json({ message: "ownerType et ownerId sont requis" });
  }
  const data = await prisma.attachment.findMany({
    where: { [OWNER_FIELD[ownerType]]: ownerId } as any,
    orderBy: { createdAt: "desc" },
  });
  res.json(data);
});
