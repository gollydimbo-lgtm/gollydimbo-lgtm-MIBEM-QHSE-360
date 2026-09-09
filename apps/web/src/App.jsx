import React, { useState, useEffect, useMemo, useRef, createContext, useContext } from 'react';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  PieChart, Pie, Cell, ComposedChart, ReferenceLine,
} from 'recharts';
import {
  LayoutDashboard, ShieldCheck, HardHat, Leaf, AlertTriangle, FileBarChart,
  ClipboardList, Activity, HeartPulse, Bell,
  FlaskConical, Users, Sun, Moon, Search, ClipboardCheck,
  FileWarning, Target, BookOpen, FolderOpen, Wrench, Menu, X, RefreshCw, LogOut, ChevronDown,
  Shield, UtensilsCrossed, Cog,
} from 'lucide-react';
import * as XLSX from 'xlsx';
import mammoth from 'mammoth';
import { api, getStoredUser, logout as apiLogout, getBaseUrl } from './api';
import LoginPage from './LoginPage';

// ============================================================================
// Thèmes — sombre (identique à la maquette de référence) et clair, au choix.
// Fourni via un Contexte React pour que chaque composant y accède sans avoir
// à le recevoir en prop explicitement.
// ============================================================================
const THEMES = {
  dark: {
    bg: '#0B0F19', card: '#111827', cardAlt: '#151B2B', border: '#1F2937',
    text: '#FFFFFF', textMuted: '#9CA3AF',
    red: '#EF4444', amber: '#F59E0B', green: '#10B981', blue: '#3B82F6',
  },
  light: {
    bg: '#F3F4F6', card: '#FFFFFF', cardAlt: '#F9FAFB', border: '#E5E7EB',
    text: '#111827', textMuted: '#6B7280',
    red: '#DC2626', amber: '#D97706', green: '#059669', blue: '#2563EB',
  },
};
const ThemeContext = createContext(THEMES.dark);
function useTheme() { return useContext(ThemeContext); }

// ============================================================================
// Données consolidées — simulent les bases QHSE distinctes (Qualité,
// Sécurité, Hygiène, Environnement, Risques/Audits) déjà en place. En
// production, chaque bloc viendrait d'un appel API dédié à son module ;
// toute la logique d'agrégation reste isolée plus bas, jamais dans l'UI.
// ============================================================================
const DATA = {
  periode: 'Septembre 2026',
  effectif: 248,
  heuresTravaillees: 39680,
  qualite: {
    tauxConformite: 92.4,
    indicateursQualite: [
      { indicateur: 'Taux de rebut production', actuel: 1.8, cible: 2, unite: '%', sensInverse: true },
      { indicateur: 'Taux de conformité réception', actuel: 96.5, cible: 98, unite: '%' },
      { indicateur: 'Taux de satisfaction client', actuel: 88, cible: 90, unite: '%' },
      { indicateur: 'Livraisons à temps', actuel: 94, cible: 95, unite: '%' },
      { indicateur: 'Taux de retour produit', actuel: 1.2, cible: 1.5, unite: '%', sensInverse: true },
    ],
    processusDetail: [
      { processus: 'Production', proprietaire: 'Directeur Production', objectifs: 'Zéro défaut, respect des délais', kpi: 'Taux de rebut < 2%' },
      { processus: 'Achats', proprietaire: 'Responsable Achats', objectifs: 'Qualité fournisseurs, coûts maîtrisés', kpi: 'Taux de conformité réception > 98%' },
      { processus: 'Logistique', proprietaire: 'Responsable Maintenance', objectifs: 'Livraisons à temps', kpi: 'Taux de service > 95%' },
      { processus: 'RH', proprietaire: 'DRH', objectifs: 'Compétences à jour', kpi: 'Taux de formation > 90%' },
      { processus: 'Commercial', proprietaire: 'Directeur Commercial', objectifs: 'Satisfaction client', kpi: 'NPS > 8/10' },
    ],
    causesNonConformites: [
      { cause: 'Défaut matière première', occurrences: 14 },
      { cause: 'Erreur de process', occurrences: 9 },
      { cause: 'Étiquetage incorrect', occurrences: 7 },
      { cause: 'Écart de pesée', occurrences: 5 },
      { cause: 'Contamination', occurrences: 3 },
      { cause: 'Autre', occurrences: 2 },
    ],
    reclamations: [
      { id: 'REC-2026-014', client: 'Distributeur Sahel SA', motif: 'Étiquetage incorrect', date: '2026-09-03', statut: 'En cours', gravite: 'Modérée' },
      { id: 'REC-2026-013', client: 'Grossiste Awa Import', motif: 'Bouteille non conforme (fuite)', date: '2026-08-28', statut: 'Clôturée', gravite: 'Élevée' },
      { id: 'REC-2026-012', client: 'Supermarché Continental', motif: 'Poids insuffisant', date: '2026-08-22', statut: 'Clôturée', gravite: 'Faible' },
      { id: 'REC-2026-011', client: 'Distributeur Sahel SA', motif: 'Retard de livraison', date: '2026-08-15', statut: 'Clôturée', gravite: 'Faible' },
      { id: 'REC-2026-010', client: 'Hôtel Ivoire Palace', motif: 'Goût altéré (lot suspect)', date: '2026-08-09', statut: 'En cours', gravite: 'Élevée' },
      { id: 'REC-2026-009', client: 'Grossiste Awa Import', motif: 'Carton endommagé', date: '2026-07-30', statut: 'Clôturée', gravite: 'Faible' },
    ],
    fournisseurs: [
      { nom: 'Verrerie Continentale', categorie: 'Emballage verre', scoreQualite: 94, derniereEvaluation: '2026-07-15', statut: 'Homologué' },
      { nom: 'AgroMalt Distribution', categorie: 'Matière première', scoreQualite: 88, derniereEvaluation: '2026-06-20', statut: 'Homologué' },
      { nom: 'PackPro Emballages', categorie: 'Étiquettes & cartons', scoreQualite: 76, derniereEvaluation: '2026-08-01', statut: 'Sous surveillance' },
      { nom: 'ChimSafe Ingrédients', categorie: 'Additifs', scoreQualite: 91, derniereEvaluation: '2026-05-28', statut: 'Homologué' },
      { nom: "Logitrans Côte d'Ivoire", categorie: 'Transport', scoreQualite: 68, derniereEvaluation: '2026-08-10', statut: "Plan d'action requis" },
    ],
  },
  securite: {
    accidentsAvecArret: 2, accidentsSansArret: 5, presquAccidents: 9,
    incidents: 10, situationsDangereuses: 1, joursPerdus: 13, joursSansAccident: 20,
    evolutionMensuelle: [
      { mois: 'Avr', accidents: 1, incidents: 4 }, { mois: 'Mai', accidents: 0, incidents: 2 },
      { mois: 'Juin', accidents: 2, incidents: 5 }, { mois: 'Juil', accidents: 1, incidents: 3 },
      { mois: 'Août', accidents: 0, incidents: 6 }, { mois: 'Sept', accidents: 2, incidents: 10 },
    ],
    evenementsParLieu: [
      { lieu: 'Atelier Production', total: 7 }, { lieu: 'Zone chargement', total: 6 },
      { lieu: 'Entrepôt', total: 5 }, { lieu: 'Atelier Maintenance', total: 5 }, { lieu: 'Chaufferie', total: 4 },
    ],
    registreEvenements: [
      { type: 'Incident', description: 'Fuite mineure de vapeur', lieu: 'Chaufferie', date: '2026-08-01', joursPerdus: 0, statut: 'Ouvert' },
      { type: 'Situation dangereuse', description: 'Câble électrique dénudé repéré', lieu: 'Atelier Maintenance', date: '2026-07-29', joursPerdus: 0, statut: 'Clôturé' },
      { type: "Presqu'accident", description: 'Chariot élévateur ayant frôlé un piéton', lieu: 'Zone chargement', date: '2026-07-24', joursPerdus: 0, statut: 'En cours' },
      { type: "Presqu'accident", description: 'Palette instable repérée à temps', lieu: 'Entrepôt', date: '2026-07-20', joursPerdus: 0, statut: 'Clôturé' },
      { type: 'Accident sans arrêt', description: 'Chute de plain-pied, sol glissant', lieu: 'Entrepôt', date: '2026-07-14', joursPerdus: 0, statut: 'Clôturé' },
    ],
    formationsRealisees: 34, formationsPlanifiees: 40,
    employes: [
      { nom: 'Ibrahima Sow', poste: 'Cariste', epiConforme: true, epiManquants: [], habilitation: 'CACES R489', dateExpiration: '2027-01-15' },
      { nom: 'Fatou Ba', poste: 'Opératrice ligne', epiConforme: true, epiManquants: [], habilitation: null, dateExpiration: null },
      { nom: 'Modou Cissé', poste: 'Agent maintenance', epiConforme: false, epiManquants: ['Gants isolants'], habilitation: 'Habilitation électrique B1V', dateExpiration: '2026-10-20' },
      { nom: 'Khady Fall', poste: 'Contrôleuse qualité', epiConforme: true, epiManquants: [], habilitation: null, dateExpiration: null },
      { nom: 'Moussa Ndiaye', poste: 'Cariste', epiConforme: true, epiManquants: [], habilitation: 'CACES R489', dateExpiration: '2026-08-01' },
      { nom: 'Aïcha Koné', poste: 'Agent chaufferie', epiConforme: false, epiManquants: ['Masque à gaz'], habilitation: 'Habilitation gaz', dateExpiration: '2027-06-10' },
      { nom: 'Yacouba Traoré', poste: 'Magasinier', epiConforme: true, epiManquants: [], habilitation: 'CACES R489', dateExpiration: '2028-02-01' },
      { nom: 'Aminata Diallo', poste: 'Technicienne labo', epiConforme: true, epiManquants: [], habilitation: null, dateExpiration: null },
    ],
  },
  hygiene: {
    visitesEnRetard: 2, aptitudesAvecReserves: 2, expositionsElevees: 1,
    controlesLocauxNonConformes: 1, mesuresAmbiantesHorsSeuil: 2,
    repartitionAptitudes: [{ label: 'Apte', valeur: 4 }, { label: 'Apte avec réserves', valeur: 2 }],
    prochainesVisites: [
      { nom: 'Modou Cissé', statut: 'En retard', jours: -15 }, { nom: 'Ibrahima Sow', statut: 'En retard', jours: -8 },
      { nom: 'Fatou Ba', statut: 'À venir', jours: 19 }, { nom: 'Khady Fall', statut: 'À venir', jours: 44 },
      { nom: 'Moussa Ndiaye', statut: 'À venir', jours: 319 },
    ],
  },
  environnement: {
    dechetsDangereuxKg: 850, tauxValorisation: 38, consommationElectriciteKwh: 38500, pointsNonConformes: 1,
    dechetsParType: [
      { type: 'Dangereux', kg: 850 }, { type: 'Non dangereux', kg: 3200 }, { type: 'Recyclés', kg: 1900 }, { type: 'Valorisés', kg: 600 },
    ],
    consommations: [
      { label: 'Eau', valeur: 420, unite: 'm³' }, { label: 'Électricité', valeur: 38500, unite: 'kWh' },
      { label: 'Carburant', valeur: 2100, unite: 'L' }, { label: 'Gaz', valeur: 850, unite: 'kg' },
    ],
    enregistrements: [
      { type: 'Dangereux', quantite: '850 kg', date: '2026-07-04', cout: 145000 },
      { type: 'Non dangereux', quantite: '3200 kg', date: '2026-07-04', cout: 80000 },
      { type: 'Recyclés', quantite: '1900 kg', date: '2026-07-04', cout: -45000 },
      { type: 'Valorisés', quantite: '600 kg', date: '2026-07-04', cout: -15000 },
    ],
    eau: {
      unite: 'm³', objectif: 400,
      historique: [
        { mois: 'Oct 25', valeur: 470 }, { mois: 'Nov 25', valeur: 455 }, { mois: 'Déc 25', valeur: 480 },
        { mois: 'Jan 26', valeur: 465 }, { mois: 'Fév 26', valeur: 450 }, { mois: 'Mar 26', valeur: 440 },
        { mois: 'Avr 26', valeur: 458 }, { mois: 'Mai 26', valeur: 435 }, { mois: 'Juin 26', valeur: 448 },
        { mois: 'Juil 26', valeur: 462 }, { mois: 'Août 26', valeur: 460 }, { mois: 'Sept 26', valeur: 420 },
      ],
    },
    electricite: {
      unite: 'kWh', objectif: 17000,
      historique: [
        { mois: 'Oct 25', valeur: 19800 }, { mois: 'Nov 25', valeur: 20100 }, { mois: 'Déc 25', valeur: 21500 },
        { mois: 'Jan 26', valeur: 21200 }, { mois: 'Fév 26', valeur: 19700 }, { mois: 'Mar 26', valeur: 19300 },
        { mois: 'Avr 26', valeur: 18900 }, { mois: 'Mai 26', valeur: 18400 }, { mois: 'Juin 26', valeur: 19100 },
        { mois: 'Juil 26', valeur: 19600 }, { mois: 'Août 26', valeur: 19200 }, { mois: 'Sept 26', valeur: 18500 },
      ],
    },
    papier: {
      unite: 'kg', objectif: 100,
      historique: [
        { mois: 'Oct 25', valeur: 165 }, { mois: 'Nov 25', valeur: 158 }, { mois: 'Déc 25', valeur: 170 },
        { mois: 'Jan 26', valeur: 152 }, { mois: 'Fév 26', valeur: 145 }, { mois: 'Mar 26', valeur: 140 },
        { mois: 'Avr 26', valeur: 138 }, { mois: 'Mai 26', valeur: 130 }, { mois: 'Juin 26', valeur: 128 },
        { mois: 'Juil 26', valeur: 135 }, { mois: 'Août 26', valeur: 150 }, { mois: 'Sept 26', valeur: 120 },
      ],
    },
  },
  risques: [
    { risque: 'Écrasement lors de manutention', cause: 'Circulation chariots/piétons non séparée', probabilite: 3, gravite: 4, responsable: 'Resp. Production', maitrise: 'Partiellement conforme' },
    { risque: 'Chute de hauteur en maintenance toiture', cause: 'Absence de ligne de vie fixe', probabilite: 2, gravite: 5, responsable: 'Resp. HSE', maitrise: 'Non conforme' },
    { risque: 'Incendie zone stockage produits', cause: 'Stockage inflammables non séparé', probabilite: 2, gravite: 5, responsable: 'Resp. HSE', maitrise: 'Partiellement conforme' },
    { risque: 'Exposition à des produits chimiques', cause: 'EPI respiratoires non systématiques', probabilite: 3, gravite: 3, responsable: 'Resp. Production', maitrise: 'Partiellement conforme' },
    { risque: 'Non-conformité produit livré client', cause: 'Contrôle final insuffisant', probabilite: 3, gravite: 3, responsable: 'Resp. Qualité', maitrise: 'Conforme' },
    { risque: 'Pollution des eaux par rejet non traité', cause: 'Défaillance station de traitement', probabilite: 2, gravite: 4, responsable: 'Resp. Environnement', maitrise: 'Partiellement conforme' },
    { risque: 'Chute de plain-pied, sol glissant', cause: 'Nettoyage sans signalisation', probabilite: 3, gravite: 2, responsable: 'Resp. Production', maitrise: 'Conforme' },
    { risque: 'Troubles musculosquelettiques', cause: 'Manutention manuelle répétitive', probabilite: 4, gravite: 2, responsable: 'Resp. HSE', maitrise: 'Sous surveillance' },
  ],
  audits: [
    { titre: 'Audit interne ISO 9001 — Production', type: 'Interne', date: '2026-07-10', statut: 'Terminé', resultat: '2 écarts mineurs' },
    { titre: 'Audit fournisseur — Verrerie Continentale', type: 'Fournisseur', date: '2026-07-15', statut: 'Terminé', resultat: 'Conforme' },
    { titre: 'Audit interne ISO 45001 — Sécurité', type: 'Interne', date: '2026-09-05', statut: 'Planifié', resultat: '—' },
    { titre: 'Audit de certification ISO 14001', type: 'Externe', date: '2026-10-20', statut: 'Planifié', resultat: '—' },
    { titre: 'Audit interne HACCP — Ligne conditionnement', type: 'Interne', date: '2026-08-22', statut: 'En cours', resultat: '—' },
  ],
  capa: [
    { action: 'Installer une ligne de vie sur la toiture', pilier: 'Sécurité', responsable: 'Resp. HSE', echeance: '2026-09-10', statut: 'En retard' },
    { action: 'Séparer le stockage des produits inflammables', pilier: 'Sécurité', responsable: 'Resp. HSE', echeance: '2026-09-25', statut: 'En cours' },
    { action: 'Renforcer le contrôle final avant expédition', pilier: 'Qualité', responsable: 'Resp. Qualité', echeance: '2026-09-05', statut: 'Terminée' },
    { action: 'Réviser la maintenance de la station de traitement', pilier: 'Environnement', responsable: 'Resp. Environnement', echeance: '2026-10-01', statut: 'En cours' },
    { action: 'Former les caristes à la circulation séparée', pilier: 'Sécurité', responsable: 'Resp. Production', echeance: '2026-09-30', statut: 'En retard' },
    { action: 'Planifier les visites médicales en retard', pilier: 'Hygiène', responsable: 'Resp. HSE', echeance: '2026-09-15', statut: 'En retard' },
    { action: 'Auditer les fournisseurs à risque matière', pilier: 'Qualité', responsable: 'Resp. Achats', echeance: '2026-10-15', statut: 'En cours' },
    { action: 'Mettre à jour le plan de circulation entrepôt', pilier: 'Sécurité', responsable: 'Resp. Production', echeance: '2026-08-20', statut: 'Terminée' },
  ],
  objectifs: [
    { titre: 'Zéro accident avec arrêt', pilier: 'Sécurité', cible: 0, actuel: 2, unite: '', echeance: '2026-12-31' },
    { titre: 'Taux de conformité qualité', pilier: 'Qualité', cible: 95, actuel: 92.4, unite: '%', echeance: '2026-12-31' },
    { titre: 'Taux de valorisation des déchets', pilier: 'Environnement', cible: 50, actuel: 38, unite: '%', echeance: '2026-12-31' },
    { titre: 'Visites médicales à jour', pilier: 'Hygiène', cible: 100, actuel: 92, unite: '%', echeance: '2026-12-31' },
  ],
  veilleReglementaire: [
    { texte: "Décret sur la gestion des déchets industriels dangereux", domaine: 'Environnement', dateApplication: '2026-11-01', statut: 'À traiter' },
    { texte: 'Mise à jour du Code du travail — durée maximale de port des EPI respiratoires', domaine: 'Sécurité', dateApplication: '2026-09-15', statut: 'En cours' },
    { texte: 'Norme HACCP boissons alcoolisées — révision des seuils de contrôle', domaine: 'Qualité', dateApplication: '2026-08-01', statut: 'Intégrée' },
    { texte: 'Arrêté sur les rejets aqueux industriels', domaine: 'Environnement', dateApplication: '2027-01-01', statut: 'À traiter' },
  ],
  documentation: [
    { titre: 'Manuel QHSE', type: 'Manuel', version: '3.2', dateMaj: '2026-06-01' },
    { titre: 'Procédure de gestion des non-conformités', type: 'Procédure', version: '2.1', dateMaj: '2026-07-12' },
    { titre: 'Plan HACCP — Boissons alcoolisées', type: 'Plan', version: '1.4', dateMaj: '2026-05-20' },
    { titre: 'DUERP — Document unique', type: 'Registre', version: '4.0', dateMaj: '2026-08-01' },
    { titre: "Politique QHSE, objectifs, organigramme", type: 'Politique', version: '2.0', dateMaj: '2026-01-15' },
  ],
};

const PERIODE_PRECEDENTE = { tauxConformite: 90.1, tf: 4.2, capaTauxRealisation: 58 };

// ============================================================================
// Logique d'agrégation — formules normées du domaine QHSE (TF/TG suivent la
// convention ILO/OSHA), jamais de valeur inventée dans l'UI elle-même.
// ============================================================================
function computeTF(d) { return (d.securite.accidentsAvecArret * 1000000) / d.heuresTravaillees; }
function computeTG(d) { return (d.securite.joursPerdus * 1000) / d.heuresTravaillees; }
function computeCapaStats(d) {
  const total = d.capa.length;
  const terminees = d.capa.filter((a) => a.statut === 'Terminée').length;
  const enCours = d.capa.filter((a) => a.statut === 'En cours').length;
  const enRetard = d.capa.filter((a) => a.statut === 'En retard').length;
  return { total, terminees, enCours, enRetard, tauxRealisation: total ? Math.round((terminees / total) * 100) : 0 };
}
function lastValue(historique) { return historique[historique.length - 1].valeur; }
function prevValue(historique) { return historique[historique.length - 2].valeur; }
function computeAnnualTrend(historique) {
  const first = historique[0].valeur, last = lastValue(historique);
  return Math.round(((last - first) / first) * 1000) / 10;
}
function computeEnvironnementScore(d) {
  const items = [d.environnement.eau, d.environnement.electricite, d.environnement.papier];
  const scores = items.map((i) => {
    const ecart = (lastValue(i.historique) - i.objectif) / i.objectif;
    return Math.max(0, Math.min(100, 100 - ecart * 100));
  });
  return Math.round(scores.reduce((a, b) => a + b, 0) / scores.length);
}
function computeHabilitationStatut(dateExpiration, aujourdHui) {
  if (!dateExpiration) return null;
  const joursRestants = Math.round((new Date(dateExpiration) - aujourdHui) / (1000 * 60 * 60 * 24));
  if (joursRestants < 0) return { statut: 'Expirée', joursRestants };
  if (joursRestants <= 60) return { statut: 'Expire bientôt', joursRestants };
  return { statut: 'Valide', joursRestants };
}
const AUJOURD_HUI = new Date('2026-09-30');
function computeEpiStats(d) {
  const employes = d.securite.employes;
  const conformes = employes.filter((e) => e.epiConforme).length;
  const habilites = employes.filter((e) => e.habilitation);
  const parStatut = { Valide: 0, 'Expire bientôt': 0, Expirée: 0 };
  habilites.forEach((e) => { const h = computeHabilitationStatut(e.dateExpiration, AUJOURD_HUI); if (h) parStatut[h.statut]++; });
  return {
    tauxPortEpi: employes.length ? Math.round((conformes / employes.length) * 100) : 0,
    nonConformes: employes.length - conformes,
    habilitationsValides: parStatut.Valide, habilitationsBientotExpirees: parStatut['Expire bientôt'], habilitationsExpirees: parStatut.Expirée,
  };
}
function computeCompositeIndex(d) {
  const qualite = d.qualite.tauxConformite;
  const securite = Math.max(0, Math.round(100 - computeTF(d) * 8));
  const hygiene = Math.max(0, 100 - (d.hygiene.visitesEnRetard + d.hygiene.aptitudesAvecReserves + d.hygiene.expositionsElevees + d.hygiene.controlesLocauxNonConformes + d.hygiene.mesuresAmbiantesHorsSeuil) * 6);
  const environnement = computeEnvironnementScore(d);
  const w = { qualite: 0.3, securite: 0.3, hygiene: 0.2, environnement: 0.2 };
  return Math.round(qualite * w.qualite + securite * w.securite + hygiene * w.hygiene + environnement * w.environnement);
}
function computeParetoData(causes) {
  const sorted = [...causes].sort((a, b) => b.occurrences - a.occurrences);
  const total = sorted.reduce((s, c) => s + c.occurrences, 0);
  let cumul = 0;
  return sorted.map((c) => { cumul += c.occurrences; return { ...c, cumulPct: total ? Math.round((cumul / total) * 1000) / 10 : 0 }; });
}
function paretoSeuil80(paretoData) {
  const idx = paretoData.findIndex((c) => c.cumulPct >= 80);
  return idx === -1 ? paretoData.length : idx + 1;
}
function computeAuditStats(d) {
  const total = d.audits.length;
  const termines = d.audits.filter((a) => a.statut === 'Terminé').length;
  const planifies = d.audits.filter((a) => a.statut === 'Planifié').length;
  return { total, termines, planifies, tauxRealisation: total ? Math.round((termines / total) * 100) : 0 };
}

// ============================================================================
// Composants UI réutilisables (thème via Contexte)
// ============================================================================
function KpiCard({ label, value, objectif, color, icon: Icon }) {
  const C = useTheme();
  return (
    <div className="rounded-xl p-4 flex-1 min-w-[150px]" style={{ backgroundColor: `${color}1A`, border: `1px solid ${color}40` }}>
      <div className="flex items-center justify-between mb-2">
        <span className="text-xs uppercase tracking-wide" style={{ color }}>{label}</span>
        {Icon && <Icon size={16} color={color} />}
      </div>
      <div className="text-3xl font-semibold" style={{ color: C.text }}>{value}</div>
      {objectif && <div className="text-xs mt-1" style={{ color: C.textMuted }}>{objectif}</div>}
    </div>
  );
}
function Panel({ title, subtitle, children, className = '', right = null, onClick }) {
  const C = useTheme();
  return (
    <div className={`rounded-xl p-5 ${className}`} style={{ backgroundColor: C.card, border: `1px solid ${C.border}` }} onClick={onClick}>
      {(title || right) && (
        <div className="flex items-start justify-between mb-1">
          <div>
            {title && <h3 className="text-sm font-semibold" style={{ color: C.text }}>{title}</h3>}
            {subtitle && <p className="text-xs" style={{ color: C.textMuted }}>{subtitle}</p>}
          </div>
          {right}
        </div>
      )}
      <div className={title || right ? 'mt-3' : ''}>{children}</div>
    </div>
  );
}
function StatusChip({ statut }) {
  const C = useTheme();
  const map = {
    Terminée: C.green, Terminé: C.green, 'En cours': C.blue, 'En retard': C.red, Ouvert: C.red, Clôturé: C.green, Planifié: C.blue,
    Conforme: C.green, 'Partiellement conforme': C.amber, 'Non conforme': C.red, 'Sous surveillance': C.blue,
    Homologué: C.green, 'À traiter': C.red, Intégrée: C.green, Valide: C.green, 'Expire bientôt': C.amber, Expirée: C.red,
    OPEN: C.red, CLOSED: C.green, ACTIVE: C.amber, PLANNED: C.blue,
  };
  const color = map[statut] || C.textMuted;
  return <span className="text-xs px-2 py-1 rounded-md font-medium" style={{ backgroundColor: `${color}22`, color }}>{statut}</span>;
}
function DonutChart({ data, colors }) {
  const C = useTheme();
  return (
    <ResponsiveContainer width="100%" height={220}>
      <PieChart>
        <Pie data={data} dataKey="value" nameKey="name" innerRadius={55} outerRadius={85} paddingAngle={2}>
          {data.map((entry, i) => <Cell key={i} fill={colors[i % colors.length]} stroke={C.card} strokeWidth={2} />)}
        </Pie>
        <Tooltip contentStyle={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, borderRadius: 8, color: C.text }} />
      </PieChart>
    </ResponsiveContainer>
  );
}
function HorizontalBars({ data, labelKey, valueKey, color }) {
  const C = useTheme();
  const max = Math.max(...data.map((d) => d[valueKey]), 1);
  return (
    <div className="space-y-3">
      {data.map((row, i) => (
        <div key={i}>
          <div className="flex justify-between text-xs mb-1" style={{ color: C.textMuted }}>
            <span>{row[labelKey]}</span><span style={{ color: C.text }}>{row[valueKey]}</span>
          </div>
          <div className="h-2 rounded-full" style={{ backgroundColor: C.border }}>
            <div className="h-2 rounded-full" style={{ width: `${(row[valueKey] / max) * 100}%`, backgroundColor: color }} />
          </div>
        </div>
      ))}
    </div>
  );
}
function ParetoChart({ causes }) {
  const C = useTheme();
  const data = computeParetoData(causes);
  const nb80 = paretoSeuil80(data);
  return (
    <div>
      <ResponsiveContainer width="100%" height={260}>
        <ComposedChart data={data} margin={{ left: 0, right: 8 }}>
          <CartesianGrid stroke={C.border} strokeDasharray="3 3" />
          <XAxis dataKey="cause" stroke={C.textMuted} fontSize={10} angle={-20} textAnchor="end" height={60} interval={0} />
          <YAxis yAxisId="left" stroke={C.textMuted} fontSize={12} label={{ value: 'Occurrences', angle: -90, position: 'insideLeft', fill: C.textMuted, fontSize: 11 }} />
          <YAxis yAxisId="right" orientation="right" domain={[0, 100]} stroke={C.textMuted} fontSize={12} label={{ value: '% cumulé', angle: 90, position: 'insideRight', fill: C.textMuted, fontSize: 11 }} />
          <Tooltip contentStyle={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, borderRadius: 8, color: C.text }} formatter={(value, name) => (name === '% cumulé' ? [`${value}%`, name] : [value, 'Occurrences'])} />
          <ReferenceLine yAxisId="right" y={80} stroke={C.amber} strokeDasharray="4 4" label={{ value: 'Seuil 80%', position: 'insideTopLeft', fill: C.amber, fontSize: 11 }} />
          <Bar yAxisId="left" dataKey="occurrences" fill={C.red} radius={[4, 4, 0, 0]} name="Occurrences" />
          <Line yAxisId="right" type="monotone" dataKey="cumulPct" stroke={C.blue} strokeWidth={2} dot={{ r: 4 }} name="% cumulé" />
        </ComposedChart>
      </ResponsiveContainer>
      <p className="text-xs mt-2" style={{ color: C.textMuted }}>{nb80} cause(s) sur {data.length} concentrent 80% des non-conformités.</p>
    </div>
  );
}
function ResourceTrendChart({ label, unite, historique, objectif, color }) {
  const C = useTheme();
  const trend = computeAnnualTrend(historique);
  return (
    <div>
      <div className="flex items-baseline justify-between mb-2">
        <span className="text-sm font-medium" style={{ color: C.text }}>{label}</span>
        <span className="text-xs" style={{ color: trend <= 0 ? C.green : C.red }}>{trend <= 0 ? '▼' : '▲'} {Math.abs(trend)}% sur 12 mois</span>
      </div>
      <ResponsiveContainer width="100%" height={160}>
        <LineChart data={historique} margin={{ left: -10 }}>
          <CartesianGrid stroke={C.border} strokeDasharray="3 3" />
          <XAxis dataKey="mois" stroke={C.textMuted} fontSize={10} interval={1} />
          <YAxis stroke={C.textMuted} fontSize={11} width={45} />
          <Tooltip contentStyle={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, borderRadius: 8, color: C.text }} formatter={(value) => [`${value} ${unite}`, label]} />
          <ReferenceLine y={objectif} stroke={C.green} strokeDasharray="4 4" label={{ value: 'Objectif', position: 'insideTopRight', fill: C.green, fontSize: 10 }} />
          <Line type="monotone" dataKey="valeur" stroke={color} strokeWidth={2} dot={{ r: 3 }} name={label} />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
function RiskMatrix5x5({ risques }) {
  const C = useTheme();
  const counts = {};
  risques.forEach((r) => { const key = `${r.gravite}-${r.probabilite}`; counts[key] = (counts[key] || 0) + 1; });
  function cellColor(score) {
    if (score >= 15) return C.red;
    if (score >= 8) return C.amber;
    if (score >= 4) return '#B45309';
    return C.green;
  }
  const rows = [5, 4, 3, 2, 1], cols = [1, 2, 3, 4, 5];
  return (
    <div>
      <div className="flex">
        <div className="w-6" />
        <div className="flex-1 grid grid-cols-5 gap-1">
          {rows.map((g) => cols.map((p) => {
            const score = g * p, count = counts[`${g}-${p}`];
            return (
              <div key={`${g}-${p}`} className="aspect-square rounded flex items-center justify-center text-xs font-semibold"
                style={{ backgroundColor: cellColor(score), color: score >= 4 ? '#1F2937' : '#064E3B', opacity: count ? 1 : 0.35 }}
                title={`Gravité ${g} × Probabilité ${p} = ${score}`}>
                {count || ''}
              </div>
            );
          }))}
        </div>
      </div>
      <div className="flex justify-between text-[11px] mt-2 px-6" style={{ color: C.textMuted }}><span>Probabilité 1</span><span>Probabilité 5</span></div>
    </div>
  );
}
function DataTable({ columns, rows, onRowClick }) {
  const C = useTheme();
  return (
    <table className="w-full text-sm">
      <thead>
        <tr style={{ color: C.textMuted }}>{columns.map((c, i) => <th key={i} className="text-left font-normal pb-2">{c}</th>)}</tr>
      </thead>
      <tbody>
        {rows.map((row, i) => (
          <tr key={i} style={{ borderTop: `1px solid ${C.border}`, cursor: onRowClick ? 'pointer' : 'default' }} onClick={onRowClick ? () => onRowClick(i) : undefined}>
            {row.map((cell, j) => <td key={j} className="py-2" style={{ color: C.text }}>{cell}</td>)}
          </tr>
        ))}
      </tbody>
    </table>
  );
}

// ============================================================================
// Connexion aux données réelles de votre API (au lieu des données de
// démonstration). Chaque page connectable appelle useCollection(chemin) ;
// les champs renvoyés par l'API (ex. Risk.hazard, Action.status='CLOSED')
// sont adaptés ici, honnêtement, plutôt que de prétendre qu'ils
// correspondent exactement à la maquette d'origine.
// ============================================================================
function useCollection(path) {
  const [state, setState] = useState({ data: null, loading: !!path, error: null });
  const [tick, setTick] = useState(0);
  useEffect(() => {
    if (!path) { setState({ data: null, loading: false, error: null }); return; }
    let cancelled = false;
    setState((s) => ({ ...s, loading: true, error: null }));
    api.get(path).then((data) => { if (!cancelled) setState({ data, loading: false, error: null }); })
      .catch((err) => { if (!cancelled) setState({ data: null, loading: false, error: err.message }); });
    return () => { cancelled = true; };
  }, [path, tick]);
  return { ...state, reload: () => setTick((t) => t + 1) };
}
// Petite fenêtre modale réutilisable pour les formulaires de création.
function Modal({ title, onClose, children, wide = false }) {
  const C = useTheme();
  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-4" style={{ backgroundColor: 'rgba(0,0,0,0.6)' }} onClick={onClose}>
      <div className={`w-full ${wide ? 'max-w-2xl max-h-[85vh] overflow-y-auto' : 'max-w-md'} rounded-xl p-5`} style={{ backgroundColor: C.card, border: `1px solid ${C.border}` }} onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-sm font-semibold" style={{ color: C.text }}>{title}</h3>
          <button onClick={onClose}><X size={16} color={C.textMuted} /></button>
        </div>
        {children}
      </div>
    </div>
  );
}
function FormField({ label, children }) {
  const C = useTheme();
  return (
    <div className="mb-3">
      <label className="block text-xs mb-1" style={{ color: C.textMuted }}>{label}</label>
      {children}
    </div>
  );
}
function inputStyle(C) { return { backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, color: C.text }; }
// Les 5 tables ci-dessous exigent un champ `code` unique côté base — générer
// automatiquement plutôt que de demander à l'utilisateur d'y penser.
function genCode(prefix) { return `${prefix}-${Date.now().toString().slice(-8)}`; }
async function confirmAndDelete(label, endpoint, onDone) {
  if (!window.confirm(`Supprimer définitivement « ${label} » ? Cette action est irréversible.`)) return;
  await api.del(endpoint);
  onDone();
}

function RiskForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ hazard: record?.hazard || '', activity: record?.activity || '', severity: record?.severity || 3, probability: record?.probability || 3, measures: record?.measures || '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault();
    setSaving(true); setError(null);
    try {
      const payload = { ...form, severity: Number(form.severity), probability: Number(form.probability) };
      if (editing) await api.patch(`/business/risks/${record.id}`, payload);
      else await api.post('/business/risks', { code: genCode('RISK'), ...payload, status: 'ACTIVE' });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.hazard, `/business/risks/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier le risque' : 'Nouveau risque'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Danger identifié"><input required value={form.hazard} onChange={(e) => setForm({ ...form, hazard: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Chute de hauteur" /></FormField>
        <FormField label="Activité / mesures existantes"><input value={form.activity} onChange={(e) => setForm({ ...form, activity: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Probabilité (1-5)"><select value={form.probability} onChange={(e) => setForm({ ...form, probability: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>{[1, 2, 3, 4, 5].map((n) => <option key={n} value={n}>{n}</option>)}</select></FormField>
          <FormField label="Gravité (1-5)"><select value={form.severity} onChange={(e) => setForm({ ...form, severity: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>{[1, 2, 3, 4, 5].map((n) => <option key={n} value={n}>{n}</option>)}</select></FormField>
        </div>
        <FormField label="Mesures de maîtrise"><textarea value={form.measures} onChange={(e) => setForm({ ...form, measures: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function AuditForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ title: record?.title || '', reference: record?.reference || '', auditDate: record ? new Date(record.auditDate).toISOString().slice(0, 10) : new Date().toISOString().slice(0, 10), status: record?.status || 'PLANNED', score: record?.score ?? '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault();
    setSaving(true); setError(null);
    try {
      const payload = { ...form, auditDate: new Date(form.auditDate).toISOString(), score: form.score === '' ? null : Number(form.score) };
      if (editing) await api.patch(`/business/audits/${record.id}`, payload);
      else await api.post('/business/audits', { code: genCode('AUD'), ...payload });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? "Modifier l'audit" : 'Planifier un audit'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Titre"><input required value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Audit interne ISO 9001 — Production" /></FormField>
        <FormField label="Référence (optionnel)"><input value={form.reference} onChange={(e) => setForm({ ...form, reference: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Date"><input required type="date" value={form.auditDate} onChange={(e) => setForm({ ...form, auditDate: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          {editing && <FormField label="Statut"><select value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="PLANNED">PLANNED</option><option value="IN_PROGRESS">IN_PROGRESS</option><option value="COMPLETED">COMPLETED</option></select></FormField>}
        </div>
        {editing && <FormField label="Score (%, optionnel)"><input type="number" min="0" max="100" value={form.score} onChange={(e) => setForm({ ...form, score: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>}
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <button type="submit" disabled={saving} className="w-full py-2.5 rounded-lg text-sm font-medium mt-1" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Planifier'}</button>
      </form>
    </Modal>
  );
}

function NonConformityForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ title: record?.title || '', description: record?.description || '', source: record?.source || '', severity: record?.severity || 2, occurredAt: record ? new Date(record.occurredAt).toISOString().slice(0, 10) : new Date().toISOString().slice(0, 10), status: record?.status || 'OPEN' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault();
    setSaving(true); setError(null);
    try {
      const payload = { ...form, severity: Number(form.severity), occurredAt: new Date(form.occurredAt).toISOString() };
      if (editing) await api.patch(`/business/non-conformities/${record.id}`, payload);
      else await api.post('/business/non-conformities', { code: genCode('NC'), ...payload });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.title, `/business/non-conformities/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier la non-conformité' : 'Déclarer une non-conformité'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Titre"><input required value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Description"><textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        <FormField label="Source"><input value={form.source} onChange={(e) => setForm({ ...form, source: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Contrôle qualité, réclamation client..." /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Date"><input required type="date" value={form.occurredAt} onChange={(e) => setForm({ ...form, occurredAt: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Sévérité (1-5)"><select value={form.severity} onChange={(e) => setForm({ ...form, severity: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>{[1, 2, 3, 4, 5].map((n) => <option key={n} value={n}>{n}</option>)}</select></FormField>
        </div>
        {editing && <FormField label="Statut"><select value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="OPEN">OPEN</option><option value="CLOSED">CLOSED</option></select></FormField>}
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function ActionForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ title: record?.title || '', description: record?.description || '', priority: record?.priority || 2, dueDate: record?.dueDate ? new Date(record.dueDate).toISOString().slice(0, 10) : '', status: record?.status || 'OPEN' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault();
    setSaving(true); setError(null);
    try {
      const payload = { ...form, priority: Number(form.priority), dueDate: form.dueDate ? new Date(form.dueDate).toISOString() : null };
      if (editing) await api.patch(`/business/actions/${record.id}`, payload);
      else await api.post('/business/actions', { code: genCode('ACT'), ...payload });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.title, `/business/actions/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? "Modifier l'action" : 'Nouvelle action corrective'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Action"><input required value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Description"><textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Priorité (1=haute, 3=basse)"><select value={form.priority} onChange={(e) => setForm({ ...form, priority: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>{[1, 2, 3].map((n) => <option key={n} value={n}>{n}</option>)}</select></FormField>
          <FormField label="Échéance"><input type="date" value={form.dueDate} onChange={(e) => setForm({ ...form, dueDate: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        {editing && <FormField label="Statut"><select value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="OPEN">OPEN</option><option value="CLOSED">CLOSED</option></select></FormField>}
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function EnvironmentForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ type: record?.type || '', value: record?.value ?? '', unit: record?.unit || '', site: record?.site || '', notes: record?.notes || '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault();
    setSaving(true); setError(null);
    try {
      const payload = { ...form, value: form.value !== '' ? Number(form.value) : null };
      if (editing) await api.patch(`/business/environment/${record.id}`, payload);
      else await api.post('/business/environment', { code: genCode('ENV'), ...payload, recordedAt: new Date().toISOString() });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.type, `/business/environment/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier le relevé' : 'Nouveau relevé environnemental'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Type de relevé"><input required value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Eau, Électricité, Déchets dangereux..." /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Valeur"><input type="number" step="any" value={form.value} onChange={(e) => setForm({ ...form, value: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Unité"><input value={form.unit} onChange={(e) => setForm({ ...form, unit: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="m³, kWh, kg..." /></FormField>
        </div>
        <FormField label="Site"><input value={form.site} onChange={(e) => setForm({ ...form, site: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Notes"><textarea value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}
function ProcessusForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ nom: record?.nom || '', proprietaire: record?.proprietaire || '', objectifs: record?.objectifs || '', kpi: record?.kpi || '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      if (editing) await api.patch(`/business/processus/${record.id}`, form);
      else await api.post('/business/processus', { code: genCode('PROC'), ...form });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.nom, `/business/processus/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier le processus' : 'Nouveau processus'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Nom du processus"><input required value={form.nom} onChange={(e) => setForm({ ...form, nom: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Propriétaire"><input value={form.proprietaire} onChange={(e) => setForm({ ...form, proprietaire: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Objectifs"><input value={form.objectifs} onChange={(e) => setForm({ ...form, objectifs: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="KPI"><input value={form.kpi} onChange={(e) => setForm({ ...form, kpi: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function IndicateurForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ indicateur: record?.indicateur || '', actuel: record?.actuel ?? '', cible: record?.cible ?? '', unite: record?.unite || '', sensInverse: record?.sensInverse || false });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      if (editing) await api.patch(`/business/indicateurs-qualite/${record.id}`, form);
      else await api.post('/business/indicateurs-qualite', { code: genCode('IND'), ...form });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.indicateur, `/business/indicateurs-qualite/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? "Modifier l'indicateur" : 'Nouvel indicateur qualité'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Indicateur"><input required value={form.indicateur} onChange={(e) => setForm({ ...form, indicateur: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Taux de rebut production" /></FormField>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Actuel"><input required type="number" step="any" value={form.actuel} onChange={(e) => setForm({ ...form, actuel: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Cible"><input required type="number" step="any" value={form.cible} onChange={(e) => setForm({ ...form, cible: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Unité"><input value={form.unite} onChange={(e) => setForm({ ...form, unite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="%" /></FormField>
        </div>
        <label className="flex items-center gap-2 text-xs mb-3" style={{ color: C.textMuted }}>
          <input type="checkbox" checked={form.sensInverse} onChange={(e) => setForm({ ...form, sensInverse: e.target.checked })} />
          Sens inverse (atteint quand actuel ≤ cible, ex. taux de rebut)
        </label>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function ReclamationForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ client: record?.client || '', motif: record?.motif || '', description: record?.description || '', date: record ? new Date(record.date).toISOString().slice(0, 10) : new Date().toISOString().slice(0, 10), gravite: record?.gravite || 'Faible', statut: record?.statut || 'OPEN' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, date: new Date(form.date).toISOString() };
      if (editing) await api.patch(`/business/reclamations/${record.id}`, payload);
      else await api.post('/business/reclamations', { code: genCode('REC'), ...payload });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.client, `/business/reclamations/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier la réclamation' : 'Nouvelle réclamation client'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Client"><input required value={form.client} onChange={(e) => setForm({ ...form, client: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Motif"><input required value={form.motif} onChange={(e) => setForm({ ...form, motif: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Description"><textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Date"><input required type="date" value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Gravité"><select value={form.gravite} onChange={(e) => setForm({ ...form, gravite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option>Faible</option><option>Modérée</option><option>Élevée</option></select></FormField>
          {editing && <FormField label="Statut"><select value={form.statut} onChange={(e) => setForm({ ...form, statut: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="OPEN">OPEN</option><option value="CLOSED">CLOSED</option></select></FormField>}
        </div>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function FournisseurForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ nom: record?.nom || '', categorie: record?.categorie || '', scoreQualite: record?.scoreQualite ?? '', derniereEvaluation: record?.derniereEvaluation ? new Date(record.derniereEvaluation).toISOString().slice(0, 10) : '', statut: record?.statut || 'HOMOLOGUE' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, scoreQualite: form.scoreQualite !== '' ? Number(form.scoreQualite) : null, derniereEvaluation: form.derniereEvaluation ? new Date(form.derniereEvaluation).toISOString() : null };
      if (editing) await api.patch(`/business/fournisseurs/${record.id}`, payload);
      else await api.post('/business/fournisseurs', { code: genCode('FOUR'), ...payload });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.nom, `/business/fournisseurs/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier le fournisseur' : 'Nouveau fournisseur'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Nom"><input required value={form.nom} onChange={(e) => setForm({ ...form, nom: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Catégorie"><input value={form.categorie} onChange={(e) => setForm({ ...form, categorie: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Score qualité (0-100)"><input type="number" min="0" max="100" value={form.scoreQualite} onChange={(e) => setForm({ ...form, scoreQualite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Dernière évaluation"><input type="date" value={form.derniereEvaluation} onChange={(e) => setForm({ ...form, derniereEvaluation: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Statut"><select value={form.statut} onChange={(e) => setForm({ ...form, statut: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="HOMOLOGUE">Homologué</option><option value="SOUS_SURVEILLANCE">Sous surveillance</option><option value="PLAN_ACTION_REQUIS">Plan d'action requis</option></select></FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function VisiteMedicaleForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ employeNom: record?.employeNom || '', poste: record?.poste || '', aptitude: record?.aptitude || '', statut: record?.statut || 'A_VENIR', prochaineVisite: record?.prochaineVisite ? new Date(record.prochaineVisite).toISOString().slice(0, 10) : '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, prochaineVisite: form.prochaineVisite ? new Date(form.prochaineVisite).toISOString() : null };
      if (editing) await api.patch(`/business/visites-medicales/${record.id}`, payload);
      else await api.post('/business/visites-medicales', { code: genCode('VM'), ...payload });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.employeNom, `/business/visites-medicales/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier la visite médicale' : 'Nouvelle visite médicale'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Employé"><input required value={form.employeNom} onChange={(e) => setForm({ ...form, employeNom: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Poste"><input value={form.poste} onChange={(e) => setForm({ ...form, poste: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Aptitude"><select value={form.aptitude} onChange={(e) => setForm({ ...form, aptitude: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="">—</option><option value="Apte">Apte</option><option value="Apte avec réserves">Apte avec réserves</option><option value="Inapte">Inapte</option></select></FormField>
          <FormField label="Prochaine visite"><input type="date" value={form.prochaineVisite} onChange={(e) => setForm({ ...form, prochaineVisite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function VeilleForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ texte: record?.texte || '', domaine: record?.domaine || '', dateApplication: record?.dateApplication ? new Date(record.dateApplication).toISOString().slice(0, 10) : '', statut: record?.statut || 'A_TRAITER' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, dateApplication: form.dateApplication ? new Date(form.dateApplication).toISOString() : null };
      if (editing) await api.patch(`/business/veille-reglementaire/${record.id}`, payload);
      else await api.post('/business/veille-reglementaire', { code: genCode('VEI'), ...payload });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.texte.slice(0, 30), `/business/veille-reglementaire/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier le texte réglementaire' : 'Nouveau texte réglementaire'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Texte"><textarea required value={form.texte} onChange={(e) => setForm({ ...form, texte: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Domaine"><input value={form.domaine} onChange={(e) => setForm({ ...form, domaine: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Qualité, Sécurité, Environnement..." /></FormField>
          <FormField label="Date d'application"><input type="date" value={form.dateApplication} onChange={(e) => setForm({ ...form, dateApplication: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Statut"><select value={form.statut} onChange={(e) => setForm({ ...form, statut: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="A_TRAITER">À traiter</option><option value="EN_COURS">En cours</option><option value="INTEGREE">Intégrée</option></select></FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function ObjectifForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ titre: record?.titre || '', pilier: record?.pilier || '', cible: record?.cible ?? '', actuel: record?.actuel ?? 0, unite: record?.unite || '', echeance: record?.echeance ? new Date(record.echeance).toISOString().slice(0, 10) : '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, echeance: form.echeance ? new Date(form.echeance).toISOString() : null };
      if (editing) await api.patch(`/business/objectifs-qhse/${record.id}`, payload);
      else await api.post('/business/objectifs-qhse', { code: genCode('OBJ'), ...payload });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.titre, `/business/objectifs-qhse/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? "Modifier l'objectif" : 'Nouvel objectif QHSE'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Titre"><input required value={form.titre} onChange={(e) => setForm({ ...form, titre: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Pilier"><select value={form.pilier} onChange={(e) => setForm({ ...form, pilier: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="">—</option><option>Qualité</option><option>Sécurité</option><option>Hygiène</option><option>Environnement</option></select></FormField>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Cible"><input required type="number" step="any" value={form.cible} onChange={(e) => setForm({ ...form, cible: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Actuel"><input type="number" step="any" value={form.actuel} onChange={(e) => setForm({ ...form, actuel: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Unité"><input value={form.unite} onChange={(e) => setForm({ ...form, unite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="%" /></FormField>
        </div>
        <FormField label="Échéance"><input type="date" value={form.echeance} onChange={(e) => setForm({ ...form, echeance: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function CategoryForm({ record, endpoint, label, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [name, setName] = useState(record?.name || '');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      if (editing) await api.patch(`${endpoint}/${record.id}`, { name });
      else await api.post(endpoint, { name });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(name, `${endpoint}/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? `Modifier la catégorie ${label}` : `Nouvelle catégorie ${label}`} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Nom de la catégorie"><input required value={name} onChange={(e) => setName(e.target.value)} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function EpcForm({ record, categories, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({
    code: record?.code || '', name: record?.name || '', categoryId: record?.categoryId || '', location: record?.location || '', zone: record?.zone || '',
    description: record?.description || '', manufacturer: record?.manufacturer || '', model: record?.model || '', reference: record?.reference || '',
    installedAt: record?.installedAt ? new Date(record.installedAt).toISOString().slice(0, 10) : '', condition: record?.condition || '', status: record?.status || 'ACTIVE',
    inspectionFrequencyDays: record?.inspectionFrequencyDays ?? '', notes: record?.notes || '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, categoryId: form.categoryId || null, installedAt: form.installedAt ? new Date(form.installedAt).toISOString() : null, inspectionFrequencyDays: form.inspectionFrequencyDays !== '' ? Number(form.inspectionFrequencyDays) : null };
      if (editing) await api.patch(`/epi/epc/${record.id}`, payload);
      else await api.post('/epi/epc', payload);
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.name, `/epi/epc/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? "Modifier l'EPC" : 'Nouvel équipement de protection collective'} onClose={onClose} wide>
      <form onSubmit={submit}>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Code"><input required value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Désignation"><input required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Garde-corps ligne 1" /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Catégorie">
            <select value={form.categoryId} onChange={(e) => setForm({ ...form, categoryId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>{(categories || []).map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
          </FormField>
          <div className="grid grid-cols-2 gap-3">
            <FormField label="Localisation"><input value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
            <FormField label="Zone"><input value={form.zone} onChange={(e) => setForm({ ...form, zone: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          </div>
        </div>
        <FormField label="Description"><textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Fabricant"><input value={form.manufacturer} onChange={(e) => setForm({ ...form, manufacturer: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Modèle"><input value={form.model} onChange={(e) => setForm({ ...form, model: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Référence"><input value={form.reference} onChange={(e) => setForm({ ...form, reference: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Date d'installation"><input type="date" value={form.installedAt} onChange={(e) => setForm({ ...form, installedAt: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Fréquence d'inspection (jours)"><input type="number" value={form.inspectionFrequencyDays} onChange={(e) => setForm({ ...form, inspectionFrequencyDays: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="État"><input value={form.condition} onChange={(e) => setForm({ ...form, condition: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Statut"><select value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="ACTIVE">Actif</option><option value="MAINTENANCE">En maintenance</option><option value="NON_CONFORME">Non conforme</option><option value="HORS_SERVICE">Hors service</option></select></FormField>
        <FormField label="Observations"><textarea value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function EpiInspectionForm({ epiOptions, onClose, onCreated }) {
  const C = useTheme();
  const [form, setForm] = useState({ epiId: '', result: 'CONFORME', observations: '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      await api.post('/epi/epi-inspections', form);
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title="Nouvelle inspection EPI" onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="EPI inspecté">
          <select required value={form.epiId} onChange={(e) => setForm({ ...form, epiId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">Sélectionner…</option>{(epiOptions || []).map((e) => <option key={e.id} value={e.id}>{e.name}</option>)}
          </select>
        </FormField>
        <FormField label="Résultat">
          <select value={form.result} onChange={(e) => setForm({ ...form, result: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="CONFORME">Conforme</option><option value="NON_CONFORME">Non conforme</option><option value="A_SURVEILLER">À surveiller</option><option value="A_REFORMER">À réformer</option>
          </select>
        </FormField>
        <FormField label="Observations"><textarea value={form.observations} onChange={(e) => setForm({ ...form, observations: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <button type="submit" disabled={saving} className="w-full py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : 'Enregistrer'}</button>
      </form>
    </Modal>
  );
}

function EpcInspectionForm({ epcOptions, onClose, onCreated }) {
  const C = useTheme();
  const [form, setForm] = useState({ epcId: '', result: 'CONFORME', observations: '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      await api.post('/epi/epc-inspections', { ...form, nextInspectionAt: null });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title="Nouvelle inspection EPC" onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="EPC inspecté">
          <select required value={form.epcId} onChange={(e) => setForm({ ...form, epcId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">Sélectionner…</option>{(epcOptions || []).map((e) => <option key={e.id} value={e.id}>{e.name}</option>)}
          </select>
        </FormField>
        <FormField label="Résultat">
          <select value={form.result} onChange={(e) => setForm({ ...form, result: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="CONFORME">Conforme</option><option value="NON_CONFORME">Non conforme</option><option value="A_SURVEILLER">À surveiller</option><option value="A_REFORMER">À réformer</option>
          </select>
        </FormField>
        <FormField label="Observations"><textarea value={form.observations} onChange={(e) => setForm({ ...form, observations: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <button type="submit" disabled={saving} className="w-full py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : 'Enregistrer'}</button>
      </form>
    </Modal>
  );
}

function JobRiskProtectionForm({ record, epiOptions, epcOptions, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ jobTitle: record?.jobTitle || '', activity: record?.activity || '', hazard: record?.hazard || '', riskDescription: record?.riskDescription || '', preventionMeasure: record?.preventionMeasure || '', epiId: record?.epiId || '', epcId: record?.epcId || '', usageFrequency: record?.usageFrequency || '', controlCriteria: record?.controlCriteria || '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, epiId: form.epiId || null, epcId: form.epcId || null };
      if (editing) await api.patch(`/epi/job-risk-protection/${record.id}`, payload);
      else await api.post('/epi/job-risk-protection', { code: genCode('JRP'), ...payload });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.jobTitle, `/epi/job-risk-protection/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier la ligne de matrice' : 'Nouvelle ligne — Poste / Risque / Protection'} onClose={onClose} wide>
      <form onSubmit={submit}>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Poste"><input required value={form.jobTitle} onChange={(e) => setForm({ ...form, jobTitle: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Opérateur production" /></FormField>
          <FormField label="Activité"><input value={form.activity} onChange={(e) => setForm({ ...form, activity: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Danger"><input required value={form.hazard} onChange={(e) => setForm({ ...form, hazard: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Bruit" /></FormField>
        <FormField label="Risque"><input value={form.riskDescription} onChange={(e) => setForm({ ...form, riskDescription: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Exposition sonore" /></FormField>
        <FormField label="Mesure de prévention"><input value={form.preventionMeasure} onChange={(e) => setForm({ ...form, preventionMeasure: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Réduction technique et organisationnelle" /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="EPI associé">
            <select value={form.epiId} onChange={(e) => setForm({ ...form, epiId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>{(epiOptions || []).map((e) => <option key={e.id} value={e.id}>{e.name}</option>)}
            </select>
          </FormField>
          <FormField label="EPC associé">
            <select value={form.epcId} onChange={(e) => setForm({ ...form, epcId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>{(epcOptions || []).map((e) => <option key={e.id} value={e.id}>{e.name}</option>)}
            </select>
          </FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Fréquence d'utilisation"><input value={form.usageFrequency} onChange={(e) => setForm({ ...form, usageFrequency: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Selon évaluation du risque" /></FormField>
          <FormField label="Critère de contrôle"><input value={form.controlCriteria} onChange={(e) => setForm({ ...form, controlCriteria: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function EmployeeForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ matricule: record?.matricule || '', firstName: record?.firstName || '', lastName: record?.lastName || '', department: record?.department || '', position: record?.position || '', active: record?.active ?? true });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      if (editing) await api.patch(`/epi/employees/${record.id}`, form);
      else await api.post('/epi/employees', form);
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(`${record.firstName} ${record.lastName}`, `/epi/employees/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? "Modifier l'employé" : 'Nouvel employé'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Matricule"><input required value={form.matricule} onChange={(e) => setForm({ ...form, matricule: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Prénom"><input required value={form.firstName} onChange={(e) => setForm({ ...form, firstName: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Nom"><input required value={form.lastName} onChange={(e) => setForm({ ...form, lastName: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Département"><input value={form.department} onChange={(e) => setForm({ ...form, department: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Poste"><input value={form.position} onChange={(e) => setForm({ ...form, position: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        {editing && <label className="flex items-center gap-2 text-xs mb-3" style={{ color: C.textMuted }}><input type="checkbox" checked={form.active} onChange={(e) => setForm({ ...form, active: e.target.checked })} />Employé actif</label>}
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function EpiCatalogForm({ record, categories, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({
    code: record?.code || '', name: record?.name || '', frequency: record?.frequency || 'DAILY', unit: record?.unit || 'piece',
    annualValidityDays: record?.annualValidityDays ?? '', minStock: record?.minStock ?? 0, maxStock: record?.maxStock ?? '', active: record?.active ?? true,
    categoryId: record?.categoryId || '', reference: record?.reference || '', subcategory: record?.subcategory || '', description: record?.description || '',
    manufacturer: record?.manufacturer || '', model: record?.model || '', size: record?.size || '', color: record?.color || '', material: record?.material || '',
    standard: record?.standard || '', durationMode: record?.durationMode || '', durationValueDays: record?.durationValueDays ?? '',
    disposable: record?.disposable || false, shared: record?.shared || false, location: record?.location || '', status: record?.status || 'ACTIVE',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, categoryId: form.categoryId || null, annualValidityDays: form.annualValidityDays !== '' ? Number(form.annualValidityDays) : null, durationValueDays: form.durationValueDays !== '' ? Number(form.durationValueDays) : null, minStock: Number(form.minStock), maxStock: form.maxStock !== '' ? Number(form.maxStock) : null };
      if (editing) await api.patch(`/epi/catalog/${record.id}`, payload);
      else await api.post('/epi/catalog', payload);
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.name, `/epi/catalog/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? "Modifier l'EPI" : 'Nouvel EPI au catalogue'} onClose={onClose} wide>
      <form onSubmit={submit}>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Code"><input required value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Désignation"><input required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Casque de sécurité" /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Catégorie">
            <select value={form.categoryId} onChange={(e) => setForm({ ...form, categoryId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>{(categories || []).map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
          </FormField>
          <FormField label="Sous-catégorie"><input value={form.subcategory} onChange={(e) => setForm({ ...form, subcategory: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Description"><textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Fabricant"><input value={form.manufacturer} onChange={(e) => setForm({ ...form, manufacturer: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Modèle"><input value={form.model} onChange={(e) => setForm({ ...form, model: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Référence"><input value={form.reference} onChange={(e) => setForm({ ...form, reference: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Taille"><input value={form.size} onChange={(e) => setForm({ ...form, size: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Couleur"><input value={form.color} onChange={(e) => setForm({ ...form, color: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Matière"><input value={form.material} onChange={(e) => setForm({ ...form, material: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Norme / référence réglementaire applicable">
          <input value={form.standard} onChange={(e) => setForm({ ...form, standard: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. EN 397 — à renseigner selon la documentation du fabricant" />
        </FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Mode de durée d'utilisation">
            <select value={form.durationMode} onChange={(e) => setForm({ ...form, durationMode: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>
              <option value="FIXED">Durée fixe</option>
              <option value="MANUFACTURER">Définie par le fabricant</option>
              <option value="REGULATION">Définie par réglementation</option>
              <option value="INSPECTION">Selon inspection</option>
              <option value="CONDITION">Selon état constaté</option>
              <option value="CONSUMPTION">Selon consommation</option>
              <option value="SINGLE_USE">Usage unique</option>
              <option value="NO_FIXED_EXPIRY">Sans échéance fixe</option>
            </select>
          </FormField>
          {form.durationMode === 'FIXED' && <FormField label="Durée (jours)"><input type="number" value={form.durationValueDays} onChange={(e) => setForm({ ...form, durationValueDays: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>}
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Fréquence de distribution"><select value={form.frequency} onChange={(e) => setForm({ ...form, frequency: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="DAILY">Quotidienne</option><option value="ANNUAL">Annuelle</option></select></FormField>
          <FormField label="Unité"><input value={form.unit} onChange={(e) => setForm({ ...form, unit: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Stock minimum"><input type="number" value={form.minStock} onChange={(e) => setForm({ ...form, minStock: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Stock maximum"><input type="number" value={form.maxStock} onChange={(e) => setForm({ ...form, maxStock: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Emplacement"><input value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="flex gap-6 mb-3">
          <label className="flex items-center gap-2 text-xs" style={{ color: C.textMuted }}><input type="checkbox" checked={form.disposable} onChange={(e) => setForm({ ...form, disposable: e.target.checked })} />Jetable</label>
          <label className="flex items-center gap-2 text-xs" style={{ color: C.textMuted }}><input type="checkbox" checked={form.shared} onChange={(e) => setForm({ ...form, shared: e.target.checked })} />Partagé (non individuel)</label>
        </div>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function fileToBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result.split(',')[1]);
    reader.onerror = () => reject(new Error('Lecture du fichier impossible'));
    reader.readAsDataURL(file);
  });
}
function fileUrlFor(storagePath) {
  const fileName = `${storagePath}`.split(/[\\/]/).pop();
  const serverRoot = getBaseUrl().replace(/\/api\/v4\/?$/, '');
  return `${serverRoot}/uploads/${fileName}`;
}
function latestVersion(doc) {
  const versions = doc.versions || [];
  return versions.length ? [...versions].sort((a, b) => b.version - a.version)[0] : null;
}

function DocumentUploadForm({ groups, onClose, onCreated }) {
  const C = useTheme();
  const [form, setForm] = useState({ title: '', category: '', documentGroup: '' });
  const [file, setFile] = useState(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { code: genCode('DOC'), title: form.title, category: form.category || 'Non classé', documentGroup: form.documentGroup || undefined };
      if (file) {
        payload.fileName = file.name;
        payload.mimeType = file.type;
        payload.base64 = await fileToBase64(file);
      }
      await api.post('/documents', payload);
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title="Ajouter un document" onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Titre"><input required value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Catégorie"><input value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Groupe">
          <select value={form.documentGroup} onChange={(e) => setForm({ ...form, documentGroup: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">Non classé</option>
            {groups.map((g) => <option key={g} value={g}>{g}</option>)}
          </select>
        </FormField>
        <FormField label="Fichier (PDF, Word, Excel...)">
          <input type="file" accept=".pdf,.doc,.docx,.xls,.xlsx" onChange={(e) => setFile(e.target.files[0] || null)} className="w-full text-sm" style={{ color: C.text }} />
        </FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <button type="submit" disabled={saving} className="w-full py-2.5 rounded-lg text-sm font-medium mt-1" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Envoi…' : 'Ajouter le document'}</button>
      </form>
    </Modal>
  );
}

function DocumentVersionForm({ doc, onClose, onCreated }) {
  const C = useTheme();
  const [file, setFile] = useState(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault();
    if (!file) { setError('Choisissez un fichier'); return; }
    setSaving(true); setError(null);
    try {
      const base64 = await fileToBase64(file);
      await api.post(`/documents/${doc.id}/versions`, { fileName: file.name, mimeType: file.type, base64 });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={`Nouvelle version — ${doc.title}`} onClose={onClose}>
      <form onSubmit={submit}>
        <p className="text-xs mb-3" style={{ color: C.textMuted }}>Version actuelle : v{doc.currentVersion}. Le nouveau fichier deviendra la version suivante — l'ancienne reste consultable dans l'historique.</p>
        <FormField label="Nouveau fichier">
          <input type="file" accept=".pdf,.doc,.docx,.xls,.xlsx" onChange={(e) => setFile(e.target.files[0] || null)} className="w-full text-sm" style={{ color: C.text }} />
        </FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <button type="submit" disabled={saving} className="w-full py-2.5 rounded-lg text-sm font-medium mt-1" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Envoi…' : 'Enregistrer la nouvelle version'}</button>
      </form>
    </Modal>
  );
}

// Lecture en ligne : PDF affiché directement, Word/Excel convertis en
// aperçu HTML lisible (mammoth / SheetJS). Le téléchargement du fichier
// original reste toujours disponible, quel que soit le format.
function DocumentViewerModal({ doc, onClose, onNewVersion, onDeleted }) {
  const C = useTheme();
  const [preview, setPreview] = useState({ loading: true, kind: null, content: null, error: null });
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState(null);
  const version = latestVersion(doc);

  async function del() {
    setDeleting(true); setDeleteError(null);
    try { await confirmAndDelete(doc.title, `/documents/${doc.id}`, () => { onDeleted(); onClose(); }); }
    catch (err) { setDeleteError(err.message); }
    setDeleting(false);
  }

  useEffect(() => {
    if (!version) { setPreview({ loading: false, kind: null, content: null, error: 'Aucun fichier associé à ce document' }); return; }
    const url = fileUrlFor(version.storagePath);
    const ext = version.fileName.split('.').pop().toLowerCase();
    setPreview({ loading: true, kind: null, content: null, error: null });
    (async () => {
      try {
        if (ext === 'pdf') {
          setPreview({ loading: false, kind: 'pdf', content: url, error: null });
        } else if (ext === 'docx' || ext === 'doc') {
          const buf = await fetch(url).then((r) => r.arrayBuffer());
          const result = await mammoth.convertToHtml({ arrayBuffer: buf });
          setPreview({ loading: false, kind: 'html', content: result.value, error: null });
        } else if (ext === 'xlsx' || ext === 'xls') {
          const buf = await fetch(url).then((r) => r.arrayBuffer());
          const wb = XLSX.read(buf, { type: 'array' });
          const html = XLSX.utils.sheet_to_html(wb.Sheets[wb.SheetNames[0]]);
          setPreview({ loading: false, kind: 'html', content: html, error: null });
        } else {
          setPreview({ loading: false, kind: 'unsupported', content: url, error: null });
        }
      } catch (err) {
        setPreview({ loading: false, kind: null, content: null, error: "Aperçu impossible pour ce fichier — téléchargez-le pour l'ouvrir." });
      }
    })();
  }, [doc.id]);

  return (
    <Modal title={doc.title} onClose={onClose} wide>
      <div className="flex items-center justify-between mb-3">
        <span className="text-xs" style={{ color: C.textMuted }}>{doc.code} · v{doc.currentVersion} · {version ? version.fileName : 'Aucun fichier'}</span>
        <div className="flex gap-2">
          {version && <a href={fileUrlFor(version.storagePath)} download={version.fileName} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, color: C.text }}>Télécharger</a>}
          <button onClick={onNewVersion} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvelle version</button>
          <button onClick={del} disabled={deleting} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>{deleting ? '…' : 'Supprimer'}</button>
        </div>
      </div>
      {deleteError && <p className="text-xs mb-3" style={{ color: C.red }}>{deleteError}</p>}

      {preview.loading && <LoadingPanel />}
      {!preview.loading && preview.error && <p className="text-sm text-center py-8" style={{ color: C.red }}>{preview.error}</p>}
      {!preview.loading && preview.kind === 'pdf' && (
        <iframe src={preview.content} title={doc.title} className="w-full rounded-lg" style={{ height: '65vh', border: `1px solid ${C.border}` }} />
      )}
      {!preview.loading && preview.kind === 'html' && (
        <div className="rounded-lg p-4 overflow-auto bg-white text-gray-900" style={{ maxHeight: '65vh' }} dangerouslySetInnerHTML={{ __html: preview.content }} />
      )}
      {!preview.loading && preview.kind === 'unsupported' && (
        <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aperçu non disponible pour ce type de fichier — utilisez « Télécharger » pour l'ouvrir.</p>
      )}

      {(doc.versions || []).length > 1 && (
        <div className="mt-4 pt-3" style={{ borderTop: `1px solid ${C.border}` }}>
          <p className="text-xs mb-2" style={{ color: C.textMuted }}>Historique des versions</p>
          {[...doc.versions].sort((a, b) => b.version - a.version).map((v) => (
            <div key={v.id} className="flex items-center justify-between text-xs py-1">
              <span style={{ color: C.text }}>v{v.version} — {v.fileName}</span>
              <a href={fileUrlFor(v.storagePath)} download={v.fileName} style={{ color: C.blue }}>Télécharger</a>
            </div>
          ))}
        </div>
      )}
    </Modal>
  );
}

const ROLES = ['ADMINISTRATEUR', 'RESPONSABLE_QHSE', 'ASSISTANT_QHSE', 'CONTROLEUR_QUALITE', 'CHEF_PRODUCTION', 'OPERATEUR', 'AUDITEUR', 'CONSULTATION'];
const ROLE_LABELS = {
  ADMINISTRATEUR: 'Administrateur (accès complet)', RESPONSABLE_QHSE: 'Responsable QHSE', ASSISTANT_QHSE: 'Assistant QHSE',
  CONTROLEUR_QUALITE: 'Contrôleur qualité', CHEF_PRODUCTION: 'Chef de production', OPERATEUR: 'Opérateur (terrain)',
  AUDITEUR: 'Auditeur', CONSULTATION: 'Consultation seule',
};

function NewUserForm({ onClose, onCreated }) {
  const C = useTheme();
  const [form, setForm] = useState({ firstName: '', lastName: '', email: '', password: '', role: 'CONSULTATION' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      await api.post('/users', form);
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title="Nouvel utilisateur" onClose={onClose}>
      <form onSubmit={submit}>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Prénom"><input required value={form.firstName} onChange={(e) => setForm({ ...form, firstName: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Nom"><input required value={form.lastName} onChange={(e) => setForm({ ...form, lastName: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Email"><input required type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Mot de passe temporaire (8 caractères minimum)"><input required type="text" minLength={8} value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="À transmettre à l'utilisateur, à changer ensuite" /></FormField>
        <FormField label="Rôle (définit l'accès)">
          <select value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            {ROLES.map((r) => <option key={r} value={r}>{ROLE_LABELS[r]}</option>)}
          </select>
        </FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <button type="submit" disabled={saving} className="w-full py-2.5 rounded-lg text-sm font-medium mt-1" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Création…' : "Créer l'utilisateur"}</button>
      </form>
    </Modal>
  );
}

function ResetPasswordForm({ user, onClose, onDone }) {
  const C = useTheme();
  const [password, setPassword] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      await api.patch(`/users/${user.id}/reset-password`, { newPassword: password });
      onDone(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={`Réinitialiser le mot de passe — ${user.firstName} ${user.lastName}`} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Nouveau mot de passe (8 caractères minimum)"><input required minLength={8} value={password} onChange={(e) => setPassword(e.target.value)} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <p className="text-xs mb-3" style={{ color: C.textMuted }}>Transmettez ce nouveau mot de passe à la personne concernée en dehors de l'application.</p>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <button type="submit" disabled={saving} className="w-full py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : 'Réinitialiser'}</button>
      </form>
    </Modal>
  );
}

function ChangeMyPasswordForm({ email, onClose }) {
  const C = useTheme();
  const [form, setForm] = useState({ currentPassword: '', newPassword: '', confirm: '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const [done, setDone] = useState(false);
  async function submit(e) {
    e.preventDefault(); setError(null);
    if (form.newPassword !== form.confirm) { setError('Les deux mots de passe ne correspondent pas'); return; }
    setSaving(true);
    try {
      await api.post('/auth/change-password', { email, currentPassword: form.currentPassword, newPassword: form.newPassword });
      setDone(true);
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title="Changer mon mot de passe" onClose={onClose}>
      {done ? (
        <p className="text-sm" style={{ color: C.green }}>Mot de passe changé avec succès. Il sera utilisé dès votre prochaine connexion.</p>
      ) : (
        <form onSubmit={submit}>
          <FormField label="Mot de passe actuel"><input required type="password" value={form.currentPassword} onChange={(e) => setForm({ ...form, currentPassword: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Nouveau mot de passe (8 caractères minimum)"><input required type="password" minLength={8} value={form.newPassword} onChange={(e) => setForm({ ...form, newPassword: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Confirmer le nouveau mot de passe"><input required type="password" value={form.confirm} onChange={(e) => setForm({ ...form, confirm: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
          <button type="submit" disabled={saving} className="w-full py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : 'Changer le mot de passe'}</button>
        </form>
      )}
    </Modal>
  );
}

function UtilisateursPage() {
  const C = useTheme();
  const users = useCollection('/users');
  const [showForm, setShowForm] = useState(false);
  const [resettingUser, setResettingUser] = useState(null);
  if (users.loading) return <LoadingPanel />;
  if (users.error) return <ErrorPanel message={users.error} onRetry={users.reload} />;
  const list = users.data || [];

  async function toggleStatus(u) {
    await api.patch(`/users/${u.id}/status`, { status: u.status === 'ACTIVE' ? 'INACTIVE' : 'ACTIVE' });
    users.reload();
  }
  async function del(u) {
    await confirmAndDelete(`${u.firstName} ${u.lastName}`, `/users/${u.id}`, () => users.reload());
  }
  const currentEmail = getStoredUser()?.email;

  return (
    <div className="space-y-6">
      {showForm && <NewUserForm onClose={() => setShowForm(false)} onCreated={users.reload} />}
      {resettingUser && <ResetPasswordForm user={resettingUser} onClose={() => setResettingUser(null)} onDone={users.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvel utilisateur</button>
      </div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="Comptes créés" value={list.length} color={C.blue} icon={Users} />
        <KpiCard label="Comptes actifs" value={list.filter((u) => u.status === 'ACTIVE').length} color={C.green} icon={ShieldCheck} />
      </div>
      <Panel title="Liste des utilisateurs">
        {list.length ? (
          <table className="w-full text-sm">
            <thead><tr style={{ color: C.textMuted }}>
              <th className="text-left font-normal pb-2">Nom</th><th className="text-left font-normal pb-2">Email</th>
              <th className="text-left font-normal pb-2">Rôle</th><th className="text-left font-normal pb-2">Statut</th><th className="text-left font-normal pb-2">Actions</th>
            </tr></thead>
            <tbody>
              {list.map((u) => (
                <tr key={u.id} style={{ borderTop: `1px solid ${C.border}` }}>
                  <td className="py-2" style={{ color: C.text }}>{u.firstName} {u.lastName}</td>
                  <td className="py-2" style={{ color: C.textMuted }}>{u.email}</td>
                  <td className="py-2" style={{ color: C.textMuted }}>{u.roles.map((r) => ROLE_LABELS[r.role.name] || r.role.name).join(', ') || '—'}</td>
                  <td className="py-2"><StatusChip statut={u.status === 'ACTIVE' ? 'Conforme' : 'Non conforme'} /></td>
                  <td className="py-2">
                    <div className="flex gap-2">
                      <button onClick={() => setResettingUser(u)} className="text-xs" style={{ color: C.blue }}>Réinitialiser mdp</button>
                      <button onClick={() => toggleStatus(u)} className="text-xs" style={{ color: u.status === 'ACTIVE' ? C.red : C.green }}>{u.status === 'ACTIVE' ? 'Désactiver' : 'Activer'}</button>
                      {u.email !== currentEmail && <button onClick={() => del(u)} className="text-xs" style={{ color: C.red }}>Supprimer</button>}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun utilisateur pour le moment</p>}
      </Panel>
    </div>
  );
}

function HaccpForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ process: record?.process || '', step: record?.step || '', hazard: record?.hazard || '', ccp: record?.ccp || false, criticalLimit: record?.criticalLimit || '', monitoring: record?.monitoring || '', result: record?.result || '', correctiveAction: record?.correctiveAction || '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      if (editing) await api.patch(`/business/haccp/${record.id}`, form);
      else await api.post('/business/haccp', { code: genCode('HACCP'), ...form });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(`${record.process} — ${record.step}`, `/business/haccp/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier le point HACCP' : 'Nouveau point HACCP'} onClose={onClose}>
      <form onSubmit={submit}>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Processus"><input required value={form.process} onChange={(e) => setForm({ ...form, process: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Étape"><input required value={form.step} onChange={(e) => setForm({ ...form, step: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Danger identifié"><input required value={form.hazard} onChange={(e) => setForm({ ...form, hazard: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <label className="flex items-center gap-2 text-xs mb-3" style={{ color: C.textMuted }}>
          <input type="checkbox" checked={form.ccp} onChange={(e) => setForm({ ...form, ccp: e.target.checked })} />
          Point critique de maîtrise (CCP)
        </label>
        <FormField label="Limite critique"><input value={form.criticalLimit} onChange={(e) => setForm({ ...form, criticalLimit: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Surveillance"><input value={form.monitoring} onChange={(e) => setForm({ ...form, monitoring: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Résultat"><input value={form.result} onChange={(e) => setForm({ ...form, result: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Action corrective"><textarea value={form.correctiveAction} onChange={(e) => setForm({ ...form, correctiveAction: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function EquipmentForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ name: record?.name || '', category: record?.category || '', location: record?.location || '', status: record?.status || 'ACTIVE', lastInspectionAt: record?.lastInspectionAt ? new Date(record.lastInspectionAt).toISOString().slice(0, 10) : '', nextInspectionAt: record?.nextInspectionAt ? new Date(record.nextInspectionAt).toISOString().slice(0, 10) : '', notes: record?.notes || '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, lastInspectionAt: form.lastInspectionAt ? new Date(form.lastInspectionAt).toISOString() : null, nextInspectionAt: form.nextInspectionAt ? new Date(form.nextInspectionAt).toISOString() : null };
      if (editing) await api.patch(`/business/equipment/${record.id}`, payload);
      else await api.post('/business/equipment', { code: genCode('EQ'), ...payload });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.name, `/business/equipment/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? "Modifier l'équipement" : 'Nouvel équipement'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Nom"><input required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Catégorie"><input value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Localisation"><input value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Dernière inspection"><input type="date" value={form.lastInspectionAt} onChange={(e) => setForm({ ...form, lastInspectionAt: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Prochaine inspection"><input type="date" value={form.nextInspectionAt} onChange={(e) => setForm({ ...form, nextInspectionAt: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Statut"><select value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="ACTIVE">Actif</option><option value="MAINTENANCE">En maintenance</option><option value="HORS_SERVICE">Hors service</option></select></FormField>
        <FormField label="Notes"><textarea value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

// Signature électronique — dessin réel au doigt/souris sur un canevas,
// jamais un simple champ texte "signé par". Exportée en image PNG (base64).
function SignaturePad({ label, value, onChange }) {
  const C = useTheme();
  const canvasRef = useRef(null);
  const drawing = useRef(false);
  const [hasDrawn, setHasDrawn] = useState(!!value);

  function pos(e) {
    const rect = canvasRef.current.getBoundingClientRect();
    const cx = e.touches ? e.touches[0].clientX : e.clientX;
    const cy = e.touches ? e.touches[0].clientY : e.clientY;
    return { x: cx - rect.left, y: cy - rect.top };
  }
  function start(e) { drawing.current = true; const { x, y } = pos(e); const ctx = canvasRef.current.getContext('2d'); ctx.beginPath(); ctx.moveTo(x, y); }
  function move(e) {
    if (!drawing.current) return;
    e.preventDefault();
    const { x, y } = pos(e);
    const ctx = canvasRef.current.getContext('2d');
    ctx.lineTo(x, y); ctx.strokeStyle = '#111'; ctx.lineWidth = 2; ctx.lineCap = 'round'; ctx.stroke();
    setHasDrawn(true);
  }
  function end() {
    if (!drawing.current) return;
    drawing.current = false;
    onChange(canvasRef.current.toDataURL('image/png'));
  }
  function clear() {
    const ctx = canvasRef.current.getContext('2d');
    ctx.clearRect(0, 0, canvasRef.current.width, canvasRef.current.height);
    setHasDrawn(false);
    onChange(null);
  }
  return (
    <div className="mb-3">
      <div className="flex items-center justify-between mb-1">
        <span className="text-xs" style={{ color: C.textMuted }}>{label}</span>
        {hasDrawn && <button type="button" onClick={clear} className="text-xs" style={{ color: C.red }}>Effacer</button>}
      </div>
      <canvas
        ref={canvasRef} width={360} height={120}
        style={{ backgroundColor: '#fff', borderRadius: 8, width: '100%', touchAction: 'none', cursor: 'crosshair' }}
        onMouseDown={start} onMouseMove={move} onMouseUp={end} onMouseLeave={end}
        onTouchStart={start} onTouchMove={move} onTouchEnd={end}
      />
    </div>
  );
}

function AssignmentForm({ epiOptions, employeeOptions, onClose, onCreated }) {
  const C = useTheme();
  const [form, setForm] = useState({
    employeeId: '', epiId: '', quantity: 1, size: '', distributedAt: new Date().toISOString().slice(0, 10),
    expectedDurationDays: '', reason: '', condition: 'Neuf',
  });
  const [employeeSignature, setEmployeeSignature] = useState(null);
  const [responsibleSignature, setResponsibleSignature] = useState(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  async function submit(e) {
    e.preventDefault();
    if (!employeeSignature || !responsibleSignature) { setError('Les deux signatures sont requises avant de valider la dotation.'); return; }
    setSaving(true); setError(null);
    try {
      const distributedAt = new Date(form.distributedAt);
      const renewalAt = form.expectedDurationDays !== '' ? new Date(distributedAt.getTime() + Number(form.expectedDurationDays) * 86400000).toISOString() : null;
      const me = getStoredUser();
      const payload = {
        ...form, quantity: Number(form.quantity), distributedAt: distributedAt.toISOString(), renewalAt,
        expectedDurationDays: form.expectedDurationDays !== '' ? Number(form.expectedDurationDays) : null,
        responsibleId: me?.id || null, employeeSignature, responsibleSignature,
      };
      await api.post('/epi/assignments', { code: genCode('DOT'), ...payload });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }

  return (
    <Modal title="Nouvelle dotation EPI" onClose={onClose} wide>
      <form onSubmit={submit}>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Employé">
            <select required value={form.employeeId} onChange={(e) => setForm({ ...form, employeeId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">Sélectionner…</option>{(employeeOptions || []).map((e) => <option key={e.id} value={e.id}>{e.firstName} {e.lastName}</option>)}
            </select>
          </FormField>
          <FormField label="EPI">
            <select required value={form.epiId} onChange={(e) => setForm({ ...form, epiId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">Sélectionner…</option>{(epiOptions || []).map((e) => <option key={e.id} value={e.id}>{e.name}</option>)}
            </select>
          </FormField>
        </div>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Quantité"><input required type="number" min="1" value={form.quantity} onChange={(e) => setForm({ ...form, quantity: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Taille"><input value={form.size} onChange={(e) => setForm({ ...form, size: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="État à la remise"><input value={form.condition} onChange={(e) => setForm({ ...form, condition: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Date de remise"><input required type="date" value={form.distributedAt} onChange={(e) => setForm({ ...form, distributedAt: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Durée prévue (jours, optionnel)"><input type="number" value={form.expectedDurationDays} onChange={(e) => setForm({ ...form, expectedDurationDays: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Calcule automatiquement la date de renouvellement" /></FormField>
        </div>
        <FormField label="Motif"><input value={form.reason} onChange={(e) => setForm({ ...form, reason: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Première dotation, remplacement..." /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <SignaturePad label="Signature du salarié" value={employeeSignature} onChange={setEmployeeSignature} />
          <SignaturePad label="Signature du responsable" value={responsibleSignature} onChange={setResponsibleSignature} />
        </div>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <button type="submit" disabled={saving} className="w-full py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : 'Valider la dotation'}</button>
      </form>
    </Modal>
  );
}

// Reçu de dotation généré automatiquement — prêt à imprimer.
function AssignmentReceiptModal({ assignment, onClose }) {
  const C = useTheme();
  return (
    <Modal title={`Reçu de dotation — ${assignment.code}`} onClose={onClose}>
      <div id="receipt-print" className="text-sm space-y-2" style={{ color: C.text }}>
        <p><b>Employé :</b> {assignment.employee?.firstName} {assignment.employee?.lastName} ({assignment.employee?.matricule})</p>
        <p><b>Équipement :</b> {assignment.epi?.name} {assignment.size ? `— taille ${assignment.size}` : ''}</p>
        <p><b>Quantité :</b> {assignment.quantity}</p>
        <p><b>Date de remise :</b> {new Date(assignment.distributedAt).toLocaleDateString('fr-FR')}</p>
        {assignment.renewalAt && <p><b>Renouvellement prévu :</b> {new Date(assignment.renewalAt).toLocaleDateString('fr-FR')}</p>}
        <p><b>État à la remise :</b> {assignment.condition || '—'}</p>
        <p><b>Motif :</b> {assignment.reason || '—'}</p>
        <p><b>Responsable :</b> {assignment.responsible?.firstName} {assignment.responsible?.lastName}</p>
        <div className="grid grid-cols-2 gap-3 pt-3">
          <div><p className="text-xs mb-1" style={{ color: C.textMuted }}>Signature salarié</p>{assignment.employeeSignature && <img src={assignment.employeeSignature} alt="Signature salarié" style={{ backgroundColor: '#fff', borderRadius: 8, width: '100%' }} />}</div>
          <div><p className="text-xs mb-1" style={{ color: C.textMuted }}>Signature responsable</p>{assignment.responsibleSignature && <img src={assignment.responsibleSignature} alt="Signature responsable" style={{ backgroundColor: '#fff', borderRadius: 8, width: '100%' }} />}</div>
        </div>
      </div>
      <button onClick={() => window.print()} className="w-full py-2.5 rounded-lg text-sm font-medium mt-4" style={{ backgroundColor: C.blue, color: '#fff' }}>Imprimer le reçu</button>
    </Modal>
  );
}

function groupCount(items, keyFn) {
  const map = {};
  (items || []).forEach((it) => { const k = keyFn(it) || 'Non renseigné'; map[k] = (map[k] || 0) + 1; });
  return Object.entries(map).map(([name, value]) => ({ name, value }));
}
function LoadingPanel() {
  const C = useTheme();
  return <div className="flex items-center gap-2 text-sm py-8 justify-center" style={{ color: C.textMuted }}><RefreshCw size={16} className="animate-spin" />Chargement des données réelles…</div>;
}
function ErrorPanel({ message, onRetry }) {
  const C = useTheme();
  return (
    <Panel>
      <p className="text-sm mb-2" style={{ color: C.red }}>Impossible de charger les données : {message}</p>
      <p className="text-xs mb-3" style={{ color: C.textMuted }}>Vérifiez que <code>docker compose up -d</code> tourne, et que l'adresse du serveur est correcte (Réglages de connexion en bas de la barre latérale).</p>
      {onRetry && <button onClick={onRetry} className="px-3 py-1.5 rounded-lg text-xs" style={{ backgroundColor: C.card, border: `1px solid ${C.border}`, color: C.text }}>Réessayer</button>}
    </Panel>
  );
}
// Bandeau discret rappelant que la page affiche des données réelles de
// production — jamais silencieux sur l'origine des chiffres affichés.
function LiveBadge() {
  const C = useTheme();
  return <span className="inline-flex items-center gap-1 text-[10px] px-2 py-0.5 rounded-full" style={{ backgroundColor: `${C.green}22`, color: C.green }}><span className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: C.green }} />Données réelles</span>;
}
// Ce module n'a pas encore de table dédiée dans votre base : la page
// reste en démonstration tant que le schéma n'a pas été étendu.
function DemoBadge() {
  const C = useTheme();
  return <span className="inline-flex items-center gap-1 text-[10px] px-2 py-0.5 rounded-full" style={{ backgroundColor: `${C.amber}22`, color: C.amber }}><span className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: C.amber }} />Démonstration — module non connecté</span>;
}
// Statuts réels de votre API (Action/NonConformity: OPEN|CLOSED,
// Risk: ACTIVE, QhseAudit: PLANNED par défaut) — calculés dynamiquement
// plutôt que suppposés, puisqu'aucune de ces valeurs n'est un enum strict
// côté schéma.
function isOverdue(dueDate, status) {
  return status !== 'CLOSED' && dueDate && new Date(dueDate) < new Date();
}
function computeCapaStatsReal(actions) {
  const total = actions.length;
  const terminees = actions.filter((a) => a.status === 'CLOSED').length;
  const enRetard = actions.filter((a) => isOverdue(a.dueDate, a.status)).length;
  const enCours = total - terminees - enRetard;
  return { total, terminees, enCours, enRetard, tauxRealisation: total ? Math.round((terminees / total) * 100) : 0 };
}

// ============================================================================
// Export Excel générique — réutilisé par toutes les cartes de rapport.
// ============================================================================
function downloadWorkbook(sheets, filename) {
  const wb = XLSX.utils.book_new();
  sheets.forEach(([name, rows]) => XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(rows), name.slice(0, 31)));
  XLSX.writeFile(wb, filename);
}
function reportDefinitions(real) {
  const { dashboardData, audits, risks, actions, environment, safetyEvents, epi } = real;
  const capaStats = computeCapaStatsReal(actions || []);
  const tauxConformite = dashboardData?.overview?.indicators?.qualite?.tauxConformite;
  const environmentByType = {};
  (environment || []).forEach((r) => { environmentByType[r.type] = (environmentByType[r.type] || 0) + (r.value || 0); });
  const severityBreakdown = groupCount(safetyEvents || [], (e) => `Sévérité ${e.severity}`);

  return [
    {
      id: 'synthese', titre: 'Rapport QHSE — Synthèse', description: "Vue d'ensemble à date, toutes données réelles.",
      sheets: () => [['Synthèse', [['Indicateur', 'Valeur'], ['Conformité qualité (30j)', tauxConformite != null ? `${tauxConformite}%` : 'Non disponible'], ['CAPA réalisées', `${capaStats.tauxRealisation}%`], ['Risques critiques (≥15)', (risks || []).filter((r) => r.score >= 15).length], ['Événements sécurité enregistrés', (safetyEvents || []).length]]]],
    },
    {
      id: 'direction', titre: 'Revue de Direction', description: 'Synthèse exécutive pour la Direction générale.',
      sheets: () => [['Revue de direction', [['Pilier', 'Statut'], ['Qualité', tauxConformite != null ? `${tauxConformite}%` : '—'], ['Sécurité', `${(safetyEvents || []).length} événement(s) enregistré(s)`], ['Environnement', `${(environment || []).length} relevé(s)`], ['CAPA', `${capaStats.tauxRealisation}% réalisées`]]]],
    },
    {
      id: 'audit', titre: "Rapport d'audit", description: 'Planning et résultats de tous les audits.',
      sheets: () => [['Audits', [['Titre', 'Référence', 'Date', 'Statut', 'Score'], ...(audits || []).map((a) => [a.title, a.reference || '—', new Date(a.auditDate).toLocaleDateString('fr-FR'), a.status, a.score ?? '—'])]]],
    },
    {
      id: 'risques', titre: 'Rapport des risques', description: 'Registre complet et scores de criticité.',
      sheets: () => [['Risques', [['Risque', 'Activité / Mesures', 'Probabilité', 'Gravité', 'Score', 'Statut'], ...(risks || []).map((r) => [r.hazard, r.activity || r.measures || '—', r.probability, r.severity, r.score, r.status])]]],
    },
    {
      id: 'capa', titre: 'Rapport CAPA', description: 'Actions correctives et préventives, avancement.',
      sheets: () => [['CAPA', [['Action', 'Priorité', 'Échéance', 'Statut'], ...(actions || []).map((a) => [a.title, a.priority, a.dueDate ? new Date(a.dueDate).toLocaleDateString('fr-FR') : '—', isOverdue(a.dueDate, a.status) ? 'EN RETARD' : a.status])]]],
    },
    {
      id: 'environnement', titre: 'Rapport environnemental', description: 'Relevés par type, tel qu\'enregistré.',
      sheets: () => [['Environnement', [['Type', 'Somme des valeurs'], ...Object.entries(environmentByType)]]],
    },
    {
      id: 'securite', titre: 'Rapport Santé & Sécurité', description: 'Événements sécurité et EPI.',
      sheets: () => [['Sécurité', [['Indicateur', 'Valeur'], ['Événements enregistrés', (safetyEvents || []).length], ...severityBreakdown.map((s) => [s.name, s.value]), ['EPI suivis', epi?.stock?.length ?? '—'], ['Effectif couvert', epi?.effectiveHeadcount ?? '—']]]],
    },
  ];
}

// ============================================================================
// Navigation — groupée par référentiel, fidèle à la maquette de référence.
// ============================================================================
const NAV_GROUPS = [
  { label: 'PILOTAGE', items: [{ id: 'pilotage', label: 'Tableau de bord', icon: LayoutDashboard }] },
  { label: 'QUALITÉ (ISO 9001:2015)', items: [
    { id: 'qualite-controles', label: 'Contrôles qualité', icon: ShieldCheck },
    { id: 'qualite-processus', label: 'Processus', icon: ClipboardList },
    { id: 'qualite-indicateurs', label: 'Indicateurs qualité', icon: Activity },
    { id: 'qualite-reclamations', label: 'Réclamations clients', icon: Bell },
    { id: 'qualite-fournisseurs', label: 'Fournisseurs', icon: FlaskConical },
  ] },
  { label: 'SÉCURITÉ (ISO 45001:2018)', items: [
    { id: 'securite-accidents', label: 'Accidents & incidents', icon: AlertTriangle },
    { id: 'securite-epi', label: 'Gestion EPI/EPC', icon: HardHat },
    { id: 'securite-hygiene', label: 'Hygiène au travail', icon: HeartPulse },
  ] },
  { label: 'ENVIRONNEMENT (ISO 14001:2026)', items: [{ id: 'environnement', label: 'Environnement', icon: Leaf }] },
  { label: 'RISQUES & AUDITS', items: [
    { id: 'risques', label: 'Registre des risques', icon: AlertTriangle },
    { id: 'audits', label: 'Audits', icon: ClipboardCheck },
    { id: 'non-conformites', label: 'Non-conformités', icon: FileWarning },
    { id: 'capa', label: 'Actions CAPA', icon: Wrench },
  ] },
  { label: 'SYSTÈME', items: [
    { id: 'documentation', label: 'Documentation (GED)', icon: BookOpen },
    { id: 'quart-heure-securite', label: "Quart d'heure sécurité", icon: Shield },
    { id: 'haccp', label: 'HACCP', icon: UtensilsCrossed },
    { id: 'equipements', label: 'Équipements', icon: Cog },
    { id: 'veille', label: 'Veille réglementaire', icon: Search },
    { id: 'objectifs', label: 'Objectifs QHSE', icon: Target },
    { id: 'rapports', label: 'Rapports', icon: FileBarChart },
    { id: 'utilisateurs', label: 'Utilisateurs', icon: Users },
  ] },
];
const PAGE_TITLES = Object.fromEntries(NAV_GROUPS.flatMap((g) => g.items).map((i) => [i.id, i.label]));

// ============================================================================
// Pages
// ============================================================================
function PilotagePage() {
  const C = useTheme();
  const dash = useCollection('/dashboard');
  const audits = useCollection('/business/audits');
  const actions = useCollection('/business/actions');
  const nonConformities = useCollection('/business/non-conformities');

  if (dash.loading || audits.loading || actions.loading || nonConformities.loading) return <LoadingPanel />;
  if (dash.error) return <ErrorPanel message={dash.error} />;

  const { counters, indicators } = dash.data.overview;
  const trends = dash.data.trends;
  const auditsPlanifies = (audits.data || []).filter((a) => a.status === 'PLANNED').length;
  const auditsTotal = (audits.data || []).length;
  const capaStats = computeCapaStatsReal(actions.data || []);
  const ncBySource = groupCount(nonConformities.data || [], (n) => n.source || 'Source non renseignée');
  const composite = indicators.qualite.tauxConformite != null
    ? Math.round(indicators.qualite.tauxConformite * 0.5 + Math.max(0, 100 - counters.actionsOverdue * 8) * 0.3 + Math.max(0, 100 - counters.risksHigh * 10) * 0.2)
    : null;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between"><LiveBadge /></div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="NC ouvertes" value={counters.nonConformitiesOpen} objectif={`${counters.nonConformitiesCritical} critique(s)`} color={C.red} icon={AlertTriangle} />
        <KpiCard label="Actions en retard" value={counters.actionsOverdue} objectif={`${counters.actionsOpen} ouverte(s) au total`} color={C.red} icon={Activity} />
        <KpiCard label="Événements sécurité" value={counters.safetyEvents30d} objectif="30 derniers jours" color={C.amber} icon={AlertTriangle} />
        <KpiCard label="Audits" value={`${auditsTotal - auditsPlanifies} / ${auditsTotal}`} objectif={`${auditsPlanifies} planifié(s)`} color={C.blue} icon={ClipboardList} />
        <KpiCard label="Taux de conformité" value={indicators.qualite.tauxConformite != null ? `${indicators.qualite.tauxConformite}%` : '—'} objectif="30 derniers jours" color={C.green} icon={ShieldCheck} />
      </div>
      <div className="grid grid-cols-2 gap-4">
        <Panel title="Événements sécurité & non-conformités par semaine" subtitle="8 dernières semaines">
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={trends.evenementsSecuriteParSemaine.map((e, i) => ({ semaine: e.weekStart.slice(5), evenements: e.count, nc: trends.nonConformitesParSemaine[i]?.count ?? 0 }))}>
              <CartesianGrid stroke={C.border} strokeDasharray="3 3" />
              <XAxis dataKey="semaine" stroke={C.textMuted} fontSize={11} />
              <YAxis stroke={C.textMuted} fontSize={12} />
              <Tooltip contentStyle={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, borderRadius: 8, color: C.text }} />
              <Line type="monotone" dataKey="evenements" stroke={C.amber} strokeWidth={2} dot={{ r: 3 }} name="Événements sécurité" />
              <Line type="monotone" dataKey="nc" stroke={C.red} strokeWidth={2} dot={{ r: 3 }} name="Non-conformités" />
            </LineChart>
          </ResponsiveContainer>
        </Panel>
        <Panel title={composite != null ? `Indice composite (estimation) : ${composite}%` : 'Indice composite'} subtitle="Qualité 50% · Actions à jour 30% · Risques maîtrisés 20%">
          <div className="flex items-center justify-center" style={{ height: 220 }}>
            {composite != null
              ? <div className="text-6xl font-bold" style={{ color: composite >= 80 ? C.green : composite >= 60 ? C.amber : C.red }}>{composite}%</div>
              : <p className="text-sm" style={{ color: C.textMuted }}>Pas assez de contrôles qualité soumis sur 30 jours pour calculer un taux de conformité.</p>}
          </div>
        </Panel>
      </div>
      <div className="grid grid-cols-3 gap-4">
        <Panel title="Non-conformités par source">
          {ncBySource.length ? <DonutChart data={ncBySource} colors={[C.red, C.amber, C.blue, C.green, '#8B5CF6', C.textMuted]} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucune non-conformité enregistrée</p>}
        </Panel>
        <Panel title="Répartition des événements sécurité par sévérité">
          {counters.safetyEventsBySeverity.length
            ? <HorizontalBars data={counters.safetyEventsBySeverity.map((s) => ({ label: `Sévérité ${s.severity}`, count: s.count }))} labelKey="label" valueKey="count" color={C.amber} />
            : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun événement sur 30 jours</p>}
        </Panel>
        <Panel title="Statut des actions correctives">
          <DonutChart data={[{ name: 'Terminées', value: capaStats.terminees }, { name: 'En cours', value: capaStats.enCours }, { name: 'En retard', value: capaStats.enRetard }]} colors={[C.green, C.blue, C.red]} />
        </Panel>
      </div>
    </div>
  );
}

function QualityControlForm({ onClose, onCreated }) {
  const C = useTheme();
  const catalogs = useCollection('/quality/catalogs');
  const [form, setForm] = useState({ siteId: '', lineId: '', machineId: '', productId: '', formatId: '', shiftId: '', lotNumber: '', templateId: '', notes: '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  if (catalogs.loading) return <Modal title="Nouveau contrôle qualité" onClose={onClose}><LoadingPanel /></Modal>;
  if (catalogs.error) return <Modal title="Nouveau contrôle qualité" onClose={onClose}><ErrorPanel message={catalogs.error} /></Modal>;
  const [sites, products, shifts, templates] = catalogs.data;
  const selectedSite = sites.find((s) => s.id === form.siteId);
  const lines = selectedSite ? selectedSite.lines : [];
  const selectedLine = lines.find((l) => l.id === form.lineId);
  const machines = selectedLine ? selectedLine.machines : [];
  const selectedProduct = products.find((p) => p.id === form.productId);
  const formats = selectedProduct ? selectedProduct.formats : [];

  async function submit(e) {
    e.preventDefault();
    setSaving(true); setError(null);
    try {
      await api.post('/quality/controls', {
        code: genCode('CTRL'), lineId: form.lineId, productId: form.productId, shiftId: form.shiftId, lotNumber: form.lotNumber,
        siteId: form.siteId || undefined, machineId: form.machineId || undefined, formatId: form.formatId || undefined,
        templateId: form.templateId || undefined, notes: form.notes || undefined,
      });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }

  return (
    <Modal title="Nouveau contrôle qualité" onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Site (optionnel)">
          <select value={form.siteId} onChange={(e) => setForm({ ...form, siteId: e.target.value, lineId: '', machineId: '' })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">—</option>{sites.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
        </FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Ligne">
            <select required value={form.lineId} onChange={(e) => setForm({ ...form, lineId: e.target.value, machineId: '' })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} disabled={!selectedSite}>
              <option value="">Sélectionner…</option>{lines.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}
            </select>
          </FormField>
          <FormField label="Machine (optionnel)">
            <select value={form.machineId} onChange={(e) => setForm({ ...form, machineId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} disabled={!selectedLine}>
              <option value="">—</option>{machines.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
            </select>
          </FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Produit">
            <select required value={form.productId} onChange={(e) => setForm({ ...form, productId: e.target.value, formatId: '' })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">Sélectionner…</option>{products.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
            </select>
          </FormField>
          <FormField label="Format (optionnel)">
            <select value={form.formatId} onChange={(e) => setForm({ ...form, formatId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} disabled={!selectedProduct}>
              <option value="">—</option>{formats.map((f) => <option key={f.id} value={f.id}>{f.label}</option>)}
            </select>
          </FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Quart">
            <select required value={form.shiftId} onChange={(e) => setForm({ ...form, shiftId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">Sélectionner…</option>{shifts.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
            </select>
          </FormField>
          <FormField label="N° de lot">
            <input required value={form.lotNumber} onChange={(e) => setForm({ ...form, lotNumber: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} />
          </FormField>
        </div>
        <FormField label="Modèle de contrôle (optionnel)">
          <select value={form.templateId} onChange={(e) => setForm({ ...form, templateId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">Aucun (contrôle simple)</option>{templates.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
          </select>
        </FormField>
        <FormField label="Notes"><textarea value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <button type="submit" disabled={saving} className="w-full py-2.5 rounded-lg text-sm font-medium mt-1" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Création…' : 'Créer le contrôle'}</button>
        <p className="text-[11px] mt-2 text-center" style={{ color: C.textMuted }}>Le contrôle est créé en statut « en cours » — la saisie des résultats point par point et la soumission finale se font depuis l'application Windows/Android pour l'instant.</p>
      </form>
    </Modal>
  );
}

// Saisie des résultats point par point + soumission finale. Reflète
// exactement les règles de l'API : un point obligatoire doit être rempli
// avant de pouvoir soumettre ; une fois COMPLIANT/NON_COMPLIANT/CANCELLED,
// le contrôle est clôturé et ne peut plus être modifié (l'API refuserait).
function ControlDetailModal({ controlId, onClose, onChanged }) {
  const C = useTheme();
  const [control, setControl] = useState(null);
  const [error, setError] = useState(null);
  const [savingPoint, setSavingPoint] = useState(null);
  const [submitting, setSubmitting] = useState(false);
  const [values, setValues] = useState({});

  async function load() {
    try {
      const c = await api.get(`/quality/controls/${controlId}`);
      setControl(c);
      const initial = {};
      (c.results || []).forEach((r) => { initial[r.pointId] = { value: r.value, comment: r.comment || '' }; });
      setValues((prev) => ({ ...initial, ...prev }));
    } catch (err) { setError(err.message); }
  }
  useEffect(() => { load(); }, [controlId]);

  if (error) return <Modal title="Contrôle qualité" onClose={onClose}><ErrorPanel message={error} /></Modal>;
  if (!control) return <Modal title="Contrôle qualité" onClose={onClose} wide><LoadingPanel /></Modal>;

  const closed = ['COMPLIANT', 'NON_COMPLIANT', 'CANCELLED'].includes(control.status);
  const points = control.template?.points || [];
  const resultByPoint = {};
  (control.results || []).forEach((r) => { resultByPoint[r.pointId] = r; });
  const missingRequired = points.filter((p) => p.required && !resultByPoint[p.id]);

  async function savePoint(point) {
    setSavingPoint(point.id); setError(null);
    const v = values[point.id] || {};
    try {
      await api.post(`/quality/controls/${controlId}/results`, {
        pointId: point.id,
        value: point.type === 'NUMERIC' ? Number(v.value) : point.type === 'BOOLEAN' ? !!v.value : v.value,
        comment: v.comment || undefined,
      });
      await load();
    } catch (err) { setError(err.message); }
    setSavingPoint(null);
  }

  async function submit() {
    setSubmitting(true); setError(null);
    try {
      await api.post(`/quality/controls/${controlId}/submit`);
      onChanged(); onClose();
    } catch (err) { setError(err.message); }
    setSubmitting(false);
  }

  async function del() {
    setSubmitting(true);
    try { await confirmAndDelete(control.code, `/quality/controls/${controlId}`, () => { onChanged(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSubmitting(false);
  }

  return (
    <Modal title={`Contrôle ${control.code}`} onClose={onClose} wide>
      <div className="flex flex-wrap items-center justify-between gap-2 mb-4">
        <div className="flex flex-wrap items-center gap-2 text-xs" style={{ color: C.textMuted }}>
          <span>{control.productRef?.name || '—'}</span>·<span>{control.productionLine?.name || '—'}</span>·<span>Lot {control.lotNumber}</span>·<StatusChip statut={control.status === 'COMPLIANT' ? 'Conforme' : control.status === 'NON_COMPLIANT' ? 'Non conforme' : control.status} />
        </div>
        <button onClick={del} disabled={submitting} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>
      </div>

      {points.length === 0 && (
        <p className="text-sm mb-4" style={{ color: C.textMuted }}>Ce contrôle n'a pas de modèle avec points de contrôle — vous pouvez le soumettre directement.</p>
      )}

      {points.length > 0 && (
        <div className="space-y-3 mb-4">
          {points.map((p) => {
            const existing = resultByPoint[p.id];
            const v = values[p.id] || {};
            return (
              <div key={p.id} className="rounded-lg p-3" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}` }}>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm" style={{ color: C.text }}>{p.label}{p.required && <span style={{ color: C.red }}> *</span>}{p.critical && <span className="text-[10px] ml-2 px-1.5 py-0.5 rounded" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Critique</span>}</span>
                  {existing && <span className="text-xs" style={{ color: existing.compliant === false ? C.red : C.green }}>{existing.compliant === false ? 'Non conforme' : 'Conforme'}</span>}
                </div>
                {!closed && (
                  <div className="flex gap-2">
                    {p.type === 'BOOLEAN' && (
                      <select value={v.value ?? ''} onChange={(e) => setValues({ ...values, [p.id]: { ...v, value: e.target.value === 'true' } })} className="px-2 py-1.5 rounded-lg text-sm outline-none" style={inputStyle(C)}>
                        <option value="">—</option><option value="true">Oui</option><option value="false">Non</option>
                      </select>
                    )}
                    {p.type === 'NUMERIC' && (
                      <input type="number" step="any" value={v.value ?? ''} onChange={(e) => setValues({ ...values, [p.id]: { ...v, value: e.target.value } })} className="w-32 px-2 py-1.5 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder={p.unit || ''} />
                    )}
                    {p.type === 'CHOICE' && (
                      <select value={v.value ?? ''} onChange={(e) => setValues({ ...values, [p.id]: { ...v, value: e.target.value } })} className="px-2 py-1.5 rounded-lg text-sm outline-none" style={inputStyle(C)}>
                        <option value="">—</option>{(p.choices || []).map((c) => <option key={c} value={c}>{c}</option>)}
                      </select>
                    )}
                    {(p.type === 'TEXT' || p.type === 'PHOTO') && (
                      <input value={v.value ?? ''} onChange={(e) => setValues({ ...values, [p.id]: { ...v, value: e.target.value } })} className="flex-1 px-2 py-1.5 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder={p.type === 'PHOTO' ? 'Référence de la photo (pièce jointe à venir)' : ''} />
                    )}
                    <input value={v.comment ?? ''} onChange={(e) => setValues({ ...values, [p.id]: { ...v, comment: e.target.value } })} className="flex-1 px-2 py-1.5 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Commentaire (optionnel)" />
                    <button onClick={() => savePoint(p)} disabled={savingPoint === p.id} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.blue, color: '#fff' }}>{savingPoint === p.id ? '…' : existing ? 'Modifier' : 'Enregistrer'}</button>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}

      {!closed ? (
        <>
          {missingRequired.length > 0 && <p className="text-xs mb-2" style={{ color: C.amber }}>{missingRequired.length} point(s) obligatoire(s) restant(s) avant de pouvoir soumettre.</p>}
          <button onClick={submit} disabled={submitting || missingRequired.length > 0} className="w-full py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: missingRequired.length > 0 ? C.border : C.green, color: missingRequired.length > 0 ? C.textMuted : '#052e1f' }}>
            {submitting ? 'Soumission…' : 'Soumettre le contrôle'}
          </button>
        </>
      ) : (
        <p className="text-xs text-center" style={{ color: C.textMuted }}>Ce contrôle est clôturé — plus aucune modification possible.</p>
      )}
    </Modal>
  );
}

function QualiteControlesPage() {
  const C = useTheme();
  const controls = useCollection('/quality/controls');
  const [showForm, setShowForm] = useState(false);
  const [selectedId, setSelectedId] = useState(null);
  if (controls.loading) return <LoadingPanel />;
  if (controls.error) return <ErrorPanel message={controls.error} onRetry={controls.reload} />;
  const list = controls.data || [];
  const soumis = list.filter((c) => c.status !== 'DRAFT' && c.status !== 'IN_PROGRESS');
  const conformes = list.filter((c) => c.status === 'COMPLIANT').length;
  const nonConformes = list.filter((c) => c.status === 'NON_COMPLIANT').length;
  const tauxConformite = soumis.length ? Math.round((conformes / soumis.length) * 100) : null;
  const sorted = [...list].sort((a, b) => new Date(b.controlDate) - new Date(a.controlDate));

  return (
    <div className="space-y-6">
      {showForm && <QualityControlForm onClose={() => setShowForm(false)} onCreated={controls.reload} />}
      {selectedId && <ControlDetailModal controlId={selectedId} onClose={() => setSelectedId(null)} onChanged={controls.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouveau contrôle</button>
      </div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="Contrôles enregistrés" value={list.length} color={C.blue} icon={ClipboardList} />
        <KpiCard label="Conformes" value={conformes} color={C.green} icon={ShieldCheck} />
        <KpiCard label="Non conformes" value={nonConformes} color={C.red} icon={AlertTriangle} />
        <KpiCard label="Taux de conformité" value={tauxConformite != null ? `${tauxConformite}%` : '—'} color={C.amber} icon={Activity} />
      </div>
      <p className="text-xs" style={{ color: C.textMuted }}>Cliquez une ligne pour saisir les résultats et soumettre le contrôle.</p>
      <Panel title="Registre des contrôles qualité">
        {sorted.length
          ? <DataTable columns={['Code', 'Produit', 'Ligne', 'Lot', 'Date', 'Statut']}
              rows={sorted.map((c) => [c.code, c.productRef?.name || '—', c.productionLine?.name || '—', c.lotNumber || '—', new Date(c.controlDate).toLocaleDateString('fr-FR'), <StatusChip statut={c.status === 'COMPLIANT' ? 'Conforme' : c.status === 'NON_COMPLIANT' ? 'Non conforme' : c.status} />])}
              onRowClick={(i) => setSelectedId(sorted[i].id)} />
          : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun contrôle qualité enregistré pour le moment</p>}
      </Panel>
    </div>
  );
}

function QualiteProcessusPage() {
  const C = useTheme();
  const processus = useCollection('/business/processus');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  if (processus.loading) return <LoadingPanel />;
  if (processus.error) return <ErrorPanel message={processus.error} onRetry={processus.reload} />;
  const procList = processus.data || [];

  return (
    <div className="space-y-6">
      {(showForm || selected) && <ProcessusForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={processus.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouveau processus</button>
      </div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="Processus cartographiés" value={procList.length} color={C.blue} icon={ClipboardList} />
        <KpiCard label="Avec propriétaire" value={procList.filter((p) => p.proprietaire).length} color={C.green} icon={ShieldCheck} />
      </div>
      <Panel title="Processus par propriétaire">
        {procList.length ? <DonutChart data={procList.map((p) => ({ name: p.proprietaire || 'Non assigné', value: 1 }))} colors={[C.blue, C.green, C.amber, C.red, '#8B5CF6']} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun processus enregistré</p>}
      </Panel>
      <Panel title="Registre des processus">
        {procList.length
          ? <DataTable columns={['Processus', 'Propriétaire', 'Objectifs', 'KPI']} rows={procList.map((p) => [p.nom, p.proprietaire || '—', p.objectifs || '—', p.kpi || '—'])} onRowClick={(i) => setSelected(procList[i])} />
          : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun processus enregistré pour le moment</p>}
      </Panel>
    </div>
  );
}

function IndicateursQualitePage() {
  const C = useTheme();
  const indicateurs = useCollection('/business/indicateurs-qualite');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  if (indicateurs.loading) return <LoadingPanel />;
  if (indicateurs.error) return <ErrorPanel message={indicateurs.error} onRetry={indicateurs.reload} />;
  const indList = indicateurs.data || [];
  const cibles = indList.filter((i) => (i.sensInverse ? i.actuel <= i.cible : i.actuel >= i.cible)).length;

  return (
    <div className="space-y-6">
      {(showForm || selected) && <IndicateurForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={indicateurs.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvel indicateur</button>
      </div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="Indicateurs suivis" value={indList.length} color={C.blue} icon={Activity} />
        <KpiCard label="Dans la cible" value={cibles} color={C.green} icon={ShieldCheck} />
        <KpiCard label="Hors cible" value={indList.length - cibles} color={C.red} icon={AlertTriangle} />
      </div>
      <Panel title="Indicateurs qualité vs cibles">
        {indList.length === 0 ? <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun indicateur enregistré</p> : (
          <div className="space-y-3">
            {indList.map((i) => {
              const atteint = i.sensInverse ? i.actuel <= i.cible : i.actuel >= i.cible;
              const pct = Math.min(100, (i.actuel / i.cible) * 100);
              return (
                <div key={i.id} className="cursor-pointer" onClick={() => setSelected(i)}>
                  <div className="flex justify-between text-xs mb-1"><span style={{ color: C.text }}>{i.indicateur}</span><span style={{ color: C.textMuted }}>{i.actuel}{i.unite} / {i.cible}{i.unite}</span></div>
                  <div className="h-2 rounded-full" style={{ backgroundColor: C.border }}><div className="h-2 rounded-full" style={{ width: `${pct}%`, backgroundColor: atteint ? C.green : C.amber }} /></div>
                </div>
              );
            })}
          </div>
        )}
      </Panel>
    </div>
  );
}

function QualiteReclamationsPage() {
  const C = useTheme();
  const reclamations = useCollection('/business/reclamations');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  if (reclamations.loading) return <LoadingPanel />;
  if (reclamations.error) return <ErrorPanel message={reclamations.error} onRetry={reclamations.reload} />;
  const list = reclamations.data || [];
  const enCours = list.filter((r) => r.statut === 'OPEN').length;
  const sorted = [...list].sort((a, b) => new Date(b.date) - new Date(a.date));

  return (
    <div className="space-y-6">
      {(showForm || selected) && <ReclamationForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={reclamations.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvelle réclamation</button>
      </div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="Réclamations" value={list.length} objectif={`${enCours} en cours`} color={C.amber} icon={Bell} />
        <KpiCard label="Gravité élevée" value={list.filter((r) => r.gravite === 'Élevée').length} color={C.red} icon={AlertTriangle} />
      </div>
      <Panel title="Registre des réclamations clients">
        {sorted.length
          ? <DataTable columns={['Client', 'Motif', 'Date', 'Gravité', 'Statut']}
              rows={sorted.map((r) => [r.client, r.motif, new Date(r.date).toLocaleDateString('fr-FR'), <span style={{ color: r.gravite === 'Élevée' ? C.red : r.gravite === 'Modérée' ? C.amber : C.textMuted }}>{r.gravite}</span>, <StatusChip statut={r.statut} />])}
              onRowClick={(i) => setSelected(sorted[i])} />
          : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune réclamation enregistrée pour le moment</p>}
      </Panel>
    </div>
  );
}

function QualiteFournisseursPage() {
  const C = useTheme();
  const fournisseurs = useCollection('/business/fournisseurs');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  if (fournisseurs.loading) return <LoadingPanel />;
  if (fournisseurs.error) return <ErrorPanel message={fournisseurs.error} onRetry={fournisseurs.reload} />;
  const list = fournisseurs.data || [];
  const statutLabel = { HOMOLOGUE: 'Conforme', SOUS_SURVEILLANCE: 'Sous surveillance', PLAN_ACTION_REQUIS: 'Non conforme' };

  return (
    <div className="space-y-6">
      {(showForm || selected) && <FournisseurForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={fournisseurs.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouveau fournisseur</button>
      </div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="Fournisseurs évalués" value={list.length} color={C.blue} icon={FlaskConical} />
        <KpiCard label="Sous surveillance" value={list.filter((f) => f.statut !== 'HOMOLOGUE').length} color={C.amber} icon={AlertTriangle} />
      </div>
      <Panel title="Évaluation des fournisseurs">
        {list.length
          ? <DataTable columns={['Fournisseur', 'Catégorie', 'Score qualité', 'Dernière évaluation', 'Statut']}
              rows={list.map((f) => [
                f.nom, f.categorie || '—',
                f.scoreQualite != null ? <div className="flex items-center gap-2"><div className="w-20 h-1.5 rounded-full" style={{ backgroundColor: C.border }}><div className="h-1.5 rounded-full" style={{ width: `${f.scoreQualite}%`, backgroundColor: f.scoreQualite >= 85 ? C.green : f.scoreQualite >= 70 ? C.amber : C.red }} /></div><span>{f.scoreQualite}%</span></div> : '—',
                f.derniereEvaluation ? new Date(f.derniereEvaluation).toLocaleDateString('fr-FR') : '—', <StatusChip statut={statutLabel[f.statut] || f.statut} />,
              ])}
              onRowClick={(i) => setSelected(list[i])} />
          : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun fournisseur enregistré pour le moment</p>}
      </Panel>
    </div>
  );
}

function SafetyEventForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ type: record?.type || 'INCIDENT', title: record?.title || '', description: record?.description || '', occurredAt: record ? new Date(record.occurredAt).toISOString().slice(0, 10) : new Date().toISOString().slice(0, 10), severity: record?.severity || 2, withLostTime: record?.withLostTime || false, lostDays: record?.lostDays ?? '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  async function submit(e) {
    e.preventDefault();
    setSaving(true); setError(null);
    try {
      const payload = { ...form, severity: Number(form.severity), occurredAt: new Date(form.occurredAt).toISOString(), lostDays: form.withLostTime && form.lostDays !== '' ? Number(form.lostDays) : null };
      if (editing) await api.patch(`/business/safety-events/${record.id}`, payload);
      else await api.post('/business/safety-events', payload);
      onCreated();
      onClose();
    } catch (err) {
      setError(err.message || 'Impossible d\'enregistrer l\'événement');
    }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.title, `/business/safety-events/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }

  return (
    <Modal title={editing ? "Modifier l'événement sécurité" : 'Déclarer un événement sécurité'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Type">
          <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="ACCIDENT">Accident</option>
            <option value="INCIDENT">Incident</option>
            <option value="PRESQU_ACCIDENT">Presqu'accident</option>
            <option value="SITUATION_DANGEREUSE">Situation dangereuse</option>
          </select>
        </FormField>
        <FormField label="Titre">
          <input required value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Fuite mineure de vapeur" />
        </FormField>
        <FormField label="Description">
          <textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} rows={3} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} />
        </FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Date">
            <input required type="date" value={form.occurredAt} onChange={(e) => setForm({ ...form, occurredAt: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} />
          </FormField>
          <FormField label="Sévérité (1 à 5)">
            <select value={form.severity} onChange={(e) => setForm({ ...form, severity: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              {[1, 2, 3, 4, 5].map((n) => <option key={n} value={n}>{n}</option>)}
            </select>
          </FormField>
        </div>
        <label className="flex items-center gap-2 text-xs mb-3" style={{ color: C.textMuted }}>
          <input type="checkbox" checked={form.withLostTime} onChange={(e) => setForm({ ...form, withLostTime: e.target.checked })} />
          Accident avec arrêt de travail
        </label>
        {form.withLostTime && (
          <FormField label="Nombre de journées perdues">
            <input type="number" min="0" value={form.lostDays} onChange={(e) => setForm({ ...form, lostDays: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} />
          </FormField>
        )}
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>
            {saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

function WorkedHoursForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({
    periodStart: record ? new Date(record.periodStart).toISOString().slice(0, 10) : new Date(new Date().getFullYear(), 0, 1).toISOString().slice(0, 10),
    periodEnd: record ? new Date(record.periodEnd).toISOString().slice(0, 10) : new Date().toISOString().slice(0, 10),
    hours: record?.hours ?? '', site: record?.site || '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, periodStart: new Date(form.periodStart).toISOString(), periodEnd: new Date(form.periodEnd).toISOString() };
      if (editing) await api.patch(`/business/worked-hours/${record.id}`, payload);
      else await api.post('/business/worked-hours', { code: genCode('HT'), ...payload });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(`${form.periodStart} → ${form.periodEnd}`, `/business/worked-hours/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier les heures travaillées' : 'Nouvelles heures travaillées'} onClose={onClose}>
      <form onSubmit={submit}>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Début de période"><input required type="date" value={form.periodStart} onChange={(e) => setForm({ ...form, periodStart: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Fin de période"><input required type="date" value={form.periodEnd} onChange={(e) => setForm({ ...form, periodEnd: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Heures travaillées (total sur la période)"><input required type="number" min="0" step="any" value={form.hours} onChange={(e) => setForm({ ...form, hours: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Site (optionnel)"><input value={form.site} onChange={(e) => setForm({ ...form, site: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function SecuriteAccidentsPage() {
  const C = useTheme();
  const events = useCollection('/business/safety-events');
  const workedHours = useCollection('/business/worked-hours');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  const [showHoursForm, setShowHoursForm] = useState(false);
  const [selectedHours, setSelectedHours] = useState(null);
  if (events.loading || workedHours.loading) return <LoadingPanel />;
  if (events.error) return <ErrorPanel message={events.error} onRetry={events.reload} />;
  const list = events.data || [];
  const hoursList = workedHours.data || [];
  const byType = groupCount(list, (e) => e.type);
  const bySeverity = groupCount(list, (e) => `Sévérité ${e.severity}`);
  const sorted = [...list].sort((a, b) => new Date(b.occurredAt) - new Date(a.occurredAt));

  // TF/TG calculés sur l'année civile en cours, à partir des heures
  // travaillées enregistrées et des accidents avec arrêt de travail.
  const yearStart = new Date(new Date().getFullYear(), 0, 1);
  const eventsThisYear = list.filter((e) => new Date(e.occurredAt) >= yearStart);
  const hoursThisYear = hoursList.filter((h) => new Date(h.periodStart) >= yearStart || new Date(h.periodEnd) >= yearStart);
  const totalHours = hoursThisYear.reduce((s, h) => s + h.hours, 0);
  const accidentsAvecArret = eventsThisYear.filter((e) => e.withLostTime).length;
  const journeesPerdues = eventsThisYear.reduce((s, e) => s + (e.withLostTime ? (e.lostDays || 0) : 0), 0);
  const tf = totalHours > 0 ? (accidentsAvecArret * 1000000) / totalHours : null;
  const tg = totalHours > 0 ? (journeesPerdues * 1000) / totalHours : null;

  return (
    <div className="space-y-6">
      {(showForm || selected) && <SafetyEventForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={events.reload} />}
      {(showHoursForm || selectedHours) && <WorkedHoursForm record={selectedHours} onClose={() => { setShowHoursForm(false); setSelectedHours(null); }} onCreated={workedHours.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <div className="flex gap-2">
          <button onClick={() => setShowHoursForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, color: C.text }}>+ Heures travaillées</button>
          <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Déclarer un événement</button>
        </div>
      </div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="Événements enregistrés" value={list.length} color={C.blue} icon={AlertTriangle} />
        <KpiCard label="Sévérité moyenne" value={list.length ? (list.reduce((s, e) => s + e.severity, 0) / list.length).toFixed(1) : '—'} color={C.amber} icon={Activity} />
        <KpiCard label="Taux de Fréquence (TF)" value={tf != null ? tf.toFixed(1) : '—'} color={C.red} icon={AlertTriangle} />
        <KpiCard label="Taux de Gravité (TG)" value={tg != null ? tg.toFixed(2) : '—'} color={C.red} icon={Activity} />
      </div>
      {totalHours === 0
        ? <p className="text-xs" style={{ color: C.textMuted }}>Aucune heure travaillée enregistrée pour {new Date().getFullYear()} — utilisez « + Heures travaillées » pour pouvoir calculer le TF/TG.</p>
        : <p className="text-xs" style={{ color: C.textMuted }}>Calculé sur {new Date().getFullYear()} : {totalHours.toLocaleString('fr-FR')} h travaillées, {accidentsAvecArret} accident(s) avec arrêt, {journeesPerdues} journée(s) perdue(s). TF = accidents avec arrêt × 1 000 000 / heures. TG = journées perdues × 1 000 / heures.</p>}
      <div className="grid grid-cols-2 gap-4">
        <Panel title="Répartition par type d'événement">
          {byType.length ? <DonutChart data={byType} colors={[C.red, '#F97316', C.amber, '#8B5CF6', C.blue, C.green]} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun événement enregistré</p>}
        </Panel>
        <Panel title="Répartition par sévérité">
          {bySeverity.length ? <HorizontalBars data={bySeverity} labelKey="name" valueKey="value" color={C.amber} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun événement enregistré</p>}
        </Panel>
      </div>
      <Panel title="Registre des événements sécurité">
        {sorted.length
          ? <DataTable columns={['Type', 'Titre', 'Description', 'Date', 'Sévérité', 'Arrêt']} rows={sorted.map((e) => [e.type, e.title, e.description || '—', new Date(e.occurredAt).toLocaleDateString('fr-FR'), e.severity, e.withLostTime ? `${e.lostDays || 0} j` : '—'])}
              onRowClick={(i) => setSelected(sorted[i])} />
          : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun événement enregistré pour le moment</p>}
      </Panel>
      <Panel title="Heures travaillées enregistrées">
        {hoursList.length
          ? <DataTable columns={['Période', 'Heures', 'Site']} rows={hoursList.map((h) => [`${new Date(h.periodStart).toLocaleDateString('fr-FR')} → ${new Date(h.periodEnd).toLocaleDateString('fr-FR')}`, h.hours.toLocaleString('fr-FR'), h.site || '—'])}
              onRowClick={(i) => setSelectedHours(hoursList[i])} />
          : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune période enregistrée pour le moment</p>}
      </Panel>
    </div>
  );
}

function SecuriteEpiPage() {
  const C = useTheme();
  const dash = useCollection('/epi/dashboard');
  const renewals = useCollection('/epi/renewals');
  const renewalBuckets = useCollection('/epi/renewal-buckets');
  const assignments = useCollection('/epi/assignments');
  const trainings = useCollection('/business/trainings');
  const catalog = useCollection('/epi/catalog');
  const employees = useCollection('/epi/employees');
  const epiCategories = useCollection('/epi/epi-categories');
  const epcCategories = useCollection('/epi/epc-categories');
  const epcList = useCollection('/epi/epc');
  const epiInspections = useCollection('/epi/epi-inspections');
  const epcInspections = useCollection('/epi/epc-inspections');
  const matrix = useCollection('/epi/job-risk-protection');
  const [tab, setTab] = useState('stock');
  const [showEpiForm, setShowEpiForm] = useState(false);
  const [showEmpForm, setShowEmpForm] = useState(false);
  const [selectedEpi, setSelectedEpi] = useState(null);
  const [selectedEmp, setSelectedEmp] = useState(null);
  const [categoryForm, setCategoryForm] = useState(null); // {kind:'epi'|'epc', record}
  const [showEpcForm, setShowEpcForm] = useState(false);
  const [selectedEpc, setSelectedEpc] = useState(null);
  const [showEpiInspForm, setShowEpiInspForm] = useState(false);
  const [showEpcInspForm, setShowEpcInspForm] = useState(false);
  const [showMatrixForm, setShowMatrixForm] = useState(false);
  const [selectedMatrix, setSelectedMatrix] = useState(null);
  const [showAssignmentForm, setShowAssignmentForm] = useState(false);
  const [receiptFor, setReceiptFor] = useState(null);

  if (dash.loading || renewals.loading || renewalBuckets.loading || assignments.loading || trainings.loading || catalog.loading || employees.loading || epiCategories.loading || epcCategories.loading || epcList.loading || epiInspections.loading || epcInspections.loading || matrix.loading) return <LoadingPanel />;
  if (dash.error) return <ErrorPanel message={dash.error} />;

  const stock = dash.data.stock || [];
  const enRupture = stock.filter((e) => e.stock <= 0).length;
  const trainingsList = trainings.data || [];
  const trainingsDone = trainingsList.filter((t) => t.status === 'DONE' || t.status === 'COMPLETED').length;
  const catalogList = catalog.data || [];
  const employeeList = employees.data || [];
  const activeEmployees = employeeList.filter((e) => e.active).length;
  const epiCatList = epiCategories.data || [];
  const epcCatList = epcCategories.data || [];
  const epcs = epcList.data || [];
  const epcNonConformes = epcs.filter((e) => e.status === 'NON_CONFORME').length;
  const assignmentList = assignments.data || [];
  const buckets = renewalBuckets.data || { expired: [], within30: [], within60: [], within90: [] };

  return (
    <div className="space-y-6">
      {(showEpiForm || selectedEpi) && <EpiCatalogForm record={selectedEpi} categories={epiCatList} onClose={() => { setShowEpiForm(false); setSelectedEpi(null); }} onCreated={() => { catalog.reload(); dash.reload(); }} />}
      {(showEmpForm || selectedEmp) && <EmployeeForm record={selectedEmp} onClose={() => { setShowEmpForm(false); setSelectedEmp(null); }} onCreated={() => { employees.reload(); dash.reload(); }} />}
      {categoryForm && <CategoryForm record={categoryForm.record} endpoint={categoryForm.kind === 'epi' ? '/epi/epi-categories' : '/epi/epc-categories'} label={categoryForm.kind === 'epi' ? 'EPI' : 'EPC'} onClose={() => setCategoryForm(null)} onCreated={() => { epiCategories.reload(); epcCategories.reload(); }} />}
      {(showEpcForm || selectedEpc) && <EpcForm record={selectedEpc} categories={epcCatList} onClose={() => { setShowEpcForm(false); setSelectedEpc(null); }} onCreated={epcList.reload} />}
      {showEpiInspForm && <EpiInspectionForm epiOptions={catalogList} onClose={() => setShowEpiInspForm(false)} onCreated={epiInspections.reload} />}
      {showEpcInspForm && <EpcInspectionForm epcOptions={epcs} onClose={() => setShowEpcInspForm(false)} onCreated={() => { epcInspections.reload(); epcList.reload(); }} />}
      {(showMatrixForm || selectedMatrix) && <JobRiskProtectionForm record={selectedMatrix} epiOptions={catalogList} epcOptions={epcs} onClose={() => { setShowMatrixForm(false); setSelectedMatrix(null); }} onCreated={matrix.reload} />}
      {showAssignmentForm && <AssignmentForm epiOptions={catalogList} employeeOptions={employeeList} onClose={() => setShowAssignmentForm(false)} onCreated={() => { assignments.reload(); renewalBuckets.reload(); dash.reload(); }} />}
      {receiptFor && <AssignmentReceiptModal assignment={receiptFor} onClose={() => setReceiptFor(null)} />}

      <div className="flex items-center justify-between"><LiveBadge /></div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="EPI au catalogue" value={catalogList.length} objectif={`${enRupture} en rupture de stock`} color={enRupture > 0 ? C.red : C.green} icon={ShieldCheck} />
        <KpiCard label="EPC enregistrés" value={epcs.length} objectif={`${epcNonConformes} non conforme(s)`} color={epcNonConformes > 0 ? C.red : C.green} icon={Cog} />
        <KpiCard label="Personnel actif" value={activeEmployees} objectif={`${employeeList.length} au total`} color={C.blue} icon={Users} />
        <KpiCard label="Renouvellements à venir" value={(renewals.data || []).length} color={C.amber} icon={AlertTriangle} />
      </div>

      <div className="flex flex-wrap gap-2">
        {[['stock', 'Stock EPI'], ['epc', 'Bibliothèque EPC'], ['categories', 'Catégories'], ['attribution', 'Attribution'], ['inspections', 'Inspections'], ['matrice', 'Matrice Poste/Risque'], ['personnel', 'Personnel'], ['renouvellements', 'Renouvellements']].map(([id, label]) => (
          <button key={id} onClick={() => setTab(id)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: tab === id ? C.blue : 'transparent', color: tab === id ? '#fff' : C.textMuted }}>{label}</button>
        ))}
      </div>

      {tab === 'stock' && (
        <Panel title="Catalogue et stock d'EPI" right={<button onClick={() => setShowEpiForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvel EPI</button>}>
          {stock.length
            ? <DataTable columns={['EPI', 'Fréquence', 'Stock', "Distribué aujourd'hui"]} rows={stock.map((e) => [e.name, e.frequency === 'DAILY' ? 'Quotidienne' : 'Annuelle', <span style={{ color: e.stock <= 0 ? C.red : C.text }}>{e.stock}</span>, e.dailyDistributed])}
                onRowClick={(i) => setSelectedEpi(stock[i])} />
            : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun EPI enregistré — utilisez « + Nouvel EPI » pour commencer le catalogue</p>}
          <p className="text-[11px] mt-3" style={{ color: C.textMuted }}>Le stock affiché est calculé à partir des mouvements (réceptions/distributions) déjà enregistrés dans l'application Windows/Android.</p>
        </Panel>
      )}

      {tab === 'epc' && (
        <Panel title="Bibliothèque des équipements de protection collective" right={<button onClick={() => setShowEpcForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvel EPC</button>}>
          {epcs.length
            ? <DataTable columns={['Code', 'Désignation', 'Catégorie', 'Localisation', 'Prochaine inspection', 'Statut']}
                rows={epcs.map((e) => [e.code, e.name, e.category?.name || '—', e.location || '—', e.nextInspectionAt ? new Date(e.nextInspectionAt).toLocaleDateString('fr-FR') : '—', <StatusChip statut={e.status === 'ACTIVE' ? 'Conforme' : e.status === 'NON_CONFORME' ? 'Non conforme' : 'Sous surveillance'} />])}
                onRowClick={(i) => setSelectedEpc(epcs[i])} />
            : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun EPC enregistré — utilisez « + Nouvel EPC » pour commencer</p>}
        </Panel>
      )}

      {tab === 'categories' && (
        <div className="grid grid-cols-2 gap-4">
          <Panel title="Catégories EPI" right={<button onClick={() => setCategoryForm({ kind: 'epi', record: null })} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Catégorie</button>}>
            {epiCatList.length
              ? <div className="space-y-1">{epiCatList.map((c) => <div key={c.id} className="flex items-center justify-between text-sm py-1.5 cursor-pointer" style={{ borderTop: `1px solid ${C.border}`, color: C.text }} onClick={() => setCategoryForm({ kind: 'epi', record: c })}>{c.name}</div>)}</div>
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune catégorie EPI</p>}
          </Panel>
          <Panel title="Catégories EPC" right={<button onClick={() => setCategoryForm({ kind: 'epc', record: null })} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Catégorie</button>}>
            {epcCatList.length
              ? <div className="space-y-1">{epcCatList.map((c) => <div key={c.id} className="flex items-center justify-between text-sm py-1.5 cursor-pointer" style={{ borderTop: `1px solid ${C.border}`, color: C.text }} onClick={() => setCategoryForm({ kind: 'epc', record: c })}>{c.name}</div>)}</div>
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune catégorie EPC</p>}
          </Panel>
        </div>
      )}

      {tab === 'inspections' && (
        <div className="space-y-4">
          <Panel title="Inspections EPI" right={<button onClick={() => setShowEpiInspForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvelle inspection</button>}>
            {(epiInspections.data || []).length
              ? <DataTable columns={['EPI', 'Date', 'Résultat', 'Observations']} rows={epiInspections.data.map((i) => [i.epi?.name || '—', new Date(i.inspectedAt).toLocaleDateString('fr-FR'), <StatusChip statut={i.result === 'CONFORME' ? 'Conforme' : i.result === 'NON_CONFORME' ? 'Non conforme' : i.result} />, i.observations || '—'])} />
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune inspection EPI enregistrée</p>}
          </Panel>
          <Panel title="Inspections EPC" right={<button onClick={() => setShowEpcInspForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvelle inspection</button>}>
            {(epcInspections.data || []).length
              ? <DataTable columns={['EPC', 'Date', 'Résultat', 'Observations']} rows={epcInspections.data.map((i) => [i.epc?.name || '—', new Date(i.inspectedAt).toLocaleDateString('fr-FR'), <StatusChip statut={i.result === 'CONFORME' ? 'Conforme' : i.result === 'NON_CONFORME' ? 'Non conforme' : i.result} />, i.observations || '—'])} />
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune inspection EPC enregistrée</p>}
          </Panel>
        </div>
      )}

      {tab === 'matrice' && (
        <Panel title="Matrice Poste → Danger → Risque → Mesure → EPI/EPC" right={<button onClick={() => setShowMatrixForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvelle ligne</button>}>
          {(matrix.data || []).length
            ? <DataTable columns={['Poste', 'Danger', 'Risque', 'Mesure', 'EPI', 'EPC']}
                rows={matrix.data.map((m) => [m.jobTitle, m.hazard, m.riskDescription || '—', m.preventionMeasure || '—', m.epi?.name || '—', m.epc?.name || '—'])}
                onRowClick={(i) => setSelectedMatrix(matrix.data[i])} />
            : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune ligne enregistrée — utilisez « + Nouvelle ligne » pour commencer la matrice</p>}
        </Panel>
      )}

      {tab === 'attribution' && (
        <Panel title="Registre des dotations" right={<button onClick={() => setShowAssignmentForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvelle dotation</button>}>
          {assignmentList.length
            ? <DataTable columns={['Code', 'Employé', 'EPI', 'Quantité', 'Date', 'Renouvellement', 'Reçu']}
                rows={assignmentList.map((a) => [a.code, `${a.employee?.firstName ?? ''} ${a.employee?.lastName ?? ''}`, a.epi?.name || '—', a.quantity, new Date(a.distributedAt).toLocaleDateString('fr-FR'), a.renewalAt ? new Date(a.renewalAt).toLocaleDateString('fr-FR') : '—', <button onClick={(e) => { e.stopPropagation(); setReceiptFor(a); }} className="text-xs" style={{ color: C.blue }}>Voir le reçu</button>])} />
            : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune dotation enregistrée — utilisez « + Nouvelle dotation » pour commencer</p>}
        </Panel>
      )}

      {tab === 'personnel' && (
        <Panel title="Liste du personnel" right={<button onClick={() => setShowEmpForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvel employé</button>}>
          {employeeList.length
            ? <DataTable columns={['Matricule', 'Nom', 'Département', 'Poste', 'Statut']}
                rows={employeeList.map((e) => [e.matricule, `${e.firstName} ${e.lastName}`, e.department || '—', e.position || '—', <StatusChip statut={e.active ? 'Conforme' : 'Non conforme'} />])}
                onRowClick={(i) => setSelectedEmp(employeeList[i])} />
            : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun employé enregistré — utilisez « + Nouvel employé » pour commencer</p>}
        </Panel>
      )}

      {tab === 'renouvellements' && (
        <div className="space-y-4">
          <div className="flex flex-wrap gap-3">
            <KpiCard label="Expirés" value={buckets.expired.length} color={C.red} icon={AlertTriangle} />
            <KpiCard label="Sous 30 jours" value={buckets.within30.length} color={C.red} icon={AlertTriangle} />
            <KpiCard label="Sous 60 jours" value={buckets.within60.length} color={C.amber} icon={Activity} />
            <KpiCard label="Sous 90 jours" value={buckets.within90.length} color={C.blue} icon={ClipboardList} />
          </div>
          {[['🔴 Expirés', buckets.expired, C.red], ['🔴 À renouveler sous 30 jours', buckets.within30, C.red], ['🟠 À renouveler sous 60 jours', buckets.within60, C.amber], ['🟡 À renouveler sous 90 jours', buckets.within90, C.blue]].map(([title, list, color]) => (
            <Panel key={title} title={title}>
              {list.length
                ? <DataTable columns={['Employé', 'EPI', 'Échéance']} rows={list.map((r) => [`${r.employee?.firstName ?? ''} ${r.employee?.lastName ?? ''}`, r.epi?.name ?? '—', <span style={{ color }}>{new Date(r.renewalAt).toLocaleDateString('fr-FR')}</span>])} />
                : <p className="text-sm text-center py-4" style={{ color: C.textMuted }}>Aucune dotation dans ce palier</p>}
            </Panel>
          ))}
        </div>
      )}
    </div>
  );
}

function SecuriteHygienePage() {
  const C = useTheme();
  const visites = useCollection('/business/visites-medicales');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  if (visites.loading) return <LoadingPanel />;
  if (visites.error) return <ErrorPanel message={visites.error} onRetry={visites.reload} />;
  const list = visites.data || [];
  const now = new Date();
  const enRetard = list.filter((v) => v.prochaineVisite && new Date(v.prochaineVisite) < now).length;
  const avecReserves = list.filter((v) => v.aptitude === 'Apte avec réserves').length;
  const inaptes = list.filter((v) => v.aptitude === 'Inapte').length;
  const parAptitude = groupCount(list.filter((v) => v.aptitude), (v) => v.aptitude);
  const sorted = [...list].sort((a, b) => (a.prochaineVisite ? new Date(a.prochaineVisite) : Infinity) - (b.prochaineVisite ? new Date(b.prochaineVisite) : Infinity));

  return (
    <div className="space-y-6">
      {(showForm || selected) && <VisiteMedicaleForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={visites.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvelle visite</button>
      </div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="Visites enregistrées" value={list.length} color={C.blue} icon={HeartPulse} />
        <KpiCard label="En retard" value={enRetard} color={C.red} icon={AlertTriangle} />
        <KpiCard label="Aptitudes avec réserves" value={avecReserves} color={C.amber} icon={HeartPulse} />
        <KpiCard label="Inaptes" value={inaptes} color={C.red} icon={AlertTriangle} />
      </div>
      <div className="grid grid-cols-2 gap-4">
        <Panel title="Répartition des aptitudes">{parAptitude.length ? <DonutChart data={parAptitude} colors={[C.green, C.amber, C.red]} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucune aptitude renseignée</p>}</Panel>
        <Panel title="Prochaines visites par employé">
          {sorted.length ? (
            <div className="space-y-2">
              {sorted.map((v) => {
                const late = v.prochaineVisite && new Date(v.prochaineVisite) < now;
                const jours = v.prochaineVisite ? Math.round((new Date(v.prochaineVisite) - now) / (1000 * 60 * 60 * 24)) : null;
                return (
                  <div key={v.id} className="flex items-center justify-between text-sm cursor-pointer" onClick={() => setSelected(v)}>
                    <span style={{ color: C.text }}>{v.employeNom}</span>
                    <span style={{ color: late ? C.red : C.green }}>{v.prochaineVisite ? (late ? `${Math.abs(jours)} j de retard` : `dans ${jours} j`) : '—'}</span>
                  </div>
                );
              })}
            </div>
          ) : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucune visite enregistrée</p>}
        </Panel>
      </div>
    </div>
  );
}

function EnvironnementPage() {
  const C = useTheme();
  const records = useCollection('/business/environment');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  if (records.loading) return <LoadingPanel />;
  if (records.error) return <ErrorPanel message={records.error} onRetry={records.reload} />;
  const list = records.data || [];
  const byType = {};
  list.forEach((r) => { byType[r.type] = (byType[r.type] || 0) + (r.value || 0); });
  const donutData = Object.entries(byType).map(([name, value]) => ({ name, value }));
  const sorted = [...list].sort((a, b) => new Date(b.recordedAt) - new Date(a.recordedAt));

  return (
    <div className="space-y-6">
      {(showForm || selected) && <EnvironmentForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={records.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouveau relevé</button>
      </div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="Relevés enregistrés" value={list.length} color={C.blue} icon={ClipboardList} />
        <KpiCard label="Types de relevés" value={Object.keys(byType).length} color={C.green} icon={Leaf} />
        <KpiCard label="Dernier relevé" value={sorted[0] ? new Date(sorted[0].recordedAt).toLocaleDateString('fr-FR') : '—'} color={C.amber} icon={Activity} />
      </div>
      <div className="grid grid-cols-2 gap-4">
        <Panel title="Répartition par type de relevé (somme des valeurs)">
          {donutData.length ? <DonutChart data={donutData} colors={[C.red, C.amber, C.blue, C.green, '#8B5CF6', C.textMuted]} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun relevé enregistré</p>}
        </Panel>
        <Panel title="Détail par type"><HorizontalBars data={donutData} labelKey="name" valueKey="value" color={C.blue} /></Panel>
      </div>
      <Panel title="Registre des relevés environnementaux">
        {sorted.length
          ? <DataTable columns={['Type', 'Valeur', 'Unité', 'Site', 'Date', 'Notes']} rows={sorted.map((r) => [r.type, r.value, r.unit || '—', r.site || '—', new Date(r.recordedAt).toLocaleDateString('fr-FR'), r.notes || '—'])}
              onRowClick={(i) => setSelected(sorted[i])} />
          : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun relevé enregistré pour le moment</p>}
      </Panel>
    </div>
  );
}

function RisquesPage() {
  const C = useTheme();
  const risks = useCollection('/business/risks');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  if (risks.loading) return <LoadingPanel />;
  if (risks.error) return <ErrorPanel message={risks.error} onRetry={risks.reload} />;
  const list = risks.data || [];
  const adapted = list.map((r) => ({ risque: r.hazard, cause: r.activity || r.measures || '—', probabilite: r.probability, gravite: r.severity, responsable: '—', maitrise: r.status, score: r.score, raw: r }));
  const critiques = adapted.filter((r) => r.score >= 15).length;

  return (
    <div className="space-y-6">
      {(showForm || selected) && <RiskForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={risks.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouveau risque</button>
      </div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="Risques recensés" value={adapted.length} color={C.blue} icon={AlertTriangle} />
        <KpiCard label="Risques critiques (≥15)" value={critiques} color={C.red} icon={AlertTriangle} />
        <KpiCard label="Score moyen" value={adapted.length ? Math.round(adapted.reduce((s, r) => s + r.score, 0) / adapted.length) : '—'} color={C.amber} icon={Activity} />
      </div>
      <p className="text-xs" style={{ color: C.textMuted }}>Le champ « Responsable » n'existe pas encore sur votre modèle de risque — dites-moi si vous voulez que je l'ajoute. Cliquez une ligne du registre pour la modifier.</p>
      <div className="grid grid-cols-2 gap-4">
        <Panel title="Matrice des risques 5×5">{adapted.length ? <RiskMatrix5x5 risques={adapted} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun risque enregistré</p>}</Panel>
        <Panel title="Cartographie — criticité décroissante">
          {adapted.length ? <HorizontalBars data={[...adapted].sort((a, b) => b.score - a.score)} labelKey="risque" valueKey="score" color={C.amber} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun risque enregistré</p>}
        </Panel>
      </div>
      <Panel title="Registre complet des risques">
        {adapted.length
          ? <DataTable columns={['Risque', 'Activité / Mesures', 'Probabilité', 'Gravité', 'Score', 'Statut']}
              rows={adapted.map((r) => [r.risque, r.cause, r.probabilite, r.gravite, r.score, <StatusChip statut={r.score >= 15 ? 'Non conforme' : r.score >= 8 ? 'Sous surveillance' : 'Conforme'} />])}
              onRowClick={(i) => setSelected(adapted[i].raw)} />
          : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun risque enregistré pour le moment</p>}
      </Panel>
    </div>
  );
}

function AuditsPage() {
  const C = useTheme();
  const audits = useCollection('/business/audits');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  if (audits.loading) return <LoadingPanel />;
  if (audits.error) return <ErrorPanel message={audits.error} onRetry={audits.reload} />;
  const list = audits.data || [];
  const planifies = list.filter((a) => a.status === 'PLANNED').length;
  const scores = list.filter((a) => a.score != null);
  const sorted = [...list].sort((a, b) => new Date(b.auditDate) - new Date(a.auditDate));

  return (
    <div className="space-y-6">
      {(showForm || selected) && <AuditForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={audits.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Planifier un audit</button>
      </div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="Audits au programme" value={list.length} color={C.blue} icon={ClipboardCheck} />
        <KpiCard label="Planifiés" value={planifies} color={C.amber} icon={Activity} />
        <KpiCard label="Réalisés / en cours" value={list.length - planifies} color={C.green} icon={ShieldCheck} />
        <KpiCard label="Score moyen" value={scores.length ? `${Math.round(scores.reduce((s, a) => s + a.score, 0) / scores.length)}%` : '—'} color={C.blue} icon={ClipboardList} />
      </div>
      <p className="text-xs" style={{ color: C.textMuted }}>Cliquez une ligne pour la modifier. Pas de suppression disponible pour les audits — votre API ne l'expose pas encore.</p>
      <Panel title="Programme d'audits">
        {sorted.length
          ? <DataTable columns={['Titre', 'Référence', 'Date', 'Statut', 'Score']} rows={sorted.map((a) => [a.title, a.reference || '—', new Date(a.auditDate).toLocaleDateString('fr-FR'), <StatusChip statut={a.status} />, a.score != null ? `${a.score}%` : '—'])}
              onRowClick={(i) => setSelected(sorted[i])} />
          : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun audit programmé pour le moment</p>}
      </Panel>
    </div>
  );
}

function NonConformitesPage() {
  const C = useTheme();
  const ncs = useCollection('/business/non-conformities');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  if (ncs.loading) return <LoadingPanel />;
  if (ncs.error) return <ErrorPanel message={ncs.error} onRetry={ncs.reload} />;
  const list = ncs.data || [];
  const bySource = groupCount(list, (n) => n.source).map((s) => ({ cause: s.name, occurrences: s.value }));
  const ouvertes = list.filter((n) => n.status !== 'CLOSED').length;
  const sorted = [...list].sort((a, b) => new Date(b.occurredAt) - new Date(a.occurredAt));

  return (
    <div className="space-y-6">
      {(showForm || selected) && <NonConformityForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={ncs.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Déclarer une non-conformité</button>
      </div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="Non-conformités" value={list.length} objectif={`${ouvertes} ouverte(s)`} color={C.red} icon={FileWarning} />
        <KpiCard label="Sources identifiées" value={bySource.length} color={C.blue} icon={ClipboardList} />
      </div>
      <Panel title="Diagramme de Pareto — par source de non-conformité" subtitle="Loi des 80/20 : occurrences (barres) et % cumulé (courbe)">
        {bySource.length ? <ParetoChart causes={bySource} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucune non-conformité enregistrée</p>}
      </Panel>
      <Panel title="Registre des non-conformités">
        {list.length
          ? <DataTable columns={['Titre', 'Source', 'Sévérité', 'Date', 'Statut']} rows={sorted.map((n) => [n.title, n.source || '—', n.severity, new Date(n.occurredAt).toLocaleDateString('fr-FR'), <StatusChip statut={n.status} />])}
              onRowClick={(i) => setSelected(sorted[i])} />
          : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune non-conformité enregistrée pour le moment</p>}
      </Panel>
    </div>
  );
}

function CapaPage() {
  const C = useTheme();
  const actions = useCollection('/business/actions');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  if (actions.loading) return <LoadingPanel />;
  if (actions.error) return <ErrorPanel message={actions.error} onRetry={actions.reload} />;
  const list = actions.data || [];
  const stats = computeCapaStatsReal(list);
  const sorted = [...list].sort((a, b) => (a.dueDate ? new Date(a.dueDate) : Infinity) - (b.dueDate ? new Date(b.dueDate) : Infinity));

  return (
    <div className="space-y-6">
      {(showForm || selected) && <ActionForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={actions.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvelle action</button>
      </div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="Actions totales" value={stats.total} color={C.blue} icon={Wrench} />
        <KpiCard label="Terminées" value={stats.terminees} color={C.green} icon={ShieldCheck} />
        <KpiCard label="En cours" value={stats.enCours} color={C.blue} icon={Activity} />
        <KpiCard label="En retard" value={stats.enRetard} color={C.red} icon={AlertTriangle} />
      </div>
      <div className="grid grid-cols-3 gap-4">
        <Panel title="Statut des actions" className="col-span-1"><DonutChart data={[{ name: 'Terminées', value: stats.terminees }, { name: 'En cours', value: stats.enCours }, { name: 'En retard', value: stats.enRetard }]} colors={[C.green, C.blue, C.red]} /></Panel>
        <Panel title="Plan d'actions correctives et préventives" className="col-span-2">
          {sorted.length
            ? <DataTable columns={['Action', 'Priorité', 'Échéance', 'Non-conformité liée', 'Statut']}
                rows={sorted.map((a) => [a.title, a.priority, a.dueDate ? new Date(a.dueDate).toLocaleDateString('fr-FR') : '—', a.nonConformity?.title || '—', <StatusChip statut={isOverdue(a.dueDate, a.status) ? 'En retard' : a.status} />])}
                onRowClick={(i) => setSelected(sorted[i])} />
            : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune action enregistrée pour le moment</p>}
        </Panel>
      </div>
    </div>
  );
}

function VeillePage() {
  const C = useTheme();
  const veille = useCollection('/business/veille-reglementaire');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  if (veille.loading) return <LoadingPanel />;
  if (veille.error) return <ErrorPanel message={veille.error} onRetry={veille.reload} />;
  const list = veille.data || [];
  const statutLabel = { A_TRAITER: 'À traiter', EN_COURS: 'En cours', INTEGREE: 'Intégrée' };
  const sorted = [...list].sort((a, b) => (a.dateApplication ? new Date(a.dateApplication) : Infinity) - (b.dateApplication ? new Date(b.dateApplication) : Infinity));

  return (
    <div className="space-y-3">
      {(showForm || selected) && <VeilleForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={veille.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouveau texte</button>
      </div>
      <Panel title="Veille réglementaire QHSE">
        {sorted.length
          ? <DataTable columns={['Texte', 'Domaine', "Date d'application", 'Statut']}
              rows={sorted.map((v) => [v.texte, v.domaine || '—', v.dateApplication ? new Date(v.dateApplication).toLocaleDateString('fr-FR') : '—', <StatusChip statut={statutLabel[v.statut] || v.statut} />])}
              onRowClick={(i) => setSelected(sorted[i])} />
          : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun texte réglementaire enregistré pour le moment</p>}
      </Panel>
    </div>
  );
}
function normalizeText(s) { return `${s}`.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, ''); }

function DocumentFolder({ label, icon: Icon, docs, defaultOpen, onOpenDoc }) {
  const C = useTheme();
  const [open, setOpen] = useState(!!defaultOpen);
  return (
    <div className="rounded-xl" style={{ backgroundColor: C.card, border: `1px solid ${C.border}` }}>
      <button onClick={() => setOpen(!open)} className="w-full flex items-center justify-between px-4 py-3">
        <span className="flex items-center gap-2 text-sm font-semibold" style={{ color: C.text }}>
          <Icon size={16} color={C.blue} />{label}
          <span className="text-xs font-normal" style={{ color: C.textMuted }}>({docs.length})</span>
        </span>
        <ChevronDown size={16} color={C.textMuted} style={{ transform: open ? 'rotate(180deg)' : 'none', transition: 'transform 0.15s' }} />
      </button>
      {open && (
        <div className="px-4 pb-3">
          {docs.length
            ? <DataTable columns={['Titre', 'Code', 'Version', 'Statut']}
                rows={docs.map((d) => [<span className="flex items-center gap-2"><FolderOpen size={14} color={C.blue} />{d.title}</span>, d.code, `v${d.currentVersion}`, <StatusChip statut={d.status === 'ACTIVE' ? 'Conforme' : d.status} />])}
                onRowClick={(i) => onOpenDoc(docs[i])} />
            : <p className="text-sm text-center py-4" style={{ color: C.textMuted }}>Aucun document dans ce dossier</p>}
        </div>
      )}
    </div>
  );
}

function DocumentationPage() {
  const C = useTheme();
  const docs = useCollection('/documents');
  const groupsQ = useCollection('/documents/groups');
  const [showUpload, setShowUpload] = useState(false);
  const [viewing, setViewing] = useState(null);
  const [addingVersionTo, setAddingVersionTo] = useState(null);
  if (docs.loading) return <LoadingPanel />;
  if (docs.error) return <ErrorPanel message={docs.error} onRetry={docs.reload} />;
  const list = docs.data || [];
  const groupLabels = {
    STRATEGIE_CONTEXTE: 'Stratégie et Contexte', RISQUES_SECURITE_CONFORMITE: 'Risques, Sécurité et Conformité',
    SUPPORTS_MAITRISE_DOCUMENTAIRE: 'Supports et Maîtrise Documentaire', OPERATIONS_MAITRISE_TERRAIN: 'Opérations et Maîtrise Terrain',
    EVALUATION_CONTROLE_AMELIORATION: 'Évaluation, Contrôle et Amélioration',
  };
  // Dossier transversal : rassemble toutes les procédures déjà en place,
  // quel que soit leur groupe ISO d'origine (un document peut donc
  // apparaître ici ET dans son dossier de groupe — deux vues, pas deux copies).
  const procedures = list.filter((d) => normalizeText(d.category).includes('procedure') || normalizeText(d.title).includes('procedure'));
  const nonClasses = list.filter((d) => !d.documentGroup);

  return (
    <div className="space-y-6">
      {showUpload && <DocumentUploadForm groups={groupsQ.data || []} onClose={() => setShowUpload(false)} onCreated={docs.reload} />}
      {viewing && <DocumentViewerModal doc={viewing} onClose={() => setViewing(null)} onNewVersion={() => { setAddingVersionTo(viewing); setViewing(null); }} onDeleted={docs.reload} />}
      {addingVersionTo && <DocumentVersionForm doc={addingVersionTo} onClose={() => setAddingVersionTo(null)} onCreated={docs.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowUpload(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Ajouter un document</button>
      </div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="Documents" value={list.length} color={C.blue} icon={FolderOpen} />
        <KpiCard label="Procédures" value={procedures.length} color={C.amber} icon={ClipboardList} />
        <KpiCard label="Groupes classés" value={new Set(list.map((d) => d.documentGroup).filter(Boolean)).size} color={C.green} icon={ShieldCheck} />
      </div>
      <p className="text-xs" style={{ color: C.textMuted }}>Cliquez un document pour le lire directement ici (PDF affiché tel quel, Word et Excel convertis en aperçu). Chaque dossier se déplie/replie au clic.</p>

      <div className="space-y-3">
        <DocumentFolder label="Procédures" icon={Wrench} docs={procedures} defaultOpen onOpenDoc={setViewing} />
        {Object.entries(groupLabels).map(([key, label]) => (
          <DocumentFolder key={key} label={label} icon={FolderOpen} docs={list.filter((d) => d.documentGroup === key)} onOpenDoc={setViewing} />
        ))}
        <DocumentFolder label="Non classés" icon={FolderOpen} docs={nonClasses} onOpenDoc={setViewing} />
      </div>
    </div>
  );
}
function ObjectifsPage() {
  const C = useTheme();
  const objectifs = useCollection('/business/objectifs-qhse');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  if (objectifs.loading) return <LoadingPanel />;
  if (objectifs.error) return <ErrorPanel message={objectifs.error} onRetry={objectifs.reload} />;
  const list = objectifs.data || [];

  return (
    <div className="space-y-4">
      {(showForm || selected) && <ObjectifForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={objectifs.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvel objectif</button>
      </div>
      {list.length === 0 && <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun objectif enregistré pour le moment</p>}
      {list.map((o) => {
        const pctRaw = o.cible === 0 ? (o.actuel === 0 ? 100 : 0) : Math.min(100, (o.actuel / o.cible) * 100);
        return (
          <Panel key={o.id} className="cursor-pointer" onClick={() => setSelected(o)}>
            <div className="flex items-center justify-between mb-2">
              <div><span className="text-sm font-semibold" style={{ color: C.text }}>{o.titre}</span>{o.pilier && <span className="text-xs ml-2" style={{ color: C.textMuted }}>({o.pilier})</span>}</div>
              <span className="text-sm font-bold" style={{ color: C.text }}>{o.actuel}{o.unite} / {o.cible}{o.unite}</span>
            </div>
            <div className="h-2 rounded-full" style={{ backgroundColor: C.border }}><div className="h-2 rounded-full" style={{ width: `${pctRaw}%`, backgroundColor: pctRaw >= 90 ? C.green : pctRaw >= 60 ? C.amber : C.red }} /></div>
            {o.echeance && <p className="text-xs mt-1" style={{ color: C.textMuted }}>Échéance : {new Date(o.echeance).toLocaleDateString('fr-FR')}</p>}
          </Panel>
        );
      })}
    </div>
  );
}
function RapportsPage() {
  const C = useTheme();
  const [derniers, setDerniers] = useState([]);
  const dashboardQ = useCollection('/dashboard');
  const auditsQ = useCollection('/business/audits');
  const risksQ = useCollection('/business/risks');
  const actionsQ = useCollection('/business/actions');
  const environmentQ = useCollection('/business/environment');
  const safetyEventsQ = useCollection('/business/safety-events');
  const epiQ = useCollection('/epi/dashboard');
  const loading = [dashboardQ, auditsQ, risksQ, actionsQ, environmentQ, safetyEventsQ, epiQ].some((q) => q.loading);

  if (loading) return <LoadingPanel />;

  const reports = reportDefinitions({
    dashboardData: dashboardQ.data, audits: auditsQ.data, risks: risksQ.data, actions: actionsQ.data,
    environment: environmentQ.data, safetyEvents: safetyEventsQ.data, epi: epiQ.data,
  });
  function generer(rep, format) {
    if (format === 'excel') {
      downloadWorkbook(rep.sheets(), `${rep.titre.replace(/[^a-zA-Z0-9]+/g, '-')}.xlsx`);
    }
    setDerniers((prev) => [{ titre: rep.titre, format, date: new Date().toLocaleString('fr-FR') }, ...prev].slice(0, 5));
  }
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between"><LiveBadge /></div>
      <div className="grid grid-cols-3 gap-4">
        {reports.map((r) => (
          <Panel key={r.id} title={r.titre} subtitle={r.description}>
            <div className="flex gap-2">
              <button onClick={() => generer(r, 'pdf')} className="flex-1 px-3 py-2 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>Générer PDF</button>
              <button onClick={() => generer(r, 'excel')} className="flex-1 px-3 py-2 rounded-lg text-xs font-medium" style={{ backgroundColor: C.cardAlt, color: C.text, border: `1px solid ${C.border}` }}>Générer Excel</button>
            </div>
          </Panel>
        ))}
      </div>
      <Panel title="Derniers rapports générés">
        {derniers.length === 0
          ? <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun rapport généré pour le moment</p>
          : <DataTable columns={['Rapport', 'Format', 'Généré le']} rows={derniers.map((d) => [d.titre, d.format.toUpperCase(), d.date])} />}
        <p className="text-xs mt-3" style={{ color: C.textMuted }}>
          « Générer PDF » ouvre un aperçu imprimable (Ctrl+P puis « Enregistrer en PDF » depuis votre navigateur) — la génération PDF directe n'est pas disponible dans cet environnement d'aperçu. « Générer Excel » télécharge un classeur réel, construit à partir de vos données actuelles.
        </p>
      </Panel>
    </div>
  );
}

function HaccpPage() {
  const C = useTheme();
  const haccp = useCollection('/business/haccp');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  if (haccp.loading) return <LoadingPanel />;
  if (haccp.error) return <ErrorPanel message={haccp.error} onRetry={haccp.reload} />;
  const list = haccp.data || [];
  const ccpCount = list.filter((h) => h.ccp).length;

  return (
    <div className="space-y-6">
      {(showForm || selected) && <HaccpForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={haccp.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouveau point HACCP</button>
      </div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="Points enregistrés" value={list.length} color={C.blue} icon={ClipboardList} />
        <KpiCard label="Points critiques (CCP)" value={ccpCount} color={C.red} icon={AlertTriangle} />
      </div>
      <Panel title="Registre HACCP">
        {list.length
          ? <DataTable columns={['Processus', 'Étape', 'Danger', 'CCP', 'Résultat']}
              rows={list.map((h) => [h.process, h.step, h.hazard, h.ccp ? <StatusChip statut="Non conforme" /> : '—', h.result || '—'])}
              onRowClick={(i) => setSelected(list[i])} />
          : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun point HACCP enregistré pour le moment</p>}
      </Panel>
    </div>
  );
}

function EquipmentPage() {
  const C = useTheme();
  const equipment = useCollection('/business/equipment');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  if (equipment.loading) return <LoadingPanel />;
  if (equipment.error) return <ErrorPanel message={equipment.error} onRetry={equipment.reload} />;
  const list = equipment.data || [];
  const statutLabel = { ACTIVE: 'Conforme', MAINTENANCE: 'Sous surveillance', HORS_SERVICE: 'Non conforme' };

  return (
    <div className="space-y-6">
      {(showForm || selected) && <EquipmentForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={equipment.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvel équipement</button>
      </div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="Équipements" value={list.length} color={C.blue} icon={Cog} />
        <KpiCard label="Hors service" value={list.filter((e) => e.status === 'HORS_SERVICE').length} color={C.red} icon={AlertTriangle} />
      </div>
      <Panel title="Registre des équipements">
        {list.length
          ? <DataTable columns={['Nom', 'Catégorie', 'Localisation', 'Prochaine inspection', 'Statut']}
              rows={list.map((e) => [e.name, e.category || '—', e.location || '—', e.nextInspectionAt ? new Date(e.nextInspectionAt).toLocaleDateString('fr-FR') : '—', <StatusChip statut={statutLabel[e.status] || e.status} />])}
              onRowClick={(i) => setSelected(list[i])} />
          : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun équipement enregistré pour le moment</p>}
      </Panel>
    </div>
  );
}

function SafetyTalkPage() {
  const C = useTheme();
  const talks = useCollection('/safety-talks');
  const [generating, setGenerating] = useState(false);
  const [error, setError] = useState(null);
  if (talks.loading) return <LoadingPanel />;
  if (talks.error) return <ErrorPanel message={talks.error} onRetry={talks.reload} />;
  const list = talks.data || [];
  const statutLabel = { DRAFT: 'Brouillon', APPROVED: 'Approuvé', DELIVERED: 'Diffusé' };

  async function generate() {
    setGenerating(true); setError(null);
    try { await api.post('/safety-talks/generate', {}); talks.reload(); }
    catch (err) { setError(err.message); }
    setGenerating(false);
  }
  async function approve(id) { await api.post(`/safety-talks/${id}/approve`, {}); talks.reload(); }
  async function deliver(id) { await api.post(`/safety-talks/${id}/deliver`, {}); talks.reload(); }
  async function del(t) { await confirmAndDelete(t.title, `/safety-talks/${t.id}`, () => talks.reload()); }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={generate} disabled={generating} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f', opacity: generating ? 0.7 : 1 }}>{generating ? 'Génération…' : "+ Générer cette semaine"}</button>
      </div>
      {error && <p className="text-xs" style={{ color: C.red }}>{error}</p>}
      <p className="text-xs" style={{ color: C.textMuted }}>Le thème est généré automatiquement à partir des accidents, incidents et non-conformités critiques des 7 derniers jours.</p>
      <div className="space-y-3">
        {list.length === 0 && <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun quart d'heure sécurité généré pour le moment</p>}
        {list.map((t) => (
          <Panel key={t.id}>
            <div className="flex items-start justify-between mb-2">
              <div>
                <p className="text-sm font-semibold" style={{ color: C.text }}>{t.title}</p>
                <p className="text-xs" style={{ color: C.textMuted }}>Semaine du {new Date(t.weekStart).toLocaleDateString('fr-FR')}</p>
              </div>
              <StatusChip statut={statutLabel[t.status] || t.status} />
            </div>
            <p className="text-xs whitespace-pre-line mb-3" style={{ color: C.text }}>{t.summary}</p>
            <div className="flex gap-2">
              {t.status === 'DRAFT' && <button onClick={() => approve(t.id)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.blue, color: '#fff' }}>Approuver</button>}
              {t.status === 'APPROVED' && <button onClick={() => deliver(t.id)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>Marquer diffusé</button>}
              <button onClick={() => del(t)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>
            </div>
          </Panel>
        ))}
      </div>
    </div>
  );
}

const PAGES = {
  pilotage: PilotagePage, 'qualite-controles': QualiteControlesPage, 'qualite-processus': QualiteProcessusPage, 'qualite-indicateurs': IndicateursQualitePage, 'qualite-reclamations': QualiteReclamationsPage, 'qualite-fournisseurs': QualiteFournisseursPage,
  'securite-accidents': SecuriteAccidentsPage, 'securite-epi': SecuriteEpiPage, 'securite-hygiene': SecuriteHygienePage,
  environnement: EnvironnementPage, risques: RisquesPage, audits: AuditsPage, 'non-conformites': NonConformitesPage, capa: CapaPage,
  documentation: DocumentationPage, 'quart-heure-securite': SafetyTalkPage, haccp: HaccpPage, equipements: EquipmentPage, veille: VeillePage, objectifs: ObjectifsPage, rapports: RapportsPage, utilisateurs: UtilisateursPage,
};

// ============================================================================
// Application
// ============================================================================
export default function QhseDashboard() {
  const [user, setUser] = useState(getStoredUser());
  const [page, setPage] = useState('pilotage');
  const [themeMode, setThemeMode] = useState('dark');
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [showChangePassword, setShowChangePassword] = useState(false);
  const C = THEMES[themeMode];
  const actionsForBadge = useCollection(user ? '/business/actions' : null);
  const capaStats = computeCapaStatsReal(actionsForBadge.data || []);
  const PageComponent = PAGES[page] || PilotagePage;

  // Si le rafraîchissement automatique finit par échouer (jeton de 30 jours
  // expiré, ou révoqué depuis un autre appareil), on ramène proprement à
  // l'écran de connexion plutôt que de laisser l'application dans un état
  // bloqué avec des erreurs partout.
  useEffect(() => {
    const onExpired = () => setUser(null);
    window.addEventListener('qhse:session-expired', onExpired);
    return () => window.removeEventListener('qhse:session-expired', onExpired);
  }, []);

  if (!user) {
    return <LoginPage onLoggedIn={setUser} />;
  }

  async function logout() {
    await apiLogout();
    setUser(null);
  }

  return (
    <ThemeContext.Provider value={C}>
      <div className="flex min-h-screen relative" style={{ backgroundColor: C.bg, fontFamily: 'Inter, system-ui, sans-serif' }}>
        {showChangePassword && <ChangeMyPasswordForm email={user.email} onClose={() => setShowChangePassword(false)} />}
        {sidebarOpen && (
          <div className="fixed inset-0 bg-black/50 z-20 md:hidden" onClick={() => setSidebarOpen(false)} />
        )}
        <aside
          className={`w-64 shrink-0 p-4 border-r overflow-y-auto fixed md:static inset-y-0 left-0 z-30 transition-transform duration-200 flex flex-col ${sidebarOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0'}`}
          style={{ borderColor: C.border, backgroundColor: C.bg }}
        >
          <div className="flex items-center justify-between gap-2 mb-6 px-2">
            <div className="flex items-center gap-2">
              <div className="w-9 h-9 rounded-lg flex items-center justify-center shrink-0" style={{ backgroundColor: C.blue }}><ShieldCheck size={20} color="#fff" /></div>
              <div>
                <div className="text-sm font-semibold" style={{ color: C.text }}>Gestion QHSE 360</div>
                <div className="text-[10px]" style={{ color: C.textMuted }}>Qualité · Sécurité · Hygiène · Environnement</div>
              </div>
            </div>
            <button className="md:hidden p-1" onClick={() => setSidebarOpen(false)}><X size={18} color={C.textMuted} /></button>
          </div>
          <div className="flex-1">
            {NAV_GROUPS.map((group) => (
              <div key={group.label} className="mb-4">
                <div className="px-3 mb-1 text-[10px] font-semibold tracking-wide" style={{ color: C.textMuted }}>{group.label}</div>
                <nav className="space-y-0.5">
                  {group.items.map((item) => {
                    const active = page === item.id, Icon = item.icon;
                    return (
                      <button key={item.id} onClick={() => { setPage(item.id); setSidebarOpen(false); }} className="w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-left transition-colors"
                        style={{ backgroundColor: active ? `${C.blue}22` : 'transparent', color: active ? C.blue : C.textMuted }}>
                        <Icon size={16} />{item.label}
                      </button>
                    );
                  })}
                </nav>
              </div>
            ))}
          </div>
          <div className="pt-3 mt-3" style={{ borderTop: `1px solid ${C.border}` }}>
            <div className="px-3 mb-2 text-xs" style={{ color: C.text }}>{user.firstName} {user.lastName}</div>
            <button onClick={() => setShowChangePassword(true)} className="w-full flex items-center gap-2 px-3 py-2 rounded-lg text-xs" style={{ color: C.textMuted }}>
              <ShieldCheck size={14} /> Changer mon mot de passe
            </button>
            <button onClick={logout} className="w-full flex items-center gap-2 px-3 py-2 rounded-lg text-xs" style={{ color: C.textMuted }}>
              <LogOut size={14} /> Se déconnecter
            </button>
          </div>
        </aside>

        <main className="flex-1 p-6 overflow-x-hidden min-w-0">
          <header className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-6">
            <div className="flex items-center gap-3">
              <button className="md:hidden p-2 rounded-lg shrink-0" style={{ backgroundColor: C.card, border: `1px solid ${C.border}` }} onClick={() => setSidebarOpen(true)}>
                <Menu size={18} color={C.text} />
              </button>
              <div>
                <h1 className="text-xl font-semibold" style={{ color: C.text }}>{PAGE_TITLES[page]}</h1>
                <p className="text-xs" style={{ color: C.textMuted }}>{new Date().toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })} · Connecté en tant que {user.email} · ISO 9001 · 14001 · 45001</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <button onClick={() => setThemeMode(themeMode === 'dark' ? 'light' : 'dark')} className="p-2 rounded-lg" style={{ backgroundColor: C.card, border: `1px solid ${C.border}` }} title="Changer de thème">
                {themeMode === 'dark' ? <Sun size={16} color={C.amber} /> : <Moon size={16} color={C.blue} />}
              </button>
              <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg" style={{ backgroundColor: C.card, border: `1px solid ${C.border}` }}>
                <Bell size={16} color={C.amber} /><span className="text-xs" style={{ color: C.text }}>{capaStats.enRetard} action(s) CAPA en retard</span>
              </div>
            </div>
          </header>
          <PageComponent />
        </main>
      </div>
    </ThemeContext.Provider>
  );
}
