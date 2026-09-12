import { Injectable, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

// ==========================================================
// MODULE HYGIÈNE AU TRAVAIL — PHASE 1
// Réutilise les mêmes conventions que qhs.service.ts / quality.service.ts
// ==========================================================

function niveauRisqueFromCriticite(criticite: number) {
  if (criticite <= 4) return 'FAIBLE';
  if (criticite <= 9) return 'MODERE';
  if (criticite <= 15) return 'ELEVE';
  return 'CRITIQUE';
}

// facteurs attendu : { items: [{ label: string, points: number (0-10) }, ...] }
function scoreErgonomiqueFromFacteurs(facteurs: any) {
  const items = facteurs?.items ?? [];
  const total = items.reduce((sum: number, i: any) => sum + (Number(i.points) || 0), 0);
  const max = items.length * 10 || 1;
  const scoreValeur = Math.round((total / max) * 100); // 0-100, plus haut = plus de risque
  let scoreErgonomique = 'FAIBLE';
  if (scoreValeur >= 75) scoreErgonomique = 'CRITIQUE';
  else if (scoreValeur >= 50) scoreErgonomique = 'ELEVE';
  else if (scoreValeur >= 25) scoreErgonomique = 'MODERE';
  return { scoreValeur, scoreErgonomique, tmsRisqueDetecte: scoreValeur >= 50 };
}

async function generateReference(prisma: PrismaService, prefix: string) {
  const count = await (prisma as any)[prefix.toLowerCase()].count?.() ?? 0;
  const year = new Date().getFullYear();
  return `${prefix}-${year}-${String(count + 1).padStart(4, '0')}`;
}

@Injectable()
export class HygieneService {
  constructor(private prisma: PrismaService) {}

  // ---------- RISQUES SANITAIRES ----------
  async createRisque(data: any, userId: string) {
    const criticite = Number(data.gravite) * Number(data.probabilite);
    const niveauRisque = niveauRisqueFromCriticite(criticite);
    const reference = await generateReference(this.prisma, 'HR');

    const risque = await this.prisma.hygieneRisk.create({
      data: {
        ...data,
        reference,
        criticite,
        niveauRisque,
        createdBy: userId,
        updatedBy: userId,
      },
    });

    // Auto-création d'action si risque critique (pattern universel Action)
    if (niveauRisque === 'CRITIQUE') {
      await this.prisma.action.create({
        data: {
          reference: `ACT-${reference}`,
          origine: 'HYGIENE_RISQUE_CRITIQUE',
          probleme: `Risque sanitaire critique : ${data.danger}`,
          responsableId: data.responsableId ?? null,
          priorite: 'HAUTE',
          statut: 'A_TRAITER',
          hygieneRiskId: risque.id,
        },
      });
    }

    return risque;
  }

  async updateRisque(id: string, data: any, userId: string) {
    const gravite = data.gravite ?? (await this.prisma.hygieneRisk.findUnique({ where: { id } }))?.gravite;
    const probabilite = data.probabilite ?? (await this.prisma.hygieneRisk.findUnique({ where: { id } }))?.probabilite;
    const criticite = Number(gravite) * Number(probabilite);
    const niveauRisque = niveauRisqueFromCriticite(criticite);
    return this.prisma.hygieneRisk.update({
      where: { id },
      data: { ...data, criticite, niveauRisque, updatedBy: userId },
    });
  }

  listRisques(filters: any) {
    return this.prisma.hygieneRisk.findMany({
      where: this.buildRisqueFilters(filters),
      include: { expositions: true, actions: true },
      orderBy: { criticite: 'desc' },
    });
  }

  private buildRisqueFilters(filters: any) {
    const where: any = {};
    if (filters.categorie) where.categorie = filters.categorie;
    if (filters.statut) where.statut = filters.statut;
    if (filters.niveauRisque) where.niveauRisque = filters.niveauRisque;
    if (filters.siteId) where.siteId = filters.siteId;
    if (filters.service) where.service = filters.service;
    if (filters.zone) where.zone = filters.zone;
    return where;
  }

  // ---------- SURVEILLANCE DES EXPOSITIONS ----------
  async createExposition(data: any) {
    const conformite =
      data.valeurMesuree != null && data.valeurLimite != null
        ? data.valeurMesuree > data.valeurLimite
          ? 'NON_CONFORME'
          : 'CONFORME'
        : 'A_VERIFIER';
    return this.prisma.hygieneExposureMonitoring.create({
      data: { ...data, conformite },
    });
  }

  listExpositions(hygieneRiskId?: string) {
    return this.prisma.hygieneExposureMonitoring.findMany({
      where: hygieneRiskId ? { hygieneRiskId } : {},
      orderBy: { dateMesure: 'desc' },
    });
  }

  // ---------- ERGONOMIE ----------
  async createErgonomicAssessment(data: any, userId: string) {
    const { scoreValeur, scoreErgonomique, tmsRisqueDetecte } = scoreErgonomiqueFromFacteurs(data.facteurs);
    return this.prisma.ergonomicAssessment.create({
      data: { ...data, scoreValeur, scoreErgonomique, tmsRisqueDetecte, createdBy: userId },
    });
  }

  async updateErgonomicAssessment(id: string, data: any) {
    const current = await this.prisma.ergonomicAssessment.findUnique({ where: { id } });
    const facteurs = data.facteurs ?? current?.facteurs;
    const { scoreValeur, scoreErgonomique, tmsRisqueDetecte } = scoreErgonomiqueFromFacteurs(facteurs);

    // historique avant/après : conserver l'ancien score avant écrasement
    const historique = Array.isArray(current?.historiqueAvantApres) ? current.historiqueAvantApres : [];
    historique.push({ date: new Date(), scoreValeur: current?.scoreValeur, scoreErgonomique: current?.scoreErgonomique });

    return this.prisma.ergonomicAssessment.update({
      where: { id },
      data: { ...data, scoreValeur, scoreErgonomique, tmsRisqueDetecte, historiqueAvantApres: historique },
    });
  }

  listErgonomicAssessments(filters: any) {
    return this.prisma.ergonomicAssessment.findMany({
      where: filters.service ? { service: filters.service } : {},
      include: { tmsCases: true, actions: true },
      orderBy: { scoreValeur: 'desc' },
    });
  }

  // ---------- TMS ----------
  createTMSCase(data: any) {
    return this.prisma.tMSCase.create({ data });
  }

  listTMSCases(filters: any) {
    return this.prisma.tMSCase.findMany({
      where: filters.zoneCorporelle ? { zoneCorporelle: filters.zoneCorporelle } : {},
      orderBy: { dateSignalement: 'desc' },
    });
  }

  async tmsParZone() {
    const cases = await this.prisma.tMSCase.findMany({ select: { zoneCorporelle: true } });
    const counts: Record<string, number> = {};
    for (const c of cases) counts[c.zoneCorporelle] = (counts[c.zoneCorporelle] || 0) + 1;
    return counts;
  }

  // ---------- SUIVI MÉDICAL (accès restreint — vérifier le rôle côté controller) ----------
  createMedicalSurveillance(data: any, userId: string) {
    return this.prisma.medicalSurveillance.create({ data: { ...data, createdBy: userId, updatedBy: userId } });
  }

  updateMedicalSurveillance(id: string, data: any, userId: string) {
    return this.prisma.medicalSurveillance.update({ where: { id }, data: { ...data, updatedBy: userId } });
  }

  listMedicalSurveillance(filters: any) {
    return this.prisma.medicalSurveillance.findMany({
      where: filters.employeId ? { employeId: filters.employeId } : {},
      orderBy: { dateProchaineVisite: 'asc' },
    });
  }

  // Résumé non-nominatif pour le tableau de bord général (aucune donnée médicale exposée)
  async medicalSummaryAnonyme() {
    const all = await this.prisma.medicalSurveillance.findMany({
      select: { statutVisite: true, aptitude: true, dateProchaineVisite: true },
    });
    const today = new Date();
    const dans30 = new Date(today.getTime() + 30 * 86400000);
    return {
      visitesPrevues: all.length,
      visitesRealisees: all.filter((v) => v.statutVisite === 'REALISEE').length,
      visitesEchues: all.filter((v) => v.statutVisite === 'ECHUE').length,
      visitesProches30j: all.filter((v) => v.dateProchaineVisite && v.dateProchaineVisite <= dans30).length,
      aptitudesAvecRestriction: all.filter((v) => v.aptitude === 'APTE_AVEC_RESTRICTIONS').length,
      inaptitudes: all.filter((v) => v.aptitude === 'INAPTE').length,
      tauxSuiviMedical: all.length ? Math.round((all.filter((v) => v.statutVisite === 'REALISEE').length / all.length) * 100) : 0,
    };
  }

  // ---------- PÉNIBILITÉ ----------
  listPenibiliteFactors() {
    return this.prisma.penibiliteFactor.findMany({ where: { actif: true } });
  }

  createPenibiliteFactor(data: any) {
    return this.prisma.penibiliteFactor.create({ data });
  }

  createPenibiliteExposition(data: any) {
    return this.prisma.penibiliteExposition.create({ data });
  }

  listPenibiliteExpositions(filters: any) {
    return this.prisma.penibiliteExposition.findMany({
      where: filters.employeId ? { employeId: filters.employeId } : {},
      include: { penibiliteFactor: true },
      orderBy: { dateEvaluation: 'desc' },
    });
  }

  // ---------- TABLEAU DE BORD (Phase 1 — KPI de base, hors médical nominatif) ----------
  async getDashboard(filters: any) {
    const risques = await this.listRisques(filters);
    const ergonomie = await this.prisma.ergonomicAssessment.findMany();
    const tms = await this.prisma.tMSCase.findMany();
    const medical = await this.medicalSummaryAnonyme();
    const penibilite = await this.prisma.penibiliteExposition.findMany();

    return {
      risquesTotal: risques.length,
      risquesCritiques: risques.filter((r) => r.niveauRisque === 'CRITIQUE').length,
      salariesExposes: risques.reduce((s, r) => s + (r.personnelExposeCount || 0), 0),
      postesErgonomieAnalyses: ergonomie.length,
      postesErgonomieCritiques: ergonomie.filter((e) => e.scoreErgonomique === 'CRITIQUE').length,
      tmsSituations: tms.length,
      tmsParZone: await this.tmsParZone(),
      suiviMedical: medical,
      penibiliteExpositions: penibilite.length,
    };
  }
}
