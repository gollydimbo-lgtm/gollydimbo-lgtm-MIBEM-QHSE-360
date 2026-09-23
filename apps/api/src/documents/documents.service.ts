import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { writeAudit } from '../common/audit-log.helper';
import { DocumentGroup } from '@prisma/client';
import { existsSync, unlinkSync } from 'fs';
import { stripSystemFields } from '../common/strip-system-fields';
import { randomUUID } from 'crypto';
import { saveFile } from './file-storage.util';

const DOC_INCLUDE_LIST = {
  versions: { orderBy: { version: 'desc' as const } },
  attachments: true,
  processus: true,
  responsible: true,
  verificateur: true,
  approbateur: true,
  createdBy: true,
  workUnit: true,
};

const DOC_INCLUDE_ONE = {
  ...DOC_INCLUDE_LIST,
  approvals: { orderBy: { createdAt: 'desc' as const } },
  diffusions: { include: { recipients: true }, orderBy: { createdAt: 'desc' as const } },
  links: true,
};

// Décale une date de `mois` mois — utilisé pour calculer automatiquement la
// prochaine échéance de révision à partir de la fréquence choisie.
function addMonths(date: Date, mois: number) {
  const d = new Date(date);
  d.setMonth(d.getMonth() + mois);
  return d;
}

const FREQUENCE_MOIS: Record<string, number> = {
  MENSUELLE: 1,
  TRIMESTRIELLE: 3,
  SEMESTRIELLE: 6,
  ANNUELLE: 12,
  BIENNALE: 24,
};

@Injectable()
export class DocumentsService {
  constructor(private db: PrismaService) {}

  private async log(action: string, entityId: string | null, userId?: string | null, oldValue?: any, newValue?: any) {
    await this.db.auditLog.create({ data: { module: 'DOCUMENT', action, entityId, userId: userId ?? null, oldValue, newValue } }).catch(() => undefined);
  }

  // ---------------------------------------------------------------------
  // Bibliothèque / CRUD document
  // ---------------------------------------------------------------------

  list(f: { status?: string; documentType?: string; domaine?: string; service?: string; siteId?: string; processusId?: string; workUnitId?: string; criticite?: string; responsibleId?: string; external?: string; q?: string }) {
    const where: any = {};
    if (f.status) where.status = f.status;
    if (f.documentType) where.documentType = f.documentType;
    if (f.domaine) where.domaine = f.domaine;
    if (f.service) where.service = f.service;
    if (f.siteId) where.siteId = f.siteId;
    if (f.processusId) where.processusId = f.processusId;
    if (f.workUnitId) where.workUnitId = f.workUnitId;
    if (f.criticite) where.criticite = f.criticite;
    if (f.responsibleId) where.responsibleId = f.responsibleId;
    if (f.external !== undefined) where.external = f.external === 'true' || (f.external as any) === true;
    if (f.q) {
      const contains = { contains: f.q, mode: 'insensitive' as const };
      where.OR = [{ title: contains }, { code: contains }, { description: contains }, { motsCles: contains }];
    }
    return this.db.document.findMany({ where, include: DOC_INCLUDE_LIST, orderBy: { updatedAt: 'desc' } });
  }

  groups() {
    return Object.values(DocumentGroup);
  }

  async get(id: string) {
    const doc = await this.db.document.findUnique({ where: { id }, include: DOC_INCLUDE_ONE });
    if (!doc) throw new NotFoundException('Document introuvable');
    return doc;
  }

  // Crée un document. Si fileName/base64 sont fournis, le fichier est
  // enregistré tout de suite comme version 1 — sinon le document est créé
  // sans fichier (une version pourra être ajoutée ensuite).
  async create(d: any) {
    const doc = await this.db.document.create({
      data: {
        code: d.code,
        title: d.title,
        category: d.category,
        documentGroup: d.documentGroup,
        status: 'DRAFT',
        processusId: d.processusId,
        nextReviewAt: d.nextReviewAt ? new Date(d.nextReviewAt) : undefined,
        createdById: d.createdById,
        description: d.description,
        documentType: d.documentType,
        domaine: d.domaine,
        service: d.service,
        activite: d.activite,
        siteId: d.siteId,
        responsibleId: d.responsibleId,
        verificateurId: d.verificateurId,
        approbateurId: d.approbateurId,
        dateEntreeVigueur: d.dateEntreeVigueur ? new Date(d.dateEntreeVigueur) : undefined,
        frequenceRevision: d.frequenceRevision,
        criticite: d.criticite ?? 'NON_CRITIQUE',
        motifCreation: d.motifCreation,
        referencesReglementaires: d.referencesReglementaires,
        referencesNormatives: d.referencesNormatives,
        motsCles: d.motsCles,
        workUnitId: d.workUnitId,
        external: !!d.external,
        sourceOrganisme: d.sourceOrganisme,
        externalReference: d.externalReference,
        diffusionAccuseRequis: !!d.diffusionAccuseRequis,
        veilleReglementaireId: d.veilleReglementaireId,
        qrToken: randomUUID(),
      },
    });
    if (d.fileName && d.base64) {
      const { storagePath, checksum } = saveFile(d.fileName, d.base64);
      await this.db.documentVersion.create({ data: { documentId: doc.id, version: 1, fileName: d.fileName, storagePath, checksum, status: 'DRAFT' } });
    }
    await this.log('Document créé', doc.id, d.createdById, undefined, { code: doc.code, title: doc.title });
    return this.db.document.findUnique({ where: { id: doc.id }, include: DOC_INCLUDE_LIST });
  }

  // Modifie les métadonnées d'un document déjà créé. Ne touche jamais au
  // fichier lui-même (voir addVersion pour ça).
  async update(id: string, d: any) {
    const before = await this.db.document.findUnique({ where: { id } });
    if (!before) throw new NotFoundException('Document introuvable');
    const data: any = {};
    const champsSimples = [
      'title', 'category', 'documentGroup', 'processusId', 'description', 'documentType', 'domaine', 'service', 'activite',
      'siteId', 'responsibleId', 'verificateurId', 'approbateurId', 'frequenceRevision', 'criticite', 'motifCreation',
      'referencesReglementaires', 'referencesNormatives', 'motsCles', 'workUnitId', 'sourceOrganisme', 'externalReference',
      'diffusionAccuseRequis', 'veilleReglementaireId',
    ];
    for (const champ of champsSimples) if (d[champ] !== undefined) data[champ] = d[champ];
    if (d.external !== undefined) data.external = !!d.external;
    if (d.nextReviewAt !== undefined) data.nextReviewAt = d.nextReviewAt ? new Date(d.nextReviewAt) : null;
    if (d.dateEntreeVigueur !== undefined) data.dateEntreeVigueur = d.dateEntreeVigueur ? new Date(d.dateEntreeVigueur) : null;
    const updated = await this.db.document.update({ where: { id }, data });
    await this.log('Document modifié', id, d.updatedById, before, data);
    return updated;
  }

  // Ajoute une nouvelle version (mise à jour progressive) à un document
  // existant. Une nouvelle version repasse tout le circuit de validation :
  // le document redevient DRAFT, il ne passe JAMAIS ACTIVE automatiquement.
  async addVersion(id: string, d: { fileName: string; mimeType?: string; base64: string; motifModification?: string }) {
    if (!d?.fileName || !d?.base64) throw new BadRequestException('fileName et base64 sont obligatoires');
    const doc = await this.db.document.findUnique({ where: { id }, include: { versions: true } });
    if (!doc) throw new NotFoundException('Document introuvable');
    const nextVersion = doc.versions.reduce((max, v) => Math.max(max, v.version), 0) + 1;
    const { storagePath, checksum } = saveFile(d.fileName, d.base64);
    await this.db.documentVersion.create({
      data: { documentId: id, version: nextVersion, fileName: d.fileName, storagePath, checksum, status: 'DRAFT', motifModification: d.motifModification },
    });
    const updated = await this.db.document.update({ where: { id }, data: { currentVersion: nextVersion, status: 'DRAFT' }, include: { versions: { orderBy: { version: 'desc' } } } });
    await this.log('Nouvelle version ajoutée', id, undefined, undefined, { version: nextVersion, motifModification: d.motifModification });
    return updated;
  }

  // Supprime un document et toutes ses versions — y compris les fichiers
  // physiques sur le disque, pas seulement les lignes en base.
  async remove(id: string) {
    const doc = await this.db.document.findUnique({ where: { id }, include: { versions: true } });
    if (!doc) throw new NotFoundException('Document introuvable');
    await this.log('Document supprimé', id, undefined, { code: doc.code, title: doc.title }, undefined);
    for (const v of doc.versions) {
      if (existsSync(v.storagePath)) unlinkSync(v.storagePath);
    }
    // Les versions/approbations/diffusions/liens sont supprimés automatiquement (onDelete: Cascade côté schéma).
    return this.db.document.delete({ where: { id } });
  }

  // ---------------------------------------------------------------------
  // Workflow de validation : Brouillon(DRAFT) -> Vérification(REVIEW) ->
  // Approbation(APPROVED) -> Publication(ACTIVE) -> ... -> Archivage(ARCHIVED)
  // ---------------------------------------------------------------------

  async submit(id: string, b: { userId?: string }) {
    const doc = await this.db.document.findUnique({ where: { id } });
    if (!doc) throw new NotFoundException('Document introuvable');
    if (doc.status !== 'DRAFT') throw new BadRequestException("Seul un document en brouillon/rédaction peut être soumis pour vérification");
    const updated = await this.db.document.update({ where: { id }, data: { status: 'REVIEW' } });
    await this.log('Document soumis pour vérification', id, b?.userId);
    return updated;
  }

  async verify(id: string, b: { decision: 'APPROUVE' | 'DEMANDE_MODIFICATION'; comment?: string; userId?: string }) {
    const doc = await this.db.document.findUnique({ where: { id } });
    if (!doc) throw new NotFoundException('Document introuvable');
    if (doc.status !== 'REVIEW') throw new BadRequestException('Seul un document en vérification peut recevoir une décision de vérification');
    const newStatus = b.decision === 'APPROUVE' ? 'APPROVED' : 'DRAFT';
    const updated = await this.db.document.update({ where: { id }, data: { status: newStatus } });
    await this.db.documentApproval.create({ data: { documentId: id, version: doc.currentVersion, userId: b.userId, role: 'VERIFICATEUR', decision: b.decision, comment: b.comment } });
    await this.log(b.decision === 'APPROUVE' ? 'Document vérifié — validé' : 'Document vérifié — modification demandée', id, b.userId, undefined, { decision: b.decision, comment: b.comment });
    return updated;
  }

  // L'approbation APPROUVE est l'événement de PUBLICATION : mise en vigueur,
  // calcul de la prochaine révision, et bascule de la précédente version
  // active en SUPERSEDED (maîtrise des documents obsolètes).
  async approve(id: string, b: { decision: 'APPROUVE' | 'REFUSE'; comment?: string; userId?: string }) {
    const doc = await this.db.document.findUnique({ where: { id } });
    if (!doc) throw new NotFoundException('Document introuvable');
    if (doc.status !== 'APPROVED') throw new BadRequestException("Seul un document au statut 'approuvé en attente de publication' peut recevoir une décision d'approbation finale");

    if (b.decision === 'REFUSE') {
      const updated = await this.db.document.update({ where: { id }, data: { status: 'DRAFT' } });
      await this.db.documentApproval.create({ data: { documentId: id, version: doc.currentVersion, userId: b.userId, role: 'APPROBATEUR', decision: 'REFUSE', comment: b.comment } });
      await this.log('Document refusé en approbation', id, b.userId, undefined, { comment: b.comment });
      return updated;
    }

    const now = new Date();
    const data: any = { status: 'ACTIVE' };
    if (!doc.dateEntreeVigueur) data.dateEntreeVigueur = now;
    if (!doc.nextReviewAt && doc.frequenceRevision && FREQUENCE_MOIS[doc.frequenceRevision]) {
      data.nextReviewAt = addMonths(now, FREQUENCE_MOIS[doc.frequenceRevision]);
    }

    // Maîtrise des documents obsolètes : toute autre version active bascule SUPERSEDED.
    await this.db.documentVersion.updateMany({ where: { documentId: id, version: { not: doc.currentVersion }, status: 'ACTIVE' }, data: { status: 'SUPERSEDED' } });
    await this.db.documentVersion.updateMany({ where: { documentId: id, version: doc.currentVersion }, data: { status: 'ACTIVE' } });

    const updated = await this.db.document.update({ where: { id }, data });
    await this.db.documentApproval.create({ data: { documentId: id, version: doc.currentVersion, userId: b.userId, role: 'APPROBATEUR', decision: 'APPROUVE', comment: b.comment } });
    await this.log('Document publié — nouvelle version en vigueur', id, b.userId, undefined, { version: doc.currentVersion, dateEntreeVigueur: data.dateEntreeVigueur, nextReviewAt: data.nextReviewAt });
    return updated;
  }

  async archive(id: string, b: { userId?: string }) {
    const doc = await this.db.document.findUnique({ where: { id } });
    if (!doc) throw new NotFoundException('Document introuvable');
    if (doc.status === 'DRAFT') throw new BadRequestException('Un document en brouillon ne peut pas être archivé directement');
    const updated = await this.db.document.update({ where: { id }, data: { status: 'ARCHIVED' } });
    await this.log('Document archivé', id, b?.userId);
    return updated;
  }

  async reopen(id: string, b: { userId?: string }) {
    const doc = await this.db.document.findUnique({ where: { id } });
    if (!doc) throw new NotFoundException('Document introuvable');
    if (doc.status !== 'ARCHIVED') throw new BadRequestException('Seul un document archivé peut être réactivé');
    const updated = await this.db.document.update({ where: { id }, data: { status: 'DRAFT' } });
    await this.log('Document réactivé depuis les archives', id, b?.userId);
    return updated;
  }

  // ---------------------------------------------------------------------
  // Diffusion
  // ---------------------------------------------------------------------

  async diffuse(id: string, b: { version?: number; recipients: { userId?: string; label?: string; accuseRequis?: boolean }[]; createdById?: string }) {
    if (!b?.recipients?.length) throw new BadRequestException('Au moins un destinataire est requis pour diffuser un document');
    const doc = await this.db.document.findUnique({ where: { id } });
    if (!doc) throw new NotFoundException('Document introuvable');
    const diffusion = await this.db.documentDiffusion.create({
      data: {
        documentId: id,
        version: b.version ?? doc.currentVersion,
        createdById: b.createdById,
        recipients: { create: b.recipients.map((r) => ({ userId: r.userId, label: r.label, accuseRequis: !!r.accuseRequis })) },
      },
      include: { recipients: true },
    });
    await this.log('Document diffusé', id, b.createdById, undefined, { version: diffusion.version, destinataires: b.recipients.length });
    return diffusion;
  }

  async accuseLecture(diffusionRecipientId: string, b?: { userId?: string }) {
    const recipient = await this.db.documentDiffusionRecipient.findUnique({ where: { id: diffusionRecipientId }, include: { diffusion: true } });
    if (!recipient) throw new NotFoundException('Destinataire de diffusion introuvable');
    const updated = await this.db.documentDiffusionRecipient.update({ where: { id: diffusionRecipientId }, data: { statutLecture: 'LU', dateLecture: new Date() } });
    await this.log("Accusé de lecture d'un document", recipient.diffusion.documentId, b?.userId, undefined, { diffusionId: recipient.diffusionId });
    return updated;
  }

  diffusionsByDocument(id: string) {
    return this.db.documentDiffusion.findMany({ where: { documentId: id }, include: { recipients: true }, orderBy: { createdAt: 'desc' } });
  }

  // ---------------------------------------------------------------------
  // Liens génériques inter-modules (même pattern que CapaLink)
  // ---------------------------------------------------------------------

  linksByDocument(id: string) {
    return this.db.documentLink.findMany({ where: { documentId: id } });
  }

  linksBySource(sourceModule: string, sourceEntityId: string) {
    return this.db.documentLink.findMany({
      where: { sourceModule, sourceEntityId },
      include: { document: { include: { versions: { orderBy: { version: 'desc' }, take: 1 } } } },
    });
  }

  linkCreate(id: string, b: { sourceModule: string; sourceEntityId: string; relationType?: string; metadata?: any; createdById?: string }) {
    return this.db.documentLink.create({
      data: { documentId: id, sourceModule: b.sourceModule, sourceEntityId: b.sourceEntityId, relationType: b.relationType ?? 'ASSOCIE', metadata:stripSystemFields(b).metadata, createdById: b.createdById },
    });
  }

  async linkDelete(linkId: string) {
    const row = await this.db.documentLink.delete({ where: { id: linkId } });
    await writeAudit(this.db, 'DOCUMENT_LINK', 'DELETE', linkId, row, null);
    return row;
  }

  async requestRevision(id: string, b: { sourceModule: string; sourceEntityId: string; motif: string; createdById?: string }) {
    const link = await this.db.documentLink.create({
      data: { documentId: id, sourceModule: b.sourceModule, sourceEntityId: b.sourceEntityId, relationType: 'REVISION_DEMANDEE', metadata: { motif: b.motif }, createdById: b.createdById },
    });
    await this.log('Révision documentaire demandée depuis ' + b.sourceModule, id, b.createdById, undefined, { motif: b.motif, sourceEntityId: b.sourceEntityId });
    return link;
  }

  // ---------------------------------------------------------------------
  // Veille réglementaire (lien uniquement)
  // ---------------------------------------------------------------------

  linkVeille(id: string, b: { veilleReglementaireId: string | null }) {
    return this.db.document.update({ where: { id }, data: { veilleReglementaireId: b.veilleReglementaireId } });
  }

  // ---------------------------------------------------------------------
  // QR code
  // ---------------------------------------------------------------------

  regenerateQr(id: string) {
    return this.db.document.update({ where: { id }, data: { qrToken: randomUUID() } });
  }

  async byQrToken(token: string) {
    const doc = await this.db.document.findUnique({ where: { qrToken: token }, include: { versions: { orderBy: { version: 'desc' }, take: 1 } } });
    if (!doc) throw new NotFoundException('Document introuvable pour ce code QR');
    return { ...doc, applicable: doc.status === 'ACTIVE' };
  }

  // ---------------------------------------------------------------------
  // Types de documents et catégories configurables
  // ---------------------------------------------------------------------

  typeList() {
    return this.db.documentType.findMany({ orderBy: { name: 'asc' } });
  }
  typeCreate(b: any) {
    return this.db.documentType.create({ data:stripSystemFields(b) });
  }
  typeUpdate(id: string, b: any) {
    return this.db.documentType.update({ where: { id }, data:stripSystemFields(b) });
  }
  async typeDelete(id: string) {
    const row = await this.db.documentType.delete({ where: { id } });
    await writeAudit(this.db, 'DOCUMENT_TYPE', 'DELETE', id, row, null);
    return row;
  }

  categoryList() {
    return this.db.documentCategoryNode.findMany({ orderBy: { ordre: 'asc' } });
  }
  categoryCreate(b: any) {
    return this.db.documentCategoryNode.create({ data:stripSystemFields(b) });
  }
  categoryUpdate(id: string, b: any) {
    return this.db.documentCategoryNode.update({ where: { id }, data:stripSystemFields(b) });
  }
  async categoryDelete(id: string) {
    const row = await this.db.documentCategoryNode.delete({ where: { id } });
    await writeAudit(this.db, 'DOCUMENT_CATEGORY', 'DELETE', id, row, null);
    return row;
  }

  // ---------------------------------------------------------------------
  // Dashboard / KPI
  // ---------------------------------------------------------------------

  async dashboard() {
    const docs = await this.db.document.findMany({ include: { diffusions: true, approvals: true } });
    const now = new Date();
    const dans90j = new Date(now.getTime() + 90 * 24 * 3600 * 1000);
    const il7j = new Date(now.getTime() - 7 * 24 * 3600 * 1000);

    const total = docs.length;
    const actifs = docs.filter((d) => d.status === 'ACTIVE').length;
    const brouillons = docs.filter((d) => d.status === 'DRAFT').length;
    const enVerification = docs.filter((d) => d.status === 'REVIEW').length;
    const enApprobation = docs.filter((d) => d.status === 'APPROVED').length;
    const obsoletes = docs.filter((d) => d.status === 'SUPERSEDED').length;
    const archives = docs.filter((d) => d.status === 'ARCHIVED').length;

    const aReviserProchainement = docs.filter((d) => d.nextReviewAt && d.nextReviewAt >= now && d.nextReviewAt <= dans90j).length;
    const enRetardRevision = docs.filter((d) => d.nextReviewAt && d.nextReviewAt < now && d.status === 'ACTIVE').length;
    const sansResponsable = docs.filter((d) => !d.responsibleId).length;
    const sansApprobateur = docs.filter((d) => !d.approbateurId).length;
    const recemmentModifies = docs.filter((d) => d.updatedAt >= il7j).length;
    const critiques = docs.filter((d) => d.criticite === 'CRITIQUE').length;
    const reglementaires = docs.filter((d) => d.external || d.veilleReglementaireId).length;
    const diffusionEnAttente = docs.filter((d) => d.status === 'ACTIVE' && (!d.diffusions || d.diffusions.length === 0)).length;
    const accuseManquant = await this.db.documentDiffusionRecipient.count({ where: { accuseRequis: true, statutLecture: 'NON_LU' } });

    const grouper = (getKey: (d: any) => string | null | undefined) => {
      const map = new Map<string, number>();
      for (const d of docs) {
        const key = getKey(d) || 'NON_DEFINI';
        map.set(key, (map.get(key) || 0) + 1);
      }
      return Array.from(map.entries()).map(([label, value]) => ({ label, value }));
    };

    const repartitionParStatut = grouper((d) => d.status);
    const repartitionParCategorie = grouper((d) => d.documentGroup);
    const repartitionParProcessusRaw = grouper((d) => d.processusId);
    const repartitionParService = grouper((d) => d.service);
    const repartitionParSite = grouper((d) => d.siteId);
    const repartitionParType = grouper((d) => d.documentType);

    const processusIds = repartitionParProcessusRaw.map((r) => r.label).filter((l) => l !== 'NON_DEFINI');
    const processus = processusIds.length ? await this.db.processus.findMany({ where: { id: { in: processusIds } } }) : [];
    const nomsProcessus = new Map(processus.map((p) => [p.id, p.nom]));
    const repartitionParProcessus = repartitionParProcessusRaw.map((r) => ({ label: nomsProcessus.get(r.label) || r.label, value: r.value }));

    const tauxAJour = actifs > 0 ? Math.round(((actifs - enRetardRevision) / actifs) * 100) : 0;
    const tauxObsoletes = total > 0 ? Math.round((obsoletes / total) * 100) : 0;
    const actifsApprouvesCorrectement = docs.filter((d) => d.status === 'ACTIVE' && d.approvals.some((a) => a.decision === 'APPROUVE')).length;
    const tauxApprouvesCorrectement = actifs > 0 ? Math.round((actifsApprouvesCorrectement / actifs) * 100) : 0;

    return {
      total, actifs, brouillons, enVerification, enApprobation, obsoletes, archives,
      aReviserProchainement, enRetardRevision, sansResponsable, sansApprobateur,
      recemmentModifies, critiques, reglementaires, diffusionEnAttente, accuseManquant,
      repartitionParStatut, repartitionParCategorie, repartitionParProcessus, repartitionParService, repartitionParSite, repartitionParType,
      tauxAJour, tauxObsoletes, tauxApprouvesCorrectement,
    };
  }

  async aTraiter() {
    const champs = { id: true, code: true, title: true, status: true, nextReviewAt: true };
    const now = new Date();
    const dans90j = new Date(now.getTime() + 90 * 24 * 3600 * 1000);

    const [aApprouver, aVerifier, aReviser, enRetard, aDiffuserCandidats, obsoletesList, sansResponsableList] = await Promise.all([
      this.db.document.findMany({ where: { status: 'APPROVED' }, select: champs }),
      this.db.document.findMany({ where: { status: 'REVIEW' }, select: champs }),
      this.db.document.findMany({ where: { nextReviewAt: { lte: dans90j, gte: now } }, select: champs }),
      this.db.document.findMany({ where: { status: 'ACTIVE', nextReviewAt: { lt: now } }, select: champs }),
      this.db.document.findMany({ where: { status: 'ACTIVE', diffusions: { none: {} } }, select: champs }),
      this.db.document.findMany({ where: { status: 'SUPERSEDED' }, select: champs }),
      this.db.document.findMany({ where: { responsibleId: null }, select: champs }),
    ]);

    const accuseManquantRecipients = await this.db.documentDiffusionRecipient.findMany({
      where: { accuseRequis: true, statutLecture: 'NON_LU' },
      include: { diffusion: { include: { document: { select: champs } } } },
    });
    const accuseManquant = accuseManquantRecipients.map((r) => r.diffusion.document);

    return { aApprouver, aVerifier, aReviser, enRetard, aDiffuser: aDiffuserCandidats, accuseManquant, obsoletes: obsoletesList, sansResponsable: sansResponsableList };
  }

  async matrice() {
    const docs = await this.db.document.findMany({
      include: {
        processus: true,
        responsible: true,
        approvals: { orderBy: { createdAt: 'desc' }, take: 1 },
        diffusions: { include: { recipients: true } },
      },
      orderBy: { code: 'asc' },
    });
    return docs.map((d) => {
      const diffusion = d.diffusions[0];
      const accusesRequis = d.diffusions.flatMap((diff) => diff.recipients).filter((r) => r.accuseRequis);
      const accuseLecture = accusesRequis.length === 0 ? 'N/A' : accusesRequis.every((r) => r.statutLecture === 'LU') ? 'COMPLET' : 'PARTIEL';
      return {
        code: d.code,
        title: d.title,
        version: d.currentVersion,
        documentType: d.documentType,
        processus: d.processus?.nom ?? null,
        responsable: d.responsible ? `${d.responsible.firstName} ${d.responsible.lastName}` : null,
        statut: d.status,
        approbation: d.approvals[0]?.decision ?? null,
        dateEntreeVigueur: d.dateEntreeVigueur,
        nextReviewAt: d.nextReviewAt,
        criticite: d.criticite,
        diffusion: diffusion ? 'DIFFUSE' : 'NON_DIFFUSE',
        accuseLecture,
        etat: d.status === 'ACTIVE' ? 'EN_VIGUEUR' : d.status === 'SUPERSEDED' ? 'OBSOLETE' : d.status,
      };
    });
  }
}
