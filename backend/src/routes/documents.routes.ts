import { Router } from "express";
import { prisma } from "../lib/prisma.js";
import {
  createDocumentSchema,
  createDocumentVersionSchema,
  decideDocumentApprovalSchema,
  distributeDocumentSchema,
  documentStatusTransitionSchema,
} from "../validation/schemas.js";
import { z } from "zod";

export const documentsRouter = Router();

documentsRouter.get("/", async (req, res) => {
  const { status, category } = req.query;
  const data = await prisma.document.findMany({
    where: {
      status: typeof status === "string" ? (status as any) : undefined,
      category: typeof category === "string" ? category : undefined,
    },
    orderBy: { updatedAt: "desc" },
    include: { owner: true, versions: { orderBy: { versionNumber: "desc" }, take: 1 } },
    take: 100,
  });
  res.json(data);
});

documentsRouter.get("/:id", async (req, res) => {
  const document = await prisma.document.findUnique({
    where: { id: req.params.id },
    include: {
      owner: true,
      versions: {
        orderBy: { versionNumber: "desc" },
        include: { approvals: { include: { approver: true } }, distributions: { include: { employee: true } } },
      },
      reviews: true,
      attachments: true,
    },
  });
  if (!document) return res.status(404).json({ message: "Document introuvable" });
  res.json(document);
});

// Crée le document + sa première version (v1).
documentsRouter.post("/", async (req, res) => {
  const parsed = createDocumentSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });

  const document = await prisma.$transaction(async (tx) => {
    const doc = await tx.document.create({
      data: { code: parsed.data.code, title: parsed.data.title, category: parsed.data.category, ownerId: req.user!.employeeId },
    });
    await tx.documentVersion.create({
      data: { documentId: doc.id, versionNumber: 1, fileUrl: parsed.data.fileUrl, createdById: req.user!.employeeId },
    });
    return doc;
  });

  res.status(201).json(document);
});

documentsRouter.post("/:id/versions", async (req, res) => {
  const parsed = createDocumentVersionSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });

  const version = await prisma.$transaction(async (tx) => {
    const last = await tx.documentVersion.findFirst({
      where: { documentId: req.params.id },
      orderBy: { versionNumber: "desc" },
    });
    return tx.documentVersion.create({
      data: {
        documentId: req.params.id,
        versionNumber: (last?.versionNumber ?? 0) + 1,
        fileUrl: parsed.data.fileUrl,
        changeNote: parsed.data.changeNote,
        createdById: req.user!.employeeId,
      },
    });
  });

  await prisma.document.update({ where: { id: req.params.id }, data: { status: "VALIDATION" } });
  res.status(201).json(version);
});

documentsRouter.patch("/:id/status", async (req, res) => {
  const parsed = documentStatusTransitionSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  const document = await prisma.document.update({ where: { id: req.params.id }, data: { status: parsed.data.toStatus } });
  res.json(document);
});

documentsRouter.post("/versions/:versionId/approvals", async (req, res) => {
  const parsed = z.object({ approverId: z.string().uuid() }).safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  const approval = await prisma.documentApproval.create({
    data: { versionId: req.params.versionId, approverId: parsed.data.approverId },
  });
  res.status(201).json(approval);
});

documentsRouter.patch("/approvals/:approvalId", async (req, res) => {
  const parsed = decideDocumentApprovalSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  const approval = await prisma.documentApproval.update({
    where: { id: req.params.approvalId },
    data: { approved: parsed.data.approved, comment: parsed.data.comment, decidedAt: new Date() },
  });
  res.json(approval);
});

documentsRouter.post("/versions/:versionId/distribute", async (req, res) => {
  const parsed = distributeDocumentSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  const distributions = await prisma.$transaction(
    parsed.data.employeeIds.map((employeeId) =>
      prisma.documentDistribution.create({ data: { versionId: req.params.versionId, employeeId } })
    )
  );
  res.status(201).json(distributions);
});

documentsRouter.patch("/distributions/:distributionId/acknowledge", async (req, res) => {
  const distribution = await prisma.documentDistribution.update({
    where: { id: req.params.distributionId },
    data: { acknowledgedAt: new Date() },
  });
  res.json(distribution);
});

documentsRouter.post("/:id/reviews", async (req, res) => {
  const parsed = z.object({ reviewDate: z.string().datetime(), comment: z.string().optional() }).safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  const review = await prisma.documentReview.create({
    data: {
      documentId: req.params.id,
      reviewDate: new Date(parsed.data.reviewDate),
      reviewedById: req.user!.employeeId,
      comment: parsed.data.comment,
    },
  });
  res.status(201).json(review);
});
