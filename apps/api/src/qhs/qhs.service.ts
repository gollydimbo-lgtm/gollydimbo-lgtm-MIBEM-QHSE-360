import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';

@Injectable()
export class QhsService {
  constructor(private db: PrismaService) {}

  // Traçabilité — même pattern que documents.service.ts. Un échec de
  // journalisation ne doit jamais faire échouer l'opération métier.
  private async log(action: string, entityId: string | null, userId?: string | null, oldValue?: any, newValue?: any) {
    await this.db.auditLog.create({ data: { module: 'SAFETY_TALK', action, entityId, userId: userId ?? null, oldValue, newValue } }).catch(() => undefined);
  }

  private mondayOf(d: Date) {
    const x = new Date(d);
    const day = x.getDay();
    const diff = (day === 0 ? -6 : 1) - day; // recule jusqu'au lundi
    x.setDate(x.getDate() + diff);
    x.setHours(0, 0, 0, 0);
    return x;
  }

  // Génère (ou régénère si déjà en brouillon) le thème du quart d'heure sécurité
  // de la semaine en cours, à partir des accidents/incidents/situations
  // dangereuses et des non-conformités critiques survenus les 7 derniers jours.
  async generate() {
    const weekStart = this.mondayOf(new Date());
    const weekEnd = new Date(weekStart); weekEnd.setDate(weekEnd.getDate() + 7);
    const since = new Date(); since.setDate(since.getDate() - 7);

    const [events, criticalNc] = await Promise.all([
      this.db.safetyEvent.findMany({ where: { occurredAt: { gte: since } }, orderBy: { severity: 'desc' } }),
      this.db.nonConformity.findMany({ where: { occurredAt: { gte: since }, severity: { gte: 4 } }, orderBy: { severity: 'desc' }, take: 5 }),
    ]);

    const byType: Record<string, number> = {};
    for (const e of events) byType[e.type] = (byType[e.type] || 0) + 1;
    const topType = Object.entries(byType).sort((a, b) => b[1] - a[1])[0];
    const mostSevere = events[0];

    // Cause racine ou zone dominante de la semaine — quand elle existe,
    // c'est un thème bien plus actionnable qu'un simple type d'événement.
    const byCause: Record<string, number> = {};
    for (const e of events) if ((e as any).causeRacine) byCause[(e as any).causeRacine] = (byCause[(e as any).causeRacine] || 0) + 1;
    const topCause = Object.entries(byCause).sort((a, b) => b[1] - a[1])[0];
    const byZone: Record<string, number> = {};
    for (const e of events) if ((e as any).zone) byZone[(e as any).zone] = (byZone[(e as any).zone] || 0) + 1;
    const topZone = Object.entries(byZone).sort((a, b) => b[1] - a[1])[0];

    const title = topCause
      ? `Prévention : ${topCause[0]}`
      : topType
      ? `Prévention : ${this.labelType(topType[0])}`
      : criticalNc.length > 0
      ? `Focus qualité : ${criticalNc[0].title}`
      : 'Rappel des consignes de sécurité générales';

    const lines: string[] = [];
    lines.push(`Période analysée : ${this.fmt(since)} → ${this.fmt(new Date())}.`);
    lines.push(`${events.length} événement(s) sécurité déclaré(s) cette semaine.`);
    if (topCause) lines.push(`Cause dominante identifiée lors des enquêtes : « ${topCause[0]} » (${topCause[1]} occurrence(s)) — thème prioritaire de la séance.`);
    if (topZone) lines.push(`Zone la plus concernée : ${topZone[0]} (${topZone[1]} événement(s)).`);
    if (topType) lines.push(`Type le plus fréquent : ${this.labelType(topType[0])} (${topType[1]} occurrence(s)).`);
    if (mostSevere) lines.push(`Événement le plus grave : « ${mostSevere.title} » (sévérité ${mostSevere.severity}).`);
    if (criticalNc.length > 0) lines.push(`${criticalNc.length} non-conformité(s) critique(s) associée(s) : ${criticalNc.map((n: { code: string }) => n.code).join(', ')}.`);
    if (events.length === 0 && criticalNc.length === 0) lines.push('Aucun événement notable cette semaine — profiter du quart d\'heure pour un rappel des bonnes pratiques et des EPI.');
    lines.push('Rappel : tout danger observé doit être déclaré immédiatement, même sans conséquence (presqu\'accident).');

    const existing = await this.db.safetyTalk.findUnique({ where: { weekStart } });
    const data = { weekStart, weekEnd, title, summary: lines.join('\n'), status: 'DRAFT' as const, generatedAt: new Date() };

    if (existing && existing.status === 'DRAFT') {
      return this.db.safetyTalk.update({ where: { weekStart }, data });
    }
    if (existing) return existing; // déjà approuvé/délivré : on ne l'écrase pas
    return this.db.safetyTalk.create({ data });
  }

  list() {
    return this.db.safetyTalk.findMany({ orderBy: { weekStart: 'desc' }, take: 20 });
  }

  approve(id: string) {
    return this.db.safetyTalk.update({ where: { id }, data: { status: 'APPROVED', approvedAt: new Date() } });
  }

  deliver(id: string) {
    return this.db.safetyTalk.update({ where: { id }, data: { status: 'DELIVERED' } });
  }

  remove(id: string) {
    return this.db.safetyTalk.delete({ where: { id } });
  }

  // =========================================================================
  // MOTEUR DE RECOMMANDATION — observe les autres modules QHSE (accidents,
  // NC, risques, actions en retard) et propose des thèmes de sensibilisation
  // justifiés. Ne crée JAMAIS de séance : la validation finale (accepter /
  // reporter / ignorer) reste toujours humaine.
  // =========================================================================

  private async ruleValue(code: string, defaut: number): Promise<number> {
    const r = await this.db.safetyTalkRule.findUnique({ where: { code } }).catch(() => null);
    if (!r || !r.active) return defaut;
    return r.periodeJours ?? r.seuil ?? defaut;
  }

  async recommendations() {
    const fenetreJours = await this.ruleValue('FENETRE_ANALYSE_JOURS', 60);
    const rappelRisqueJours = await this.ruleValue('RAPPEL_RISQUE_JOURS', 180);
    const since = new Date(); since.setDate(since.getDate() - fenetreJours);
    const now = new Date();

    const propositions: { theme: string; motif: string; priorite: string; sourceModules: string; score: number; metadata: any }[] = [];

    // --- 1) Événements sécurité (SafetyEvent) groupés par catégorie/type ---
    const events = await this.db.safetyEvent.findMany({ where: { occurredAt: { gte: since } } });
    const groupesEvents: Record<string, typeof events> = {};
    for (const e of events) {
      const cle = e.categorie || e.type || 'Non catégorisé';
      (groupesEvents[cle] ||= []).push(e);
    }
    for (const [cle, liste] of Object.entries(groupesEvents)) {
      const graves = liste.filter((e) => e.severity >= 4);
      if (liste.length < 2 && graves.length === 0) continue;
      const priorite = graves.length > 0 ? 'CRITIQUE' : liste.length >= 3 ? 'ELEVEE' : 'MOYENNE';
      propositions.push({
        theme: `Prévention : ${this.labelType(cle) !== cle ? this.labelType(cle) : cle}`,
        motif: `${liste.length} événement(s) « ${cle} » déclaré(s) sur les ${fenetreJours} derniers jours${graves.length ? `, dont ${graves.length} grave(s) (sévérité ≥ 4)` : ''}.`,
        priorite,
        sourceModules: 'SAFETY_EVENT',
        score: liste.length * 10 + (graves.length > 0 ? 10 : 0),
        metadata: { eventIds: liste.map((e) => e.id), ncIds: [], riskIds: [], actionIds: [] },
      });
    }

    // --- 2) Non-conformités groupées par classification/category ---
    const ncs = await this.db.nonConformity.findMany({ where: { occurredAt: { gte: since } } });
    const groupesNc: Record<string, typeof ncs> = {};
    for (const n of ncs) {
      const cle = n.classification || n.criticiteNiveau || 'Non classée';
      (groupesNc[cle] ||= []).push(n);
    }
    for (const [cle, liste] of Object.entries(groupesNc)) {
      const critiques = liste.filter((n) => (n.criticiteNiveau || '').toUpperCase() === 'CRITIQUE');
      if (liste.length < 2 && critiques.length === 0) continue;
      const priorite = critiques.length > 0 ? 'CRITIQUE' : liste.length >= 3 ? 'ELEVEE' : 'MOYENNE';
      propositions.push({
        theme: `Prévention qualité : ${cle}`,
        motif: `${liste.length} non-conformité(s) « ${cle} » relevée(s) sur les ${fenetreJours} derniers jours${critiques.length ? `, dont ${critiques.length} critique(s)` : ''}.`,
        priorite,
        sourceModules: 'NON_CONFORMITY',
        score: liste.length * 10 + (critiques.length > 0 ? 10 : 0),
        metadata: { eventIds: [], ncIds: liste.map((n) => n.id), riskIds: [], actionIds: [] },
      });
    }

    // --- 3) Risques critiques/élevés jamais rappelés récemment ---
    const risquesCritiques = await this.db.risk.findMany({ where: { status: 'ACTIVE', grossLevel: { in: ['CRITIQUE', 'ELEVEE', 'ELEVE'] } } });
    for (const r of risquesCritiques) {
      const rappelRecent = await this.db.safetyTalkRecommendation.findFirst({
        where: {
          sourceModules: 'RISK',
          safetyTalkId: { not: null },
          createdAt: { gte: new Date(now.getTime() - rappelRisqueJours * 86400000) },
          metadata: { path: ['riskIds'], array_contains: r.id } as any,
        },
      }).catch(() => null);
      if (rappelRecent) continue;
      propositions.push({
        theme: `Rappel préventif : ${r.hazard}`,
        motif: `Risque « ${r.hazard} » au niveau ${r.grossLevel} sans rappel de sensibilisation depuis plus de ${rappelRisqueJours} jours.`,
        priorite: 'ELEVEE',
        sourceModules: 'RISK',
        score: 25,
        metadata: { eventIds: [], ncIds: [], riskIds: [r.id], actionIds: [] },
      });
    }

    // --- 4) Actions CAPA en retard, regroupées par unité de travail ---
    const actionsEnRetard = await this.db.action.findMany({ where: { dueDate: { lt: now }, status: { notIn: ['CLOSED', 'CANCELLED'] } } });
    const groupesActions: Record<string, typeof actionsEnRetard> = {};
    for (const a of actionsEnRetard) {
      const cle = a.workUnitId || 'SANS_UNITE';
      if (cle === 'SANS_UNITE') continue;
      (groupesActions[cle] ||= []).push(a);
    }
    for (const [workUnitId, liste] of Object.entries(groupesActions)) {
      if (liste.length < 3) continue;
      const wu = await this.db.workUnit.findUnique({ where: { id: workUnitId } }).catch(() => null);
      propositions.push({
        theme: `Rappel des échéances : ${wu?.name || workUnitId}`,
        motif: `${liste.length} action(s) corrective(s)/préventive(s) en retard sur l'unité « ${wu?.name || workUnitId} ».`,
        priorite: 'ELEVEE',
        sourceModules: 'ACTION',
        score: liste.length * 8,
        metadata: { eventIds: [], ncIds: [], riskIds: [], actionIds: liste.map((a) => a.id) },
      });
    }

    // --- Déduplication : pas de nouvelle ligne si une PROPOSEE identique existe déjà (14 j) ---
    const recentes = await this.db.safetyTalkRecommendation.findMany({
      where: { status: 'PROPOSEE', createdAt: { gte: new Date(now.getTime() - 14 * 86400000) } },
    });
    const themesExistants = new Set(recentes.map((r) => r.theme));
    const aCreer = propositions.filter((p) => !themesExistants.has(p.theme));

    if (aCreer.length) {
      await this.db.safetyTalkRecommendation.createMany({
        data: aCreer.map((p) => ({ theme: p.theme, motif: p.motif, priorite: p.priorite, sourceModules: p.sourceModules, score: p.score, metadata: p.metadata, status: 'PROPOSEE' })),
      });
    }
    await this.log('Analyse du moteur de recommandation', null, null, null, { propositionsDetectees: propositions.length, nouvellesLignes: aCreer.length });

    return this.db.safetyTalkRecommendation.findMany({ where: { status: 'PROPOSEE' }, orderBy: { score: 'desc' } });
  }

  // Lecture simple — n'exécute jamais l'analyse, pour un affichage rapide.
  // L'actualisation se fait explicitement via recommendations().
  recommendationsList() {
    return this.db.safetyTalkRecommendation.findMany({ where: { status: 'PROPOSEE' }, orderBy: { score: 'desc' } });
  }

  async recommendationDecision(id: string, b: { decision: 'ACCEPTER' | 'REPORTER' | 'IGNORER' }) {
    const status = b.decision === 'ACCEPTER' ? 'ACCEPTEE' : b.decision === 'REPORTER' ? 'REPORTEE' : 'IGNOREE';
    const updated = await this.db.safetyTalkRecommendation.update({ where: { id }, data: { status } });
    await this.log('Décision sur recommandation : ' + b.decision, id);
    return updated;
  }

  // =========================================================================
  // BIBLIOTHÈQUE DE THÈMES — contenu réel, réutilisable pour préremplir une
  // fiche (manuellement ou à partir d'une recommandation acceptée).
  // =========================================================================
  themeLibrary(): { categorie: string; themes: { titre: string; objectif: string; pointsEssentiels: string; bonnesPratiques: string; mauvaisesPratiques: string; questions: string }[] }[] {
    return [
      {
        categorie: 'Sécurité générale',
        themes: [
          { titre: 'Culture sécurité au quotidien', objectif: 'Faire de la sécurité une habitude partagée par tous, pas seulement une règle imposée.', pointsEssentiels: 'La sécurité est la responsabilité de chacun. Un geste sûr aujourd\'hui évite un accident demain. Observer, signaler, agir.', bonnesPratiques: 'Signaler immédiatement tout danger observé, même mineur. Porter ses EPI sans attendre un rappel.', mauvaisesPratiques: 'Ignorer une anomalie « parce que ça n\'arrive jamais ». Contourner une consigne pour gagner du temps.', questions: 'Quel danger avez-vous observé cette semaine ? Qu\'auriez-vous fait différemment ?' },
          { titre: 'Droit d\'alerte et droit de retrait', objectif: 'Rappeler que tout collaborateur peut, et doit, arrêter une situation dangereuse.', pointsEssentiels: 'Le droit de retrait s\'exerce face à un danger grave et imminent, sans sanction possible. L\'alerte doit être immédiate, à l\'oral puis tracée.', bonnesPratiques: 'Prévenir son responsable dès qu\'un danger est identifié. Ne jamais reprendre le travail sans levée du danger confirmée.', mauvaisesPratiques: 'Continuer à travailler « pour ne pas déranger ». Garder l\'information pour soi.', questions: 'Sauriez-vous reconnaître un danger grave et imminent ? Qui prévenir en premier ?' },
          { titre: 'Règles vitales de l\'entreprise', objectif: 'Rappeler les quelques règles dont le non-respect peut entraîner un accident mortel.', pointsEssentiels: 'Un petit nombre de règles non négociables couvre la majorité des accidents graves : consignation énergie, port du harnais, port des EPI critiques.', bonnesPratiques: 'Appliquer la règle même seul, même pressé. Faire respecter la règle par ses collègues.', mauvaisesPratiques: 'Considérer une règle vitale comme optionnelle selon la tâche.', questions: 'Quelles sont nos règles vitales ? Laquelle est la plus souvent contournée et pourquoi ?' },
        ],
      },
      {
        categorie: 'EPI',
        themes: [
          { titre: 'Port et contrôle des EPI', objectif: 'S\'assurer que chaque EPI est porté correctement et vérifié avant usage.', pointsEssentiels: 'Un EPI mal ajusté ou endommagé ne protège plus. Le contrôle visuel avant chaque utilisation est un réflexe, pas une option.', bonnesPratiques: 'Vérifier l\'état de l\'EPI avant chaque prise de poste. Le remplacer dès qu\'il est endommagé ou périmé.', mauvaisesPratiques: 'Porter un EPI abîmé « en attendant le remplacement ». Retirer son EPI pour plus de confort.', questions: 'Comment vérifiez-vous l\'état de votre EPI avant usage ? Que faire si un EPI est manquant ?' },
          { titre: 'Protection auditive et respiratoire', objectif: 'Rappeler les risques d\'exposition au bruit et aux poussières/vapeurs et les moyens de s\'en protéger.', pointsEssentiels: 'Une exposition répétée, même à faible dose, provoque des atteintes irréversibles (surdité, maladies respiratoires). Le protecteur doit être adapté au poste.', bonnesPratiques: 'Porter le protecteur adapté dès l\'entrée en zone à risque. Signaler tout inconfort ou gêne respiratoire.', mauvaisesPratiques: 'Retirer le casque anti-bruit « juste une minute ». Réutiliser un masque au-delà de sa durée de vie.', questions: 'Dans quelles zones le port est-il obligatoire ? Quels signes doivent alerter ?' },
        ],
      },
      {
        categorie: 'Risques professionnels',
        themes: [
          { titre: 'Prévention des chutes de hauteur et de plain-pied', objectif: 'Réduire le risque de chute, première cause d\'accident grave.', pointsEssentiels: 'Une chute peut survenir aussi bien en hauteur qu\'au sol (sol glissant, encombrement). Le port du harnais et le dégagement des zones de circulation sont essentiels.', bonnesPratiques: 'Utiliser systématiquement la protection collective avant l\'individuelle. Signaler et nettoyer immédiatement un sol glissant.', mauvaisesPratiques: 'Monter sur un support instable pour gagner du temps. Laisser un obstacle sur un passage.', questions: 'Quelles zones de circulation présentent un risque de chute ? Comment sécuriser un travail en hauteur ponctuel ?' },
          { titre: 'Manutention et troubles musculo-squelettiques (TMS)', objectif: 'Limiter les contraintes physiques liées au port de charges et aux gestes répétitifs.', pointsEssentiels: 'Les TMS sont la première cause de maladie professionnelle. Les bons gestes et les aides à la manutention réduisent fortement le risque.', bonnesPratiques: 'Plier les jambes, garder le dos droit, utiliser les aides mécaniques disponibles. Alterner les tâches pour limiter la répétitivité.', mauvaisesPratiques: 'Soulever seul une charge trop lourde. Se tordre le dos pour atteindre un objet éloigné.', questions: 'Quelles aides à la manutention sont disponibles sur votre poste ? Ressentez-vous des douleurs récurrentes ?' },
          { titre: 'Risque électrique', objectif: 'Rappeler les dangers de l\'électricité et les règles de consignation.', pointsEssentiels: 'Le risque électrique est invisible et peut être mortel. Seules les personnes habilitées interviennent sur une installation, après consignation.', bonnesPratiques: 'Ne jamais intervenir sur une installation électrique sans habilitation. Signaler tout matériel électrique endommagé.', mauvaisesPratiques: 'Bricoler une rallonge ou un branchement « en dépannage ». Ignorer une odeur de brûlé ou un échauffement anormal.', questions: 'Qui est habilité électrique dans votre équipe ? Que faire face à un matériel électrique défectueux ?' },
          { titre: 'Sécurité machines et équipements de travail', objectif: 'Prévenir les accidents liés aux organes en mouvement et aux dispositifs de sécurité des machines.', pointsEssentiels: 'Un carter retiré ou une sécurité neutralisée supprime la protection prévue par le constructeur. Toute anomalie doit être signalée avant remise en route.', bonnesPratiques: 'Ne jamais neutraliser un dispositif de sécurité. Consigner la machine avant toute intervention de maintenance.', mauvaisesPratiques: 'Retirer un carter de protection « pour aller plus vite ». Nettoyer une machine en marche.', questions: 'Quels dispositifs de sécurité équipent votre machine ? Que faire si l\'un d\'eux est défaillant ?' },
        ],
      },
      {
        categorie: 'Urgences',
        themes: [
          { titre: 'Incendie et évacuation', objectif: 'S\'assurer que chacun connaît la conduite à tenir en cas de départ de feu.', pointsEssentiels: 'Les premières minutes sont déterminantes. Connaître le point de rassemblement et les issues de secours sauve des vies.', bonnesPratiques: 'Donner l\'alerte immédiatement, évacuer calmement vers le point de rassemblement. Ne jamais utiliser les ascenseurs.', mauvaisesPratiques: 'Retourner chercher ses affaires personnelles. Bloquer une issue de secours avec du matériel.', questions: 'Où se trouve le point de rassemblement de votre zone ? Sauriez-vous utiliser un extincteur ?' },
          { titre: 'Premiers secours', objectif: 'Rappeler les gestes qui sauvent en attendant les secours.', pointsEssentiels: 'Protéger, alerter, secourir : l\'ordre des priorités face à un accident. Un geste simple, bien fait, peut être décisif.', bonnesPratiques: 'Alerter les secours avec les bonnes informations (lieu, nature, nombre de victimes). Rester avec la victime jusqu\'à l\'arrivée des secours.', mauvaisesPratiques: 'Déplacer une victime sans nécessité. Improviser un geste de secours non maîtrisé.', questions: 'Qui sont les sauveteurs secouristes du travail de votre zone ? Connaissez-vous le numéro d\'urgence interne ?' },
        ],
      },
      {
        categorie: 'Environnement et hygiène',
        themes: [
          { titre: 'Gestion des déchets', objectif: 'Rappeler le tri et l\'élimination correcte des déchets, y compris dangereux.', pointsEssentiels: 'Un déchet mal trié peut polluer, coûter cher à traiter ou créer un risque pour la santé. Chaque filière a des règles précises.', bonnesPratiques: 'Trier systématiquement selon les filières définies. Utiliser les contenants dédiés aux déchets dangereux.', mauvaisesPratiques: 'Mélanger les déchets « pour aller plus vite ». Jeter un produit chimique dans une poubelle classique.', questions: 'Quelles filières de tri existent sur votre poste ? Que faire d\'un déchet dont vous ignorez la filière ?' },
          { titre: 'Manipulation des produits dangereux', objectif: 'Prévenir les risques chimiques liés au stockage et à la manipulation des produits.', pointsEssentiels: 'La fiche de données de sécurité (FDS) indique les risques et les protections nécessaires. Le stockage doit respecter les incompatibilités entre produits.', bonnesPratiques: 'Consulter la FDS avant toute manipulation d\'un nouveau produit. Porter les EPI adaptés (gants, lunettes).', mauvaisesPratiques: 'Transvaser un produit dans un contenant non étiqueté. Stocker des produits incompatibles côte à côte.', questions: 'Où trouver les FDS de votre atelier ? Que faire en cas de projection ou d\'inhalation ?' },
        ],
      },
    ];
  }

  private findMatchingTheme(theme: string, motif: string) {
    const lib = this.themeLibrary();
    const texte = `${theme} ${motif}`.toLowerCase();
    let best: { titre: string; objectif: string; pointsEssentiels: string; bonnesPratiques: string; mauvaisesPratiques: string; questions: string } | null = null;
    for (const cat of lib) {
      for (const t of cat.themes) {
        const mots = t.titre.toLowerCase().split(/\s+/).filter((m) => m.length > 3);
        if (mots.some((m) => texte.includes(m))) { best = t; break; }
      }
      if (best) break;
    }
    return best;
  }

  async generateFromRecommendation(recommendationId: string, b: any = {}) {
    const reco = await this.db.safetyTalkRecommendation.findUnique({ where: { id: recommendationId } });
    if (!reco) throw new BadRequestException('Recommandation introuvable');
    const weekStart = this.mondayOf(new Date());
    const weekEnd = new Date(weekStart); weekEnd.setDate(weekEnd.getDate() + 7);
    const matched = this.findMatchingTheme(reco.theme, reco.motif);

    const data: any = {
      weekStart: b.weekStart ? new Date(b.weekStart) : new Date(),
      weekEnd: b.weekEnd ? new Date(b.weekEnd) : weekEnd,
      title: reco.theme,
      summary: reco.motif,
      theme: reco.theme,
      objectif: matched?.objectif || `Sensibiliser l'équipe sur : ${reco.theme}.`,
      pointsEssentiels: matched?.pointsEssentiels || reco.motif,
      bonnesPratiques: matched?.bonnesPratiques || null,
      mauvaisesPratiques: matched?.mauvaisesPratiques || null,
      questions: matched?.questions || null,
      priorite: reco.priorite,
      origineType: 'AUTO_RECOMMANDE',
      origineRaison: reco.motif,
      origineModules: reco.sourceModules,
      status: 'DRAFT',
      ...b,
    };
    const created = await this.db.safetyTalk.create({ data });
    await this.db.safetyTalkRecommendation.update({ where: { id: recommendationId }, data: { safetyTalkId: created.id, status: 'ACCEPTEE' } });
    await this.log('Génération depuis recommandation', created.id, b.userId, null, { recommendationId, theme: reco.theme });
    return created;
  }

  async create(b: any) {
    const weekStart = b.weekStart ? new Date(b.weekStart) : this.mondayOf(new Date());
    const weekEnd = b.weekEnd ? new Date(b.weekEnd) : new Date(new Date(weekStart).setDate(weekStart.getDate() + 7));
    const data = { ...b, weekStart, weekEnd, origineType: 'MANUEL', status: 'DRAFT' };
    const created = await this.db.safetyTalk.create({ data });
    await this.log('Création manuelle', created.id, b.userId, null, data);
    return created;
  }

  async update(id: string, b: any) {
    const current = await this.db.safetyTalk.findUnique({ where: { id } });
    if (!current) throw new BadRequestException('Quart d\'heure sécurité introuvable');
    if (current.status === 'DELIVERED') throw new BadRequestException('Une séance déjà réalisée n\'est plus modifiable.');
    const updated = await this.db.safetyTalk.update({ where: { id }, data: b });
    await this.log('Modification', id, b.userId, current, updated);
    return updated;
  }

  // =========================================================================
  // PLANIFICATION
  // =========================================================================
  async schedule(id: string, b: { scheduledAt: string | Date; frequence?: string; duree?: number }) {
    const updated = await this.db.safetyTalk.update({ where: { id }, data: { scheduledAt: new Date(b.scheduledAt), frequence: b.frequence, duree: b.duree } });
    await this.log('Planification', id, undefined, null, b);
    return updated;
  }

  async postpone(id: string, b: { scheduledAt: string | Date }) {
    const current = await this.db.safetyTalk.findUnique({ where: { id } });
    if (!current) throw new BadRequestException('Quart d\'heure sécurité introuvable');
    const data: any = { scheduledAt: new Date(b.scheduledAt) };
    if (current.status === 'REPORTE') data.status = current.approvedAt ? 'APPROVED' : 'DRAFT';
    else data.status = 'REPORTE';
    const updated = await this.db.safetyTalk.update({ where: { id }, data });
    await this.log('Report', id, undefined, current, updated);
    return updated;
  }

  async cancel(id: string, b: any = {}) {
    const current = await this.db.safetyTalk.findUnique({ where: { id } });
    if (!current) throw new BadRequestException('Quart d\'heure sécurité introuvable');
    if (current.status === 'DELIVERED') throw new BadRequestException('Une séance déjà réalisée ne peut pas être annulée.');
    const updated = await this.db.safetyTalk.update({ where: { id }, data: { status: 'ANNULE' } });
    await this.log('Annulation', id, b.userId, current, updated);
    return updated;
  }

  // =========================================================================
  // ÉMARGEMENT
  // =========================================================================
  participantsList(id: string) {
    return this.db.safetyTalkParticipant.findMany({ where: { safetyTalkId: id }, include: { employee: true, user: true }, orderBy: { createdAt: 'asc' } });
  }

  addParticipant(id: string, b: { employeeId?: string; userId?: string; present?: boolean; motifAbsence?: string; signature?: string }) {
    return this.db.safetyTalkParticipant.create({ data: { safetyTalkId: id, employeeId: b.employeeId, userId: b.userId, present: b.present ?? true, motifAbsence: b.motifAbsence, signature: b.signature } });
  }

  bulkAddParticipants(id: string, b: { employeeIds: string[] }) {
    return this.db.safetyTalkParticipant.createMany({ data: (b.employeeIds || []).map((employeeId) => ({ safetyTalkId: id, employeeId, present: true })) });
  }

  removeParticipant(participantId: string) {
    return this.db.safetyTalkParticipant.delete({ where: { id: participantId } });
  }

  // =========================================================================
  // REMONTÉES TERRAIN → CAPA / NC / SAFETY EVENT (toujours sur décision humaine)
  // =========================================================================
  feedbackList(id: string) {
    return this.db.safetyTalkFeedback.findMany({ where: { safetyTalkId: id }, orderBy: { createdAt: 'desc' } });
  }

  async addFeedback(id: string, b: any) {
    const created = await this.db.safetyTalkFeedback.create({ data: { ...b, safetyTalkId: id } });
    await this.log('Remontée terrain ajoutée', created.id, b.reportedById);
    return created;
  }

  private feedbackCriticiteToSeverity(criticite?: string | null): number {
    const n = (criticite || '').toUpperCase();
    if (n === 'CRITIQUE') return 5;
    if (n === 'ELEVEE' || n === 'ELEVE') return 4;
    if (n === 'MOYENNE' || n === 'MODEREE') return 3;
    if (n === 'FAIBLE') return 2;
    return 2;
  }

  private feedbackTypeToActionType(type: string): string {
    const preventif = ['DANGER', 'SITUATION_DANGEREUSE', 'COMPORTEMENT_RISQUE', 'EQUIPEMENT_DEFECTUEUX', 'EPI_MANQUANT', 'EPC_DEFAILLANT', 'ORGANISATION'];
    const correctif = ['ANOMALIE', 'PRESQUE_ACCIDENT', 'NC'];
    if (preventif.includes(type)) return 'PREVENTIVE';
    if (correctif.includes(type)) return 'CORRECTIVE';
    if (type === 'AMELIORATION') return 'AMELIORATION';
    return 'CORRECTIVE';
  }

  async transformFeedback(feedbackId: string, b: { targetModule: 'ACTION' | 'NON_CONFORMITY' | 'SAFETY_EVENT'; overrides?: any; userId?: string }) {
    const feedback = await this.db.safetyTalkFeedback.findUnique({ where: { id: feedbackId } });
    if (!feedback) throw new BadRequestException('Remontée terrain introuvable');
    const safetyTalk = await this.db.safetyTalk.findUnique({ where: { id: feedback.safetyTalkId } });
    const overrides = b.overrides || {};
    let created: any;

    if (b.targetModule === 'ACTION') {
      const dueDate = new Date(); dueDate.setDate(dueDate.getDate() + 7);
      created = await this.db.action.create({
        data: {
          code: `AT-${Date.now()}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`,
          title: feedback.description.slice(0, 120),
          description: feedback.description,
          actionType: this.feedbackTypeToActionType(feedback.type),
          criticite: feedback.criticite,
          dueDate,
          source: 'Quart d\'heure sécurité',
          ...overrides,
        },
      });
      await this.db.capaLink.create({ data: { actionId: created.id, sourceModule: 'SAFETY_TALK', sourceEntityId: safetyTalk?.id || feedback.safetyTalkId, relationType: 'GENEREE_PAR', createdById: b.userId || null } });
    } else if (b.targetModule === 'NON_CONFORMITY') {
      created = await this.db.nonConformity.create({
        data: {
          code: `NC-${Date.now()}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`,
          title: feedback.description.slice(0, 120),
          description: feedback.description,
          source: 'Quart d\'heure sécurité',
          classification: feedback.criticite || undefined,
          occurredAt: new Date(),
          ...overrides,
        },
      });
    } else if (b.targetModule === 'SAFETY_EVENT') {
      created = await this.db.safetyEvent.create({
        data: {
          type: 'SITUATION_DANGEREUSE',
          categorie: feedback.type,
          title: feedback.description.slice(0, 120),
          description: feedback.description,
          occurredAt: new Date(),
          severity: this.feedbackCriticiteToSeverity(feedback.criticite),
          statut: 'DECLARE',
          zone: feedback.localisation || undefined,
          ...overrides,
        },
      });
    } else {
      throw new BadRequestException('Module cible non pris en charge');
    }

    const updatedFeedback = await this.db.safetyTalkFeedback.update({
      where: { id: feedbackId },
      data: { status: 'TRANSFORME', transformedIntoModule: b.targetModule, transformedIntoId: created.id },
    });
    await this.log('Remontée terrain transformée en ' + b.targetModule, feedbackId, b.userId, feedback, { targetModule: b.targetModule, createdId: created.id });
    return { feedback: updatedFeedback, created };
  }

  // =========================================================================
  // QUIZ
  // =========================================================================
  quizSubmit(id: string, b: { participantId?: string; score: number; total: number }) {
    return this.db.safetyTalkQuizResult.create({ data: { safetyTalkId: id, participantId: b.participantId, score: b.score, total: b.total } });
  }

  async quizStats(id: string) {
    const results = await this.db.safetyTalkQuizResult.findMany({ where: { safetyTalkId: id } });
    const participants = results.length;
    const scoreMoyen = participants ? Math.round((results.reduce((s, r) => s + (r.total ? r.score / r.total : 0), 0) / participants) * 1000) / 10 : 0;
    const tauxReussite = participants ? Math.round((results.filter((r) => r.total > 0 && r.score / r.total >= 0.5).length / participants) * 1000) / 10 : 0;
    return { participants, scoreMoyen, tauxReussite };
  }

  // =========================================================================
  // DASHBOARD / KPI / MATRICE
  // =========================================================================
  async dashboard() {
    const now = new Date();
    const talks = await this.db.safetyTalk.findMany({ include: { participants: true, feedbacks: true, recommendations: true } });

    const planifies = talks.filter((t) => ['DRAFT', 'APPROVED'].includes(t.status) && t.scheduledAt && new Date(t.scheduledAt) >= now).length;
    const realises = talks.filter((t) => t.status === 'DELIVERED').length;
    const enRetard = talks.filter((t) => t.scheduledAt && new Date(t.scheduledAt) < now && !['DELIVERED', 'ANNULE'].includes(t.status)).length;
    const annules = talks.filter((t) => t.status === 'ANNULE').length;
    const totalPlanifiable = talks.filter((t) => t.scheduledAt).length;
    const tauxRealisation = totalPlanifiable ? Math.round((realises / totalPlanifiable) * 1000) / 10 : 0;

    const tousParticipants = talks.flatMap((t) => t.participants);
    const participants = tousParticipants.length;
    const presents = tousParticipants.filter((p) => p.present).length;
    const tauxParticipation = participants ? Math.round((presents / participants) * 1000) / 10 : 0;

    const themesTraites = new Set(talks.filter((t) => t.status === 'DELIVERED').map((t) => t.title)).size;
    const tousFeedbacks = talks.flatMap((t) => t.feedbacks);
    const remonteesTerrain = tousFeedbacks.length;
    const dangersDetectes = tousFeedbacks.filter((f) => f.type !== 'AMELIORATION').length;
    const actionsCreees = tousFeedbacks.filter((f) => f.status === 'TRANSFORME' && f.transformedIntoModule === 'ACTION').length;

    // Actions issues du module, via la matrice CapaLink (sourceModule='SAFETY_TALK').
    let actionsClotures = 0, actionsEnRetard = 0;
    try {
      const liens = await this.db.capaLink.findMany({ where: { sourceModule: 'SAFETY_TALK' }, select: { actionId: true } });
      if (liens.length) {
        const actions = await this.db.action.findMany({ where: { id: { in: liens.map((l) => l.actionId) } } });
        actionsClotures = actions.filter((a) => a.status === 'CLOSED').length;
        actionsEnRetard = actions.filter((a) => a.dueDate && new Date(a.dueDate) < now && !['CLOSED', 'CANCELLED'].includes(a.status)).length;
      }
    } catch { /* calcul best-effort, ne bloque jamais le dashboard */ }

    const sujetsAutoGeneres = talks.filter((t) => t.origineType === 'AUTO_RECOMMANDE').length;
    const sensibilisationsAccidents = talks.filter((t) => (t.origineModules || '').includes('SAFETY_EVENT')).length;
    const sensibilisationsNc = talks.filter((t) => (t.origineModules || '').includes('NON_CONFORMITY')).length;
    const sensibilisationsRisques = talks.filter((t) => (t.origineModules || '').includes('RISK')).length;

    return {
      planifies, realises, enRetard, annules, tauxRealisation, participants, tauxParticipation,
      themesTraites, remonteesTerrain, dangersDetectes, actionsCreees, actionsClotures, actionsEnRetard,
      sujetsAutoGeneres, sensibilisationsAccidents, sensibilisationsNc, sensibilisationsRisques,
    };
  }

  async matrice() {
    const recos = await this.db.safetyTalkRecommendation.findMany({ where: { safetyTalkId: { not: null } }, include: { safetyTalk: true }, orderBy: { createdAt: 'desc' } });
    return recos.map((r) => {
      const meta: any = r.metadata || {};
      return {
        source: r.sourceModules,
        evenement: (meta.eventIds || []).concat(meta.ncIds || []).concat(meta.actionIds || []).join(', ') || null,
        risque: (meta.riskIds || []).join(', ') || null,
        theme: r.safetyTalk?.title || r.theme,
        priorite: r.priorite,
        statut: r.safetyTalk?.status || r.status,
      };
    });
  }

  // =========================================================================
  // RÈGLES CONFIGURABLES
  // =========================================================================
  rulesList() {
    return this.db.safetyTalkRule.findMany({ orderBy: { code: 'asc' } });
  }

  rulesUpsert(b: { code: string; label: string; seuil?: number; periodeJours?: number; active?: boolean }) {
    return this.db.safetyTalkRule.upsert({
      where: { code: b.code },
      update: { label: b.label, seuil: b.seuil, periodeJours: b.periodeJours, active: b.active ?? true },
      create: { code: b.code, label: b.label, seuil: b.seuil, periodeJours: b.periodeJours, active: b.active ?? true },
    });
  }

  rulesDelete(id: string) {
    return this.db.safetyTalkRule.delete({ where: { id } });
  }

  private labelType(t: string) {
    return ({
      ACCIDENT: 'accidents',
      INCIDENT: 'incidents',
      PRESQU_ACCIDENT: 'presqu\'accidents',
      SITUATION_DANGEREUSE: 'situations dangereuses',
    } as Record<string, string>)[t] || t;
  }
  private fmt(d: Date) { return d.toISOString().slice(0, 10); }
}
