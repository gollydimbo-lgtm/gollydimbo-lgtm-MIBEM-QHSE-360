// Catalogue de recommandations QHSE, basé sur les mots-clés du titre/description
// d'une non-conformité, d'un accident ou d'un risque. Volontairement simple
// (correspondance de mots-clés) : la décision finale reste toujours humaine
// (l'utilisateur ACCEPTE / MODIFIE / REFUSE / AJOUTE une suggestion), comme
// prévu dans le cahier des charges — ce moteur ne fait que proposer.
export type RecommendationRule = { keywords: string[]; category: string; actions: string[] };

export const RECOMMENDATION_RULES: RecommendationRule[] = [
  {
    category: 'Étiquetage / marquage',
    keywords: ['étiquet', 'etiquet', 'marquage', 'code-barres', 'date de péremption', 'dlc', 'ddm'],
    actions: [
      'Bloquer le lot concerné',
      'Vérifier les paramètres d\'impression de la ligne',
      'Contrôler les derniers lots produits sur la même plage horaire',
      'Identifier la cause (réglage machine, consommable, opérateur)',
      'Former l\'opérateur si nécessaire',
      'Mettre en place une vérification renforcée pendant 48h',
      'Vérifier l\'efficacité de la correction sous 7 jours',
    ],
  },
  {
    category: 'Sertissage / bouchage / bague de sécurité',
    keywords: ['sertissage', 'bouchage', 'bague', 'sur-capsule', 'menchon', 'capsul'],
    actions: [
      'Bloquer le lot concerné',
      'Arrêter la ligne et contrôler le réglage de la sertisseuse/boucheuse',
      'Prélever un échantillon renforcé (13 sachets de 500 unités)',
      'Vérifier le couple de serrage / la pression de sertissage',
      'Contrôler les bouteilles/canettes déjà stockées du même lot',
      'Former le contrôleur si le défaut n\'a pas été détecté à temps',
      'Vérifier l\'efficacité sur les 3 prochains contrôles',
    ],
  },
  {
    category: 'Poids / remplissage',
    keywords: ['poids', 'pesée', 'remplissage', 'sous-dosage', 'sur-dosage', 'niveau de remplissage'],
    actions: [
      'Bloquer le lot concerné',
      'Recalibrer la doseuse/remplisseuse',
      'Contrôler le suivi de pesée opérateur sur le quart en cours',
      'Vérifier l\'étalonnage des balances de contrôle',
      'Réaliser un contrôle à 100% sur les 30 dernières minutes de production',
      'Vérifier l\'efficacité sous 24h',
    ],
  },
  {
    category: 'Corps étranger / propreté',
    keywords: ['corps étranger', 'corps etranger', 'propreté', 'saleté', 'verre', 'insecte', 'contamination'],
    actions: [
      'Bloquer immédiatement le lot concerné',
      'Isoler et analyser l\'échantillon non conforme',
      'Renforcer l\'inspection visuelle sur la ligne',
      'Vérifier les procédures de nettoyage et désinfection (plan HACCP)',
      'Rechercher la source de contamination (CCP concerné)',
      'Vérifier l\'efficacité par un contrôle renforcé pendant 3 jours',
    ],
  },
  {
    category: 'Accident / chute / blessure',
    keywords: ['chute', 'coupure', 'brûlure', 'brulure', 'blessure', 'accident', 'écrasement', 'ecrasement'],
    actions: [
      'Sécuriser immédiatement la zone concernée',
      'Apporter les premiers secours si nécessaire',
      'Déclarer l\'accident à la CNPS/l\'organisme compétent si arrêt de travail',
      'Ouvrir une investigation (causes immédiates et profondes)',
      'Vérifier le port des EPI adaptés au poste',
      'Mettre en place une action corrective avant reprise du poste',
      'Réaliser un retour d\'expérience (REX) avec l\'équipe',
    ],
  },
  {
    category: 'Situation dangereuse / presqu\'accident',
    keywords: ['situation dangereuse', 'presqu\'accident', 'presqu accident', 'quasi-accident', 'danger imminent'],
    actions: [
      'Neutraliser le danger immédiat si possible',
      'Signaler la zone (balisage, consigne)',
      'Analyser la situation avec le responsable de secteur',
      'Évaluer si le DUERP doit être mis à jour',
      'Définir une mesure corrective avant réoccurrence',
      'Informer les équipes concernées (quart d\'heure sécurité)',
    ],
  },
  {
    category: 'Équipement / panne',
    keywords: ['panne', 'équipement', 'equipement', 'machine', 'dysfonctionnement', 'maintenance'],
    actions: [
      'Arrêter l\'équipement en toute sécurité (consignation si besoin)',
      'Déclarer une intervention de maintenance',
      'Vérifier l\'historique d\'inspection de l\'équipement',
      'Évaluer l\'impact sur les lots en cours de production',
      'Planifier une inspection préventive renforcée',
      'Vérifier l\'efficacité après remise en service',
    ],
  },
  {
    category: 'Documentation / procédure',
    keywords: ['procédure', 'procedure', 'document', 'instruction', 'non respect', 'non-respect'],
    actions: [
      'Rappeler la procédure applicable à l\'équipe concernée',
      'Vérifier si la procédure est à jour et accessible sur le terrain',
      'Former ou re-former le personnel concerné',
      'Mettre à jour le document si la cause est un écart de procédure obsolète',
      'Vérifier l\'application correcte lors du prochain contrôle',
    ],
  },
];

// Actions génériques proposées quand aucune règle spécifique ne correspond,
// pour ne jamais renvoyer une liste vide.
export const GENERIC_ACTIONS = [
  'Analyser la cause racine avec l\'équipe concernée',
  'Définir une action corrective et un responsable',
  'Fixer une échéance réaliste',
  'Vérifier l\'efficacité de l\'action après mise en œuvre',
];

export function suggestActions(text: string): { category: string; actions: string[] }[] {
  const normalized = (text || '').toLowerCase();
  const matches = RECOMMENDATION_RULES.filter(r => r.keywords.some(k => normalized.includes(k)));
  if (matches.length === 0) return [{ category: 'Général', actions: GENERIC_ACTIONS }];
  return matches.map(m => ({ category: m.category, actions: m.actions }));
}
