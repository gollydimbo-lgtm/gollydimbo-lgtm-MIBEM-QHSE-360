import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { stripSystemFields } from '../common/strip-system-fields';
import { currentSiteScope } from '../common/audit-context';

// Module HACCP — remplace l'ancien HaccpRecord (CRUD plat) par une étude
// complète (équipe, diagramme de flux, dangers, CCP/CP, surveillance, PRP,
// révisions). Le point le plus important : la chaîne
// HACCP → Non-conformité → Action CAPA → Vérification d'efficacité est
// PROPOSÉE automatiquement par le système, jamais imposée. Un relevé de
// surveillance hors limite crée directement une NonConformity (même style
// que SafetyTalkFeedback.transformFeedback pour SAFETY_EVENT) mais la
// création de l'Action CAPA reste toujours un clic humain explicite, via le
// préremplissage capaPrefillFromSource('HACCP_CCP', ...) dans business.service.ts.
@Injectable()
export class HaccpService {
  constructor(private db: PrismaService) {}

  // Traçabilité — même pattern que qhs.service.ts/documents.service.ts. Un
  // échec de journalisation ne doit jamais faire échouer l'opération métier.
  private async log(action: string, entityId: string | null, userId?: string | null, oldValue?: any, newValue?: any) {
    await this.db.auditLog.create({ data: { module: 'HACCP', action, entityId, userId: userId ?? null, oldValue, newValue } }).catch(() => undefined);
  }

  // =========================================================================
  // ÉTUDES HACCP
  // =========================================================================
  studiesList() {
    return this.db.haccpStudy.findMany({ where: { ...currentSiteScope() }, orderBy: { createdAt: 'desc' } });
  }

  studyGet(id: string) {
    return this.db.haccpStudy.findUnique({
      where: { id },
      include: {
        team: true,
        steps: { orderBy: { ordre: 'asc' }, include: { hazards: { include: { ccps: true } } } },
        prps: true,
        revisions: { orderBy: { date: 'desc' } },
      },
    });
  }

  async studyCreate(b: any) {
    const created = await this.db.haccpStudy.create({ data:stripSystemFields(b) });
    await this.log('Création étude HACCP', created.id, b.responsableId, null, b);
    return created;
  }

  async studyUpdate(id: string, b: any) {
    const current = await this.db.haccpStudy.findUnique({ where: { id } });
    if (!current) throw new BadRequestException('Étude HACCP introuvable');
    const updated = await this.db.haccpStudy.update({ where: { id }, data:stripSystemFields(b) });
    await this.log('Modification étude HACCP', id, b.responsableId, current, updated);
    return updated;
  }

  async studyDelete(id: string) {
    const current = await this.db.haccpStudy.findUnique({ where: { id } });
    const deleted = await this.db.haccpStudy.delete({ where: { id } });
    await this.log('Suppression étude HACCP', id, null, current, null);
    return deleted;
  }

  // Workflow de validation — garde de statut, même pattern que
  // documents.service.ts (submitForReview/decideReview) : chaque étape ne
  // peut avancer que depuis l'état précédent attendu.
  async studyValidate(id: string, b: any = {}) {
    const study = await this.db.haccpStudy.findUnique({ where: { id } });
    if (!study) throw new BadRequestException('Étude HACCP introuvable');
    if (study.status === 'BROUILLON') {
      const updated = await this.db.haccpStudy.update({ where: { id }, data: { status: 'EN_VALIDATION' } });
      await this.log('Étude soumise pour validation', id, b.userId, study, updated);
      return updated;
    }
    if (study.status === 'EN_VALIDATION') {
      const updated = await this.db.haccpStudy.update({ where: { id }, data: { status: 'VALIDE', dateValidation: new Date() } });
      await this.log('Étude HACCP validée', id, b.userId, study, updated);
      return updated;
    }
    throw new BadRequestException("Seule une étude en brouillon ou en validation peut avancer dans ce workflow (statut actuel : " + study.status + ").");
  }

  // Crée une ligne d'historique et met à jour la version / les échéances de
  // révision de l'étude — jamais une révision silencieuse sans trace.
  async studyRevise(id: string, b: { version?: string; declencheur: string; description?: string; responsableId?: string; prochaineRevision?: string | Date }) {
    const study = await this.db.haccpStudy.findUnique({ where: { id } });
    if (!study) throw new BadRequestException('Étude HACCP introuvable');
    if (!b?.declencheur) throw new BadRequestException('Le déclencheur de la révision est obligatoire.');
    const revision = await this.db.haccpRevision.create({
      data: { studyId: id, version: b.version || study.version, declencheur: b.declencheur, description: b.description, responsableId: b.responsableId },
    });
    const updated = await this.db.haccpStudy.update({
      where: { id },
      data: {
        version: b.version || study.version,
        dateDerniereRevision: new Date(),
        prochaineRevision: b.prochaineRevision ? new Date(b.prochaineRevision) : study.prochaineRevision,
      },
    });
    await this.log('Révision du plan HACCP', id, b.responsableId, study, { revision, updated });
    return { study: updated, revision };
  }

  // =========================================================================
  // ÉQUIPE HACCP
  // =========================================================================
  teamList(studyId: string) {
    return this.db.haccpTeamMember.findMany({ where: { studyId }, include: { employee: true, user: true }, orderBy: { createdAt: 'asc' } });
  }

  async teamAdd(studyId: string, b: any) {
    const created = await this.db.haccpTeamMember.create({ data:{...stripSystemFields(b), studyId } });
    await this.log("Ajout d'un membre de l'équipe HACCP", created.id, b.userId);
    return created;
  }

  async teamRemove(memberId: string) {
    const deleted = await this.db.haccpTeamMember.delete({ where: { id: memberId } });
    await this.log("Retrait d'un membre de l'équipe HACCP", memberId);
    return deleted;
  }

  // =========================================================================
  // DIAGRAMME DE FLUX (ÉTAPES)
  // =========================================================================
  stepsList(studyId: string) {
    return this.db.haccpProcessStep.findMany({ where: { studyId }, orderBy: { ordre: 'asc' } });
  }

  async stepCreate(studyId: string, b: any) {
    const count = await this.db.haccpProcessStep.count({ where: { studyId } });
    const created = await this.db.haccpProcessStep.create({ data:{...stripSystemFields(b), studyId, ordre: b.ordre ?? count } });
    await this.log('Ajout étape du diagramme de flux', created.id, b.responsableId);
    return created;
  }

  async stepUpdate(id: string, b: any) {
    const current = await this.db.haccpProcessStep.findUnique({ where: { id } });
    if (!current) throw new BadRequestException('Étape introuvable');
    const updated = await this.db.haccpProcessStep.update({ where: { id }, data:stripSystemFields(b) });
    await this.log('Modification étape', id, b.responsableId, current, updated);
    return updated;
  }

  async stepDelete(id: string) {
    const current = await this.db.haccpProcessStep.findUnique({ where: { id } });
    const deleted = await this.db.haccpProcessStep.delete({ where: { id } });
    await this.log('Suppression étape', id, null, current, null);
    return deleted;
  }

  async stepsReorder(studyId: string, b: { ids: string[] }) {
    const ids = b?.ids || [];
    await Promise.all(ids.map((id, index) => this.db.haccpProcessStep.update({ where: { id }, data: { ordre: index } }).catch(() => undefined)));
    await this.log('Réordonnancement du diagramme de flux', studyId, null, null, { ids });
    return this.db.haccpProcessStep.findMany({ where: { studyId }, orderBy: { ordre: 'asc' } });
  }

  // =========================================================================
  // ANALYSE DES DANGERS
  // =========================================================================
  // Matrice de cotation par défaut : gravité × probabilité. C'est un défaut
  // raisonnable pour démarrer, PAS une valeur réglementaire imposée — à
  // affiner/configurer plus tard si besoin, isolée ici pour rester
  // facilement remplaçable.
  private calculerNiveauRisque(gravite?: number | null, probabilite?: number | null): string | null {
    if (gravite == null || probabilite == null) return null;
    const score = gravite * probabilite;
    if (score <= 4) return 'FAIBLE';
    if (score <= 9) return 'MODERE';
    if (score <= 16) return 'SIGNIFICATIF';
    return 'CRITIQUE';
  }

  hazardsByStudy(studyId: string) {
    return this.db.haccpHazard.findMany({ where: { studyId }, include: { step: true, ccps: true }, orderBy: { createdAt: 'asc' } });
  }

  async hazardCreate(stepId: string, b: any) {
    const step = await this.db.haccpProcessStep.findUnique({ where: { id: stepId } });
    if (!step) throw new BadRequestException('Étape introuvable');
    const niveauRisque = this.calculerNiveauRisque(b.gravite, b.probabilite);
    const created = await this.db.haccpHazard.create({ data:{...stripSystemFields(b), studyId: step.studyId, stepId, niveauRisque } });
    await this.log('Danger identifié', created.id);
    return created;
  }

  async hazardUpdate(id: string, b: any) {
    const current = await this.db.haccpHazard.findUnique({ where: { id } });
    if (!current) throw new BadRequestException('Danger introuvable');
    const gravite = b.gravite ?? current.gravite;
    const probabilite = b.probabilite ?? current.probabilite;
    const niveauRisque = (b.gravite !== undefined || b.probabilite !== undefined) ? this.calculerNiveauRisque(gravite, probabilite) : undefined;
    const data = niveauRisque !== undefined ? { ...b, niveauRisque } : b;
    const updated = await this.db.haccpHazard.update({ where: { id }, data });
    await this.log('Modification danger', id, undefined, current, updated);
    return updated;
  }

  async hazardDelete(id: string) {
    const current = await this.db.haccpHazard.findUnique({ where: { id } });
    const deleted = await this.db.haccpHazard.delete({ where: { id } });
    await this.log('Suppression danger', id, null, current, null);
    return deleted;
  }

  // =========================================================================
  // CCP / CP
  // =========================================================================
  // Référence générée automatiquement — compte les CCP/CP déjà existants de
  // l'étude, pour le même type, +1, formaté sur 2 chiffres (CCP-01, CP-01...).
  private async genererReference(studyId: string, type: string): Promise<string> {
    const count = await this.db.haccpCcp.count({ where: { studyId, type } });
    const prefixe = type === 'CP' ? 'CP' : 'CCP';
    return `${prefixe}-${String(count + 1).padStart(2, '0')}`;
  }

  ccpsByStudy(studyId: string) {
    return this.db.haccpCcp.findMany({ where: { studyId }, include: { hazard: true, step: true }, orderBy: { reference: 'asc' } });
  }

  async ccpCreate(hazardId: string, b: any) {
    const hazard = await this.db.haccpHazard.findUnique({ where: { id: hazardId } });
    if (!hazard) throw new BadRequestException('Danger introuvable');
    const type = b.type === 'CP' ? 'CP' : 'CCP';
    const reference = await this.genererReference(hazard.studyId, type);
    const created = await this.db.haccpCcp.create({ data:{...stripSystemFields(b), type, reference, studyId: hazard.studyId, hazardId, stepId: hazard.stepId } });
    await this.log('Fiche CCP/CP créée', created.id, b.responsableId);
    return created;
  }

  async ccpUpdate(id: string, b: any) {
    const current = await this.db.haccpCcp.findUnique({ where: { id } });
    if (!current) throw new BadRequestException('CCP introuvable');
    // La référence ne se régénère jamais après coup — elle reste stable une
    // fois attribuée, comme un code de document ou d'action.
    const { reference, ...safe } = b;
    const updated = await this.db.haccpCcp.update({ where: { id }, data: safe });
    await this.log('Modification CCP', id, b.responsableId, current, updated);
    return updated;
  }

  async ccpDelete(id: string) {
    const current = await this.db.haccpCcp.findUnique({ where: { id } });
    const deleted = await this.db.haccpCcp.delete({ where: { id } });
    await this.log('Suppression CCP', id, null, current, null);
    return deleted;
  }

  // =========================================================================
  // SURVEILLANCE CCP — le point le plus important après la chaîne CAPA.
  // Un résultat hors limite (conforme=false) crée AUTOMATIQUEMENT une
  // NonConformity (jamais une Action, qui reste un acte humain explicite
  // via /business/capa-links/create-from-source avec sourceModule='HACCP_CCP').
  // =========================================================================
  monitoringByCcp(ccpId: string) {
    return this.db.haccpMonitoringRecord.findMany({ where: { ccpId }, orderBy: { createdAt: 'desc' } });
  }

  // Niveau de criticité de la NC créée — CCP = CRITIQUE (danger maîtrisé
  // par ce point précis, pas de rattrapage possible ailleurs dans le
  // process), CP = MAJEURE (point de vigilance, marge de sécurité plus
  // large). Même logique que capaPrefillFromSource('HACCP_CCP', ...) dans
  // business.service.ts, à garder cohérente avec elle.
  private niveauDepuisCcp(ccp: { type: string }): string {
    return ccp.type === 'CCP' ? 'CRITIQUE' : 'MAJEURE';
  }

  // Crée la Non-conformité liée au relevé et boucle le relevé dessus
  // (statut NON_CONFORME + nonConformityId). Ne crée JAMAIS d'Action CAPA :
  // c'est un acte humain explicite depuis la NC ou le relevé.
  private async declencherNonConformite(record: any, ccp: any) {
    const niveau = this.niveauDepuisCcp(ccp);
    const details: string[] = [];
    if (ccp.limiteCritique) details.push(`limite critique : ${ccp.limiteCritique}`);
    if (record.valeur != null) details.push(`valeur mesurée : ${record.valeur}${ccp.unite || ''}`);
    if (record.valeurTexte) details.push(record.valeurTexte);
    const nc = await this.db.nonConformity.create({
      data: {
        code: `NC-HACCP-${Date.now()}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`,
        title: `Écart CCP ${ccp.reference}${ccp.dangerMaitrise ? ` — ${ccp.dangerMaitrise}` : ''}`,
        description: `Relevé de surveillance hors limite sur ${ccp.reference}${details.length ? ` (${details.join(', ')})` : ''}.`,
        source: 'HACCP',
        classification: niveau,
        criticiteNiveau: niveau,
        occurredAt: record.dateRealisee || new Date(),
        responsibleId: ccp.responsableId || undefined,
        haccpMonitoringRecordId: record.id,
      },
    });
    const updatedRecord = await this.db.haccpMonitoringRecord.update({
      where: { id: record.id },
      data: { statut: 'NON_CONFORME', nonConformityId: nc.id },
    });
    await this.log('Non-conformité HACCP créée automatiquement depuis un relevé CCP hors limite', nc.id, null, null, { ccpId: ccp.id, monitoringRecordId: record.id });
    return { record: updatedRecord, nonConformity: nc };
  }

  async monitoringCreate(ccpId: string, b: any) {
    const ccp = await this.db.haccpCcp.findUnique({ where: { id: ccpId } });
    if (!ccp) throw new BadRequestException('CCP introuvable');
    const statut = b.statut || (b.conforme === false ? 'NON_CONFORME' : b.conforme === true ? 'CONFORME' : b.dateRealisee ? 'REALISE' : 'A_REALISER');
    const created = await this.db.haccpMonitoringRecord.create({
      data: {
        ccpId,
        studyId: ccp.studyId,
        datePrevue: b.datePrevue ? new Date(b.datePrevue) : undefined,
        dateRealisee: b.dateRealisee ? new Date(b.dateRealisee) : (b.conforme !== undefined ? new Date() : undefined),
        valeur: b.valeur,
        valeurTexte: b.valeurTexte,
        conforme: b.conforme,
        statut,
        lotNumero: b.lotNumero,
        responsableId: b.responsableId,
        commentaire: b.commentaire,
        photoUrl: b.photoUrl,
        signature: b.signature,
      },
    });
    await this.log('Relevé de surveillance CCP créé', created.id, b.responsableId);
    if (b.conforme === false) {
      const { record } = await this.declencherNonConformite(created, ccp);
      return record;
    }
    return created;
  }

  async monitoringUpdate(id: string, b: any) {
    const current = await this.db.haccpMonitoringRecord.findUnique({ where: { id } });
    if (!current) throw new BadRequestException('Relevé de surveillance introuvable');
    const ccp = await this.db.haccpCcp.findUnique({ where: { id: current.ccpId } });
    if (!ccp) throw new BadRequestException('CCP introuvable');
    const data: any = { ...b };
    if (b.datePrevue) data.datePrevue = new Date(b.datePrevue);
    if (b.dateRealisee) data.dateRealisee = new Date(b.dateRealisee);
    if (!b.statut && b.conforme !== undefined) data.statut = b.conforme === false ? 'NON_CONFORME' : 'CONFORME';
    const updated = await this.db.haccpMonitoringRecord.update({ where: { id }, data });
    await this.log('Relevé de surveillance CCP modifié', id, b.responsableId, current, updated);

    // Bascule vers hors-limite : ne redéclenche jamais une deuxième NC si
    // une a déjà été créée pour ce relevé.
    if (b.conforme === false && current.conforme !== false && !current.nonConformityId) {
      const { record } = await this.declencherNonConformite(updated, ccp);
      return record;
    }
    return updated;
  }

  monitoringToday() {
    const start = new Date(); start.setHours(0, 0, 0, 0);
    const end = new Date(start); end.setDate(end.getDate() + 1);
    return this.db.haccpMonitoringRecord.findMany({
      where: { datePrevue: { gte: start, lt: end } },
      include: { ccp: true },
      orderBy: { datePrevue: 'asc' },
    });
  }

  monitoringOverdue() {
    const now = new Date();
    return this.db.haccpMonitoringRecord.findMany({
      where: { datePrevue: { lt: now }, statut: { in: ['A_REALISER', 'EN_RETARD'] } },
      include: { ccp: true },
      orderBy: { datePrevue: 'asc' },
    });
  }

  // =========================================================================
  // PRP — programmes prérequis / bonnes pratiques d'hygiène
  // =========================================================================
  prpsList() {
    return this.db.haccpPrp.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async prpCreate(b: any) {
    const created = await this.db.haccpPrp.create({ data:stripSystemFields(b) });
    await this.log('Création PRP', created.id, b.responsableId);
    return created;
  }

  async prpUpdate(id: string, b: any) {
    const current = await this.db.haccpPrp.findUnique({ where: { id } });
    if (!current) throw new BadRequestException('PRP introuvable');
    const updated = await this.db.haccpPrp.update({ where: { id }, data:stripSystemFields(b) });
    await this.log('Modification PRP', id, b.responsableId, current, updated);
    return updated;
  }

  async prpDelete(id: string) {
    const current = await this.db.haccpPrp.findUnique({ where: { id } });
    const deleted = await this.db.haccpPrp.delete({ where: { id } });
    await this.log('Suppression PRP', id, null, current, null);
    return deleted;
  }

  // =========================================================================
  // MATRICE — vue plate étude/étape/danger/CCP/statut, même esprit que
  // qhs.service.ts.matrice().
  // =========================================================================
  async matrice() {
    const studies = await this.db.haccpStudy.findMany({
      include: { steps: { orderBy: { ordre: 'asc' }, include: { hazards: { include: { ccps: true } } } } },
      orderBy: { code: 'asc' },
    });
    const lignes: any[] = [];
    for (const s of studies) {
      for (const step of s.steps) {
        for (const hz of step.hazards) {
          if (hz.ccps.length === 0) {
            lignes.push({ etude: s.name, etudeCode: s.code, etape: step.nom, danger: hz.libelle, type: hz.type, niveauRisque: hz.niveauRisque, ccp: null, statut: null });
            continue;
          }
          for (const c of hz.ccps) {
            lignes.push({ etude: s.name, etudeCode: s.code, etape: step.nom, danger: hz.libelle, type: hz.type, niveauRisque: hz.niveauRisque, ccp: c.reference, ccpType: c.type, statut: c.active ? 'ACTIF' : 'INACTIF' });
          }
        }
      }
    }
    return lignes;
  }

  // =========================================================================
  // DASHBOARD — KPI raisonnablement dérivables des modèles ci-dessus. Ce qui
  // est simplifié est documenté en commentaire (pas de sur-ingénierie).
  // =========================================================================
  async dashboard() {
    const now = new Date();
    const [studies, steps, hazards, ccps, monitoring] = await Promise.all([
      this.db.haccpStudy.findMany(),
      this.db.haccpProcessStep.findMany(),
      this.db.haccpHazard.findMany(),
      this.db.haccpCcp.findMany(),
      this.db.haccpMonitoringRecord.findMany(),
    ]);

    const dangersParType: Record<string, number> = {};
    for (const h of hazards) dangersParType[h.type] = (dangersParType[h.type] || 0) + 1;

    const ccpActifs = ccps.filter((c) => c.active && c.type === 'CCP');
    const cpActifs = ccps.filter((c) => c.active && c.type === 'CP');
    const ccpEnAnomalie = ccpActifs.filter((c) => monitoring.some((m) => m.ccpId === c.id && m.statut === 'NON_CONFORME')).length;

    const controlesRealises = monitoring.filter((m) => ['REALISE', 'CONFORME', 'NON_CONFORME'].includes(m.statut)).length;
    const controlesConformes = monitoring.filter((m) => m.conforme === true).length;
    const controlesNonConformes = monitoring.filter((m) => m.conforme === false).length;
    const controlesEnRetard = monitoring.filter((m) => m.datePrevue && new Date(m.datePrevue) < now && ['A_REALISER', 'EN_RETARD'].includes(m.statut)).length;
    const controlesPrevus = monitoring.filter((m) => m.datePrevue).length;
    const tauxRealisation = controlesPrevus ? Math.round((controlesRealises / controlesPrevus) * 1000) / 10 : 0;
    const controlesEvalues = controlesConformes + controlesNonConformes;
    const tauxConformite = controlesEvalues ? Math.round((controlesConformes / controlesEvalues) * 1000) / 10 : 0;

    // NC/Actions HACCP — pas de champ "module" dédié sur NonConformity/Action :
    // on réutilise `source`/`NonConformity.source === 'HACCP'` (comme le fait
    // déjà le reste de l'application pour tracer l'origine d'une NC) et la
    // matrice CapaLink (sourceModule='HACCP_CCP') pour les actions, exactement
    // comme qhs.service.ts.dashboard() le fait pour 'SAFETY_TALK'. Simplification
    // assumée : une action CAPA créée depuis une NC HACCP mais reliée via
    // nonConformityId plutôt que via CapaLink est comptée aussi.
    let ncOuvertes = 0, actionsOuvertes = 0, actionsEnRetard = 0;
    try {
      const ncHaccp = await this.db.nonConformity.findMany({ where: { source: 'HACCP' }, select: { id: true, status: true } });
      ncOuvertes = ncHaccp.filter((n) => !['CLOSED', 'FERMEE'].includes(n.status)).length;
      const [liens, actionsParNc] = await Promise.all([
        this.db.capaLink.findMany({ where: { sourceModule: 'HACCP_CCP' }, select: { actionId: true } }),
        ncHaccp.length ? this.db.action.findMany({ where: { nonConformityId: { in: ncHaccp.map((n) => n.id) } }, select: { id: true } }) : Promise.resolve([]),
      ]);
      const actionIds = Array.from(new Set([...liens.map((l) => l.actionId), ...actionsParNc.map((a) => a.id)]));
      if (actionIds.length) {
        const actions = await this.db.action.findMany({ where: { id: { in: actionIds } } });
        actionsOuvertes = actions.filter((a) => !['CLOSED', 'CANCELLED'].includes(a.status)).length;
        actionsEnRetard = actions.filter((a) => a.dueDate && new Date(a.dueDate) < now && !['CLOSED', 'CANCELLED'].includes(a.status)).length;
      }
    } catch { /* calcul best-effort, ne bloque jamais le dashboard */ }

    return {
      etudesActives: studies.filter((s) => s.status === 'VALIDE').length,
      etudesTotal: studies.length,
      etapes: steps.length,
      dangers: hazards.length,
      dangersParType,
      ccp: ccpActifs.length,
      cp: cpActifs.length,
      ccpConformes: ccpActifs.length - ccpEnAnomalie,
      ccpEnAnomalie,
      controlesRealises,
      controlesConformes,
      controlesNonConformes,
      controlesEnRetard,
      tauxRealisation,
      tauxConformite,
      ncOuvertes,
      actionsOuvertes,
      actionsEnRetard,
    };
  }
}
