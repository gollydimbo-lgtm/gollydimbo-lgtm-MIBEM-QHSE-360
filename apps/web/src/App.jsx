import React, { useState, useEffect, useMemo, useRef, createContext, useContext } from 'react';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  PieChart, Pie, Cell, ComposedChart, ReferenceLine, Bar,
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
  const categoriesQ = useCollection('/business/risk-categories');
  const workUnitsQ = useCollection('/business/work-units');
  const [form, setForm] = useState({
    hazard: record?.hazard || '', categoryId: record?.categoryId || '', workUnitId: record?.workUnitId || '',
    activity: record?.activity || '', hazardousSituation: record?.hazardousSituation || '', hazardousEvent: record?.hazardousEvent || '',
    potentialDamage: record?.potentialDamage || '', exposedPersons: record?.exposedPersons || '', exposedPersonCount: record?.exposedPersonCount ?? '',
    method: record?.method || 'GP', severity: record?.severity || 3, probability: record?.probability || 3, exposure: record?.exposure || 1,
    measures: record?.measures || '',
    residualSeverity: record?.residualSeverity ?? '', residualProbability: record?.residualProbability ?? '', residualExposure: record?.residualExposure ?? '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  function buildPayload() {
    return {
      ...form,
      severity: Number(form.severity), probability: Number(form.probability), exposure: Number(form.exposure) || 1,
      categoryId: form.categoryId || null, workUnitId: form.workUnitId || null,
      exposedPersonCount: form.exposedPersonCount === '' ? null : Number(form.exposedPersonCount),
      residualSeverity: form.residualSeverity === '' ? null : Number(form.residualSeverity),
      residualProbability: form.residualProbability === '' ? null : Number(form.residualProbability),
      residualExposure: form.residualExposure === '' ? null : Number(form.residualExposure),
    };
  }
  async function submit(e) {
    e.preventDefault();
    setSaving(true); setError(null);
    try {
      const payload = buildPayload();
      if (editing) await api.patch(`/business/risks/${record.id}`, payload);
      else await api.post('/business/risks', { code: genCode('RISK'), ...payload, status: 'ACTIVE' });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  // Réévaluer conserve l'ancienne évaluation dans l'historique (RiskEvaluation)
  // au lieu de simplement écraser les valeurs — contrairement à "Enregistrer".
  async function reevaluate() {
    setSaving(true); setError(null);
    try { await api.post(`/business/risks/${record.id}/reevaluate`, buildPayload()); onCreated(); onClose(); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.hazard, `/business/risks/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier le risque' : 'Nouveau risque'} onClose={onClose} wide>
      <form onSubmit={submit}>
        <FormField label="Danger identifié"><input required value={form.hazard} onChange={(e) => setForm({ ...form, hazard: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Chute de hauteur" /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Catégorie">
            <select value={form.categoryId} onChange={(e) => setForm({ ...form, categoryId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>{(categoriesQ.data || []).map((c) => <option key={c.id} value={c.id}>{c.label}</option>)}
            </select>
          </FormField>
          <FormField label="Unité de travail">
            <select value={form.workUnitId} onChange={(e) => setForm({ ...form, workUnitId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>{(workUnitsQ.data || []).map((w) => <option key={w.id} value={w.id}>{w.name}</option>)}
            </select>
          </FormField>
        </div>
        <FormField label="Activité concernée"><input value={form.activity} onChange={(e) => setForm({ ...form, activity: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Situation dangereuse"><input value={form.hazardousSituation} onChange={(e) => setForm({ ...form, hazardousSituation: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Événement redouté"><input value={form.hazardousEvent} onChange={(e) => setForm({ ...form, hazardousEvent: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Dommage potentiel"><input value={form.potentialDamage} onChange={(e) => setForm({ ...form, potentialDamage: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Personnes exposées"><input value={form.exposedPersons} onChange={(e) => setForm({ ...form, exposedPersons: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Opérateurs ligne 1" /></FormField>
          <FormField label="Nombre de personnes exposées"><input type="number" min="0" value={form.exposedPersonCount} onChange={(e) => setForm({ ...form, exposedPersonCount: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Méthode d'évaluation">
          <select value={form.method} onChange={(e) => setForm({ ...form, method: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="GP">Gravité × Probabilité</option>
            <option value="GPE">Gravité × Probabilité × Exposition</option>
          </select>
        </FormField>
        <div className={`grid ${form.method === 'GPE' ? 'grid-cols-3' : 'grid-cols-2'} gap-3`}>
          <FormField label="Probabilité (1-5)"><select value={form.probability} onChange={(e) => setForm({ ...form, probability: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>{[1, 2, 3, 4, 5].map((n) => <option key={n} value={n}>{n}</option>)}</select></FormField>
          <FormField label="Gravité (1-5)"><select value={form.severity} onChange={(e) => setForm({ ...form, severity: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>{[1, 2, 3, 4, 5].map((n) => <option key={n} value={n}>{n}</option>)}</select></FormField>
          {form.method === 'GPE' && <FormField label="Exposition (1-5)"><select value={form.exposure} onChange={(e) => setForm({ ...form, exposure: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>{[1, 2, 3, 4, 5].map((n) => <option key={n} value={n}>{n}</option>)}</select></FormField>}
        </div>
        {editing && <p className="text-xs mb-3" style={{ color: C.textMuted }}>Risque brut actuel : <strong style={{ color: C.text }}>{record.grossScore ?? record.score}</strong> ({record.grossLevel || '—'})</p>}
        <FormField label="Mesures de prévention existantes (résumé)"><textarea value={form.measures} onChange={(e) => setForm({ ...form, measures: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        <p className="text-xs font-medium mb-2" style={{ color: C.textMuted }}>Évaluation du risque résiduel (après mesures) — optionnelle</p>
        <div className={`grid ${form.method === 'GPE' ? 'grid-cols-3' : 'grid-cols-2'} gap-3`}>
          <FormField label="Probabilité résiduelle"><select value={form.residualProbability} onChange={(e) => setForm({ ...form, residualProbability: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="">—</option>{[1, 2, 3, 4, 5].map((n) => <option key={n} value={n}>{n}</option>)}</select></FormField>
          <FormField label="Gravité résiduelle"><select value={form.residualSeverity} onChange={(e) => setForm({ ...form, residualSeverity: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="">—</option>{[1, 2, 3, 4, 5].map((n) => <option key={n} value={n}>{n}</option>)}</select></FormField>
          {form.method === 'GPE' && <FormField label="Exposition résiduelle"><select value={form.residualExposure} onChange={(e) => setForm({ ...form, residualExposure: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="">—</option>{[1, 2, 3, 4, 5].map((n) => <option key={n} value={n}>{n}</option>)}</select></FormField>}
        </div>
        {editing && record.residualScore != null && <p className="text-xs mb-3" style={{ color: C.textMuted }}>Risque résiduel actuel : <strong style={{ color: C.text }}>{record.residualScore}</strong> ({record.residualLevel}) — statut : {record.controlStatus}</p>}
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          {editing && <button type="button" onClick={reevaluate} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.amber}22`, color: C.amber }}>Réévaluer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function AuditForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const processusQ = useCollection('/business/processus');
  const [form, setForm] = useState({ title: record?.title || '', reference: record?.reference || '', auditDate: record ? new Date(record.auditDate).toISOString().slice(0, 10) : new Date().toISOString().slice(0, 10), status: record?.status || 'PLANNED', score: record?.score ?? '', processusId: record?.processusId || '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault();
    setSaving(true); setError(null);
    try {
      const payload = { ...form, auditDate: new Date(form.auditDate).toISOString(), score: form.score === '' ? null : Number(form.score), processusId: form.processusId || null };
      if (editing) await api.patch(`/business/audits/${record.id}`, payload);
      else await api.post('/business/audits', { code: genCode('AUD'), ...payload });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.title, `/business/audits/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
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
        <FormField label="Processus concerné (optionnel)">
          <select value={form.processusId} onChange={(e) => setForm({ ...form, processusId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">—</option>{(processusQ.data || []).map((p) => <option key={p.id} value={p.id}>{p.nom}</option>)}
          </select>
        </FormField>
        {editing && <FormField label="Score (%, optionnel)"><input type="number" min="0" max="100" value={form.score} onChange={(e) => setForm({ ...form, score: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>}
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Planifier'}</button>
        </div>
      </form>
    </Modal>
  );
}

function AuditDetailModal({ audit, onClose, onChanged, onEdit }) {
  const C = useTheme();
  const [findings, setFindings] = useState(audit.auditFindings || []);
  const [showAdd, setShowAdd] = useState(false);
  const [form, setForm] = useState({ description: '', classification: '', critical: false });
  const [saving, setSaving] = useState(false);
  const [generatingId, setGeneratingId] = useState(null);
  const [error, setError] = useState(null);

  async function addFinding(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const f = await api.post(`/business/audits/${audit.id}/findings`, form);
      setFindings((prev) => [...prev, f]); setForm({ description: '', classification: '', critical: false }); setShowAdd(false);
      onChanged();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function deleteFinding(id) {
    try { await api.delete(`/business/audit-findings/${id}`); setFindings((prev) => prev.filter((f) => f.id !== id)); onChanged(); }
    catch (err) { alert(err.message); }
  }
  async function generateNc(id) {
    setGeneratingId(id);
    try {
      const updated = await api.post(`/business/audit-findings/${id}/generate-nc`, {});
      setFindings((prev) => prev.map((f) => (f.id === id ? updated : f)));
      onChanged();
    } catch (err) { alert(err.message); }
    setGeneratingId(null);
  }

  return (
    <Modal title={audit.title} onClose={onClose}>
      <div className="flex items-center justify-between mb-3">
        <p className="text-xs" style={{ color: C.textMuted }}>{new Date(audit.auditDate).toLocaleDateString('fr-FR')} · {audit.reference || 'sans référence'} · {audit.processus?.nom || 'aucun processus rattaché'}</p>
        <button onClick={onEdit} className="text-xs px-2 py-1 rounded-lg" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, color: C.text }}>Modifier l'audit</button>
      </div>

      <div className="flex items-center justify-between mb-2">
        <p className="text-sm font-semibold" style={{ color: C.text }}>Constats ({findings.length})</p>
        <button onClick={() => setShowAdd((s) => !s)} className="text-xs px-2 py-1 rounded-lg" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Constat</button>
      </div>

      {showAdd && (
        <form onSubmit={addFinding} className="p-3 rounded-lg mb-3" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}` }}>
          <FormField label="Description"><textarea required value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
          <div className="grid grid-cols-2 gap-3">
            <FormField label="Classification (optionnel)">
              <select value={form.classification} onChange={(e) => setForm({ ...form, classification: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
                <option value="">—</option>
                <option value="OBSERVATION">Observation</option><option value="ECART_MINEUR">Écart mineur</option>
                <option value="NC_MINEURE">Non-conformité mineure</option><option value="NC_MAJEURE">Non-conformité majeure</option>
                <option value="NC_CRITIQUE">Non-conformité critique</option><option value="DANGER_IMMEDIAT">Danger immédiat</option>
              </select>
            </FormField>
            <label className="flex items-center gap-2 text-xs mt-6" style={{ color: C.textMuted }}><input type="checkbox" checked={form.critical} onChange={(e) => setForm({ ...form, critical: e.target.checked })} />Constat critique</label>
          </div>
          {error && <p className="text-xs mb-2" style={{ color: C.red }}>{error}</p>}
          <button type="submit" disabled={saving} className="w-full py-2 rounded-lg text-xs font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : 'Ajouter le constat'}</button>
        </form>
      )}

      {findings.length
        ? <div className="space-y-2">
            {findings.map((f) => (
              <div key={f.id} className="p-2.5 rounded-lg" style={{ backgroundColor: C.cardAlt, border: `1px solid ${f.critical ? C.red : C.border}` }}>
                <div className="flex items-start justify-between gap-2">
                  <p className="text-sm flex-1" style={{ color: C.text }}>{f.description}</p>
                  <button onClick={() => deleteFinding(f.id)} className="text-xs" style={{ color: C.red }}>×</button>
                </div>
                <div className="flex items-center justify-between mt-1">
                  <span className="text-[10px]" style={{ color: C.textMuted }}>{f.classification || (f.critical ? 'Critique' : 'Standard')}{f.nonConformityId ? ' · NC générée' : ''}</span>
                  {!f.nonConformityId && <button onClick={() => generateNc(f.id)} disabled={generatingId === f.id} className="text-[11px] px-2 py-0.5 rounded-full" style={{ backgroundColor: `${C.red}22`, color: C.red }}>{generatingId === f.id ? '…' : 'Générer une NC'}</button>}
                </div>
              </div>
            ))}
          </div>
        : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun constat enregistré pour cet audit</p>}
    </Modal>
  );
}

function NonConformityForm({ record, prefill, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const risksQ = useCollection('/business/risks');
  const [form, setForm] = useState({
    title: record?.title || prefill?.title || '', description: record?.description || prefill?.description || '',
    source: record?.source || prefill?.source || '', severity: record?.severity || prefill?.severity || 2,
    occurredAt: record ? new Date(record.occurredAt).toISOString().slice(0, 10) : new Date().toISOString().slice(0, 10),
    status: record?.status || 'OPEN', epiId: record?.epiId || prefill?.epiId || null, epcId: record?.epcId || prefill?.epcId || null,
    riskId: record?.riskId || '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const [generatingRisk, setGeneratingRisk] = useState(false);
  async function submit(e) {
    e.preventDefault();
    setSaving(true); setError(null);
    try {
      const payload = { ...form, severity: Number(form.severity), occurredAt: new Date(form.occurredAt).toISOString(), riskId: form.riskId || null };
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
  // Point 19 : générer directement un risque à partir de cette NC plutôt que
  // de ressaisir le même danger dans le Registre des risques.
  async function generateRisk() {
    setGeneratingRisk(true); setError(null);
    try { const risk = await api.post(`/business/non-conformities/${record.id}/generate-risk`, {}); setForm({ ...form, riskId: risk.id }); onCreated(); }
    catch (err) { setError(err.message); }
    setGeneratingRisk(false);
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
        <FormField label="Risque lié (Registre des risques)">
          <select value={form.riskId} onChange={(e) => setForm({ ...form, riskId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">—</option>{(risksQ.data || []).map((r) => <option key={r.id} value={r.id}>{r.hazard}</option>)}
          </select>
          {editing && !form.riskId && <button type="button" onClick={generateRisk} disabled={generatingRisk} className="mt-2 text-xs px-2 py-1 rounded-lg" style={{ backgroundColor: C.green, color: '#052e1f' }}>{generatingRisk ? '…' : 'Générer un risque à partir de cette NC'}</button>}
        </FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function ActionForm({ record, prefill, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ title: record?.title || prefill?.title || '', description: record?.description || prefill?.description || '', priority: record?.priority || 2, dueDate: record?.dueDate ? new Date(record.dueDate).toISOString().slice(0, 10) : '', status: record?.status || 'OPEN' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault();
    setSaving(true); setError(null);
    try {
      const payload = { ...form, priority: Number(form.priority), dueDate: form.dueDate ? new Date(form.dueDate).toISOString() : null, reclamationId: prefill?.reclamationId || record?.reclamationId || undefined, safetyEventId: prefill?.safetyEventId || record?.safetyEventId || undefined };
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
  const processusQ = useCollection('/business/processus');
  const [form, setForm] = useState({
    type: record?.type || '', categorie: record?.categorie || '', sousCategorie: record?.sousCategorie || '',
    value: record?.value ?? '', unit: record?.unit || '', site: record?.site || '', processusId: record?.processusId || '',
    seuilReglementaire: record?.seuilReglementaire ?? '', conforme: record?.conforme ?? null,
    cout: record?.cout ?? '', modeTraitement: record?.modeTraitement || '', destination: record?.destination || '', notes: record?.notes || '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault();
    setSaving(true); setError(null);
    try {
      const payload = {
        ...form, value: form.value !== '' ? Number(form.value) : null, processusId: form.processusId || null,
        seuilReglementaire: form.seuilReglementaire === '' ? null : Number(form.seuilReglementaire),
        cout: form.cout === '' ? null : Number(form.cout),
      };
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
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Catégorie">
            <select value={form.categorie} onChange={(e) => setForm({ ...form, categorie: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>
              {['Déchets', 'Eau', 'Énergie', 'Carburants', 'Émissions atmosphériques', 'GES / Carbone', 'Effluents', 'Sols', 'Produits chimiques', 'Nuisances', 'Biodiversité'].map((c) => <option key={c} value={c}>{c}</option>)}
            </select>
          </FormField>
          <FormField label="Sous-catégorie (optionnel)"><input value={form.sousCategorie} onChange={(e) => setForm({ ...form, sousCategorie: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Déchets dangereux, Scope 1..." /></FormField>
        </div>
        <FormField label="Type de relevé"><input required value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Consommation d'eau, Électricité..." /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Valeur"><input type="number" step="any" value={form.value} onChange={(e) => setForm({ ...form, value: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Unité"><input value={form.unit} onChange={(e) => setForm({ ...form, unit: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="m³, kWh, kg, tCO₂e..." /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Site (optionnel)"><input value={form.site} onChange={(e) => setForm({ ...form, site: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Processus concerné (optionnel)">
            <select value={form.processusId} onChange={(e) => setForm({ ...form, processusId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>{(processusQ.data || []).map((p) => <option key={p.id} value={p.id}>{p.nom}</option>)}
            </select>
          </FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Seuil réglementaire (optionnel)"><input type="number" step="any" value={form.seuilReglementaire} onChange={(e) => setForm({ ...form, seuilReglementaire: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Coût (optionnel)"><input type="number" step="any" value={form.cout} onChange={(e) => setForm({ ...form, cout: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Mode de traitement (optionnel)"><input value={form.modeTraitement} onChange={(e) => setForm({ ...form, modeTraitement: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Recyclage, valorisation, élimination..." /></FormField>
          <FormField label="Destination (optionnel)"><input value={form.destination} onChange={(e) => setForm({ ...form, destination: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
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

function EnvironnementAspectForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const processusQ = useCollection('/business/processus');
  const [form, setForm] = useState({
    aspect: record?.aspect || '', activite: record?.activite || '', source: record?.source || '', impact: record?.impact || '',
    milieu: record?.milieu || '', situation: record?.situation || 'NORMALE', processusId: record?.processusId || '',
    frequence: record?.frequence || 1, gravite: record?.gravite || 1, probabilite: record?.probabilite || 1, maitrise: record?.maitrise || 1,
    mesuresMaitrise: record?.mesuresMaitrise || '', statut: record?.statut || 'ACTIVE',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const criticitePreview = Math.round((Number(form.frequence) * Number(form.gravite) * Number(form.probabilite)) / (Number(form.maitrise) || 1));
  const significatifPreview = criticitePreview >= 12;

  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, processusId: form.processusId || null };
      if (editing) await api.patch(`/business/environnement-aspects/${record.id}`, payload);
      else await api.post('/business/environnement-aspects', { code: genCode('ASP'), ...payload });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.aspect, `/business/environnement-aspects/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? "Modifier l'aspect environnemental" : 'Nouvel aspect environnemental'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Aspect environnemental"><input required value={form.aspect} onChange={(e) => setForm({ ...form, aspect: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Rejet de vapeur d'eau" /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Activité (optionnel)"><input value={form.activite} onChange={(e) => setForm({ ...form, activite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Source (optionnel)"><input value={form.source} onChange={(e) => setForm({ ...form, source: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Impact environnemental (optionnel)"><input value={form.impact} onChange={(e) => setForm({ ...form, impact: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Milieu concerné">
            <select value={form.milieu} onChange={(e) => setForm({ ...form, milieu: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>{['Air', 'Eau', 'Sol', 'Sous-sol', 'Biodiversité', 'Ressources naturelles', 'Population', 'Climat'].map((m) => <option key={m} value={m}>{m}</option>)}
            </select>
          </FormField>
          <FormField label="Situation">
            <select value={form.situation} onChange={(e) => setForm({ ...form, situation: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="NORMALE">Normale</option><option value="ANORMALE">Anormale</option><option value="URGENCE">Situation d'urgence</option>
            </select>
          </FormField>
        </div>
        <FormField label="Processus concerné (optionnel)">
          <select value={form.processusId} onChange={(e) => setForm({ ...form, processusId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">—</option>{(processusQ.data || []).map((p) => <option key={p.id} value={p.id}>{p.nom}</option>)}
          </select>
        </FormField>
        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Cotation — Criticité = Fréquence × Gravité × Probabilité ÷ Maîtrise</p>
        <div className="grid grid-cols-4 gap-2">
          {['frequence', 'gravite', 'probabilite', 'maitrise'].map((k) => (
            <FormField key={k} label={k === 'frequence' ? 'Fréquence' : k === 'gravite' ? 'Gravité' : k === 'probabilite' ? 'Probabilité' : 'Maîtrise'}>
              <select value={form[k]} onChange={(e) => setForm({ ...form, [k]: Number(e.target.value) })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>{[1, 2, 3, 4].map((n) => <option key={n} value={n}>{n}</option>)}</select>
            </FormField>
          ))}
        </div>
        <p className="text-xs mb-3" style={{ color: significatifPreview ? C.red : C.green }}>Criticité calculée : {criticitePreview} — {significatifPreview ? 'aspect significatif' : 'non significatif'}</p>
        <FormField label="Mesures de maîtrise (optionnel)"><textarea value={form.mesuresMaitrise} onChange={(e) => setForm({ ...form, mesuresMaitrise: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        {editing && <FormField label="Statut"><select value={form.statut} onChange={(e) => setForm({ ...form, statut: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="ACTIVE">Actif</option><option value="MAITRISE">Maîtrisé</option><option value="CLOTURE">Clôturé</option></select></FormField>}
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
  const users = useCollection('/users');
  const [form, setForm] = useState({
    nom: record?.nom || '', type: record?.type || 'OPERATIONNEL', criticite: record?.criticite || '',
    piloteId: record?.piloteId || '', finalite: record?.finalite || '',
    proprietaire: record?.proprietaire || '', objectifs: record?.objectifs || '', kpi: record?.kpi || '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, piloteId: form.piloteId || null, criticite: form.criticite || null };
      if (editing) await api.patch(`/business/processus/${record.id}`, payload);
      else await api.post('/business/processus', { code: genCode('PROC'), ...payload });
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
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Type">
            <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="STRATEGIQUE">Stratégique / management</option>
              <option value="OPERATIONNEL">Opérationnel</option>
              <option value="SUPPORT">Support</option>
              <option value="AUTRE">Autre</option>
            </select>
          </FormField>
          <FormField label="Criticité (optionnel)">
            <select value={form.criticite} onChange={(e) => setForm({ ...form, criticite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>
              <option value="FAIBLE">Faible</option><option value="MOYEN">Moyen</option>
              <option value="IMPORTANT">Important</option><option value="CRITIQUE">Critique</option>
            </select>
          </FormField>
        </div>
        <FormField label="Pilote (optionnel)">
          <select value={form.piloteId} onChange={(e) => setForm({ ...form, piloteId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">—</option>{(users.data || []).map((u) => <option key={u.id} value={u.id}>{u.firstName} {u.lastName}</option>)}
          </select>
        </FormField>
        <FormField label="Finalité (optionnel)"><textarea value={form.finalite} onChange={(e) => setForm({ ...form, finalite: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
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

function IndicateurForm({ record, onClose, onCreated, domaine = 'QUALITE' }) {
  const C = useTheme();
  const editing = !!record;
  const processusQ = useCollection('/business/processus');
  const [form, setForm] = useState({
    indicateur: record?.indicateur || '', actuel: record?.actuel ?? '', cible: record?.cible ?? '', unite: record?.unite || '', sensInverse: record?.sensInverse || false,
    categorie: record?.categorie || '', formule: record?.formule || '', frequence: record?.frequence || '', processusId: record?.processusId || '',
    seuilVert: record?.seuilVert ?? '', seuilOrange: record?.seuilOrange ?? '', poids: record?.poids ?? 1,
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, processusId: form.processusId || null, seuilVert: form.seuilVert === '' ? null : Number(form.seuilVert), seuilOrange: form.seuilOrange === '' ? null : Number(form.seuilOrange), poids: Number(form.poids) || 1 };
      if (editing) await api.patch(`/business/indicateurs-qualite/${record.id}`, payload);
      else await api.post('/business/indicateurs-qualite', { code: genCode('IND'), domaine, ...payload });
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
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Catégorie (optionnel)"><input value={form.categorie} onChange={(e) => setForm({ ...form, categorie: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Production, Satisfaction client..." /></FormField>
          <FormField label="Fréquence (optionnel)">
            <select value={form.frequence} onChange={(e) => setForm({ ...form, frequence: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option><option value="QUOTIDIENNE">Quotidienne</option><option value="HEBDOMADAIRE">Hebdomadaire</option><option value="MENSUELLE">Mensuelle</option><option value="TRIMESTRIELLE">Trimestrielle</option><option value="ANNUELLE">Annuelle</option>
            </select>
          </FormField>
        </div>
        <FormField label="Formule (optionnel)"><input value={form.formule} onChange={(e) => setForm({ ...form, formule: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Conformes / Total × 100" /></FormField>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Actuel"><input required type="number" step="any" value={form.actuel} onChange={(e) => setForm({ ...form, actuel: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Cible"><input required type="number" step="any" value={form.cible} onChange={(e) => setForm({ ...form, cible: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Unité"><input value={form.unite} onChange={(e) => setForm({ ...form, unite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="%" /></FormField>
        </div>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Seuil vert (optionnel)"><input type="number" step="any" value={form.seuilVert} onChange={(e) => setForm({ ...form, seuilVert: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Seuil orange (optionnel)"><input type="number" step="any" value={form.seuilOrange} onChange={(e) => setForm({ ...form, seuilOrange: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Pondération"><input type="number" step="any" min="0" value={form.poids} onChange={(e) => setForm({ ...form, poids: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Processus concerné (optionnel)">
          <select value={form.processusId} onChange={(e) => setForm({ ...form, processusId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">—</option>{(processusQ.data || []).map((p) => <option key={p.id} value={p.id}>{p.nom}</option>)}
          </select>
        </FormField>
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
  const processusQ = useCollection('/business/processus');
  const fournisseursQ = useCollection('/business/fournisseurs');
  const [form, setForm] = useState({
    client: record?.client || '', typeClient: record?.typeClient || '', clientContact: record?.clientContact || '',
    motif: record?.motif || '', description: record?.description || '', canal: record?.canal || '',
    date: record ? new Date(record.date).toISOString().slice(0, 10) : new Date().toISOString().slice(0, 10),
    dateEvenement: record?.dateEvenement ? new Date(record.dateEvenement).toISOString().slice(0, 10) : '',
    produitService: record?.produitService || '', reference: record?.reference || '', lotNumber: record?.lotNumber || '',
    commandeNumber: record?.commandeNumber || '', factureNumber: record?.factureNumber || '', quantiteConcernee: record?.quantiteConcernee ?? '',
    processusId: record?.processusId || '', fournisseurId: record?.fournisseurId || '',
    categorieProbleme: record?.categorieProbleme || '', gravite: record?.gravite || 'Faible', statut: record?.statut || 'OPEN',
    delaiCibleJours: record?.delaiCibleJours ?? '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = {
        ...form, date: new Date(form.date).toISOString(),
        dateEvenement: form.dateEvenement ? new Date(form.dateEvenement).toISOString() : null,
        quantiteConcernee: form.quantiteConcernee === '' ? null : Number(form.quantiteConcernee),
        delaiCibleJours: form.delaiCibleJours === '' ? null : Number(form.delaiCibleJours),
        processusId: form.processusId || null, fournisseurId: form.fournisseurId || null,
      };
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
        <p className="text-xs font-semibold uppercase tracking-wide mb-2" style={{ color: C.textMuted }}>Identification</p>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Client"><input required value={form.client} onChange={(e) => setForm({ ...form, client: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Type de client (optionnel)"><input value={form.typeClient} onChange={(e) => setForm({ ...form, typeClient: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Particulier, entreprise..." /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Contact (optionnel)"><input value={form.clientContact} onChange={(e) => setForm({ ...form, clientContact: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Canal de réception (optionnel)">
            <select value={form.canal} onChange={(e) => setForm({ ...form, canal: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option><option value="TELEPHONE">Téléphone</option><option value="EMAIL">Email</option><option value="SITE_WEB">Site web</option><option value="RESEAUX_SOCIAUX">Réseaux sociaux</option><option value="COURRIER">Courrier</option><option value="COMMERCIAL">Commercial</option><option value="SAV">Service après-vente</option><option value="DIRECTE">Réclamation directe</option><option value="AUTRE">Autre</option>
            </select>
          </FormField>
        </div>
        <FormField label="Motif"><input required value={form.motif} onChange={(e) => setForm({ ...form, motif: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Description"><textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Date de réception"><input required type="date" value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Date de l'événement (optionnel)"><input type="date" value={form.dateEvenement} onChange={(e) => setForm({ ...form, dateEvenement: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>

        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Produit / service concerné</p>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Produit / service (optionnel)"><input value={form.produitService} onChange={(e) => setForm({ ...form, produitService: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Référence (optionnel)"><input value={form.reference} onChange={(e) => setForm({ ...form, reference: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="N° de lot (optionnel)"><input value={form.lotNumber} onChange={(e) => setForm({ ...form, lotNumber: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="N° de commande (optionnel)"><input value={form.commandeNumber} onChange={(e) => setForm({ ...form, commandeNumber: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Quantité concernée (optionnel)"><input type="number" step="any" value={form.quantiteConcernee} onChange={(e) => setForm({ ...form, quantiteConcernee: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Processus concerné (optionnel)">
            <select value={form.processusId} onChange={(e) => setForm({ ...form, processusId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>{(processusQ.data || []).map((p) => <option key={p.id} value={p.id}>{p.nom}</option>)}
            </select>
          </FormField>
          <FormField label="Fournisseur concerné (optionnel)">
            <select value={form.fournisseurId} onChange={(e) => setForm({ ...form, fournisseurId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>{(fournisseursQ.data || []).map((f) => <option key={f.id} value={f.id}>{f.nom}</option>)}
            </select>
          </FormField>
        </div>

        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Classification</p>
        <FormField label="Nature du problème (optionnel)">
          <select value={form.categorieProbleme} onChange={(e) => setForm({ ...form, categorieProbleme: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">—</option>
            {['Défaut produit', 'Non-conformité', 'Produit endommagé', 'Erreur de quantité', 'Erreur de livraison', 'Retard de livraison', 'Emballage', 'Étiquetage', 'Facturation', 'Service', 'Communication', 'Délai', 'Support technique', 'Comportement du personnel', 'Hygiène', 'Sécurité', 'Autre'].map((c) => <option key={c} value={c}>{c}</option>)}
          </select>
        </FormField>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Gravité"><select value={form.gravite} onChange={(e) => setForm({ ...form, gravite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option>Faible</option><option>Modérée</option><option>Majeure</option><option>Critique</option></select></FormField>
          <FormField label="Délai cible (jours, optionnel)"><input type="number" value={form.delaiCibleJours} onChange={(e) => setForm({ ...form, delaiCibleJours: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          {editing && <FormField label="Statut"><select value={form.statut} onChange={(e) => setForm({ ...form, statut: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="OPEN">Ouverte</option><option value="CLOSED">Clôturée</option></select></FormField>}
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

function ReclamationDetailModal({ reclamationId, onClose, onChanged, onEdit }) {
  const C = useTheme();
  const [r, setR] = useState(null);
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);
  const [showActionForm, setShowActionForm] = useState(false);
  const [ncPrefill, setNcPrefill] = useState(null);
  const users = useCollection('/users');
  const [form, setForm] = useState(null);

  async function load() {
    try {
      const data = await api.get(`/business/reclamations/${reclamationId}`);
      setR(data);
      setForm((prev) => prev || {
        dateAccuseReception: data.dateAccuseReception ? new Date(data.dateAccuseReception).toISOString().slice(0, 10) : '',
        datePremiereReponse: data.datePremiereReponse ? new Date(data.datePremiereReponse).toISOString().slice(0, 10) : '',
        dateResolutionPrevue: data.dateResolutionPrevue ? new Date(data.dateResolutionPrevue).toISOString().slice(0, 10) : '',
        dateResolutionReelle: data.dateResolutionReelle ? new Date(data.dateResolutionReelle).toISOString().slice(0, 10) : '',
        dateCloture: data.dateCloture ? new Date(data.dateCloture).toISOString().slice(0, 10) : '',
        actionCurative: data.actionCurative || '', actionCurativeResponsableId: data.actionCurativeResponsableId || '',
        actionCurativeDate: data.actionCurativeDate ? new Date(data.actionCurativeDate).toISOString().slice(0, 10) : '', actionCurativeCout: data.actionCurativeCout ?? '',
        methodeAnalyse: data.methodeAnalyse || '', pourquoi1: data.pourquoi1 || '', pourquoi2: data.pourquoi2 || '', pourquoi3: data.pourquoi3 || '', pourquoi4: data.pourquoi4 || '', pourquoi5: data.pourquoi5 || '',
        categorieCauseIshikawa: data.categorieCauseIshikawa || '', causeRacine: data.causeRacine || '',
        efficacite: data.efficacite || '', satisfaction: data.satisfaction || '', noteSatisfaction: data.noteSatisfaction ?? '', commentaireClient: data.commentaireClient || '',
        coutRemboursement: data.coutRemboursement ?? '', coutRemplacement: data.coutRemplacement ?? '', coutTransport: data.coutTransport ?? '', coutMainOeuvre: data.coutMainOeuvre ?? '', coutAutres: data.coutAutres ?? '',
        recurrente: data.recurrente || false,
      });
    } catch (err) { setError(err.message); }
  }
  useEffect(() => { load(); }, [reclamationId]);

  if (error) return <Modal title="Réclamation" onClose={onClose}><ErrorPanel message={error} /></Modal>;
  if (!r || !form) return <Modal title="Réclamation" onClose={onClose} wide><LoadingPanel /></Modal>;

  const coutTotal = [form.coutRemboursement, form.coutRemplacement, form.coutTransport, form.coutMainOeuvre, form.coutAutres, form.actionCurativeCout].reduce((s, v) => s + (Number(v) || 0), 0);

  async function save() {
    setSaving(true); setError(null);
    try {
      const payload = { ...form };
      ['dateAccuseReception', 'datePremiereReponse', 'dateResolutionPrevue', 'dateResolutionReelle', 'dateCloture', 'actionCurativeDate'].forEach((k) => { payload[k] = form[k] ? new Date(form[k]).toISOString() : null; });
      ['actionCurativeCout', 'noteSatisfaction', 'coutRemboursement', 'coutRemplacement', 'coutTransport', 'coutMainOeuvre', 'coutAutres'].forEach((k) => { payload[k] = form[k] === '' ? null : Number(form[k]); });
      payload.actionCurativeResponsableId = form.actionCurativeResponsableId || null;
      await api.patch(`/business/reclamations/${reclamationId}`, payload);
      onChanged(); await load();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }

  return (
    <>
      {showActionForm && <ActionForm prefill={{ title: `Action — réclamation ${r.client}`, reclamationId: r.id }} onClose={() => setShowActionForm(false)} onCreated={() => { onChanged(); load(); }} />}
      {ncPrefill && <NonConformityForm prefill={ncPrefill} onClose={() => setNcPrefill(null)} onCreated={() => setNcPrefill(null)} />}
      <Modal title={`Réclamation — ${r.client}`} onClose={onClose} wide>
        <div className="flex flex-wrap items-center gap-2 text-xs mb-4" style={{ color: C.textMuted }}>
          <span>{r.motif}</span>·<span>{new Date(r.date).toLocaleDateString('fr-FR')}</span>·<StatusChip statut={r.gravite} />·<StatusChip statut={r.statut === 'OPEN' ? 'Ouverte' : 'Clôturée'} />
          <button onClick={onEdit} className="text-xs px-2 py-1 rounded-lg ml-2" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, color: C.text }}>Modifier</button>
          <span className="ml-auto font-semibold" style={{ color: C.text }}>Coût total : {coutTotal.toLocaleString('fr-FR')} FCFA</span>
        </div>

        <p className="text-xs font-semibold uppercase tracking-wide mb-2" style={{ color: C.textMuted }}>Accusé de réception et délais (SLA)</p>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Accusé de réception"><input type="date" value={form.dateAccuseReception} onChange={(e) => setForm({ ...form, dateAccuseReception: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Première réponse"><input type="date" value={form.datePremiereReponse} onChange={(e) => setForm({ ...form, datePremiereReponse: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Résolution prévue"><input type="date" value={form.dateResolutionPrevue} onChange={(e) => setForm({ ...form, dateResolutionPrevue: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Résolution réelle"><input type="date" value={form.dateResolutionReelle} onChange={(e) => setForm({ ...form, dateResolutionReelle: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Clôture"><input type="date" value={form.dateCloture} onChange={(e) => setForm({ ...form, dateCloture: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>

        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Action curative immédiate</p>
        <FormField label="Action réalisée"><input value={form.actionCurative} onChange={(e) => setForm({ ...form, actionCurative: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Remplacement, remboursement, réparation..." /></FormField>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Responsable">
            <select value={form.actionCurativeResponsableId} onChange={(e) => setForm({ ...form, actionCurativeResponsableId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>{(users.data || []).map((u) => <option key={u.id} value={u.id}>{u.firstName} {u.lastName}</option>)}
            </select>
          </FormField>
          <FormField label="Date"><input type="date" value={form.actionCurativeDate} onChange={(e) => setForm({ ...form, actionCurativeDate: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Coût (FCFA)"><input type="number" step="any" value={form.actionCurativeCout} onChange={(e) => setForm({ ...form, actionCurativeCout: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>

        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Analyse des causes</p>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Méthode">
            <select value={form.methodeAnalyse} onChange={(e) => setForm({ ...form, methodeAnalyse: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option><option value="5_POURQUOI">5 Pourquoi</option><option value="ISHIKAWA">Ishikawa (5M)</option><option value="PARETO">Pareto</option><option value="AUTRE">Autre</option>
            </select>
          </FormField>
          <FormField label="Catégorie Ishikawa (si applicable)">
            <select value={form.categorieCauseIshikawa} onChange={(e) => setForm({ ...form, categorieCauseIshikawa: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option><option value="MAIN_OEUVRE">Main-d'œuvre</option><option value="METHODE">Méthode</option><option value="MACHINE">Machine</option><option value="MATIERE">Matière</option><option value="MILIEU">Milieu</option><option value="MESURE">Mesure</option>
            </select>
          </FormField>
        </div>
        {form.methodeAnalyse === '5_POURQUOI' && [1, 2, 3, 4, 5].map((n) => (
          <FormField key={n} label={`Pourquoi ${n} ?`}><input value={form[`pourquoi${n}`]} onChange={(e) => setForm({ ...form, [`pourquoi${n}`]: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        ))}
        <FormField label="Cause racine retenue"><input value={form.causeRacine} onChange={(e) => setForm({ ...form, causeRacine: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        {!r.nonConformityId && (
          <button type="button" onClick={() => setNcPrefill({ title: `Réclamation — ${r.client}`, description: form.causeRacine || r.description, source: 'RECLAMATION', severity: r.gravite === 'Critique' ? 3 : r.gravite === 'Majeure' ? 2 : 1 })} className="text-xs mb-3" style={{ color: C.blue }}>Créer une non-conformité à partir de cette réclamation</button>
        )}

        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Vérification d'efficacité et satisfaction</p>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Efficacité de l'action">
            <select value={form.efficacite} onChange={(e) => setForm({ ...form, efficacite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option><option value="EFFICACE">Efficace</option><option value="PARTIELLEMENT_EFFICACE">Partiellement efficace</option><option value="INEFFICACE">Inefficace</option>
            </select>
          </FormField>
          <FormField label="Satisfaction client">
            <select value={form.satisfaction} onChange={(e) => setForm({ ...form, satisfaction: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option><option value="SATISFAIT">Satisfait</option><option value="PARTIELLEMENT_SATISFAIT">Partiellement satisfait</option><option value="INSATISFAIT">Insatisfait</option>
            </select>
          </FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Note de satisfaction (optionnel)"><input type="number" min="0" max="10" step="any" value={form.noteSatisfaction} onChange={(e) => setForm({ ...form, noteSatisfaction: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <label className="flex items-center gap-2 text-xs mt-6" style={{ color: C.textMuted }}><input type="checkbox" checked={form.recurrente} onChange={(e) => setForm({ ...form, recurrente: e.target.checked })} />Problème récurrent</label>
        </div>
        <FormField label="Commentaire client (optionnel)"><textarea value={form.commentaireClient} onChange={(e) => setForm({ ...form, commentaireClient: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>

        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Coûts détaillés</p>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Remboursement"><input type="number" step="any" value={form.coutRemboursement} onChange={(e) => setForm({ ...form, coutRemboursement: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Remplacement"><input type="number" step="any" value={form.coutRemplacement} onChange={(e) => setForm({ ...form, coutRemplacement: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Transport"><input type="number" step="any" value={form.coutTransport} onChange={(e) => setForm({ ...form, coutTransport: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Main d'œuvre"><input type="number" step="any" value={form.coutMainOeuvre} onChange={(e) => setForm({ ...form, coutMainOeuvre: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Autres"><input type="number" step="any" value={form.coutAutres} onChange={(e) => setForm({ ...form, coutAutres: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>

        <div className="flex items-center justify-between mt-4 mb-2">
          <p className="text-xs font-semibold uppercase tracking-wide" style={{ color: C.textMuted }}>Plan d'actions correctives</p>
          <button type="button" onClick={() => setShowActionForm(true)} className="text-xs px-2 py-1 rounded-lg" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Action</button>
        </div>
        {(r.actions || []).length
          ? <div className="space-y-1 mb-3">{r.actions.map((a) => <div key={a.id} className="flex justify-between text-xs py-1" style={{ borderTop: `1px solid ${C.border}` }}><span style={{ color: C.text }}>{a.title}</span><StatusChip statut={a.status} /></div>)}</div>
          : <p className="text-xs mb-3" style={{ color: C.textMuted }}>Aucune action liée pour le moment</p>}

        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <button onClick={save} disabled={saving} className="w-full py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : 'Enregistrer'}</button>
      </Modal>
    </>
  );
}

function FournisseurForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const users = useCollection('/users');
  const [form, setForm] = useState({
    nom: record?.nom || '', nomCommercial: record?.nomCommercial || '', typeFournisseur: record?.typeFournisseur || '', categorie: record?.categorie || '',
    familleAchat: record?.familleAchat || '', produitsServices: record?.produitsServices || '',
    pays: record?.pays || '', ville: record?.ville || '',
    contactNom: record?.contactNom || '', contactTelephone: record?.contactTelephone || '', contactEmail: record?.contactEmail || '',
    responsableInterneId: record?.responsableInterneId || '',
    statut: record?.statut || 'HOMOLOGUE', niveauRisque: record?.niveauRisque || '', criticite: record?.criticite || false,
    capaciteTechnique: record?.capaciteTechnique || '', capaciteCommerciale: record?.capaciteCommerciale || '', situationFinanciere: record?.situationFinanciere || '',
    dateHomologation: record?.dateHomologation ? new Date(record.dateHomologation).toISOString().slice(0, 10) : '',
    dateProchaineReevaluation: record?.dateProchaineReevaluation ? new Date(record.dateProchaineReevaluation).toISOString().slice(0, 10) : '',
    monoSource: record?.monoSource || false, solutionSecours: record?.solutionSecours || false, delaiRemplacementJours: record?.delaiRemplacementJours ?? '',
    scoreQualite: record?.scoreQualite ?? '', scoreLivraison: record?.scoreLivraison ?? '', scoreQhse: record?.scoreQhse ?? '', scoreCommercial: record?.scoreCommercial ?? '', scoreReactivite: record?.scoreReactivite ?? '',
    derniereEvaluation: record?.derniereEvaluation ? new Date(record.derniereEvaluation).toISOString().slice(0, 10) : '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = {
        ...form, responsableInterneId: form.responsableInterneId || null, niveauRisque: form.niveauRisque || null,
        dateHomologation: form.dateHomologation ? new Date(form.dateHomologation).toISOString() : null,
        dateProchaineReevaluation: form.dateProchaineReevaluation ? new Date(form.dateProchaineReevaluation).toISOString() : null,
        derniereEvaluation: form.derniereEvaluation ? new Date(form.derniereEvaluation).toISOString() : null,
        delaiRemplacementJours: form.delaiRemplacementJours === '' ? null : Number(form.delaiRemplacementJours),
        scoreQualite: form.scoreQualite === '' ? null : Number(form.scoreQualite), scoreLivraison: form.scoreLivraison === '' ? null : Number(form.scoreLivraison),
        scoreQhse: form.scoreQhse === '' ? null : Number(form.scoreQhse), scoreCommercial: form.scoreCommercial === '' ? null : Number(form.scoreCommercial),
        scoreReactivite: form.scoreReactivite === '' ? null : Number(form.scoreReactivite),
      };
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
        <p className="text-xs font-semibold uppercase tracking-wide mb-2" style={{ color: C.textMuted }}>Identification</p>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Raison sociale"><input required value={form.nom} onChange={(e) => setForm({ ...form, nom: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Nom commercial (optionnel)"><input value={form.nomCommercial} onChange={(e) => setForm({ ...form, nomCommercial: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Type">
            <select value={form.typeFournisseur} onChange={(e) => setForm({ ...form, typeFournisseur: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option><option value="FOURNISSEUR">Fournisseur</option><option value="PRESTATAIRE">Prestataire</option><option value="SOUS_TRAITANT">Sous-traitant</option><option value="CONSULTANT">Consultant</option><option value="TRANSPORTEUR">Transporteur</option><option value="AUTRE">Autre</option>
            </select>
          </FormField>
          <FormField label="Catégorie (optionnel)"><input value={form.categorie} onChange={(e) => setForm({ ...form, categorie: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Famille d'achat / produits-services (optionnel)"><input value={form.produitsServices} onChange={(e) => setForm({ ...form, produitsServices: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Pays (optionnel)"><input value={form.pays} onChange={(e) => setForm({ ...form, pays: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Ville (optionnel)"><input value={form.ville} onChange={(e) => setForm({ ...form, ville: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Contact (optionnel)"><input value={form.contactNom} onChange={(e) => setForm({ ...form, contactNom: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Téléphone (optionnel)"><input value={form.contactTelephone} onChange={(e) => setForm({ ...form, contactTelephone: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Email (optionnel)"><input value={form.contactEmail} onChange={(e) => setForm({ ...form, contactEmail: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Responsable interne (optionnel)">
          <select value={form.responsableInterneId} onChange={(e) => setForm({ ...form, responsableInterneId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">—</option>{(users.data || []).map((u) => <option key={u.id} value={u.id}>{u.firstName} {u.lastName}</option>)}
          </select>
        </FormField>

        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Statut et risque</p>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Statut">
            <select value={form.statut} onChange={(e) => setForm({ ...form, statut: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="PROSPECT">Prospect</option><option value="EN_QUALIFICATION">En qualification</option><option value="EN_ATTENTE_HOMOLOGATION">En attente d'homologation</option>
              <option value="HOMOLOGUE">Homologué</option><option value="HOMOLOGUE_CONDITIONS">Homologué sous conditions</option><option value="SOUS_SURVEILLANCE">Sous surveillance</option>
              <option value="SUSPENDU">Suspendu</option><option value="BLOQUE">Bloqué</option><option value="INACTIF">Inactif</option><option value="RETIRE">Retiré du panel</option>
            </select>
          </FormField>
          <FormField label="Niveau de risque">
            <select value={form.niveauRisque} onChange={(e) => setForm({ ...form, niveauRisque: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option><option value="FAIBLE">Faible</option><option value="MODERE">Modéré</option><option value="ELEVE">Élevé</option><option value="CRITIQUE">Critique</option>
            </select>
          </FormField>
          <label className="flex items-center gap-2 text-xs mt-6" style={{ color: C.textMuted }}><input type="checkbox" checked={form.criticite} onChange={(e) => setForm({ ...form, criticite: e.target.checked })} />Fournisseur critique</label>
        </div>

        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Qualification</p>
        <FormField label="Capacité technique (optionnel)"><textarea value={form.capaciteTechnique} onChange={(e) => setForm({ ...form, capaciteTechnique: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        <FormField label="Capacité commerciale (optionnel)"><textarea value={form.capaciteCommerciale} onChange={(e) => setForm({ ...form, capaciteCommerciale: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        <FormField label="Situation financière (optionnel)"><textarea value={form.situationFinanciere} onChange={(e) => setForm({ ...form, situationFinanciere: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>

        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Homologation</p>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Date d'homologation"><input type="date" value={form.dateHomologation} onChange={(e) => setForm({ ...form, dateHomologation: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Prochaine réévaluation"><input type="date" value={form.dateProchaineReevaluation} onChange={(e) => setForm({ ...form, dateProchaineReevaluation: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>

        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Continuité d'approvisionnement</p>
        <div className="grid grid-cols-3 gap-3">
          <label className="flex items-center gap-2 text-xs" style={{ color: C.textMuted }}><input type="checkbox" checked={form.monoSource} onChange={(e) => setForm({ ...form, monoSource: e.target.checked })} />Mono-source</label>
          <label className="flex items-center gap-2 text-xs" style={{ color: C.textMuted }}><input type="checkbox" checked={form.solutionSecours} onChange={(e) => setForm({ ...form, solutionSecours: e.target.checked })} />Solution de secours</label>
          <FormField label="Délai remplacement (jours)"><input type="number" value={form.delaiRemplacementJours} onChange={(e) => setForm({ ...form, delaiRemplacementJours: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>

        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Scores par domaine (0-100)</p>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Qualité"><input type="number" min="0" max="100" value={form.scoreQualite} onChange={(e) => setForm({ ...form, scoreQualite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Livraison"><input type="number" min="0" max="100" value={form.scoreLivraison} onChange={(e) => setForm({ ...form, scoreLivraison: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="QHSE"><input type="number" min="0" max="100" value={form.scoreQhse} onChange={(e) => setForm({ ...form, scoreQhse: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Commercial"><input type="number" min="0" max="100" value={form.scoreCommercial} onChange={(e) => setForm({ ...form, scoreCommercial: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Réactivité"><input type="number" min="0" max="100" value={form.scoreReactivite} onChange={(e) => setForm({ ...form, scoreReactivite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Dernière évaluation"><input type="date" value={form.derniereEvaluation} onChange={(e) => setForm({ ...form, derniereEvaluation: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
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

function VisiteMedicaleForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({
    employeNom: record?.employeNom || '', poste: record?.poste || '', service: record?.service || '', typeVisite: record?.typeVisite || '',
    dateDerniereVisite: record?.dateDerniereVisite ? new Date(record.dateDerniereVisite).toISOString().slice(0, 10) : '',
    aptitude: record?.aptitude || '', restrictions: record?.restrictions || '', amenagementPoste: record?.amenagementPoste || '',
    medecinService: record?.medecinService || '', suiviParticulier: record?.suiviParticulier || false,
    statut: record?.statut || 'A_VENIR', prochaineVisite: record?.prochaineVisite ? new Date(record.prochaineVisite).toISOString().slice(0, 10) : '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, prochaineVisite: form.prochaineVisite ? new Date(form.prochaineVisite).toISOString() : null, dateDerniereVisite: form.dateDerniereVisite ? new Date(form.dateDerniereVisite).toISOString() : null };
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
        <p className="text-[11px] mb-3" style={{ color: C.textMuted }}>Données administratives de suivi uniquement — aucun détail médical n'est demandé ni conservé ici.</p>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Employé"><input required value={form.employeNom} onChange={(e) => setForm({ ...form, employeNom: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Poste"><input value={form.poste} onChange={(e) => setForm({ ...form, poste: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Service (optionnel)"><input value={form.service} onChange={(e) => setForm({ ...form, service: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Type de visite (optionnel)">
            <select value={form.typeVisite} onChange={(e) => setForm({ ...form, typeVisite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option><option value="EMBAUCHE">Embauche</option><option value="PERIODIQUE">Périodique</option><option value="REPRISE">Reprise</option><option value="OCCASIONNELLE">Occasionnelle</option>
            </select>
          </FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Dernière visite (optionnel)"><input type="date" value={form.dateDerniereVisite} onChange={(e) => setForm({ ...form, dateDerniereVisite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Prochaine visite"><input type="date" value={form.prochaineVisite} onChange={(e) => setForm({ ...form, prochaineVisite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Aptitude"><select value={form.aptitude} onChange={(e) => setForm({ ...form, aptitude: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="">—</option><option value="Apte">Apte</option><option value="Apte avec réserves">Apte avec réserves</option><option value="Inapte">Inapte</option></select></FormField>
          <FormField label="Médecin / service de santé (optionnel)"><input value={form.medecinService} onChange={(e) => setForm({ ...form, medecinService: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        {form.aptitude === 'Apte avec réserves' && (
          <FormField label="Restrictions professionnelles"><input value={form.restrictions} onChange={(e) => setForm({ ...form, restrictions: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        )}
        <FormField label="Aménagement de poste (optionnel)"><input value={form.amenagementPoste} onChange={(e) => setForm({ ...form, amenagementPoste: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <label className="flex items-center gap-2 text-xs mb-3" style={{ color: C.textMuted }}>
          <input type="checkbox" checked={form.suiviParticulier} onChange={(e) => setForm({ ...form, suiviParticulier: e.target.checked })} />
          Suivi particulier
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

function RisqueSanitaireForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const processusQ = useCollection('/business/processus');
  const [form, setForm] = useState({
    categorie: record?.categorie || '', danger: record?.danger || '', source: record?.source || '', activite: record?.activite || '',
    poste: record?.poste || '', zone: record?.zone || '', processusId: record?.processusId || '',
    personnelExpose: record?.personnelExpose || '', nombrePersonnesExposees: record?.nombrePersonnesExposees ?? '',
    dureeExposition: record?.dureeExposition || '', frequenceExposition: record?.frequenceExposition || '', voieExposition: record?.voieExposition || '',
    gravite: record?.gravite || 1, probabilite: record?.probabilite || 1,
    mesuresExistantes: record?.mesuresExistantes || '', mesuresSupplementaires: record?.mesuresSupplementaires || '',
    echeance: record?.echeance ? new Date(record.echeance).toISOString().slice(0, 10) : '', statut: record?.statut || 'ACTIVE',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const criticitePreview = Number(form.gravite) * Number(form.probabilite);
  const niveauPreview = criticitePreview >= 12 ? { label: 'Critique', color: C.red } : criticitePreview >= 6 ? { label: 'Élevé', color: C.amber } : { label: 'Faible/Modéré', color: C.green };

  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, processusId: form.processusId || null, nombrePersonnesExposees: form.nombrePersonnesExposees === '' ? null : Number(form.nombrePersonnesExposees), echeance: form.echeance ? new Date(form.echeance).toISOString() : null };
      if (editing) await api.patch(`/business/risques-sanitaires/${record.id}`, payload);
      else await api.post('/business/risques-sanitaires', { code: genCode('RS'), ...payload });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.danger, `/business/risques-sanitaires/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier le risque sanitaire' : 'Nouveau risque sanitaire'} onClose={onClose}>
      <form onSubmit={submit}>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Catégorie">
            <select value={form.categorie} onChange={(e) => setForm({ ...form, categorie: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option><option value="PHYSIQUE">Physique</option><option value="CHIMIQUE">Chimique</option><option value="BIOLOGIQUE">Biologique</option><option value="CONDITIONS_TRAVAIL">Conditions de travail</option>
            </select>
          </FormField>
          <FormField label="Danger"><input required value={form.danger} onChange={(e) => setForm({ ...form, danger: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Exposition au bruit" /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Source (optionnel)"><input value={form.source} onChange={(e) => setForm({ ...form, source: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Activité (optionnel)"><input value={form.activite} onChange={(e) => setForm({ ...form, activite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Poste (optionnel)"><input value={form.poste} onChange={(e) => setForm({ ...form, poste: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Zone (optionnel)"><input value={form.zone} onChange={(e) => setForm({ ...form, zone: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Processus concerné (optionnel)">
          <select value={form.processusId} onChange={(e) => setForm({ ...form, processusId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">—</option>{(processusQ.data || []).map((p) => <option key={p.id} value={p.id}>{p.nom}</option>)}
          </select>
        </FormField>

        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Exposition</p>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Personnel exposé (optionnel)"><input value={form.personnelExpose} onChange={(e) => setForm({ ...form, personnelExpose: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Nombre de personnes exposées (optionnel)"><input type="number" min="0" value={form.nombrePersonnesExposees} onChange={(e) => setForm({ ...form, nombrePersonnesExposees: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Durée d'exposition (optionnel)"><input value={form.dureeExposition} onChange={(e) => setForm({ ...form, dureeExposition: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Fréquence (optionnel)"><input value={form.frequenceExposition} onChange={(e) => setForm({ ...form, frequenceExposition: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Voie d'exposition (optionnel)"><input value={form.voieExposition} onChange={(e) => setForm({ ...form, voieExposition: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>

        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Criticité</p>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Gravité (1 à 4)"><select value={form.gravite} onChange={(e) => setForm({ ...form, gravite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>{[1, 2, 3, 4].map((n) => <option key={n} value={n}>{n}</option>)}</select></FormField>
          <FormField label="Probabilité (1 à 4)"><select value={form.probabilite} onChange={(e) => setForm({ ...form, probabilite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>{[1, 2, 3, 4].map((n) => <option key={n} value={n}>{n}</option>)}</select></FormField>
        </div>
        <p className="text-xs mb-3" style={{ color: niveauPreview.color }}>Criticité calculée : {criticitePreview} ({niveauPreview.label})</p>

        <FormField label="Mesures existantes (optionnel)"><textarea value={form.mesuresExistantes} onChange={(e) => setForm({ ...form, mesuresExistantes: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        <FormField label="Mesures supplémentaires nécessaires (optionnel)"><textarea value={form.mesuresSupplementaires} onChange={(e) => setForm({ ...form, mesuresSupplementaires: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Échéance (optionnel)"><input type="date" value={form.echeance} onChange={(e) => setForm({ ...form, echeance: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          {editing && <FormField label="Statut"><select value={form.statut} onChange={(e) => setForm({ ...form, statut: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="ACTIVE">Actif</option><option value="MAITRISE">Maîtrisé</option><option value="CLOTURE">Clôturé</option></select></FormField>}
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

function AnalyseErgonomiqueForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({
    poste: record?.poste || '', zone: record?.zone || '',
    stationDeboutProlongee: record?.stationDeboutProlongee || false, stationAssiseProlongee: record?.stationAssiseProlongee || false,
    travailRepetitif: record?.travailRepetitif || false, manutentionChargesLourdes: record?.manutentionChargesLourdes || false,
    posturesContraignantes: record?.posturesContraignantes || false, ecranInformatiquePosture: record?.ecranInformatiquePosture || false,
    vibrations: record?.vibrations || false, eclairageInsuffisant: record?.eclairageInsuffisant || false, espaceInsuffisant: record?.espaceInsuffisant || false,
    observations: record?.observations || '', actionsProposees: record?.actionsProposees || '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const facteurs = [
    ['stationDeboutProlongee', 'Station debout prolongée'], ['stationAssiseProlongee', 'Station assise prolongée'],
    ['travailRepetitif', 'Travail répétitif'], ['manutentionChargesLourdes', 'Manutention de charges lourdes'],
    ['posturesContraignantes', 'Postures contraignantes'], ['ecranInformatiquePosture', 'Poste écran mal positionné'],
    ['vibrations', 'Vibrations'], ['eclairageInsuffisant', 'Éclairage insuffisant'], ['espaceInsuffisant', 'Espace de travail insuffisant'],
  ];
  const count = facteurs.filter(([k]) => form[k]).length;
  const scorePreview = count >= 6 ? { label: 'Critique', color: C.red } : count >= 4 ? { label: 'Élevé', color: C.red } : count >= 2 ? { label: 'Modéré', color: C.amber } : { label: 'Faible', color: C.green };

  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      if (editing) await api.patch(`/business/analyses-ergonomiques/${record.id}`, form);
      else await api.post('/business/analyses-ergonomiques', { code: genCode('ERG'), ...form });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.poste, `/business/analyses-ergonomiques/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? "Modifier l'analyse ergonomique" : 'Analyser un poste'} onClose={onClose}>
      <form onSubmit={submit}>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Poste"><input required value={form.poste} onChange={(e) => setForm({ ...form, poste: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Zone (optionnel)"><input value={form.zone} onChange={(e) => setForm({ ...form, zone: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Facteurs de risque observés</p>
        <div className="grid grid-cols-2 gap-1 mb-3">
          {facteurs.map(([key, label]) => (
            <label key={key} className="flex items-center gap-2 text-xs" style={{ color: C.textMuted }}>
              <input type="checkbox" checked={form[key]} onChange={(e) => setForm({ ...form, [key]: e.target.checked })} />
              {label}
            </label>
          ))}
        </div>
        <p className="text-xs mb-3" style={{ color: scorePreview.color }}>Score ergonomique calculé : {scorePreview.label} ({count} facteur{count > 1 ? 's' : ''})</p>
        <FormField label="Observations (optionnel)"><textarea value={form.observations} onChange={(e) => setForm({ ...form, observations: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        <FormField label="Actions proposées (optionnel)"><textarea value={form.actionsProposees} onChange={(e) => setForm({ ...form, actionsProposees: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} placeholder="Réaménagement, aide mécanique, rotation des tâches, formation gestes et postures..." /></FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function TmsSignalementForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ poste: record?.poste || '', zoneCorporelle: record?.zoneCorporelle || '', activite: record?.activite || '', frequence: record?.frequence || '', statut: record?.statut || 'SIGNALE' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      if (editing) await api.patch(`/business/tms-signalements/${record.id}`, form);
      else await api.post('/business/tms-signalements', { code: genCode('TMS'), ...form });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.zoneCorporelle, `/business/tms-signalements/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier le signalement' : 'Signaler une situation TMS'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Zone corporelle concernée">
          <select required value={form.zoneCorporelle} onChange={(e) => setForm({ ...form, zoneCorporelle: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">—</option>{['Dos', 'Épaules', 'Cou', 'Poignets', 'Mains', 'Coudes', 'Genoux', 'Jambes', 'Pieds', 'Autre'].map((z) => <option key={z} value={z}>{z}</option>)}
          </select>
        </FormField>
        <FormField label="Poste (optionnel)"><input value={form.poste} onChange={(e) => setForm({ ...form, poste: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Activité (optionnel)"><input value={form.activite} onChange={(e) => setForm({ ...form, activite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Fréquence (optionnel)"><input value={form.frequence} onChange={(e) => setForm({ ...form, frequence: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        {editing && <FormField label="Statut"><select value={form.statut} onChange={(e) => setForm({ ...form, statut: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}><option value="SIGNALE">Signalé</option><option value="EN_ANALYSE">En analyse</option><option value="TRAITE">Traité</option></select></FormField>}
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function PenibiliteExpositionForm({ facteurs, onClose, onCreated }) {
  const C = useTheme();
  const [form, setForm] = useState({ facteurId: facteurs[0]?.id || '', poste: '', niveauExposition: '', duree: '', frequence: '', mesuresPrevention: '', prochaineReevaluation: '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      await api.post('/business/penibilite-expositions', { ...form, prochaineReevaluation: form.prochaineReevaluation ? new Date(form.prochaineReevaluation).toISOString() : null });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title="Enregistrer une exposition à la pénibilité" onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Facteur de pénibilité">
          <select required value={form.facteurId} onChange={(e) => setForm({ ...form, facteurId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            {facteurs.map((f) => <option key={f.id} value={f.id}>{f.nom}</option>)}
          </select>
        </FormField>
        <FormField label="Poste (optionnel)"><input value={form.poste} onChange={(e) => setForm({ ...form, poste: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Niveau d'exposition (optionnel)"><input value={form.niveauExposition} onChange={(e) => setForm({ ...form, niveauExposition: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Durée (optionnel)"><input value={form.duree} onChange={(e) => setForm({ ...form, duree: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Mesures de prévention (optionnel)"><textarea value={form.mesuresPrevention} onChange={(e) => setForm({ ...form, mesuresPrevention: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        <FormField label="Prochaine réévaluation (optionnel)"><input type="date" value={form.prochaineReevaluation} onChange={(e) => setForm({ ...form, prochaineReevaluation: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <button type="submit" disabled={saving} className="w-full py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : 'Enregistrer'}</button>
      </form>
    </Modal>
  );
}

function ProduitChimiqueForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const fournisseursQ = useCollection('/business/fournisseurs');
  const [form, setForm] = useState({
    nom: record?.nom || '', reference: record?.reference || '', fournisseurId: record?.fournisseurId || '',
    quantiteStockee: record?.quantiteStockee ?? '', quantiteConsommee: record?.quantiteConsommee ?? '', unite: record?.unite || '',
    classification: record?.classification || '', dangerEnvironnemental: record?.dangerEnvironnemental || '', zoneStockage: record?.zoneStockage || '',
    retention: record?.retention || false, fdsDisponible: record?.fdsDisponible || false,
    dateControle: record?.dateControle ? new Date(record.dateControle).toISOString().slice(0, 10) : '',
    dateExpiration: record?.dateExpiration ? new Date(record.dateExpiration).toISOString().slice(0, 10) : '',
    seuilAlerteStock: record?.seuilAlerteStock ?? '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = {
        ...form, fournisseurId: form.fournisseurId || null,
        quantiteStockee: form.quantiteStockee === '' ? null : Number(form.quantiteStockee),
        quantiteConsommee: form.quantiteConsommee === '' ? null : Number(form.quantiteConsommee),
        seuilAlerteStock: form.seuilAlerteStock === '' ? null : Number(form.seuilAlerteStock),
        dateControle: form.dateControle ? new Date(form.dateControle).toISOString() : null,
        dateExpiration: form.dateExpiration ? new Date(form.dateExpiration).toISOString() : null,
      };
      if (editing) await api.patch(`/business/produits-chimiques/${record.id}`, payload);
      else await api.post('/business/produits-chimiques', { code: genCode('CHIM'), ...payload });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.nom, `/business/produits-chimiques/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier le produit chimique' : 'Nouveau produit chimique'} onClose={onClose}>
      <form onSubmit={submit}>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Nom"><input required value={form.nom} onChange={(e) => setForm({ ...form, nom: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Référence (optionnel)"><input value={form.reference} onChange={(e) => setForm({ ...form, reference: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Fournisseur (optionnel)">
          <select value={form.fournisseurId} onChange={(e) => setForm({ ...form, fournisseurId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">—</option>{(fournisseursQ.data || []).map((f) => <option key={f.id} value={f.id}>{f.nom}</option>)}
          </select>
        </FormField>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Quantité stockée"><input type="number" step="any" value={form.quantiteStockee} onChange={(e) => setForm({ ...form, quantiteStockee: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Unité"><input value={form.unite} onChange={(e) => setForm({ ...form, unite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="L, kg..." /></FormField>
          <FormField label="Seuil d'alerte stock"><input type="number" step="any" value={form.seuilAlerteStock} onChange={(e) => setForm({ ...form, seuilAlerteStock: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Classification (optionnel)"><input value={form.classification} onChange={(e) => setForm({ ...form, classification: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Danger environnemental (optionnel)"><input value={form.dangerEnvironnemental} onChange={(e) => setForm({ ...form, dangerEnvironnemental: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Zone de stockage (optionnel)"><input value={form.zoneStockage} onChange={(e) => setForm({ ...form, zoneStockage: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <label className="flex items-center gap-2 text-xs" style={{ color: C.textMuted }}><input type="checkbox" checked={form.retention} onChange={(e) => setForm({ ...form, retention: e.target.checked })} />Rétention en place</label>
          <label className="flex items-center gap-2 text-xs" style={{ color: C.textMuted }}><input type="checkbox" checked={form.fdsDisponible} onChange={(e) => setForm({ ...form, fdsDisponible: e.target.checked })} />FDS disponible</label>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Date de contrôle (optionnel)"><input type="date" value={form.dateControle} onChange={(e) => setForm({ ...form, dateControle: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Date d'expiration (optionnel)"><input type="date" value={form.dateExpiration} onChange={(e) => setForm({ ...form, dateExpiration: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
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
  const editing = !!record?.id;
  const users = useCollection('/users');
  const [form, setForm] = useState({ texte: record?.texte || '', domaine: record?.domaine || '', dateApplication: record?.dateApplication ? new Date(record.dateApplication).toISOString().slice(0, 10) : '', statut: record?.statut || 'A_TRAITER', responsableId: record?.responsableId || '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, dateApplication: form.dateApplication ? new Date(form.dateApplication).toISOString() : null, responsableId: form.responsableId || null };
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
        <FormField label="Responsable (optionnel)">
          <select value={form.responsableId} onChange={(e) => setForm({ ...form, responsableId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">—</option>{(users.data || []).map((u) => <option key={u.id} value={u.id}>{u.firstName} {u.lastName}</option>)}
          </select>
        </FormField>
        <FormField label="Statut">
          <select value={form.statut} onChange={(e) => setForm({ ...form, statut: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="A_TRAITER">À traiter</option><option value="EN_COURS">En cours</option><option value="INTEGREE">Intégrée</option>
            <option value="CONFORME">Conforme</option><option value="PARTIELLEMENT_CONFORME">Partiellement conforme</option><option value="NON_CONFORME">Non conforme</option>
            <option value="NON_APPLICABLE">Non applicable</option><option value="A_VERIFIER">À vérifier</option>
          </select>
        </FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function TrainingForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const processusQ = useCollection('/business/processus');
  const [form, setForm] = useState({
    title: record?.title || '', trainer: record?.trainer || '',
    scheduledAt: record ? new Date(record.scheduledAt).toISOString().slice(0, 10) : new Date().toISOString().slice(0, 10),
    durationHours: record?.durationHours ?? '', status: record?.status || 'PLANNED',
    expiryAt: record?.expiryAt ? new Date(record.expiryAt).toISOString().slice(0, 10) : '',
    processusId: record?.processusId || '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = {
        ...form, durationHours: form.durationHours === '' ? null : Number(form.durationHours),
        scheduledAt: new Date(form.scheduledAt).toISOString(),
        expiryAt: form.expiryAt ? new Date(form.expiryAt).toISOString() : null,
        processusId: form.processusId || null,
      };
      if (editing) await api.patch(`/business/trainings/${record.id}`, payload);
      else await api.post('/business/trainings', { code: genCode('FORM'), ...payload });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.title, `/business/trainings/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier la formation' : 'Nouvelle formation'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Intitulé"><input required value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Formateur (optionnel)"><input value={form.trainer} onChange={(e) => setForm({ ...form, trainer: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Durée (heures, optionnel)"><input type="number" step="any" value={form.durationHours} onChange={(e) => setForm({ ...form, durationHours: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Date"><input required type="date" value={form.scheduledAt} onChange={(e) => setForm({ ...form, scheduledAt: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Statut">
            <select value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="PLANNED">Planifiée</option><option value="DONE">Réalisée</option><option value="CANCELLED">Annulée</option>
            </select>
          </FormField>
        </div>
        <FormField label="Date d'expiration (optionnel — habilitation à renouveler)"><input type="date" value={form.expiryAt} onChange={(e) => setForm({ ...form, expiryAt: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Processus concerné (optionnel)">
          <select value={form.processusId} onChange={(e) => setForm({ ...form, processusId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">—</option>{(processusQ.data || []).map((p) => <option key={p.id} value={p.id}>{p.nom}</option>)}
          </select>
        </FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Créer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function ObjectifForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const processusQ = useCollection('/business/processus');
  const [form, setForm] = useState({ titre: record?.titre || '', pilier: record?.pilier || '', cible: record?.cible ?? '', actuel: record?.actuel ?? 0, unite: record?.unite || '', echeance: record?.echeance ? new Date(record.echeance).toISOString().slice(0, 10) : '', processusId: record?.processusId || '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, echeance: form.echeance ? new Date(form.echeance).toISOString() : null, processusId: form.processusId || null };
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
        <FormField label="Processus concerné (optionnel)">
          <select value={form.processusId} onChange={(e) => setForm({ ...form, processusId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">—</option>{(processusQ.data || []).map((p) => <option key={p.id} value={p.id}>{p.nom}</option>)}
          </select>
        </FormField>
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
  const processusQ = useCollection('/business/processus');
  const [form, setForm] = useState({ title: '', category: '', documentGroup: '', processusId: '', nextReviewAt: '' });
  const [file, setFile] = useState(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { code: genCode('DOC'), title: form.title, category: form.category || 'Non classé', documentGroup: form.documentGroup || undefined, processusId: form.processusId || undefined, nextReviewAt: form.nextReviewAt ? new Date(form.nextReviewAt).toISOString() : undefined };
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
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Processus concerné (optionnel)">
            <select value={form.processusId} onChange={(e) => setForm({ ...form, processusId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>{(processusQ.data || []).map((p) => <option key={p.id} value={p.id}>{p.nom}</option>)}
            </select>
          </FormField>
          <FormField label="Prochaine révision (optionnel)"><input type="date" value={form.nextReviewAt} onChange={(e) => setForm({ ...form, nextReviewAt: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
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
function DocumentViewerModal({ doc, onClose, onNewVersion, onDeleted, onChanged }) {
  const C = useTheme();
  const [preview, setPreview] = useState({ loading: true, kind: null, content: null, error: null });
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState(null);
  const processusQ = useCollection('/business/processus');
  const [meta, setMeta] = useState({ processusId: doc.processusId || '', nextReviewAt: doc.nextReviewAt ? new Date(doc.nextReviewAt).toISOString().slice(0, 10) : '' });
  const [savingMeta, setSavingMeta] = useState(false);
  const version = latestVersion(doc);

  async function saveMeta() {
    setSavingMeta(true);
    try {
      await api.patch(`/documents/${doc.id}`, { processusId: meta.processusId || null, nextReviewAt: meta.nextReviewAt ? new Date(meta.nextReviewAt).toISOString() : null });
      onChanged();
    } catch (err) { alert(err.message); }
    setSavingMeta(false);
  }

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

      <div className="flex items-end gap-2 mb-4 p-3 rounded-lg" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}` }}>
        <FormField label="Processus concerné">
          <select value={meta.processusId} onChange={(e) => setMeta({ ...meta, processusId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">—</option>{(processusQ.data || []).map((p) => <option key={p.id} value={p.id}>{p.nom}</option>)}
          </select>
        </FormField>
        <FormField label="Prochaine révision">
          <input type="date" value={meta.nextReviewAt} onChange={(e) => setMeta({ ...meta, nextReviewAt: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} />
        </FormField>
        <button onClick={saveMeta} disabled={savingMeta} className="px-3 py-2 rounded-lg text-xs font-medium mb-3" style={{ backgroundColor: C.blue, color: '#fff', opacity: savingMeta ? 0.7 : 1 }}>{savingMeta ? '…' : 'Enregistrer'}</button>
      </div>

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

function EpcMaintenanceForm({ epcOptions, onClose, onCreated }) {
  const C = useTheme();
  const [form, setForm] = useState({ epcId: '', type: 'PREVENTIVE', description: '', cost: '', nextMaintenanceAt: '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, cost: form.cost === '' ? null : Number(form.cost), nextMaintenanceAt: form.nextMaintenanceAt ? new Date(form.nextMaintenanceAt).toISOString() : null };
      await api.post('/epi/maintenance', payload);
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title="Nouvelle intervention de maintenance EPC" onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Équipement">
          <select required value={form.epcId} onChange={(e) => setForm({ ...form, epcId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">Sélectionner…</option>{(epcOptions || []).map((e) => <option key={e.id} value={e.id}>{e.code} — {e.name}</option>)}
          </select>
        </FormField>
        <FormField label="Type d'intervention">
          <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="PREVENTIVE">Préventive</option><option value="CORRECTIVE">Corrective</option>
          </select>
        </FormField>
        <FormField label="Description"><textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Coût (optionnel)"><input type="number" step="any" value={form.cost} onChange={(e) => setForm({ ...form, cost: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Prochaine échéance"><input type="date" value={form.nextMaintenanceAt} onChange={(e) => setForm({ ...form, nextMaintenanceAt: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <button type="submit" disabled={saving} className="w-full py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : 'Enregistrer'}</button>
      </form>
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
  const { dashboardData, audits, risks, actions, environment, safetyEvents, epi, assignments, employees, epcList, renewalBuckets, qualityControls, processus, indicateursAutoCompare, indicateursQualite, indiceGlobal, reclamations, reclamationsStats, reclamationsScore, safetyEventsStats, safetyEventsRecidives, fournisseurs, fournisseursClassement, fournisseursAlertes, fournisseursMatriceRisque, visitesMedicales, risquesSanitaires, analysesErgonomiques, tmsSignalements, hygieneIndiceGlobal, hygieneAlertes } = real;
  const capaStats = computeCapaStatsReal(actions || []);
  const tauxConformite = dashboardData?.overview?.indicators?.qualite?.tauxConformite;
  const environmentByType = {};
  (environment || []).forEach((r) => { environmentByType[r.type] = (environmentByType[r.type] || 0) + (r.value || 0); });
  const severityBreakdown = groupCount(safetyEvents || [], (e) => `Sévérité ${e.severity}`);
  const equippedEmployeeIds = new Set((assignments || []).map((a) => a.employeeId));
  const nonEquipped = (employees || []).filter((e) => e.active && !equippedEmployeeIds.has(e.id));
  const buckets = renewalBuckets || { expired: [], within30: [], within60: [], within90: [] };

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
    {
      id: 'epi-stock', titre: 'État du stock EPI', description: 'Catalogue complet, stock actuel et distributions du jour.',
      sheets: () => [['Stock EPI', [['EPI', 'Fréquence', 'Stock', 'Stock minimum', "Distribué aujourd'hui"], ...(epi?.stock || []).map((e) => [e.name, e.frequency === 'DAILY' ? 'Quotidienne' : 'Annuelle', e.stock, e.minStock ?? 0, e.dailyDistributed ?? 0])]]],
    },
    {
      id: 'epi-dotations', titre: 'Fiches de dotation', description: 'Historique complet des dotations EPI par employé.',
      sheets: () => [['Dotations', [['Code', 'Employé', 'EPI', 'Quantité', 'Date', 'Renouvellement', 'Responsable'], ...(assignments || []).map((a) => [a.code, `${a.employee?.firstName ?? ''} ${a.employee?.lastName ?? ''}`, a.epi?.name || '—', a.quantity, new Date(a.distributedAt).toLocaleDateString('fr-FR'), a.renewalAt ? new Date(a.renewalAt).toLocaleDateString('fr-FR') : '—', `${a.responsible?.firstName ?? ''} ${a.responsible?.lastName ?? ''}`])]]],
    },
    {
      id: 'epi-non-equipes', titre: 'Employés non équipés', description: "Personnel actif n'ayant reçu aucune dotation EPI.",
      sheets: () => [['Non équipés', [['Matricule', 'Nom', 'Département', 'Poste'], ...nonEquipped.map((e) => [e.matricule, `${e.firstName} ${e.lastName}`, e.department || '—', e.position || '—'])]]],
    },
    {
      id: 'epi-renouvellement', titre: 'Rapport de renouvellement', description: 'Dotations expirées ou à renouveler sous 90 jours, par palier.',
      sheets: () => [['Renouvellement', [['Palier', 'Employé', 'EPI', 'Échéance'],
        ...buckets.expired.map((r) => ['Expiré', `${r.employee?.firstName ?? ''} ${r.employee?.lastName ?? ''}`, r.epi?.name ?? '—', new Date(r.renewalAt).toLocaleDateString('fr-FR')]),
        ...buckets.within30.map((r) => ['Sous 30 jours', `${r.employee?.firstName ?? ''} ${r.employee?.lastName ?? ''}`, r.epi?.name ?? '—', new Date(r.renewalAt).toLocaleDateString('fr-FR')]),
        ...buckets.within60.map((r) => ['Sous 60 jours', `${r.employee?.firstName ?? ''} ${r.employee?.lastName ?? ''}`, r.epi?.name ?? '—', new Date(r.renewalAt).toLocaleDateString('fr-FR')]),
        ...buckets.within90.map((r) => ['Sous 90 jours', `${r.employee?.firstName ?? ''} ${r.employee?.lastName ?? ''}`, r.epi?.name ?? '—', new Date(r.renewalAt).toLocaleDateString('fr-FR')]),
      ]]],
    },
    {
      id: 'epc-rapport', titre: 'Rapport EPC', description: 'Bibliothèque complète des équipements de protection collective.',
      sheets: () => [['EPC', [['Code', 'Désignation', 'Catégorie', 'Localisation', 'Statut', 'Prochaine inspection'], ...(epcList || []).map((e) => [e.code, e.name, e.category?.name || '—', e.location || '—', e.status, e.nextInspectionAt ? new Date(e.nextInspectionAt).toLocaleDateString('fr-FR') : '—'])]]],
    },
    {
      id: 'controles-registre', titre: 'Registre des contrôles', description: 'Tous domaines confondus — type, résultat, taux de conformité, décision finale.',
      sheets: () => [['Contrôles', [['Code', 'Domaine', 'Type', 'Date', 'Statut', 'Taux de conformité', 'Décision finale'], ...(qualityControls || []).map((c) => [c.code, c.domain, c.type?.name || '—', new Date(c.controlDate).toLocaleDateString('fr-FR'), c.status, c.conformityRate != null ? `${c.conformityRate}%` : '—', c.finalDecision || '—'])]]],
    },
    {
      id: 'processus-global', titre: 'Rapport global des processus', description: "Cartographie, criticité, score de maîtrise et alertes de tous les processus.",
      sheets: () => {
        const list = processus || [];
        const parType = groupCount(list, (p) => kProcessTypeLabels[p.type] || p.type || 'Non classé');
        return [
          ['Synthèse', [['Indicateur', 'Valeur'], ['Processus cartographiés', list.length], ...parType.map((t) => [t.name, t.value]), ['Critiques', list.filter((p) => p.criticite === 'CRITIQUE').length], ['Sans pilote', list.filter((p) => !p.piloteId).length]]],
          ['Registre', [['Processus', 'Type', 'Criticité', 'Pilote', 'Score de maîtrise', 'Complétude', 'Alertes'], ...list.map((p) => { const score = computeMaturityScore(p); const lvl = maturityLevel(score); return [p.nom, kProcessTypeLabels[p.type] || p.type, p.criticite ? kCriticiteLabel[p.criticite] : '—', p.pilote ? `${p.pilote.firstName} ${p.pilote.lastName}` : '—', `${lvl.label} (${score}/100)`, `${computeCompleteness(p)}%`, processusAlerts(p).join(' · ') || 'Aucune']; })]],
        ];
      },
    },
    {
      id: 'indicateurs-mensuel', titre: 'Rapport mensuel qualité', description: "Indice global, bibliothèque automatique (mois en cours vs précédent) et indicateurs manuels.",
      sheets: () => {
        const auto = indicateursAutoCompare || [];
        const manuels = indicateursQualite || [];
        return [
          ['Indice global', [['Indicateur', 'Valeur'], ['Indice global de performance qualité', indiceGlobal?.indice != null ? `${indiceGlobal.indice}/100` : 'Non disponible']]],
          ['Bibliothèque automatique', [['Indicateur', 'Catégorie', 'Mois en cours', 'Mois précédent', 'Formule'], ...auto.map((a) => [a.nom, a.categorie, a.valeur != null ? `${a.valeur}${a.unite}` : '—', a.valeurPrecedente != null ? `${a.valeurPrecedente}${a.unite}` : '—', a.formule])]],
          ['Indicateurs manuels', [['Indicateur', 'Catégorie', 'Actuel', 'Cible', 'Statut'], ...manuels.map((i) => { const st = indicateurStatus(i.actuel, i.cible, i.sensInverse, i.seuilVert, i.seuilOrange); return [i.indicateur, i.categorie || '—', `${i.actuel}${i.unite || ''}`, `${i.cible}${i.unite || ''}`, st.label]; })]],
        ];
      },
    },
    {
      id: 'reclamations-rapport', titre: 'Rapport réclamations clients', description: "Score global, performance, Pareto des causes, analyses et registre complet.",
      sheets: () => {
        const list = reclamations || [];
        const s = reclamationsStats || { volume: {}, performance: {}, pareto: [], parClient: [], parProduit: [], parProcessus: [] };
        const sc = reclamationsScore || { score: null, detail: [] };
        return [
          ['Synthèse', [
            ['Indicateur', 'Valeur'],
            ['Score global de performance', sc.score != null ? `${sc.score}/100` : 'Non disponible'],
            ['Réclamations totales', s.volume.total ?? 0], ['Ouvertes', s.volume.ouvertes ?? 0], ['Clôturées', s.volume.cloturees ?? 0],
            ['Critiques', s.volume.critiques ?? 0], ['En retard', s.volume.enRetard ?? 0],
            ['Taux de clôture', s.performance.tauxCloture != null ? `${s.performance.tauxCloture}%` : '—'],
            ['Taux de clôture dans les délais', s.performance.tauxClotureDelai != null ? `${s.performance.tauxClotureDelai}%` : '—'],
            ['Délai moyen de résolution (jours)', s.performance.delaiMoyenResolution ?? '—'],
          ]],
          ['Pareto des causes', [['Cause', 'Nombre', '%', '% cumulé'], ...(s.pareto || []).map((p) => [p.name, p.value, `${p.pct}%`, `${p.cumulPct}%`])]],
          ['Par client', [['Client', 'Nombre'], ...(s.parClient || []).map((c) => [c.name, c.value])]],
          ['Registre complet', [['Client', 'Motif', 'Produit/Service', 'Date', 'Gravité', 'Statut', 'Coût total'], ...list.map((r) => [r.client, r.motif, r.produitService || '—', new Date(r.date).toLocaleDateString('fr-FR'), r.gravite, r.statut === 'OPEN' ? 'Ouverte' : 'Clôturée', r.coutTotal || 0])]],
        ];
      },
    },
    {
      id: 'accidents-rapport', titre: 'Rapport accidents & incidents', description: "TF/TG, Pareto des causes, récidives détectées et registre complet.",
      sheets: () => {
        const list = safetyEvents || [];
        const s = safetyEventsStats || { volume: {}, pareto: [], parMecanisme: [], parLesion: [], parZone: [] };
        const r = safetyEventsRecidives || { parCauseRacine: [], parZone: [], parMecanisme: [] };
        return [
          ['Synthèse', [
            ['Indicateur', 'Valeur'],
            ['Événements totaux', s.volume.total ?? 0], ['Accidents', s.volume.accidents ?? 0], ['Incidents', s.volume.incidents ?? 0],
            ['Avec arrêt de travail', s.volume.avecArret ?? 0], ['Graves (sévérité ≥ 4)', s.volume.graves ?? 0],
          ]],
          ['Pareto des causes', [['Cause racine', 'Nombre', '%', '% cumulé'], ...(s.pareto || []).map((p) => [p.name, p.value, `${p.pct}%`, `${p.cumulPct}%`])]],
          ['Par mécanisme', [['Mécanisme', 'Nombre'], ...(s.parMecanisme || []).map((c) => [c.name, c.value])]],
          ['Par zone', [['Zone', 'Nombre'], ...(s.parZone || []).map((c) => [c.name, c.value])]],
          ['Récidives détectées', [['Critère', 'Type', 'Occurrences'], ...(r.parCauseRacine || []).map((x) => [x.critere, 'Cause racine', x.nombre]), ...(r.parZone || []).map((x) => [x.critere, 'Zone', x.nombre]), ...(r.parMecanisme || []).map((x) => [x.critere, 'Mécanisme', x.nombre])]],
          ['Registre complet', [['Type', 'Titre', 'Date', 'Sévérité', 'Arrêt', 'Statut'], ...list.map((e) => [e.type, e.title, new Date(e.occurredAt).toLocaleDateString('fr-FR'), e.severity, e.withLostTime ? `${e.lostDays || 0} j` : '—', e.statut || 'DECLARE'])]],
        ];
      },
    },
    {
      id: 'fournisseurs-rapport', titre: 'Rapport fournisseurs', description: "Classement top/flop, alertes, matrice de risque et registre complet.",
      sheets: () => {
        const list = fournisseurs || [];
        const classement = fournisseursClassement || { top: [], flop: [] };
        const alertes = fournisseursAlertes || [];
        const matrice = fournisseursMatriceRisque || [];
        const statutLabel = {
          PROSPECT: 'Prospect', EN_QUALIFICATION: 'En qualification', EN_ATTENTE_HOMOLOGATION: "En attente d'homologation",
          HOMOLOGUE: 'Homologué', HOMOLOGUE_CONDITIONS: 'Homologué sous conditions', SOUS_SURVEILLANCE: 'Sous surveillance',
          SUSPENDU: 'Suspendu', BLOQUE: 'Bloqué', INACTIF: 'Inactif', RETIRE: 'Retiré du panel',
        };
        return [
          ['Synthèse', [
            ['Indicateur', 'Valeur'],
            ['Fournisseurs totaux', list.length], ['Critiques', list.filter((f) => f.criticite).length],
            ['En attente d\'homologation', list.filter((f) => ['EN_ATTENTE_HOMOLOGATION', 'EN_QUALIFICATION'].includes(f.statut)).length],
            ['Alertes actives', alertes.length],
          ]],
          ['Top 10', [['Fournisseur', 'Score global'], ...classement.top.map((f) => [f.nom, `${f.score}%`])]],
          ['Moins performants', [['Fournisseur', 'Score global'], ...classement.flop.map((f) => [f.nom, `${f.score}%`])]],
          ['Alertes', [['Fournisseur', 'Niveau', 'Motifs'], ...alertes.map((a) => [a.nom, a.niveau, a.motifs.map((m) => m.label).join(' · ')])]],
          ['Matrice de risque', [['Fournisseur', 'Risque', 'Probabilité', 'Gravité', 'Score'], ...matrice.map((r) => [r.fournisseur || '—', r.hazard, r.probability, r.severity, r.score])]],
          ['Registre complet', [['Fournisseur', 'Type', 'Statut', 'Niveau de risque', 'Score qualité', 'Score livraison', 'Score QHSE'], ...list.map((f) => [f.nom, f.typeFournisseur || f.categorie || '—', statutLabel[f.statut] || f.statut, f.niveauRisque || '—', f.scoreQualite ?? '—', f.scoreLivraison ?? '—', f.scoreQhse ?? '—'])]],
        ];
      },
    },
    {
      id: 'hygiene-rapport', titre: 'Rapport Hygiène au travail', description: "Indice global, risques sanitaires, ergonomie/TMS, pénibilité et alertes.",
      sheets: () => {
        const visitesL = visitesMedicales || [];
        const risquesL = risquesSanitaires || [];
        const ergonomiesL = analysesErgonomiques || [];
        const tmsL = tmsSignalements || [];
        const indice = hygieneIndiceGlobal || { indice: null, detail: [] };
        const alertesL = hygieneAlertes || [];
        const scoreErgoLabel = { FAIBLE: 'Faible', MODERE: 'Modéré', ELEVE: 'Élevé', CRITIQUE: 'Critique' };
        return [
          ['Synthèse', [
            ['Indicateur', 'Valeur'],
            ['Indice global Hygiène au travail', indice.indice != null ? `${indice.indice}/100` : 'Non disponible'],
            ['Visites médicales suivies', visitesL.length], ['Risques sanitaires actifs', risquesL.filter((r) => r.statut === 'ACTIVE').length],
            ['Risques critiques', risquesL.filter((r) => r.criticite >= 12 && r.statut === 'ACTIVE').length],
            ['Postes analysés (ergonomie)', ergonomiesL.length], ['Signalements TMS', tmsL.length],
            ['Alertes actives', alertesL.length],
          ]],
          ['Détail de l\'indice', [['Composante', 'Valeur', 'Poids'], ...(indice.detail || []).map((d) => [d.nom, d.valeur != null ? `${d.valeur}%` : '—', d.poids])]],
          ['Risques sanitaires', [['Danger', 'Catégorie', 'Poste/Zone', 'Personnes exposées', 'Criticité', 'Statut'], ...risquesL.map((r) => [r.danger, r.categorie || '—', [r.poste, r.zone].filter(Boolean).join(' / ') || '—', r.nombrePersonnesExposees ?? '—', r.criticite, r.statut])]],
          ['Ergonomie', [['Poste', 'Zone', 'Score'], ...ergonomiesL.map((e) => [e.poste, e.zone || '—', scoreErgoLabel[e.scoreErgonomique] || e.scoreErgonomique])]],
          ['TMS', [['Zone corporelle', 'Poste', 'Date', 'Statut'], ...tmsL.map((t) => [t.zoneCorporelle, t.poste || '—', new Date(t.dateSignalement).toLocaleDateString('fr-FR'), t.statut])]],
          ['Alertes', [['Type', 'Libellé', 'Niveau'], ...alertesL.map((a) => [a.type, a.label, a.niveau])]],
        ];
      },
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

function ControlTypeForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ name: record?.name || '', domain: record?.domain || 'QUALITE', description: record?.description || '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      if (editing) await api.patch(`/quality/types/${record.id}`, form);
      else await api.post('/quality/types', { code: genCode('CTYPE'), ...form });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.name, `/quality/types/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier le type de contrôle' : 'Nouveau type de contrôle'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Nom"><input required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Contrôle réception, Contrôle machine, Contrôle hygiène..." /></FormField>
        <FormField label="Domaine">
          <select value={form.domain} onChange={(e) => setForm({ ...form, domain: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="QUALITE">Qualité (centré produit/ligne/lot)</option>
            <option value="SECURITE">Sécurité</option>
            <option value="HYGIENE">Hygiène</option>
            <option value="ENVIRONNEMENT">Environnement</option>
            <option value="EPI_EPC">EPI/EPC</option>
            <option value="MAINTENANCE">Maintenance</option>
            <option value="FOURNISSEUR">Fournisseur</option>
            <option value="AUTRE">Autre</option>
          </select>
        </FormField>
        <FormField label="Description (optionnel)"><textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
        {form.domain !== 'QUALITE' && <p className="text-[11px] mb-3" style={{ color: C.textMuted }}>Un contrôle de ce type n'exigera pas de ligne/produit/quart/lot — seulement le modèle et sa checklist.</p>}
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Créer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function QualityControlForm({ onClose, onCreated }) {
  const C = useTheme();
  const catalogs = useCollection('/quality/catalogs');
  const types = useCollection('/quality/types');
  const templatesQ = useCollection('/quality/templates');
  const processusQ = useCollection('/business/processus');
  const [form, setForm] = useState({ typeId: '', siteId: '', lineId: '', machineId: '', productId: '', formatId: '', shiftId: '', lotNumber: '', templateId: '', processusId: '', notes: '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const [showTypeForm, setShowTypeForm] = useState(false);

  if (catalogs.loading || types.loading || templatesQ.loading || processusQ.loading) return <Modal title="Nouveau contrôle" onClose={onClose}><LoadingPanel /></Modal>;
  if (catalogs.error) return <Modal title="Nouveau contrôle" onClose={onClose}><ErrorPanel message={catalogs.error} /></Modal>;
  const [sites, products, shifts] = catalogs.data;
  const typeList = types.data || [];
  const allTemplates = templatesQ.data || [];
  const processusList = processusQ.data || [];
  const selectedType = typeList.find((t) => t.id === form.typeId);
  // Sans type sélectionné, on garde le comportement historique (contrôle
  // qualité classique) — rien ne casse pour qui ne choisit pas de type.
  const domain = selectedType?.domain || 'QUALITE';
  const isQualite = domain === 'QUALITE';
  const filteredTemplates = form.typeId ? allTemplates.filter((t) => t.typeId === form.typeId) : allTemplates;
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
        code: genCode('CTRL'), domain, typeId: form.typeId || undefined,
        lineId: isQualite ? form.lineId : undefined, productId: isQualite ? form.productId : undefined,
        shiftId: isQualite ? form.shiftId : undefined, lotNumber: isQualite ? form.lotNumber : undefined,
        siteId: form.siteId || undefined, machineId: form.machineId || undefined, formatId: form.formatId || undefined,
        templateId: form.templateId || undefined, processusId: form.processusId || undefined, notes: form.notes || undefined,
      });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }

  return (
    <>
      <Modal title="Nouveau contrôle" onClose={onClose}>
        <form onSubmit={submit}>
          <FormField label="Type de contrôle">
            <div className="flex gap-2">
              <select value={form.typeId} onChange={(e) => setForm({ ...form, typeId: e.target.value, templateId: '' })} className="flex-1 px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
                <option value="">Contrôle qualité classique (ligne/produit/lot)</option>
                {typeList.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
              </select>
              <button type="button" onClick={() => setShowTypeForm(true)} className="px-3 py-2 rounded-lg text-xs font-medium" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, color: C.text }}>+ Type</button>
            </div>
          </FormField>

          {isQualite && (
            <>
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
            </>
          )}

          <FormField label="Modèle de contrôle (optionnel)">
            <select value={form.templateId} onChange={(e) => setForm({ ...form, templateId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">Aucun (contrôle simple)</option>{filteredTemplates.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
            </select>
          </FormField>
          <FormField label="Processus concerné (optionnel)">
            <select value={form.processusId} onChange={(e) => setForm({ ...form, processusId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>{processusList.map((p) => <option key={p.id} value={p.id}>{p.nom}</option>)}
            </select>
          </FormField>
          <FormField label="Notes"><textarea value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
          {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
          <button type="submit" disabled={saving} className="w-full py-2.5 rounded-lg text-sm font-medium mt-1" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Création…' : 'Créer le contrôle'}</button>
          <p className="text-[11px] mt-2 text-center" style={{ color: C.textMuted }}>Le contrôle est créé en statut « en cours » — la saisie des résultats point par point et la soumission finale se font depuis l'application Windows/Android pour l'instant.</p>
        </form>
      </Modal>
      {showTypeForm && <ControlTypeForm onClose={() => setShowTypeForm(false)} onCreated={types.reload} />}
    </>
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
  const [sampling, setSampling] = useState(null);
  const [savingSampling, setSavingSampling] = useState(false);

  async function load() {
    try {
      const c = await api.get(`/quality/controls/${controlId}`);
      setControl(c);
      const initial = {};
      (c.results || []).forEach((r) => { initial[r.pointId] = { value: r.value, comment: r.comment || '', notApplicable: r.notApplicable }; });
      setValues((prev) => ({ ...initial, ...prev }));
      setSampling((prev) => prev || { lotSize: c.lotSize ?? '', sampleSize: c.sampleSize ?? '', samplingMethod: c.samplingMethod ?? '', acceptanceThreshold: c.acceptanceThreshold ?? '', rejectionThreshold: c.rejectionThreshold ?? '' });
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
  const decisionLabels = { CONFORME: 'Conforme', CONFORME_SOUS_RESERVE: 'Conforme sous réserve', NON_CONFORME: 'Non conforme', REFUSE: 'Refusé' };

  async function saveSampling() {
    setSavingSampling(true); setError(null);
    try {
      await api.patch(`/quality/controls/${controlId}`, {
        lotSize: sampling.lotSize === '' ? null : Number(sampling.lotSize),
        sampleSize: sampling.sampleSize === '' ? null : Number(sampling.sampleSize),
        samplingMethod: sampling.samplingMethod || null,
        acceptanceThreshold: sampling.acceptanceThreshold === '' ? null : Number(sampling.acceptanceThreshold),
        rejectionThreshold: sampling.rejectionThreshold === '' ? null : Number(sampling.rejectionThreshold),
      });
      await load();
    } catch (err) { setError(err.message); }
    setSavingSampling(false);
  }

  async function savePoint(point) {
    setSavingPoint(point.id); setError(null);
    const v = values[point.id] || {};
    try {
      await api.post(`/quality/controls/${controlId}/results`, {
        pointId: point.id,
        value: v.notApplicable ? null : (point.type === 'NUMERIC' ? Number(v.value) : point.type === 'BOOLEAN' ? !!v.value : v.value),
        comment: v.comment || undefined,
        notApplicable: !!v.notApplicable,
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

      {(control.conformityRate != null || control.finalDecision) && (
        <div className="grid grid-cols-3 gap-2 mb-4">
          {control.conformityRate != null && <div className="p-2 rounded-lg text-center" style={{ backgroundColor: C.cardAlt }}><p className="text-[10px]" style={{ color: C.textMuted }}>Taux de conformité</p><p className="text-lg font-bold" style={{ color: C.text }}>{control.conformityRate}%</p></div>}
          {control.defectRate != null && <div className="p-2 rounded-lg text-center" style={{ backgroundColor: C.cardAlt }}><p className="text-[10px]" style={{ color: C.textMuted }}>Taux de défaut</p><p className="text-lg font-bold" style={{ color: C.text }}>{control.defectRate}%</p></div>}
          {control.finalDecision && <div className="p-2 rounded-lg text-center" style={{ backgroundColor: C.cardAlt }}><p className="text-[10px]" style={{ color: C.textMuted }}>Décision finale</p><p className="text-sm font-bold" style={{ color: control.finalDecision === 'CONFORME' ? C.green : control.finalDecision === 'REFUSE' ? C.red : C.amber }}>{decisionLabels[control.finalDecision] || control.finalDecision}</p></div>}
        </div>
      )}

      {!closed && sampling && (
        <div className="mb-4 p-3 rounded-lg" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}` }}>
          <p className="text-xs font-medium mb-2" style={{ color: C.text }}>Échantillonnage (optionnel)</p>
          <div className="grid grid-cols-3 gap-2 mb-2">
            <FormField label="Taille du lot"><input type="number" value={sampling.lotSize} onChange={(e) => setSampling({ ...sampling, lotSize: e.target.value })} className="w-full px-2 py-1.5 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
            <FormField label="Taille échantillon"><input type="number" value={sampling.sampleSize} onChange={(e) => setSampling({ ...sampling, sampleSize: e.target.value })} className="w-full px-2 py-1.5 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
            <FormField label="Méthode"><input value={sampling.samplingMethod} onChange={(e) => setSampling({ ...sampling, samplingMethod: e.target.value })} className="w-full px-2 py-1.5 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          </div>
          <div className="grid grid-cols-2 gap-2 mb-2">
            <FormField label="Seuil d'acceptation (%)"><input type="number" step="any" value={sampling.acceptanceThreshold} onChange={(e) => setSampling({ ...sampling, acceptanceThreshold: e.target.value })} className="w-full px-2 py-1.5 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
            <FormField label="Seuil de rejet (%)"><input type="number" step="any" value={sampling.rejectionThreshold} onChange={(e) => setSampling({ ...sampling, rejectionThreshold: e.target.value })} className="w-full px-2 py-1.5 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          </div>
          <button onClick={saveSampling} disabled={savingSampling} className="text-xs px-3 py-1.5 rounded-lg font-medium" style={{ backgroundColor: C.blue, color: '#fff' }}>{savingSampling ? '…' : 'Enregistrer'}</button>
        </div>
      )}

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
                  {existing && <span className="text-xs" style={{ color: existing.notApplicable ? C.textMuted : existing.compliant === false ? C.red : C.green }}>{existing.notApplicable ? 'Non applicable' : existing.compliant === false ? 'Non conforme' : 'Conforme'}</span>}
                </div>
                {!closed && (
                  <div className="space-y-2">
                    <div className="flex gap-2">
                      {p.type === 'BOOLEAN' && (
                        <select disabled={v.notApplicable} value={v.value ?? ''} onChange={(e) => setValues({ ...values, [p.id]: { ...v, value: e.target.value === 'true' } })} className="px-2 py-1.5 rounded-lg text-sm outline-none" style={inputStyle(C)}>
                          <option value="">—</option><option value="true">Oui</option><option value="false">Non</option>
                        </select>
                      )}
                      {p.type === 'NUMERIC' && (
                        <input disabled={v.notApplicable} type="number" step="any" value={v.value ?? ''} onChange={(e) => setValues({ ...values, [p.id]: { ...v, value: e.target.value } })} className="w-32 px-2 py-1.5 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder={p.unit || ''} />
                      )}
                      {p.type === 'CHOICE' && (
                        <select disabled={v.notApplicable} value={v.value ?? ''} onChange={(e) => setValues({ ...values, [p.id]: { ...v, value: e.target.value } })} className="px-2 py-1.5 rounded-lg text-sm outline-none" style={inputStyle(C)}>
                          <option value="">—</option>{(p.choices || []).map((c) => <option key={c} value={c}>{c}</option>)}
                        </select>
                      )}
                      {(p.type === 'TEXT' || p.type === 'PHOTO') && (
                        <input disabled={v.notApplicable} value={v.value ?? ''} onChange={(e) => setValues({ ...values, [p.id]: { ...v, value: e.target.value } })} className="flex-1 px-2 py-1.5 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder={p.type === 'PHOTO' ? 'Référence de la photo (pièce jointe à venir)' : ''} />
                      )}
                      <input value={v.comment ?? ''} onChange={(e) => setValues({ ...values, [p.id]: { ...v, comment: e.target.value } })} className="flex-1 px-2 py-1.5 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Commentaire (optionnel)" />
                      <button onClick={() => savePoint(p)} disabled={savingPoint === p.id} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.blue, color: '#fff' }}>{savingPoint === p.id ? '…' : existing ? 'Modifier' : 'Enregistrer'}</button>
                    </div>
                    <label className="flex items-center gap-2 text-xs" style={{ color: C.textMuted }}>
                      <input type="checkbox" checked={!!v.notApplicable} onChange={(e) => setValues({ ...values, [p.id]: { ...v, notApplicable: e.target.checked } })} />
                      Non applicable
                    </label>
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

function ControlScheduleForm({ record, types, templates, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({
    name: record?.name || '', typeId: record?.typeId || '', templateId: record?.templateId || '',
    frequency: record?.frequency || 'WEEKLY', intervalDays: record?.intervalDays ?? '',
    nextDueDate: record ? new Date(record.nextDueDate).toISOString().slice(0, 10) : new Date().toISOString().slice(0, 10),
    active: record?.active ?? true,
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      const payload = { ...form, typeId: form.typeId || null, templateId: form.templateId || null, intervalDays: form.intervalDays === '' ? null : Number(form.intervalDays), nextDueDate: new Date(form.nextDueDate).toISOString() };
      if (editing) await api.patch(`/quality/schedules/${record.id}`, payload);
      else await api.post('/quality/schedules', { code: genCode('SCHED'), ...payload });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.name, `/quality/schedules/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier le planning' : 'Nouveau planning de contrôle'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Nom"><input required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Contrôle hygiène hebdomadaire ligne 1" /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Type de contrôle (optionnel)">
            <select value={form.typeId} onChange={(e) => setForm({ ...form, typeId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>{(types || []).map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
            </select>
          </FormField>
          <FormField label="Modèle (optionnel)">
            <select value={form.templateId} onChange={(e) => setForm({ ...form, templateId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>{(templates || []).map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
            </select>
          </FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Fréquence">
            <select value={form.frequency} onChange={(e) => setForm({ ...form, frequency: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="DAILY">Quotidienne</option><option value="WEEKLY">Hebdomadaire</option><option value="MONTHLY">Mensuelle</option>
              <option value="QUARTERLY">Trimestrielle</option><option value="BIANNUAL">Semestrielle</option><option value="ANNUAL">Annuelle</option>
              <option value="CUSTOM">Intervalle personnalisé</option>
            </select>
          </FormField>
          {form.frequency === 'CUSTOM' && <FormField label="Intervalle (jours)"><input type="number" value={form.intervalDays} onChange={(e) => setForm({ ...form, intervalDays: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>}
        </div>
        <FormField label="Prochaine échéance"><input required type="date" value={form.nextDueDate} onChange={(e) => setForm({ ...form, nextDueDate: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        {editing && <label className="flex items-center gap-2 text-xs mb-3" style={{ color: C.textMuted }}><input type="checkbox" checked={form.active} onChange={(e) => setForm({ ...form, active: e.target.checked })} />Actif</label>}
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : editing ? 'Enregistrer les modifications' : 'Créer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function QualiteControlesPage() {
  const C = useTheme();
  const controls = useCollection('/quality/controls');
  const types = useCollection('/quality/types');
  const templatesQ = useCollection('/quality/templates');
  const schedules = useCollection('/quality/schedules');
  const scheduleBuckets = useCollection('/quality/schedules-buckets');
  const [showForm, setShowForm] = useState(false);
  const [selectedId, setSelectedId] = useState(null);
  const [tab, setTab] = useState('dashboard');
  const [domainFilter, setDomainFilter] = useState('');
  const [showScheduleForm, setShowScheduleForm] = useState(false);
  const [selectedSchedule, setSelectedSchedule] = useState(null);
  const [generating, setGenerating] = useState(null);

  if (controls.loading || types.loading || templatesQ.loading || schedules.loading || scheduleBuckets.loading) return <LoadingPanel />;
  if (controls.error) return <ErrorPanel message={controls.error} onRetry={controls.reload} />;

  const allList = controls.data || [];
  const list = domainFilter ? allList.filter((c) => c.domain === domainFilter) : allList;
  const soumis = list.filter((c) => c.status !== 'DRAFT' && c.status !== 'IN_PROGRESS');
  const conformes = list.filter((c) => c.status === 'COMPLIANT').length;
  const nonConformes = list.filter((c) => c.status === 'NON_COMPLIANT').length;
  const enAttente = list.filter((c) => c.status === 'DRAFT' || c.status === 'IN_PROGRESS').length;
  const tauxConformite = soumis.length ? Math.round((conformes / soumis.length) * 100) : null;
  const sorted = [...list].sort((a, b) => new Date(b.controlDate) - new Date(a.controlDate));
  const domains = [...new Set(allList.map((c) => c.domain))];
  const byDomain = groupCount(list, (c) => c.domain);
  const byType = groupCount(list.filter((c) => c.type), (c) => c.type?.name || 'Sans type');
  const buckets = scheduleBuckets.data || { overdue: [], dueSoon: [], upcoming: [] };
  const decisionLabels = { CONFORME: 'Conforme', CONFORME_SOUS_RESERVE: 'Conforme sous réserve', NON_CONFORME: 'Non conforme', REFUSE: 'Refusé' };
  const freqLabels = { DAILY: 'Quotidienne', WEEKLY: 'Hebdomadaire', MONTHLY: 'Mensuelle', QUARTERLY: 'Trimestrielle', BIANNUAL: 'Semestrielle', ANNUAL: 'Annuelle', CUSTOM: 'Personnalisée' };

  async function generateNow(s) {
    setGenerating(s.id);
    try { await api.post(`/quality/schedules/${s.id}/generate`, {}); controls.reload(); schedules.reload(); scheduleBuckets.reload(); }
    catch (e) { alert(e.message); }
    setGenerating(null);
  }

  return (
    <div className="space-y-6">
      {showForm && <QualityControlForm onClose={() => setShowForm(false)} onCreated={controls.reload} />}
      {selectedId && <ControlDetailModal controlId={selectedId} onClose={() => setSelectedId(null)} onChanged={controls.reload} />}
      {(showScheduleForm || selectedSchedule) && <ControlScheduleForm record={selectedSchedule} types={types.data} templates={templatesQ.data} onClose={() => { setShowScheduleForm(false); setSelectedSchedule(null); }} onCreated={() => { schedules.reload(); scheduleBuckets.reload(); }} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouveau contrôle</button>
      </div>

      <div className="flex flex-wrap gap-2">
        {[['dashboard', 'Tableau de bord'], ['registre', 'Registre'], ['planification', 'Planification']].map(([id, label]) => (
          <button key={id} onClick={() => setTab(id)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: tab === id ? C.blue : 'transparent', color: tab === id ? '#fff' : C.textMuted }}>{label}</button>
        ))}
      </div>

      {tab === 'dashboard' && (
        <div className="space-y-6">
          {domains.length > 1 && (
            <div className="flex flex-wrap gap-2">
              <button onClick={() => setDomainFilter('')} className="px-3 py-1 rounded-full text-xs font-medium" style={{ backgroundColor: !domainFilter ? C.blue : C.cardAlt, color: !domainFilter ? '#fff' : C.textMuted, border: `1px solid ${C.border}` }}>Tous domaines</button>
              {domains.map((d) => <button key={d} onClick={() => setDomainFilter(d)} className="px-3 py-1 rounded-full text-xs font-medium" style={{ backgroundColor: domainFilter === d ? C.blue : C.cardAlt, color: domainFilter === d ? '#fff' : C.textMuted, border: `1px solid ${C.border}` }}>{d}</button>)}
            </div>
          )}
          <div className="flex flex-wrap gap-3">
            <KpiCard label="Contrôles enregistrés" value={list.length} color={C.blue} icon={ClipboardList} />
            <KpiCard label="En attente" value={enAttente} color={C.amber} icon={Activity} />
            <KpiCard label="Conformes" value={conformes} color={C.green} icon={ShieldCheck} />
            <KpiCard label="Non conformes" value={nonConformes} color={C.red} icon={AlertTriangle} />
            <KpiCard label="Taux de conformité" value={tauxConformite != null ? `${tauxConformite}%` : '—'} color={C.amber} icon={Activity} />
            <KpiCard label="Contrôles en retard" value={buckets.overdue.length} color={buckets.overdue.length > 0 ? C.red : C.green} icon={AlertTriangle} />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <Panel title="Contrôles par domaine">
              {byDomain.length ? <DonutChart data={byDomain} colors={[C.blue, C.green, C.amber, C.red, '#8B5CF6', '#EC4899']} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun contrôle enregistré</p>}
            </Panel>
            <Panel title="Contrôles par type">
              {byType.length ? <DonutChart data={byType} colors={[C.blue, C.green, C.amber, C.red, '#8B5CF6', '#EC4899']} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun contrôle typé enregistré</p>}
            </Panel>
          </div>
        </div>
      )}

      {tab === 'registre' && (
        <div className="space-y-4">
          <p className="text-xs" style={{ color: C.textMuted }}>Cliquez une ligne pour saisir les résultats et soumettre le contrôle.</p>
          <Panel title="Registre des contrôles">
            {sorted.length
              ? <DataTable columns={['Code', 'Type', 'Produit', 'Ligne', 'Lot', 'Date', 'Statut', 'Décision']}
                  rows={sorted.map((c) => [c.code, c.type?.name || c.domain, c.productRef?.name || '—', c.productionLine?.name || '—', c.lotNumber || '—', new Date(c.controlDate).toLocaleDateString('fr-FR'), <StatusChip statut={c.status === 'COMPLIANT' ? 'Conforme' : c.status === 'NON_COMPLIANT' ? 'Non conforme' : c.status} />, decisionLabels[c.finalDecision] || c.finalDecision || '—'])}
                  onRowClick={(i) => setSelectedId(sorted[i].id)} />
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun contrôle enregistré pour le moment</p>}
          </Panel>
        </div>
      )}

      {tab === 'planification' && (
        <div className="space-y-4">
          <div className="flex justify-end">
            <button onClick={() => setShowScheduleForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouveau planning</button>
          </div>
          {[['🔴 En retard', buckets.overdue, C.red], ['🟡 Sous 7 jours', buckets.dueSoon, C.amber], ['À venir', buckets.upcoming, C.blue]].map(([title, sl, color]) => (
            <Panel key={title} title={title}>
              {sl.length
                ? <div className="space-y-2">
                    {sl.map((s) => (
                      <div key={s.id} className="flex items-center justify-between py-2" style={{ borderTop: `1px solid ${C.border}` }}>
                        <div className="cursor-pointer" onClick={() => setSelectedSchedule(s)}>
                          <p className="text-sm font-medium" style={{ color: C.text }}>{s.name}</p>
                          <p className="text-xs" style={{ color: C.textMuted }}>{freqLabels[s.frequency] || s.frequency} • {s.assignedTo ? `${s.assignedTo.firstName} ${s.assignedTo.lastName}` : 'Non affecté'} • échéance <span style={{ color }}>{new Date(s.nextDueDate).toLocaleDateString('fr-FR')}</span></p>
                        </div>
                        <button onClick={() => generateNow(s)} disabled={generating === s.id} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: generating === s.id ? 0.6 : 1 }}>{generating === s.id ? 'Génération…' : 'Générer maintenant'}</button>
                      </div>
                    ))}
                  </div>
                : <p className="text-sm text-center py-4" style={{ color: C.textMuted }}>Aucun planning dans ce palier</p>}
            </Panel>
          ))}
        </div>
      )}
    </div>
  );
}

const kProcessTypeLabels = { STRATEGIQUE: 'Stratégique', OPERATIONNEL: 'Opérationnel', SUPPORT: 'Support', AUTRE: 'Autre' };
const kCriticiteColor = (C, crit) => ({ FAIBLE: C.green, MOYEN: C.blue, IMPORTANT: C.amber, CRITIQUE: C.red }[crit] || C.textMuted);
const kCriticiteLabel = { FAIBLE: 'Faible', MOYEN: 'Moyen', IMPORTANT: 'Important', CRITIQUE: 'Critique' };

// Score de maîtrise — combine plusieurs signaux réellement disponibles
// (pilotage, criticité, écarts ouverts, audits, objectifs, documentation,
// formations à jour). Les seuils ci-dessous sont volontairement des
// constantes simples à ajuster ici, plutôt qu'un réglage caché dans
// l'interface.
function objectifsHorsCible(p) {
  const now = new Date();
  return (p.objectifsQhse || []).filter((o) => o.echeance && new Date(o.echeance) < now && o.actuel < o.cible);
}
function formationsExpirees(p) {
  const now = new Date();
  return (p.trainings || []).filter((t) => t.expiryAt && new Date(t.expiryAt) < now);
}
function documentsEnRetard(p) {
  const now = new Date();
  return (p.documents || []).filter((d) => d.nextReviewAt && new Date(d.nextReviewAt) < now);
}
function auditsEnRetard(p) {
  const now = new Date();
  return (p.audits || []).filter((a) => a.status === 'PLANNED' && new Date(a.auditDate) < now);
}
function computeMaturityScore(p) {
  let score = 60;
  if (!p.piloteId) score -= 15;
  if (p.criticite === 'CRITIQUE') score -= 10;
  score -= Math.min(20, (p._count?.nonConformities || 0) * 5);
  score -= Math.min(15, (p._count?.actions || 0) * 3);
  score -= Math.min(10, (p._count?.risks || 0) * 2);
  score -= Math.min(15, objectifsHorsCible(p).length * 5);
  score -= Math.min(10, formationsExpirees(p).length * 5);
  score -= Math.min(10, documentsEnRetard(p).length * 5);
  score -= Math.min(10, auditsEnRetard(p).length * 5);
  if ((p.audits || []).length > 0) score += 10;
  if ((p.objectifsQhse || []).length > 0) score += 5;
  if ((p.documents || []).length > 0) score += 5;
  return Math.max(0, Math.min(100, score));
}
function maturityLevel(score) {
  if (score >= 80) return { label: 'Maîtrisé', emoji: '🟢' };
  if (score >= 60) return { label: 'À surveiller', emoji: '🟡' };
  if (score >= 40) return { label: 'À améliorer', emoji: '🟠' };
  return { label: 'Critique', emoji: '🔴' };
}
// Score de complétude — proportion d'éléments clés effectivement
// renseignés sur la fiche processus.
function computeCompleteness(p) {
  const checks = [!!p.piloteId, !!p.finalite, !!p.criticite, (p.activities || []).length > 0, (p.exigences || []).length > 0, (p._count?.risks || 0) > 0, (p.objectifsQhse || []).length > 0, !!p.kpi];
  return Math.round((checks.filter(Boolean).length / checks.length) * 100);
}
function processusAlerts(p) {
  const alerts = [];
  if (!p.piloteId) alerts.push('Sans pilote');
  if (!p.kpi) alerts.push('Sans indicateur');
  if (!(p._count?.risks > 0)) alerts.push('Sans analyse de risques');
  if (!((p.objectifsQhse || []).length > 0)) alerts.push('Sans objectif');
  const hc = objectifsHorsCible(p).length; if (hc > 0) alerts.push(`${hc} objectif(s) hors cible`);
  const fe = formationsExpirees(p).length; if (fe > 0) alerts.push(`${fe} formation(s) expirée(s)`);
  const dr = documentsEnRetard(p).length; if (dr > 0) alerts.push(`${dr} document(s) en retard de révision`);
  const ar = auditsEnRetard(p).length; if (ar > 0) alerts.push(`${ar} audit(s) en retard`);
  return alerts;
}

function ProcessusCartography({ procList, links, onLinkCreate, onLinkDelete, onPositionCommit, onSelect }) {
  const C = useTheme();
  const containerRef = useRef(null);
  const [zoom, setZoom] = useState(1);
  const [linkMode, setLinkMode] = useState(false);
  const [linkSource, setLinkSource] = useState(null);
  const [dragId, setDragId] = useState(null);
  const [positions, setPositions] = useState({});

  useEffect(() => {
    const next = {};
    procList.forEach((p, i) => {
      next[p.id] = p.positionX != null && p.positionY != null
        ? { x: p.positionX, y: p.positionY }
        : { x: 40 + (i % 4) * 220, y: 40 + Math.floor(i / 4) * 130 };
    });
    setPositions(next);
  }, [procList]);

  function onBoxMouseDown(e, p) {
    e.stopPropagation();
    if (linkMode) {
      if (!linkSource) setLinkSource(p.id);
      else if (linkSource !== p.id) { onLinkCreate(linkSource, p.id); setLinkSource(null); }
      return;
    }
    setDragId(p.id);
  }
  function onMouseMove(e) {
    if (!dragId || !containerRef.current) return;
    const rect = containerRef.current.getBoundingClientRect();
    const x = (e.clientX - rect.left) / zoom - 90;
    const y = (e.clientY - rect.top) / zoom - 28;
    setPositions((prev) => ({ ...prev, [dragId]: { x, y } }));
  }
  function onMouseUp() {
    if (dragId && positions[dragId]) onPositionCommit(dragId, positions[dragId].x, positions[dragId].y);
    setDragId(null);
  }

  const byId = Object.fromEntries(procList.map((p) => [p.id, p]));

  return (
    <div>
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <button onClick={() => setZoom((z) => Math.max(0.5, z - 0.1))} className="w-8 h-8 rounded-lg text-sm" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, color: C.text }}>−</button>
          <span className="text-xs w-12 text-center" style={{ color: C.textMuted }}>{Math.round(zoom * 100)}%</span>
          <button onClick={() => setZoom((z) => Math.min(2, z + 0.1))} className="w-8 h-8 rounded-lg text-sm" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, color: C.text }}>+</button>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={() => { setLinkMode((m) => !m); setLinkSource(null); }} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: linkMode ? C.blue : C.cardAlt, color: linkMode ? '#fff' : C.text, border: `1px solid ${C.border}` }}>{linkMode ? (linkSource ? 'Cliquez le processus cible…' : 'Cliquez le processus source…') : '+ Lien entre processus'}</button>
          <button onClick={() => window.print()} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, color: C.text }}>Imprimer / PDF</button>
        </div>
      </div>
      <div
        ref={containerRef}
        onMouseMove={onMouseMove}
        onMouseUp={onMouseUp}
        onMouseLeave={onMouseUp}
        className="relative overflow-auto rounded-xl"
        style={{ height: 560, backgroundColor: C.cardAlt, border: `1px solid ${C.border}` }}
      >
        <div style={{ transform: `scale(${zoom})`, transformOrigin: 'top left', position: 'relative', width: 1400, height: 900 }}>
          <svg className="absolute inset-0 pointer-events-none" width={1400} height={900}>
            {links.map((l) => {
              const s = positions[l.sourceId], t = positions[l.targetId];
              if (!s || !t) return null;
              return <line key={l.id} x1={s.x + 90} y1={s.y + 28} x2={t.x + 90} y2={t.y + 28} stroke={C.blue} strokeWidth={1.5} markerEnd="url(#arrow)" />;
            })}
            <defs>
              <marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><polygon points="0 0, 8 4, 0 8" fill={C.blue} /></marker>
            </defs>
          </svg>
          {procList.map((p) => {
            const pos = positions[p.id] || { x: 0, y: 0 };
            const score = computeMaturityScore(p);
            const lvl = maturityLevel(score);
            return (
              <div
                key={p.id}
                onMouseDown={(e) => onBoxMouseDown(e, p)}
                onClick={() => !dragId && !linkMode && onSelect(p)}
                className="absolute p-2.5 rounded-lg select-none"
                style={{ left: pos.x, top: pos.y, width: 180, cursor: linkMode ? 'crosshair' : 'grab', backgroundColor: C.card, border: `2px solid ${linkSource === p.id ? C.blue : (p.criticite ? kCriticiteColor(C, p.criticite) : C.border)}` }}
              >
                <p className="text-xs font-medium truncate" style={{ color: C.text }}>{p.nom}</p>
                <div className="flex items-center justify-between mt-1">
                  <span className="text-[10px]" style={{ color: C.textMuted }}>{kProcessTypeLabels[p.type] || p.type}</span>
                  <span className="text-[11px]">{lvl.emoji}</span>
                </div>
              </div>
            );
          })}
        </div>
      </div>
      {links.length > 0 && (
        <div className="flex flex-wrap gap-2 mt-3">
          {links.map((l) => (
            <span key={l.id} className="text-[11px] px-2 py-1 rounded-full flex items-center gap-1" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, color: C.textMuted }}>
              {byId[l.sourceId]?.nom || '?'} → {byId[l.targetId]?.nom || '?'}
              <button onClick={() => onLinkDelete(l.id)} style={{ color: C.red }}>×</button>
            </span>
          ))}
        </div>
      )}
    </div>
  );
}

// Rapport individuel d'un processus — identification, SIPOC/activités,
// RACI, exigences, risques, actions, NC, audits, documents, formations,
// objectifs, score de maîtrise. Toutes les données sont déjà présentes
// dans la fiche processus telle que renvoyée par l'API, aucun appel
// supplémentaire nécessaire.
function downloadProcessusReport(p) {
  const score = computeMaturityScore(p); const lvl = maturityLevel(score);
  const sheets = [
    ['Identification', [
      ['Champ', 'Valeur'],
      ['Code', p.code], ['Nom', p.nom], ['Type', kProcessTypeLabels[p.type] || p.type],
      ['Criticité', p.criticite ? kCriticiteLabel[p.criticite] : '—'],
      ['Pilote', p.pilote ? `${p.pilote.firstName} ${p.pilote.lastName}` : '—'],
      ['Suppléant', p.suppleant ? `${p.suppleant.firstName} ${p.suppleant.lastName}` : '—'],
      ['Finalité', p.finalite || '—'], ['Objectif principal', p.objectifPrincipal || '—'],
      ['Score de maîtrise', `${lvl.emoji} ${lvl.label} (${score}/100)`], ['Score de complétude', `${computeCompleteness(p)}%`],
      ['Alertes', processusAlerts(p).join(' · ') || 'Aucune'],
    ]],
    ['Activités (SIPOC)', [['Ordre', 'Activité', 'Responsable', 'Entrées', 'Sorties', 'Criticité'], ...(p.activities || []).map((a) => [a.order, a.name, a.responsible ? `${a.responsible.firstName} ${a.responsible.lastName}` : '—', a.inputs || '—', a.outputs || '—', a.criticality || '—'])]],
    ['RACI', [['Activité', 'Rôle', 'RACI'], ...(p.activities || []).flatMap((a) => (a.racis || []).map((r) => [a.name, r.user ? `${r.user.firstName} ${r.user.lastName}` : r.roleLabel || '—', r.raci]))]],
    ['Exigences', [['Exigence', 'Origine', 'Applicable', 'Statut', 'Prochaine échéance'], ...(p.exigences || []).map((e) => [e.exigence, e.origine || '—', e.applicable ? 'Oui' : 'Non', e.statutConformite, e.prochaineEcheance ? new Date(e.prochaineEcheance).toLocaleDateString('fr-FR') : '—'])]],
    ['Risques', [['Danger', 'Activité', 'Score', 'Statut'], ...(p.risks || []).map((r) => [r.hazard, r.activity || '—', r.score, r.status])]],
    ['Actions', [['Titre', 'Priorité', 'Échéance', 'Statut'], ...(p.actions || []).map((a) => [a.title, a.priority, a.dueDate ? new Date(a.dueDate).toLocaleDateString('fr-FR') : '—', a.status])]],
    ['Non-conformités', [['Titre', 'Classification', 'Statut'], ...(p.nonConformities || []).map((n) => [n.title, n.classification || '—', n.status])]],
    ['Audits', [['Titre', 'Date', 'Statut', 'Score'], ...(p.audits || []).map((a) => [a.title, new Date(a.auditDate).toLocaleDateString('fr-FR'), a.status, a.score != null ? `${a.score}%` : '—'])]],
    ['Documents', [['Titre', 'Catégorie', 'Prochaine révision'], ...(p.documents || []).map((d) => [d.title, d.category, d.nextReviewAt ? new Date(d.nextReviewAt).toLocaleDateString('fr-FR') : '—'])]],
    ['Formations', [['Intitulé', 'Date', 'Expiration'], ...(p.trainings || []).map((t) => [t.title, new Date(t.scheduledAt).toLocaleDateString('fr-FR'), t.expiryAt ? new Date(t.expiryAt).toLocaleDateString('fr-FR') : '—'])]],
    ['Objectifs', [['Titre', 'Cible', 'Actuel', 'Échéance'], ...(p.objectifsQhse || []).map((o) => [o.titre, o.cible, o.actuel, o.echeance ? new Date(o.echeance).toLocaleDateString('fr-FR') : '—'])]],
  ];
  downloadWorkbook(sheets, `Processus_${p.code}.xlsx`);
}

function QualiteProcessusPage() {
  const C = useTheme();
  const processus = useCollection('/business/processus');
  const linksQ = useCollection('/business/processus-links');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  const [tab, setTab] = useState('dashboard');
  if (processus.loading || linksQ.loading) return <LoadingPanel />;
  if (processus.error) return <ErrorPanel message={processus.error} onRetry={processus.reload} />;
  const procList = processus.data || [];
  const linkList = linksQ.data || [];

  async function createLink(sourceId, targetId) {
    try { await api.post('/business/processus-links', { sourceId, targetId }); linksQ.reload(); } catch (e) { alert(e.message); }
  }
  async function deleteLink(id) {
    try { await api.delete(`/business/processus-links/${id}`); linksQ.reload(); } catch (e) { alert(e.message); }
  }
  async function commitPosition(id, x, y) {
    try { await api.patch(`/business/processus/${id}`, { positionX: x, positionY: y }); } catch (e) { /* silencieux — le déplacement reste visible localement */ }
  }

  const parType = groupCount(procList, (p) => kProcessTypeLabels[p.type] || p.type || 'Non classé');
  const sansPilote = procList.filter((p) => !p.piloteId);
  const critiques = procList.filter((p) => p.criticite === 'CRITIQUE');
  const avecActionsOuvertes = procList.filter((p) => (p._count?.actions || 0) > 0);
  const avecNcOuvertes = procList.filter((p) => (p._count?.nonConformities || 0) > 0);
  const avecAudit = procList.filter((p) => (p.audits || []).length > 0);
  // Priorités QHSE — les processus qui appellent le plus l'attention,
  // combinant plusieurs signaux plutôt qu'un seul critère.
  const priorites = procList
    .map((p) => ({ p, score: (!p.piloteId ? 2 : 0) + (p.criticite === 'CRITIQUE' ? 3 : p.criticite === 'IMPORTANT' ? 1 : 0) + (p._count?.nonConformities || 0) + (p._count?.actions || 0) }))
    .filter((x) => x.score > 0).sort((a, b) => b.score - a.score).slice(0, 8);

  const typeGroups = ['STRATEGIQUE', 'OPERATIONNEL', 'SUPPORT', 'AUTRE'];

  return (
    <div className="space-y-6">
      {(showForm || selected) && <ProcessusForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={processus.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouveau processus</button>
      </div>

      <div className="flex flex-wrap gap-2">
        {[['dashboard', 'Tableau de bord'], ['cartographie', 'Cartographie'], ['registre', 'Registre']].map(([id, label]) => (
          <button key={id} onClick={() => setTab(id)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: tab === id ? C.blue : 'transparent', color: tab === id ? '#fff' : C.textMuted }}>{label}</button>
        ))}
      </div>

      {tab === 'dashboard' && (
        <div className="space-y-6">
          <div className="flex flex-wrap gap-3">
            <KpiCard label="Processus cartographiés" value={procList.length} color={C.blue} icon={ClipboardList} />
            <KpiCard label="Stratégiques" value={procList.filter((p) => p.type === 'STRATEGIQUE').length} color={C.blue} icon={ShieldCheck} />
            <KpiCard label="Opérationnels" value={procList.filter((p) => p.type === 'OPERATIONNEL').length} color={C.green} icon={Activity} />
            <KpiCard label="Supports" value={procList.filter((p) => p.type === 'SUPPORT').length} color={C.amber} icon={ClipboardList} />
            <KpiCard label="Critiques" value={critiques.length} color={critiques.length > 0 ? C.red : C.green} icon={AlertTriangle} />
            <KpiCard label="Sans pilote" value={sansPilote.length} color={sansPilote.length > 0 ? C.red : C.green} icon={Users} />
            <KpiCard label="Avec actions ouvertes" value={avecActionsOuvertes.length} color={C.amber} icon={ClipboardList} />
            <KpiCard label="Avec NC ouvertes" value={avecNcOuvertes.length} color={avecNcOuvertes.length > 0 ? C.red : C.green} icon={AlertTriangle} />
            <KpiCard label="Ayant fait l'objet d'un audit" value={avecAudit.length} color={C.blue} icon={ShieldCheck} />
          </div>

          <Panel title="Priorités QHSE" subtitle="Les processus qui appellent le plus l'attention en ce moment">
            {priorites.length
              ? <div className="space-y-2">
                  {priorites.map(({ p, score }) => (
                    <div key={p.id} onClick={() => setSelected(p)} className="flex items-center justify-between py-2 cursor-pointer" style={{ borderTop: `1px solid ${C.border}` }}>
                      <div>
                        <p className="text-sm font-medium" style={{ color: C.text }}>{p.nom}</p>
                        <p className="text-xs" style={{ color: C.textMuted }}>
                          {!p.piloteId && 'Sans pilote · '}
                          {p.criticite === 'CRITIQUE' && 'Criticité critique · '}
                          {(p._count?.nonConformities || 0) > 0 && `${p._count.nonConformities} NC ouverte(s) · `}
                          {(p._count?.actions || 0) > 0 && `${p._count.actions} action(s) ouverte(s)`}
                        </p>
                      </div>
                      <span className="text-xs px-2 py-1 rounded-full" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Priorité {score}</span>
                    </div>
                  ))}
                </div>
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun processus n'appelle une attention particulière pour le moment</p>}
          </Panel>

          <Panel title="Alertes automatiques">
            {procList.some((p) => processusAlerts(p).length > 0)
              ? <div className="space-y-2">
                  {procList.filter((p) => processusAlerts(p).length > 0).map((p) => (
                    <div key={p.id} onClick={() => setSelected(p)} className="flex items-center justify-between py-1.5 cursor-pointer" style={{ borderTop: `1px solid ${C.border}` }}>
                      <span className="text-sm" style={{ color: C.text }}>{p.nom}</span>
                      <span className="text-xs" style={{ color: C.amber }}>{processusAlerts(p).join(' · ')}</span>
                    </div>
                  ))}
                </div>
              : <p className="text-sm text-center py-4" style={{ color: C.textMuted }}>Aucune alerte — tous les processus ont un pilote, un indicateur, une analyse de risques et un objectif</p>}
          </Panel>

          <Panel title="Processus par type">
            {parType.length ? <DonutChart data={parType} colors={[C.blue, C.green, C.amber, C.red]} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun processus enregistré</p>}
          </Panel>
        </div>
      )}

      {tab === 'cartographie' && (
        procList.length === 0
          ? <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun processus enregistré pour le moment</p>
          : <ProcessusCartography procList={procList} links={linkList} onLinkCreate={createLink} onLinkDelete={deleteLink} onPositionCommit={commitPosition} onSelect={setSelected} />
      )}

      {tab === 'registre' && (
        <Panel title="Registre des processus">
          {procList.length
            ? <DataTable columns={['Processus', 'Type', 'Criticité', 'Pilote', 'NC ouvertes', 'Actions ouvertes', 'Maîtrise', 'Complétude', '']}
                rows={procList.map((p) => {
                  const score = computeMaturityScore(p); const lvl = maturityLevel(score);
                  return [p.nom, kProcessTypeLabels[p.type] || p.type, p.criticite ? kCriticiteLabel[p.criticite] : '—', p.pilote ? `${p.pilote.firstName} ${p.pilote.lastName}` : '—', p._count?.nonConformities || 0, p._count?.actions || 0, `${lvl.emoji} ${lvl.label}`, `${computeCompleteness(p)}%`,
                    <button onClick={(e) => { e.stopPropagation(); downloadProcessusReport(p); }} className="text-xs" style={{ color: C.blue }}>Rapport</button>];
                })}
                onRowClick={(i) => setSelected(procList[i])} />
            : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun processus enregistré pour le moment</p>}
        </Panel>
      )}
    </div>
  );
}

function indicateurStatus(actuel, cible, sensInverse, seuilVert, seuilOrange) {
  if (actuel == null) return { color: null, label: '—' };
  // Seuils explicites si renseignés, sinon un repère par défaut basé sur
  // l'écart à la cible — jamais un calcul caché, juste un repère visuel.
  if (seuilVert != null && seuilOrange != null) {
    const good = sensInverse ? actuel <= seuilVert : actuel >= seuilVert;
    const warn = sensInverse ? actuel <= seuilOrange : actuel >= seuilOrange;
    if (good) return { color: 'green', label: 'Conforme' };
    if (warn) return { color: 'amber', label: 'À surveiller' };
    return { color: 'red', label: 'Non conforme' };
  }
  if (cible == null) return { color: null, label: '—' };
  const ratio = sensInverse ? (cible === 0 ? (actuel === 0 ? 1 : 0) : cible / Math.max(actuel, 0.0001)) : (cible === 0 ? 1 : actuel / cible);
  if (ratio >= 1) return { color: 'green', label: 'Conforme' };
  if (ratio >= 0.7) return { color: 'amber', label: 'À surveiller' };
  return { color: 'red', label: 'Non conforme' };
}

function IndicateurDetailModal({ indicateur, onClose, onChanged }) {
  const C = useTheme();
  const [showActionForm, setShowActionForm] = useState(false);
  const actuel = indicateur.actuel; const cible = indicateur.cible;
  const atteint = indicateur.sensInverse ? actuel <= cible : actuel >= cible;
  const ecart = Math.round((actuel - cible) * 100) / 100;
  const mesures = [...(indicateur.mesures || [])].sort((a, b) => new Date(b.periode) - new Date(a.periode));
  const st = indicateurStatus(actuel, cible, indicateur.sensInverse, indicateur.seuilVert, indicateur.seuilOrange);
  const statusColorMap = { green: C.green, amber: C.amber, red: C.red };

  return (
    <>
      {showActionForm && <ActionForm prefill={{ title: `Corriger l'écart — ${indicateur.indicateur}`, description: `Valeur actuelle ${actuel}${indicateur.unite || ''}, cible ${cible}${indicateur.unite || ''} (écart ${ecart > 0 ? '+' : ''}${ecart}${indicateur.unite || ''}).` }} onClose={() => setShowActionForm(false)} onCreated={onChanged} />}
      <Modal title={indicateur.indicateur} onClose={onClose}>
        <div className="grid grid-cols-3 gap-2 mb-4">
          <div className="p-2 rounded-lg text-center" style={{ backgroundColor: C.cardAlt }}><p className="text-[10px]" style={{ color: C.textMuted }}>Actuel</p><p className="text-lg font-bold" style={{ color: statusColorMap[st.color] || C.text }}>{actuel}{indicateur.unite}</p></div>
          <div className="p-2 rounded-lg text-center" style={{ backgroundColor: C.cardAlt }}><p className="text-[10px]" style={{ color: C.textMuted }}>Cible</p><p className="text-lg font-bold" style={{ color: C.text }}>{cible}{indicateur.unite}</p></div>
          <div className="p-2 rounded-lg text-center" style={{ backgroundColor: C.cardAlt }}><p className="text-[10px]" style={{ color: C.textMuted }}>Écart</p><p className="text-lg font-bold" style={{ color: atteint ? C.green : C.red }}>{ecart > 0 ? '+' : ''}{ecart}{indicateur.unite}</p></div>
        </div>
        {(indicateur.categorie || indicateur.formule || indicateur.processus) && (
          <div className="mb-4 text-xs space-y-1" style={{ color: C.textMuted }}>
            {indicateur.categorie && <p>Catégorie : {indicateur.categorie}</p>}
            {indicateur.formule && <p>Formule : {indicateur.formule}</p>}
            {indicateur.processus && <p>Processus : {indicateur.processus.nom}</p>}
            {indicateur.frequence && <p>Fréquence : {indicateur.frequence}</p>}
          </div>
        )}
        {!atteint && (
          <button onClick={() => setShowActionForm(true)} className="w-full py-2 rounded-lg text-xs font-medium mb-4" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Créer une action corrective</button>
        )}
        <p className="text-sm font-semibold mb-2" style={{ color: C.text }}>Historique des mesures</p>
        {mesures.length
          ? <div className="space-y-1 max-h-64 overflow-auto">
              {mesures.map((m) => (
                <div key={m.id} className="flex justify-between text-xs py-1" style={{ borderTop: `1px solid ${C.border}` }}>
                  <span style={{ color: C.textMuted }}>{new Date(m.periode).toLocaleDateString('fr-FR')}{m.commentaire ? ` — ${m.commentaire}` : ''}</span>
                  <span style={{ color: C.text }}>{m.valeur}{indicateur.unite}</span>
                </div>
              ))}
            </div>
          : <p className="text-xs text-center py-4" style={{ color: C.textMuted }}>Aucune mesure enregistrée pour le moment</p>}
      </Modal>
    </>
  );
}

function IndicateurDomainPanel({ domaine, titre }) {
  const C = useTheme();
  const indicateurs = useCollection(`/business/indicateurs-qualite?domaine=${domaine}`);
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  const [detailFor, setDetailFor] = useState(null);
  const [mesureFor, setMesureFor] = useState(null);
  if (indicateurs.loading) return <LoadingPanel />;
  if (indicateurs.error) return <ErrorPanel message={indicateurs.error} onRetry={indicateurs.reload} />;
  const list = indicateurs.data || [];
  const cibles = list.filter((i) => (i.sensInverse ? i.actuel <= i.cible : i.actuel >= i.cible)).length;

  return (
    <div className="space-y-4">
      {(showForm || selected) && <IndicateurForm record={selected} domaine={domaine} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={indicateurs.reload} />}
      {mesureFor && <IndicateurMesureDialog indicateur={mesureFor} onClose={() => setMesureFor(null)} onCreated={indicateurs.reload} />}
      {detailFor && <IndicateurDetailModal indicateur={detailFor} onClose={() => setDetailFor(null)} onChanged={indicateurs.reload} />}
      <div className="flex items-center justify-between">
        <p className="text-sm font-semibold" style={{ color: C.text }}>{titre}</p>
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvel indicateur</button>
      </div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="Indicateurs suivis" value={list.length} color={C.blue} icon={Activity} />
        <KpiCard label="Dans la cible" value={cibles} color={C.green} icon={ShieldCheck} />
        <KpiCard label="Hors cible" value={list.length - cibles} color={C.red} icon={AlertTriangle} />
      </div>
      {list.length === 0
        ? <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun indicateur enregistré pour ce domaine</p>
        : <div className="space-y-4">
            {list.map((i) => {
              const atteint = i.sensInverse ? i.actuel <= i.cible : i.actuel >= i.cible;
              const pct = Math.min(100, (i.actuel / i.cible) * 100);
              return (
                <div key={i.id}>
                  <div className="flex justify-between items-center text-xs mb-1">
                    <span className="cursor-pointer" style={{ color: C.text }} onClick={() => setDetailFor(i)}>{i.indicateur} {i.categorie && <span style={{ color: C.textMuted }}>· {i.categorie}</span>}</span>
                    <div className="flex items-center gap-2">
                      <span style={{ color: C.textMuted }}>{i.actuel}{i.unite} / {i.cible}{i.unite}</span>
                      <button onClick={() => setMesureFor(i)} className="text-[11px]" style={{ color: C.blue }}>+ Mesure</button>
                      <button onClick={() => setSelected(i)} className="text-[11px]" style={{ color: C.textMuted }}>Modifier</button>
                    </div>
                  </div>
                  <div className="h-2 rounded-full" style={{ backgroundColor: C.border }}><div className="h-2 rounded-full" style={{ width: `${pct}%`, backgroundColor: atteint ? C.green : C.amber }} /></div>
                </div>
              );
            })}
          </div>}
    </div>
  );
}

function IndicateurMesureDialog({ indicateur, onClose, onCreated }) {
  const C = useTheme();
  const [valeur, setValeur] = useState('');
  const [commentaire, setCommentaire] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      await api.post(`/business/indicateurs-qualite/${indicateur.id}/mesures`, { valeur: Number(valeur), commentaire: commentaire || undefined });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={`Nouvelle mesure — ${indicateur.indicateur}`} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Valeur"><input required type="number" step="any" value={valeur} onChange={(e) => setValeur(e.target.value)} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        <FormField label="Commentaire (optionnel)"><input value={commentaire} onChange={(e) => setCommentaire(e.target.value)} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <button type="submit" disabled={saving} className="w-full py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : 'Enregistrer la mesure'}</button>
      </form>
    </Modal>
  );
}

function IndicateursQualitePage() {
  const C = useTheme();
  const indicateurs = useCollection('/business/indicateurs-qualite');
  const auto = useCollection('/business/indicateurs-auto-compare');
  const indice = useCollection('/business/indice-global-qualite');
  const ponderations = useCollection('/business/indicateurs-ponderation');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  const [detailFor, setDetailFor] = useState(null);
  const [mesureFor, setMesureFor] = useState(null);
  const [categorieFilter, setCategorieFilter] = useState('');
  const [showPonderation, setShowPonderation] = useState(false);
  if (indicateurs.loading || auto.loading || indice.loading || ponderations.loading) return <LoadingPanel />;
  if (indicateurs.error) return <ErrorPanel message={indicateurs.error} onRetry={indicateurs.reload} />;
  const allIndList = indicateurs.data || [];
  const categories = [...new Set(allIndList.map((i) => i.categorie).filter(Boolean))];
  const indList = categorieFilter ? allIndList.filter((i) => i.categorie === categorieFilter) : allIndList;
  const autoList = auto.data || [];
  const indiceData = indice.data || { indice: null, detail: [] };
  const cibles = indList.filter((i) => (i.sensInverse ? i.actuel <= i.cible : i.actuel >= i.cible)).length;
  const statusColorMap = { green: C.green, amber: C.amber, red: C.red };
  const indiceStatus = indicateurStatus(indiceData.indice, null, false, 80, 60);

  async function savePonderation(autoKey, poids) {
    try { await api.post('/business/indicateurs-ponderation', { autoKey, poids: Number(poids) }); ponderations.reload(); indice.reload(); }
    catch (e) { alert(e.message); }
  }

  return (
    <div className="space-y-6">
      {(showForm || selected) && <IndicateurForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={indicateurs.reload} />}
      {mesureFor && <IndicateurMesureDialog indicateur={mesureFor} onClose={() => setMesureFor(null)} onCreated={indicateurs.reload} />}
      {detailFor && <IndicateurDetailModal indicateur={detailFor} onClose={() => setDetailFor(null)} onChanged={indicateurs.reload} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvel indicateur</button>
      </div>

      <Panel title="Indice global de performance qualité" subtitle="Moyenne pondérée de la bibliothèque automatique — pondérations configurables ci-dessous.">
        <div className="flex items-center gap-6">
          <p className="text-5xl font-bold" style={{ color: statusColorMap[indiceStatus.color] || C.text }}>{indiceData.indice != null ? `${indiceData.indice}` : '—'}<span className="text-lg" style={{ color: C.textMuted }}>/100</span></p>
          <button onClick={() => setShowPonderation((s) => !s)} className="text-xs px-2 py-1 rounded-lg" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, color: C.text }}>{showPonderation ? 'Masquer les pondérations' : 'Régler les pondérations'}</button>
        </div>
        {showPonderation && (
          <div className="mt-4 space-y-2">
            {(indiceData.detail || []).map((d) => (
              <div key={d.key} className="flex items-center justify-between text-xs">
                <span style={{ color: C.text }}>{d.nom}</span>
                <input type="number" min="0" step="0.5" defaultValue={d.poids} onBlur={(e) => savePonderation(d.key, e.target.value)} className="w-16 px-2 py-1 rounded-lg text-xs outline-none" style={inputStyle(C)} />
              </div>
            ))}
          </div>
        )}
      </Panel>

      <div className="flex flex-wrap gap-3">
        <KpiCard label="Indicateurs suivis" value={indList.length} color={C.blue} icon={Activity} />
        <KpiCard label="Dans la cible" value={cibles} color={C.green} icon={ShieldCheck} />
        <KpiCard label="Hors cible" value={indList.length - cibles} color={C.red} icon={AlertTriangle} />
      </div>

      <Panel title="Bibliothèque automatique" subtitle="Mois en cours vs mois précédent — calculée depuis les contrôles, non-conformités, actions, réclamations, fournisseurs et audits déjà enregistrés.">
        <div className="grid grid-cols-3 gap-3">
          {autoList.map((a) => {
            const st = indicateurStatus(a.valeur, null, a.sensInverse, null, null);
            const delta = a.valeur != null && a.valeurPrecedente != null ? Math.round((a.valeur - a.valeurPrecedente) * 10) / 10 : null;
            const deltaGood = delta != null ? (a.sensInverse ? delta <= 0 : delta >= 0) : null;
            return (
              <div key={a.key} className="p-3 rounded-lg" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}` }}>
                <p className="text-xs" style={{ color: C.textMuted }}>{a.categorie}</p>
                <p className="text-sm font-medium mb-1" style={{ color: C.text }}>{a.nom}</p>
                <div className="flex items-baseline gap-2">
                  <p className="text-2xl font-bold" style={{ color: statusColorMap[st.color] || C.text }}>{a.valeur != null ? `${a.valeur}${a.unite}` : '—'}</p>
                  {delta != null && <span className="text-xs font-medium" style={{ color: deltaGood ? C.green : C.red }}>{delta > 0 ? '▲' : delta < 0 ? '▼' : '='}{Math.abs(delta)}{a.unite}</span>}
                </div>
                <p className="text-[10px] mt-1" style={{ color: C.textMuted }}>{a.formule}</p>
              </div>
            );
          })}
        </div>
      </Panel>

      <Panel title="Indicateurs qualité vs cibles" right={categories.length > 0 && (
        <select value={categorieFilter} onChange={(e) => setCategorieFilter(e.target.value)} className="px-2 py-1 rounded-lg text-xs outline-none" style={inputStyle(C)}>
          <option value="">Toutes catégories</option>{categories.map((cat) => <option key={cat} value={cat}>{cat}</option>)}
        </select>
      )}>
        {indList.length === 0 ? <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun indicateur enregistré</p> : (
          <div className="space-y-4">
            {indList.map((i) => {
              const atteint = i.sensInverse ? i.actuel <= i.cible : i.actuel >= i.cible;
              const pct = Math.min(100, (i.actuel / i.cible) * 100);
              const st = indicateurStatus(i.actuel, i.cible, i.sensInverse, i.seuilVert, i.seuilOrange);
              return (
                <div key={i.id}>
                  <div className="flex justify-between items-center text-xs mb-1">
                    <span className="cursor-pointer" style={{ color: C.text }} onClick={() => setDetailFor(i)}>{i.indicateur} {i.categorie && <span style={{ color: C.textMuted }}>· {i.categorie}</span>}</span>
                    <div className="flex items-center gap-2">
                      <span style={{ color: C.textMuted }}>{i.actuel}{i.unite} / {i.cible}{i.unite}</span>
                      <button onClick={() => setMesureFor(i)} className="text-[11px]" style={{ color: C.blue }}>+ Mesure</button>
                      <button onClick={() => setSelected(i)} className="text-[11px]" style={{ color: C.textMuted }}>Modifier</button>
                    </div>
                  </div>
                  <div className="h-2 rounded-full" style={{ backgroundColor: C.border }}><div className="h-2 rounded-full" style={{ width: `${pct}%`, backgroundColor: atteint ? C.green : C.amber }} /></div>
                  {i.mesures?.length > 1 && <p className="text-[10px] mt-1" style={{ color: C.textMuted }}>Historique : {i.mesures.slice(0, 5).reverse().map((m) => m.valeur).join(' → ')}</p>}
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
  const stats = useCollection('/business/reclamations-stats');
  const alertesQ = useCollection('/business/reclamations-alertes');
  const scoreQ = useCollection('/business/reclamations-score');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  const [detailFor, setDetailFor] = useState(null);
  const [tab, setTab] = useState('dashboard');
  const [showPonderation, setShowPonderation] = useState(false);
  if (reclamations.loading || stats.loading || alertesQ.loading || scoreQ.loading) return <LoadingPanel />;
  if (reclamations.error) return <ErrorPanel message={reclamations.error} onRetry={reclamations.reload} />;
  const list = reclamations.data || [];
  const s = stats.data || { volume: {}, performance: {}, pareto: [], parClient: [], parProduit: [], parProcessus: [], recurrencesDetectees: [] };
  const alertes = alertesQ.data || [];
  const score = scoreQ.data || { score: null, detail: [] };
  const enCours = list.filter((r) => r.statut === 'OPEN').length;
  const recurrentes = list.filter((r) => r.recurrente).length;
  const graviteColor = { Critique: C.red, Majeure: C.red, Modérée: C.amber, Élevée: C.red, Faible: C.textMuted };
  const now = new Date();
  const enRetard = list.filter((r) => r.statut === 'OPEN' && r.delaiCibleJours && new Date(r.date).getTime() + r.delaiCibleJours * 86400000 < now.getTime()).length;
  const coutTotalGlobal = list.reduce((s2, r) => s2 + (r.coutTotal || 0), 0);
  const closedWithSat = list.filter((r) => r.satisfaction);
  const satisfaits = closedWithSat.filter((r) => r.satisfaction === 'SATISFAIT').length;
  const sorted = [...list].sort((a, b) => new Date(b.date) - new Date(a.date));
  const niveauColor = { CRITIQUE: C.red, URGENT: C.red, ATTENTION: C.amber, INFORMATION: C.blue };
  const scoreLevel = score.score == null ? null : score.score >= 80 ? { label: 'Excellent', color: C.green } : score.score >= 65 ? { label: 'Bon', color: C.green } : score.score >= 50 ? { label: 'À surveiller', color: C.amber } : score.score >= 35 ? { label: 'Insuffisant', color: C.red } : { label: 'Critique', color: C.red };

  async function savePonderation(key, poids) {
    try { await api.post('/business/indicateurs-ponderation', { autoKey: key, poids: Number(poids) }); scoreQ.reload(); }
    catch (e) { alert(e.message); }
  }

  return (
    <div className="space-y-6">
      {(showForm || selected) && <ReclamationForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={reclamations.reload} />}
      {detailFor && <ReclamationDetailModal reclamationId={detailFor} onClose={() => setDetailFor(null)} onChanged={() => { reclamations.reload(); stats.reload(); alertesQ.reload(); scoreQ.reload(); }} onEdit={() => { setSelected(list.find((r) => r.id === detailFor)); setDetailFor(null); }} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvelle réclamation</button>
      </div>

      <div className="flex flex-wrap gap-2">
        {[['dashboard', 'Tableau de bord'], ['registre', 'Registre']].map(([id, label]) => (
          <button key={id} onClick={() => setTab(id)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: tab === id ? C.blue : 'transparent', color: tab === id ? '#fff' : C.textMuted }}>{label}</button>
        ))}
      </div>

      {tab === 'dashboard' && (
        <div className="space-y-6">
          <Panel title="Score global de performance réclamations" subtitle="Moyenne pondérée — pondérations configurables ci-dessous.">
            <div className="flex items-center gap-6">
              <div>
                <p className="text-5xl font-bold" style={{ color: scoreLevel?.color || C.text }}>{score.score != null ? score.score : '—'}<span className="text-lg" style={{ color: C.textMuted }}>/100</span></p>
                {scoreLevel && <p className="text-xs font-medium" style={{ color: scoreLevel.color }}>{scoreLevel.label}</p>}
              </div>
              <button onClick={() => setShowPonderation((v) => !v)} className="text-xs px-2 py-1 rounded-lg" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, color: C.text }}>{showPonderation ? 'Masquer les pondérations' : 'Régler les pondérations'}</button>
            </div>
            {showPonderation && (
              <div className="mt-4 space-y-2">
                {(score.detail || []).map((d) => (
                  <div key={d.key} className="flex items-center justify-between text-xs">
                    <span style={{ color: C.text }}>{d.nom} {d.valeur != null && <span style={{ color: C.textMuted }}>({d.valeur}%)</span>}</span>
                    <input type="number" min="0" step="0.5" defaultValue={d.poids} onBlur={(e) => savePonderation(d.key, e.target.value)} className="w-16 px-2 py-1 rounded-lg text-xs outline-none" style={inputStyle(C)} />
                  </div>
                ))}
              </div>
            )}
          </Panel>

          <Panel title="Alertes automatiques" subtitle={`${alertes.length} réclamation(s) ouverte(s) nécessitant attention`}>
            {alertes.length
              ? <div className="space-y-2">
                  {alertes.map((a) => (
                    <div key={a.id} onClick={() => setDetailFor(a.id)} className="flex items-center justify-between py-2 cursor-pointer" style={{ borderTop: `1px solid ${C.border}` }}>
                      <div>
                        <p className="text-sm font-medium" style={{ color: C.text }}>{a.client} — {a.motif}</p>
                        <p className="text-xs" style={{ color: C.textMuted }}>{a.motifs.map((m) => m.label).join(' · ')}</p>
                      </div>
                      <span className="text-[11px] px-2 py-1 rounded-full font-medium" style={{ backgroundColor: `${niveauColor[a.niveau]}22`, color: niveauColor[a.niveau] }}>{a.niveau}</span>
                    </div>
                  ))}
                </div>
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune alerte — tout est sous contrôle</p>}
          </Panel>

          <div className="flex flex-wrap gap-3">
            <KpiCard label="Réclamations" value={list.length} objectif={`${enCours} en cours`} color={C.amber} icon={Bell} />
            <KpiCard label="Gravité majeure/critique" value={list.filter((r) => r.gravite === 'Majeure' || r.gravite === 'Critique' || r.gravite === 'Élevée').length} color={C.red} icon={AlertTriangle} />
            <KpiCard label="En retard" value={enRetard} color={enRetard > 0 ? C.red : C.green} icon={AlertTriangle} />
            <KpiCard label="Récurrences détectées" value={s.recurrencesDetectees.length} color={s.recurrencesDetectees.length > 0 ? C.amber : C.green} icon={Activity} />
            <KpiCard label="Satisfaction (après traitement)" value={closedWithSat.length ? `${Math.round((satisfaits / closedWithSat.length) * 100)}%` : '—'} color={C.blue} icon={ShieldCheck} />
            <KpiCard label="Coût total" value={`${coutTotalGlobal.toLocaleString('fr-FR')} FCFA`} color={C.amber} icon={ClipboardList} />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <Panel title="Performance">
              <div className="space-y-2 text-xs">
                <div className="flex justify-between"><span style={{ color: C.textMuted }}>Taux de clôture</span><span style={{ color: C.text }}>{s.performance.tauxCloture != null ? `${s.performance.tauxCloture}%` : '—'}</span></div>
                <div className="flex justify-between"><span style={{ color: C.textMuted }}>Taux de clôture dans les délais</span><span style={{ color: C.text }}>{s.performance.tauxClotureDelai != null ? `${s.performance.tauxClotureDelai}%` : '—'}</span></div>
                <div className="flex justify-between"><span style={{ color: C.textMuted }}>Délai moyen d'accusé de réception</span><span style={{ color: C.text }}>{s.performance.delaiMoyenAccuseReception != null ? `${s.performance.delaiMoyenAccuseReception} j` : '—'}</span></div>
                <div className="flex justify-between"><span style={{ color: C.textMuted }}>Délai moyen de première réponse</span><span style={{ color: C.text }}>{s.performance.delaiMoyenPremiereReponse != null ? `${s.performance.delaiMoyenPremiereReponse} j` : '—'}</span></div>
                <div className="flex justify-between"><span style={{ color: C.textMuted }}>Délai moyen de résolution</span><span style={{ color: C.text }}>{s.performance.delaiMoyenResolution != null ? `${s.performance.delaiMoyenResolution} j` : '—'}</span></div>
                <div className="flex justify-between"><span style={{ color: C.textMuted }}>Délai moyen de clôture</span><span style={{ color: C.text }}>{s.performance.delaiMoyenCloture != null ? `${s.performance.delaiMoyenCloture} j` : '—'}</span></div>
              </div>
            </Panel>

            <Panel title="Récurrences détectées automatiquement" subtitle="Même client, même nature de problème, plus d'une fois">
              {s.recurrencesDetectees.length
                ? <div className="space-y-2">
                    {s.recurrencesDetectees.slice(0, 6).map((r, i) => (
                      <div key={i} className="flex justify-between text-xs py-1" style={{ borderTop: `1px solid ${C.border}` }}>
                        <span style={{ color: C.text }}>{r.client} — {r.cause}</span>
                        <span style={{ color: C.amber }}>{r.nombre}×</span>
                      </div>
                    ))}
                  </div>
                : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune récurrence détectée</p>}
            </Panel>
          </div>

          <Panel title="Pareto des causes" subtitle="80% des réclamations viennent généralement de 20% des causes">
            {s.pareto.length
              ? <ResponsiveContainer width="100%" height={280}>
                  <ComposedChart data={s.pareto}>
                    <CartesianGrid strokeDasharray="3 3" stroke={C.border} />
                    <XAxis dataKey="name" tick={{ fontSize: 10, fill: C.textMuted }} angle={-20} textAnchor="end" height={60} />
                    <YAxis yAxisId="left" tick={{ fontSize: 10, fill: C.textMuted }} />
                    <YAxis yAxisId="right" orientation="right" domain={[0, 100]} tick={{ fontSize: 10, fill: C.textMuted }} />
                    <Tooltip contentStyle={{ backgroundColor: C.card, border: `1px solid ${C.border}`, fontSize: 12 }} />
                    <Bar yAxisId="left" dataKey="value" name="Nombre" fill={C.blue} radius={[4, 4, 0, 0]} />
                    <Line yAxisId="right" type="monotone" dataKey="cumulPct" name="% cumulé" stroke={C.amber} strokeWidth={2} dot={{ r: 3 }} />
                  </ComposedChart>
                </ResponsiveContainer>
              : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucune réclamation classifiée pour le moment</p>}
          </Panel>

          <div className="grid grid-cols-3 gap-4">
            <Panel title="Par client">
              {s.parClient.length ? <div className="space-y-1">{s.parClient.map((c) => <div key={c.name} className="flex justify-between text-xs py-1" style={{ borderTop: `1px solid ${C.border}` }}><span style={{ color: C.text }}>{c.name}</span><span style={{ color: C.textMuted }}>{c.value}</span></div>)}</div> : <p className="text-xs text-center py-4" style={{ color: C.textMuted }}>—</p>}
            </Panel>
            <Panel title="Par produit/service">
              {s.parProduit.length ? <div className="space-y-1">{s.parProduit.map((c) => <div key={c.name} className="flex justify-between text-xs py-1" style={{ borderTop: `1px solid ${C.border}` }}><span style={{ color: C.text }}>{c.name}</span><span style={{ color: C.textMuted }}>{c.value}</span></div>)}</div> : <p className="text-xs text-center py-4" style={{ color: C.textMuted }}>—</p>}
            </Panel>
            <Panel title="Par processus">
              {s.parProcessus.length ? <div className="space-y-1">{s.parProcessus.map((c) => <div key={c.name} className="flex justify-between text-xs py-1" style={{ borderTop: `1px solid ${C.border}` }}><span style={{ color: C.text }}>{c.name}</span><span style={{ color: C.textMuted }}>{c.value}</span></div>)}</div> : <p className="text-xs text-center py-4" style={{ color: C.textMuted }}>—</p>}
            </Panel>
          </div>
        </div>
      )}

      {tab === 'registre' && (
        <Panel title="Registre des réclamations clients">
          {sorted.length
            ? <DataTable columns={['Client', 'Motif', 'Produit/Service', 'Date', 'Gravité', 'Statut', 'Coût']}
                rows={sorted.map((r) => [r.client, r.motif, r.produitService || '—', new Date(r.date).toLocaleDateString('fr-FR'), <span style={{ color: graviteColor[r.gravite] || C.textMuted }}>{r.gravite}</span>, <StatusChip statut={r.statut === 'OPEN' ? 'Ouverte' : 'Clôturée'} />, r.coutTotal ? `${r.coutTotal.toLocaleString('fr-FR')} FCFA` : '—'])}
                onRowClick={(i) => setDetailFor(sorted[i].id)} />
            : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune réclamation enregistrée pour le moment</p>}
        </Panel>
      )}
    </div>
  );
}

function FournisseurDetailModal({ fournisseurId, onClose, onEdit }) {
  const C = useTheme();
  const [f, setF] = useState(null);
  const [score, setScore] = useState(null);
  const [error, setError] = useState(null);
  const statutLabel = {
    PROSPECT: 'Prospect', EN_QUALIFICATION: 'En qualification', EN_ATTENTE_HOMOLOGATION: "En attente d'homologation",
    HOMOLOGUE: 'Homologué', HOMOLOGUE_CONDITIONS: 'Homologué sous conditions', SOUS_SURVEILLANCE: 'Sous surveillance',
    SUSPENDU: 'Suspendu', BLOQUE: 'Bloqué', INACTIF: 'Inactif', RETIRE: 'Retiré du panel',
  };

  async function load() {
    try {
      const [detail, sc] = await Promise.all([api.get(`/business/fournisseurs/${fournisseurId}`), api.get(`/business/fournisseurs/${fournisseurId}/score`)]);
      setF(detail); setScore(sc);
    } catch (err) { setError(err.message); }
  }
  useEffect(() => { load(); }, [fournisseurId]);

  if (error) return <Modal title="Fournisseur" onClose={onClose}><ErrorPanel message={error} /></Modal>;
  if (!f || !score) return <Modal title="Fournisseur" onClose={onClose} wide><LoadingPanel /></Modal>;

  const ncOuvertes = (f.nonConformities || []).filter((n) => n.status === 'OPEN').length;
  const actionsOuvertes = (f.actions || []).filter((a) => a.status !== 'CLOSED').length;
  const scoreLevel = score.score == null ? null : score.score >= 85 ? { label: 'Excellent', color: C.green } : score.score >= 70 ? { label: 'Bon', color: C.green } : score.score >= 50 ? { label: 'Acceptable', color: C.amber } : { label: 'Critique', color: C.red };

  return (
    <Modal title={f.nom} onClose={onClose} wide>
      <div className="flex flex-wrap items-center gap-2 text-xs mb-4" style={{ color: C.textMuted }}>
        <span>{f.typeFournisseur || f.categorie || '—'}</span>·<StatusChip statut={statutLabel[f.statut] || f.statut} />
        {f.niveauRisque && <StatusChip statut={f.niveauRisque} />}
        {f.criticite && <span style={{ color: C.red }}>● Critique</span>}
        <button onClick={onEdit} className="text-xs px-2 py-1 rounded-lg ml-2" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, color: C.text }}>Modifier</button>
      </div>

      <div className="flex items-center gap-6 mb-4">
        <div>
          <p className="text-4xl font-bold" style={{ color: scoreLevel?.color || C.text }}>{score.score != null ? score.score : '—'}<span className="text-base" style={{ color: C.textMuted }}>/100</span></p>
          {scoreLevel && <p className="text-xs font-medium" style={{ color: scoreLevel.color }}>{scoreLevel.label}</p>}
        </div>
        <div className="grid grid-cols-5 gap-2 flex-1">
          {(score.detail || []).map((d) => (
            <div key={d.key} className="p-2 rounded-lg text-center" style={{ backgroundColor: C.cardAlt }}>
              <p className="text-[10px]" style={{ color: C.textMuted }}>{d.nom}</p>
              <p className="text-sm font-bold" style={{ color: C.text }}>{d.valeur != null ? `${d.valeur}%` : '—'}</p>
            </div>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-4 gap-3 mb-4">
        <div className="p-2 rounded-lg text-center" style={{ backgroundColor: C.cardAlt }}><p className="text-[10px]" style={{ color: C.textMuted }}>NC ouvertes</p><p className="text-lg font-bold" style={{ color: ncOuvertes > 0 ? C.red : C.text }}>{ncOuvertes}</p></div>
        <div className="p-2 rounded-lg text-center" style={{ backgroundColor: C.cardAlt }}><p className="text-[10px]" style={{ color: C.textMuted }}>Actions ouvertes</p><p className="text-lg font-bold" style={{ color: C.text }}>{actionsOuvertes}</p></div>
        <div className="p-2 rounded-lg text-center" style={{ backgroundColor: C.cardAlt }}><p className="text-[10px]" style={{ color: C.textMuted }}>Audits</p><p className="text-lg font-bold" style={{ color: C.text }}>{(f.audits || []).length}</p></div>
        <div className="p-2 rounded-lg text-center" style={{ backgroundColor: C.cardAlt }}><p className="text-[10px]" style={{ color: C.textMuted }}>Certifications</p><p className="text-lg font-bold" style={{ color: C.text }}>{(f.certifications || []).length}</p></div>
      </div>

      {(f.capaciteTechnique || f.capaciteCommerciale || f.situationFinanciere) && (
        <div className="mb-4 text-xs space-y-1" style={{ color: C.textMuted }}>
          {f.capaciteTechnique && <p><span style={{ color: C.text }}>Capacité technique :</span> {f.capaciteTechnique}</p>}
          {f.capaciteCommerciale && <p><span style={{ color: C.text }}>Capacité commerciale :</span> {f.capaciteCommerciale}</p>}
          {f.situationFinanciere && <p><span style={{ color: C.text }}>Situation financière :</span> {f.situationFinanciere}</p>}
        </div>
      )}

      {f.certifications?.length > 0 && (
        <>
          <p className="text-xs font-semibold uppercase tracking-wide mb-2" style={{ color: C.textMuted }}>Certifications</p>
          <div className="space-y-1 mb-4">
            {f.certifications.map((cert) => {
              const expired = cert.dateExpiration && new Date(cert.dateExpiration) < new Date();
              return (
                <div key={cert.id} className="flex justify-between text-xs py-1" style={{ borderTop: `1px solid ${C.border}` }}>
                  <span style={{ color: C.text }}>{cert.type}{cert.numero ? ` (${cert.numero})` : ''}</span>
                  <span style={{ color: expired ? C.red : C.textMuted }}>{cert.dateExpiration ? new Date(cert.dateExpiration).toLocaleDateString('fr-FR') : '—'}{expired ? ' — expirée' : ''}</span>
                </div>
              );
            })}
          </div>
        </>
      )}

      {f.nonConformities?.length > 0 && (
        <>
          <p className="text-xs font-semibold uppercase tracking-wide mb-2" style={{ color: C.textMuted }}>Non-conformités récentes</p>
          <div className="space-y-1 mb-4">
            {f.nonConformities.slice(0, 5).map((n) => <div key={n.id} className="flex justify-between text-xs py-1" style={{ borderTop: `1px solid ${C.border}` }}><span style={{ color: C.text }}>{n.title}</span><StatusChip statut={n.status} /></div>)}
          </div>
        </>
      )}

      {f.actions?.length > 0 && (
        <>
          <p className="text-xs font-semibold uppercase tracking-wide mb-2" style={{ color: C.textMuted }}>Actions</p>
          <div className="space-y-1">
            {f.actions.slice(0, 5).map((a) => <div key={a.id} className="flex justify-between text-xs py-1" style={{ borderTop: `1px solid ${C.border}` }}><span style={{ color: C.text }}>{a.title}</span><StatusChip statut={a.status} /></div>)}
          </div>
        </>
      )}
    </Modal>
  );
}

function QualiteFournisseursPage() {
  const C = useTheme();
  const fournisseurs = useCollection('/business/fournisseurs');
  const classementQ = useCollection('/business/fournisseurs-classement');
  const alertesQ = useCollection('/business/fournisseurs-alertes');
  const matriceQ = useCollection('/business/fournisseurs-matrice-risque');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  const [detailFor, setDetailFor] = useState(null);
  const [tab, setTab] = useState('dashboard');
  if (fournisseurs.loading || classementQ.loading || alertesQ.loading || matriceQ.loading) return <LoadingPanel />;
  if (fournisseurs.error) return <ErrorPanel message={fournisseurs.error} onRetry={fournisseurs.reload} />;
  const list = fournisseurs.data || [];
  const classement = classementQ.data || { top: [], flop: [] };
  const alertes = alertesQ.data || [];
  const matrice = matriceQ.data || [];
  const niveauColor = { CRITIQUE: C.red, URGENT: C.red, ATTENTION: C.amber };
  const statutLabel = {
    PROSPECT: 'Prospect', EN_QUALIFICATION: 'En qualification', EN_ATTENTE_HOMOLOGATION: "En attente d'homologation",
    HOMOLOGUE: 'Homologué', HOMOLOGUE_CONDITIONS: 'Homologué sous conditions', SOUS_SURVEILLANCE: 'Sous surveillance',
    SUSPENDU: 'Suspendu', BLOQUE: 'Bloqué', INACTIF: 'Inactif', RETIRE: 'Retiré du panel',
  };
  const criticiteCount = list.filter((f) => f.criticite).length;
  const nonHomologues = list.filter((f) => ['EN_ATTENTE_HOMOLOGATION', 'EN_QUALIFICATION'].includes(f.statut)).length;
  const avecNcOuvertes = list.filter((f) => (f._count?.nonConformities || 0) > 0).length;
  const now = new Date();
  const reevaluationEchue = list.filter((f) => f.dateProchaineReevaluation && new Date(f.dateProchaineReevaluation) < now).length;

  function scoreGlobalApprox(f) {
    const scores = [f.scoreQualite, f.scoreLivraison, f.scoreQhse, f.scoreCommercial, f.scoreReactivite].filter((v) => v != null);
    return scores.length ? Math.round(scores.reduce((s, v) => s + v, 0) / scores.length) : null;
  }

  return (
    <div className="space-y-6">
      {(showForm || selected) && <FournisseurForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={() => { fournisseurs.reload(); classementQ.reload(); }} />}
      {detailFor && <FournisseurDetailModal fournisseurId={detailFor} onClose={() => setDetailFor(null)} onEdit={() => { setSelected(list.find((f) => f.id === detailFor)); setDetailFor(null); }} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouveau fournisseur</button>
      </div>

      <div className="flex flex-wrap gap-2">
        {[['dashboard', 'Tableau de bord'], ['registre', 'Registre']].map(([id, label]) => (
          <button key={id} onClick={() => setTab(id)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: tab === id ? C.blue : 'transparent', color: tab === id ? '#fff' : C.textMuted }}>{label}</button>
        ))}
      </div>

      {tab === 'dashboard' && (
        <div className="space-y-6">
          <div className="flex flex-wrap gap-3">
            <KpiCard label="Fournisseurs" value={list.length} color={C.blue} icon={FlaskConical} />
            <KpiCard label="Critiques" value={criticiteCount} color={criticiteCount > 0 ? C.red : C.green} icon={AlertTriangle} />
            <KpiCard label="En attente d'homologation" value={nonHomologues} color={nonHomologues > 0 ? C.amber : C.green} icon={ClipboardList} />
            <KpiCard label="Avec NC ouvertes" value={avecNcOuvertes} color={avecNcOuvertes > 0 ? C.red : C.green} icon={AlertTriangle} />
            <KpiCard label="Réévaluation échue" value={reevaluationEchue} color={reevaluationEchue > 0 ? C.red : C.green} icon={AlertTriangle} />
          </div>

          <Panel title="Alertes automatiques" subtitle={`${alertes.length} fournisseur(s) nécessitant attention`}>
            {alertes.length
              ? <div className="space-y-2">
                  {alertes.map((a) => (
                    <div key={a.id} onClick={() => setDetailFor(a.id)} className="flex items-center justify-between py-2 cursor-pointer" style={{ borderTop: `1px solid ${C.border}` }}>
                      <div>
                        <p className="text-sm font-medium" style={{ color: C.text }}>{a.nom}</p>
                        <p className="text-xs" style={{ color: C.textMuted }}>{a.motifs.map((m) => m.label).join(' · ')}</p>
                      </div>
                      <span className="text-[11px] px-2 py-1 rounded-full font-medium" style={{ backgroundColor: `${niveauColor[a.niveau]}22`, color: niveauColor[a.niveau] }}>{a.niveau}</span>
                    </div>
                  ))}
                </div>
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune alerte — tout est sous contrôle</p>}
          </Panel>

          {matrice.length > 0 && (
            <Panel title="Matrice de risque fournisseurs" subtitle="Risques actifs liés à un fournisseur — probabilité × gravité.">
              <DataTable columns={['Fournisseur', 'Risque', 'Probabilité', 'Gravité', 'Score']}
                rows={matrice.map((r) => [r.fournisseur || '—', r.hazard, r.probability, r.severity, <span style={{ color: r.score >= 12 ? C.red : r.score >= 6 ? C.amber : C.green, fontWeight: 600 }}>{r.score}</span>])} />
            </Panel>
          )}

          <div className="grid grid-cols-2 gap-4">
            <Panel title="Top 10 fournisseurs" subtitle="Classés par score global pondéré (mêmes pondérations que le score détaillé).">
              {classement.top.length
                ? <div className="space-y-1">{classement.top.map((f, i) => <div key={f.id} onClick={() => setDetailFor(f.id)} className="flex justify-between text-xs py-1.5 cursor-pointer" style={{ borderTop: `1px solid ${C.border}` }}><span style={{ color: C.text }}>{i + 1}. {f.nom}</span><span style={{ color: C.green, fontWeight: 600 }}>{f.score}%</span></div>)}</div>
                : <p className="text-xs text-center py-4" style={{ color: C.textMuted }}>Aucun fournisseur avec un score renseigné</p>}
            </Panel>
            <Panel title="Fournisseurs les moins performants">
              {classement.flop.length
                ? <div className="space-y-1">{classement.flop.map((f, i) => <div key={f.id} onClick={() => setDetailFor(f.id)} className="flex justify-between text-xs py-1.5 cursor-pointer" style={{ borderTop: `1px solid ${C.border}` }}><span style={{ color: C.text }}>{i + 1}. {f.nom}</span><span style={{ color: f.score < 50 ? C.red : C.amber, fontWeight: 600 }}>{f.score}%</span></div>)}</div>
                : <p className="text-xs text-center py-4" style={{ color: C.textMuted }}>Aucun fournisseur avec un score renseigné</p>}
            </Panel>
          </div>
        </div>
      )}

      {tab === 'registre' && (
        <Panel title="Évaluation des fournisseurs">
          {list.length
            ? <DataTable columns={['Fournisseur', 'Type', 'Score global (moyenne)', 'NC ouvertes', 'Statut']}
                rows={list.map((f) => {
                  const score = scoreGlobalApprox(f);
                  return [
                    f.nom, f.typeFournisseur || f.categorie || '—',
                    score != null ? <div className="flex items-center gap-2"><div className="w-20 h-1.5 rounded-full" style={{ backgroundColor: C.border }}><div className="h-1.5 rounded-full" style={{ width: `${score}%`, backgroundColor: score >= 85 ? C.green : score >= 70 ? C.amber : C.red }} /></div><span>{score}%</span></div> : '—',
                    f._count?.nonConformities || 0,
                    <StatusChip statut={statutLabel[f.statut] || f.statut} />,
                  ];
                })}
                onRowClick={(i) => setDetailFor(list[i].id)} />
            : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun fournisseur enregistré pour le moment</p>}
        </Panel>
      )}
    </div>
  );
}

function SafetyEventForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const processusQ = useCollection('/business/processus');
  const fournisseursQ = useCollection('/business/fournisseurs');
  const [form, setForm] = useState({
    type: record?.type || 'INCIDENT', categorie: record?.categorie || '', title: record?.title || '', description: record?.description || '',
    occurredAt: record ? new Date(record.occurredAt).toISOString().slice(0, 10) : new Date().toISOString().slice(0, 10),
    severity: record?.severity || 2, withLostTime: record?.withLostTime || false, lostDays: record?.lostDays ?? '',
    zone: record?.zone || '', atelier: record?.atelier || '', poste: record?.poste || '', activite: record?.activite || '',
    personneNom: record?.personneNom || '', personneFonction: record?.personneFonction || '', typePersonnel: record?.typePersonnel || '',
    typeLesion: record?.typeLesion || '', siegeLesion: record?.siegeLesion || '', mecanisme: record?.mecanisme || '',
    consequenceMaterielle: record?.consequenceMaterielle || '', consequenceEnvironnementale: record?.consequenceEnvironnementale || '',
    potentielGravite: record?.potentielGravite || '', processusId: record?.processusId || '', fournisseurId: record?.fournisseurId || '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const isAccident = form.type === 'ACCIDENT';
  const isSignalFaible = form.type === 'INCIDENT' || form.type === 'PRESQU_ACCIDENT' || form.type === 'SITUATION_DANGEREUSE';

  async function submit(e) {
    e.preventDefault();
    setSaving(true); setError(null);
    try {
      const payload = { ...form, severity: Number(form.severity), occurredAt: new Date(form.occurredAt).toISOString(), lostDays: form.withLostTime && form.lostDays !== '' ? Number(form.lostDays) : null, processusId: form.processusId || null, fournisseurId: form.fournisseurId || null };
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
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Type">
            <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="ACCIDENT">Accident</option>
              <option value="INCIDENT">Incident</option>
              <option value="PRESQU_ACCIDENT">Presqu'accident</option>
              <option value="SITUATION_DANGEREUSE">Situation dangereuse</option>
            </select>
          </FormField>
          <FormField label="Catégorie (optionnel)">
            <select value={form.categorie} onChange={(e) => setForm({ ...form, categorie: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option><option value="ACCIDENT_TRAVAIL">Accident du travail</option><option value="ACCIDENT_TRAJET">Accident de trajet</option><option value="EVENEMENT_DANGEREUX">Événement dangereux</option><option value="AUTRE">Autre</option>
            </select>
          </FormField>
        </div>
        <FormField label="Titre">
          <input required value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Fuite mineure de vapeur" />
        </FormField>
        <FormField label="Description factuelle">
          <textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} rows={3} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} placeholder="Que s'est-il passé, où, comment — sans attribuer de responsabilité" />
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

        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Localisation</p>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Zone (optionnel)"><input value={form.zone} onChange={(e) => setForm({ ...form, zone: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Atelier (optionnel)"><input value={form.atelier} onChange={(e) => setForm({ ...form, atelier: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Poste (optionnel)"><input value={form.poste} onChange={(e) => setForm({ ...form, poste: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Activité (optionnel)"><input value={form.activite} onChange={(e) => setForm({ ...form, activite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>

        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Personne concernée</p>
        <div className="grid grid-cols-3 gap-3">
          <FormField label="Nom (optionnel)"><input value={form.personneNom} onChange={(e) => setForm({ ...form, personneNom: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Fonction (optionnel)"><input value={form.personneFonction} onChange={(e) => setForm({ ...form, personneFonction: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Type de personnel">
            <select value={form.typePersonnel} onChange={(e) => setForm({ ...form, typePersonnel: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option><option value="SALARIE">Salarié</option><option value="INTERIMAIRE">Intérimaire</option><option value="SOUS_TRAITANT">Sous-traitant</option><option value="STAGIAIRE">Stagiaire</option><option value="VISITEUR">Visiteur</option><option value="AUTRE">Autre</option>
            </select>
          </FormField>
        </div>

        {isAccident && (
          <>
            <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Conséquences</p>
            <div className="grid grid-cols-2 gap-3">
              <FormField label="Type de lésion (optionnel)"><input value={form.typeLesion} onChange={(e) => setForm({ ...form, typeLesion: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Coupure, fracture, brûlure..." /></FormField>
              <FormField label="Siège de la lésion (optionnel)"><input value={form.siegeLesion} onChange={(e) => setForm({ ...form, siegeLesion: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Main, dos, œil..." /></FormField>
            </div>
            <FormField label="Mécanisme de survenue (optionnel)"><input value={form.mecanisme} onChange={(e) => setForm({ ...form, mecanisme: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Chute de hauteur, coincement, contact électrique..." /></FormField>
            <div className="grid grid-cols-2 gap-3">
              <FormField label="Conséquence matérielle (optionnel)"><input value={form.consequenceMaterielle} onChange={(e) => setForm({ ...form, consequenceMaterielle: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
              <FormField label="Conséquence environnementale (optionnel)"><input value={form.consequenceEnvironnementale} onChange={(e) => setForm({ ...form, consequenceEnvironnementale: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
            </div>
          </>
        )}

        {isSignalFaible && (
          <FormField label="Potentiel de gravité — quelle aurait pu être la conséquence maximale ?">
            <select value={form.potentielGravite} onChange={(e) => setForm({ ...form, potentielGravite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option><option value="AUCUN">Aucun dommage</option><option value="LEGERE">Blessure légère</option><option value="GRAVE">Blessure grave</option><option value="INVALIDITE">Invalidité</option><option value="DECES">Décès</option><option value="COLLECTIF">Accident collectif</option>
            </select>
          </FormField>
        )}

        <label className="flex items-center gap-2 text-xs mb-3" style={{ color: C.textMuted }}>
          <input type="checkbox" checked={form.withLostTime} onChange={(e) => setForm({ ...form, withLostTime: e.target.checked })} />
          Accident avec arrêt de travail
        </label>
        {form.withLostTime && (
          <FormField label="Nombre de journées perdues">
            <input type="number" min="0" value={form.lostDays} onChange={(e) => setForm({ ...form, lostDays: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} />
          </FormField>
        )}

        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Liens</p>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Processus concerné (optionnel)">
            <select value={form.processusId} onChange={(e) => setForm({ ...form, processusId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>{(processusQ.data || []).map((p) => <option key={p.id} value={p.id}>{p.nom}</option>)}
            </select>
          </FormField>
          <FormField label="Fournisseur/sous-traitant concerné (optionnel)">
            <select value={form.fournisseurId} onChange={(e) => setForm({ ...form, fournisseurId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>{(fournisseursQ.data || []).map((f) => <option key={f.id} value={f.id}>{f.nom}</option>)}
            </select>
          </FormField>
        </div>

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

function SafetyEventDetailModal({ eventId, onClose, onChanged, onEdit }) {
  const C = useTheme();
  const [ev, setEv] = useState(null);
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);
  const [generatingRisk, setGeneratingRisk] = useState(false);
  const [showActionForm, setShowActionForm] = useState(false);
  const users = useCollection('/users');
  const [form, setForm] = useState(null);
  const statutLabel = { DECLARE: 'Déclaré', SECURISE: 'Sécurisé', INVESTIGATION: 'En investigation', ANALYSE_CAUSES: 'Analyse des causes', ACTIONS_DEFINIES: 'Actions définies', ACTIONS_EN_COURS: 'Actions en cours', VERIFICATION: "Vérification d'efficacité", VALIDE: 'Validé', CLOTURE: 'Clôturé' };

  async function load() {
    try {
      const data = await api.get(`/business/safety-events/${eventId}`);
      setEv(data);
      setForm((prev) => prev || {
        statut: data.statut || 'DECLARE', enqueteurId: data.enqueteurId || '', dateEnquete: data.dateEnquete ? new Date(data.dateEnquete).toISOString().slice(0, 10) : '',
        methodeAnalyse: data.methodeAnalyse || '', causeHumaine: data.causeHumaine || '', causeMethode: data.causeMethode || '', causeMachine: data.causeMachine || '',
        causeMatiere: data.causeMatiere || '', causeMilieu: data.causeMilieu || '', causeManagement: data.causeManagement || '', causeRacine: data.causeRacine || '',
      });
    } catch (err) { setError(err.message); }
  }
  useEffect(() => { load(); }, [eventId]);

  if (error) return <Modal title="Événement sécurité" onClose={onClose}><ErrorPanel message={error} /></Modal>;
  if (!ev || !form) return <Modal title="Événement sécurité" onClose={onClose} wide><LoadingPanel /></Modal>;

  async function save() {
    setSaving(true); setError(null);
    try {
      const payload = { ...form, dateEnquete: form.dateEnquete ? new Date(form.dateEnquete).toISOString() : null, enqueteurId: form.enqueteurId || null };
      await api.patch(`/business/safety-events/${eventId}`, payload);
      onChanged(); await load();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  // Point 19 du cahier des charges du Registre des risques : un accident
  // peut générer directement un risque, préréempli, plutôt que de saisir
  // le même danger deux fois.
  async function generateRisk() {
    setGeneratingRisk(true); setError(null);
    try { await api.post(`/business/safety-events/${eventId}/generate-risk`, {}); onChanged(); await load(); }
    catch (err) { setError(err.message); }
    setGeneratingRisk(false);
  }

  return (
    <>
      {showActionForm && <ActionForm prefill={{ title: `Action — ${ev.title}`, safetyEventId: ev.id }} onClose={() => setShowActionForm(false)} onCreated={() => { onChanged(); load(); }} />}
      <Modal title={ev.title} onClose={onClose} wide>
        <div className="flex flex-wrap items-center gap-2 text-xs mb-4" style={{ color: C.textMuted }}>
          <span>{new Date(ev.occurredAt).toLocaleDateString('fr-FR')}</span>·<StatusChip statut={ev.type} />·<span>Sévérité {ev.severity}</span>
          <button onClick={onEdit} className="text-xs px-2 py-1 rounded-lg ml-2" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, color: C.text }}>Modifier</button>
          {ev.employee && <span>· {ev.employee.firstName} {ev.employee.lastName}</span>}
        </div>

        <div className="flex items-center justify-between p-2.5 rounded-lg mb-3" style={{ backgroundColor: C.cardAlt }}>
          {ev.risk
            ? <p className="text-xs" style={{ color: C.text }}>Risque lié : <strong>{ev.risk.hazard}</strong> ({ev.risk.grossLevel || ev.risk.score})</p>
            : <p className="text-xs" style={{ color: C.textMuted }}>Aucun risque relié dans le registre</p>}
          {!ev.risk && <button onClick={generateRisk} disabled={generatingRisk} className="text-xs px-2 py-1 rounded-lg" style={{ backgroundColor: C.green, color: '#052e1f' }}>{generatingRisk ? '…' : 'Créer un risque à partir de cet accident'}</button>}
        </div>

        <FormField label="Statut">
          <select value={form.statut} onChange={(e) => setForm({ ...form, statut: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            {Object.entries(statutLabel).map(([k, l]) => <option key={k} value={k}>{l}</option>)}
          </select>
        </FormField>

        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Enquête</p>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Enquêteur">
            <select value={form.enqueteurId} onChange={(e) => setForm({ ...form, enqueteurId: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
              <option value="">—</option>{(users.data || []).map((u) => <option key={u.id} value={u.id}>{u.firstName} {u.lastName}</option>)}
            </select>
          </FormField>
          <FormField label="Date d'enquête"><input type="date" value={form.dateEnquete} onChange={(e) => setForm({ ...form, dateEnquete: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Méthode d'analyse">
          <select value={form.methodeAnalyse} onChange={(e) => setForm({ ...form, methodeAnalyse: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
            <option value="">—</option><option value="5_POURQUOI">5 Pourquoi</option><option value="ARBRE_CAUSES">Arbre des causes</option><option value="ISHIKAWA">Ishikawa (5M)</option><option value="AUTRE">Autre</option>
          </select>
        </FormField>

        <p className="text-xs font-semibold uppercase tracking-wide mb-2 mt-3" style={{ color: C.textMuted }}>Analyse des causes — jamais limitée à « erreur humaine »</p>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Facteurs humains"><input value={form.causeHumaine} onChange={(e) => setForm({ ...form, causeHumaine: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Méthodes"><input value={form.causeMethode} onChange={(e) => setForm({ ...form, causeMethode: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Machines/équipements"><input value={form.causeMachine} onChange={(e) => setForm({ ...form, causeMachine: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Matières/produits"><input value={form.causeMatiere} onChange={(e) => setForm({ ...form, causeMatiere: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Milieu/environnement"><input value={form.causeMilieu} onChange={(e) => setForm({ ...form, causeMilieu: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Management/organisation"><input value={form.causeManagement} onChange={(e) => setForm({ ...form, causeManagement: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        <FormField label="Cause racine retenue"><input value={form.causeRacine} onChange={(e) => setForm({ ...form, causeRacine: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>

        <div className="flex items-center justify-between mt-4 mb-2">
          <p className="text-xs font-semibold uppercase tracking-wide" style={{ color: C.textMuted }}>Actions (hiérarchie : élimination → substitution → protection collective → organisation → EPI)</p>
          <button type="button" onClick={() => setShowActionForm(true)} className="text-xs px-2 py-1 rounded-lg" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Action</button>
        </div>
        {(ev.actions || []).length
          ? <div className="space-y-1 mb-3">{ev.actions.map((a) => <div key={a.id} className="flex justify-between text-xs py-1" style={{ borderTop: `1px solid ${C.border}` }}><span style={{ color: C.text }}>{a.title}</span><StatusChip statut={a.status} /></div>)}</div>
          : <p className="text-xs mb-3" style={{ color: C.textMuted }}>Aucune action liée pour le moment</p>}

        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <button onClick={save} disabled={saving} className="w-full py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : 'Enregistrer'}</button>
      </Modal>
    </>
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
  const stats = useCollection('/business/safety-events-stats');
  const alertesQ = useCollection('/business/safety-events-alertes');
  const recidivesQ = useCollection('/business/safety-events-recidives');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  const [detailFor, setDetailFor] = useState(null);
  const [showHoursForm, setShowHoursForm] = useState(false);
  const [selectedHours, setSelectedHours] = useState(null);
  if (events.loading || workedHours.loading || stats.loading || alertesQ.loading || recidivesQ.loading) return <LoadingPanel />;
  if (events.error) return <ErrorPanel message={events.error} onRetry={events.reload} />;
  const list = events.data || [];
  const hoursList = workedHours.data || [];
  const s = stats.data || { volume: {}, pareto: [], parMecanisme: [], parLesion: [], parZone: [] };
  const alertes = alertesQ.data || [];
  const recidives = recidivesQ.data || { parCauseRacine: [], parZone: [], parMecanisme: [] };
  const niveauColor = { CRITIQUE: C.red, URGENT: C.red, ATTENTION: C.amber };
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
      {detailFor && <SafetyEventDetailModal eventId={detailFor} onClose={() => setDetailFor(null)} onChanged={events.reload} onEdit={() => { setSelected(list.find((e) => e.id === detailFor)); setDetailFor(null); }} />}
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
      <Panel title="Alertes automatiques" subtitle={`${alertes.length} événement(s) ouvert(s) nécessitant attention`}>
        {alertes.length
          ? <div className="space-y-2">
              {alertes.map((a) => (
                <div key={a.id} onClick={() => setDetailFor(a.id)} className="flex items-center justify-between py-2 cursor-pointer" style={{ borderTop: `1px solid ${C.border}` }}>
                  <div>
                    <p className="text-sm font-medium" style={{ color: C.text }}>{a.title}</p>
                    <p className="text-xs" style={{ color: C.textMuted }}>{a.motifs.map((m) => m.label).join(' · ')}</p>
                  </div>
                  <span className="text-[11px] px-2 py-1 rounded-full font-medium" style={{ backgroundColor: `${niveauColor[a.niveau]}22`, color: niveauColor[a.niveau] }}>{a.niveau}</span>
                </div>
              ))}
            </div>
          : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune alerte — tout est sous contrôle</p>}
      </Panel>

      {(recidives.parCauseRacine.length > 0 || recidives.parZone.length > 0 || recidives.parMecanisme.length > 0) && (
        <Panel title="Risque de récidive détecté" subtitle="Même cause racine, même zone ou même mécanisme apparu plus d'une fois.">
          <div className="grid grid-cols-3 gap-4">
            {[['Par cause racine', recidives.parCauseRacine], ['Par zone', recidives.parZone], ['Par mécanisme', recidives.parMecanisme]].map(([label, items]) => (
              <div key={label}>
                <p className="text-xs font-semibold mb-2" style={{ color: C.textMuted }}>{label}</p>
                {items.length
                  ? items.slice(0, 5).map((r, i) => <div key={i} className="flex justify-between text-xs py-1" style={{ borderTop: `1px solid ${C.border}` }}><span style={{ color: C.text }}>{r.critere}</span><span style={{ color: C.amber }}>{r.nombre}×</span></div>)
                  : <p className="text-xs" style={{ color: C.textMuted }}>—</p>}
              </div>
            ))}
          </div>
        </Panel>
      )}

      <Panel title="Pareto des causes" subtitle="Identifié lors des enquêtes — 80% des événements viennent généralement de 20% des causes.">
        {s.pareto.length
          ? <ResponsiveContainer width="100%" height={260}>
              <ComposedChart data={s.pareto}>
                <CartesianGrid strokeDasharray="3 3" stroke={C.border} />
                <XAxis dataKey="name" tick={{ fontSize: 10, fill: C.textMuted }} angle={-20} textAnchor="end" height={60} />
                <YAxis yAxisId="left" tick={{ fontSize: 10, fill: C.textMuted }} />
                <YAxis yAxisId="right" orientation="right" domain={[0, 100]} tick={{ fontSize: 10, fill: C.textMuted }} />
                <Tooltip contentStyle={{ backgroundColor: C.card, border: `1px solid ${C.border}`, fontSize: 12 }} />
                <Bar yAxisId="left" dataKey="value" name="Nombre" fill={C.red} radius={[4, 4, 0, 0]} />
                <Line yAxisId="right" type="monotone" dataKey="cumulPct" name="% cumulé" stroke={C.amber} strokeWidth={2} dot={{ r: 3 }} />
              </ComposedChart>
            </ResponsiveContainer>
          : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucune cause racine renseignée dans les enquêtes pour le moment</p>}
      </Panel>

      <div className="grid grid-cols-2 gap-4">
        <Panel title="Répartition par type d'événement">
          {byType.length ? <DonutChart data={byType} colors={[C.red, '#F97316', C.amber, '#8B5CF6', C.blue, C.green]} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun événement enregistré</p>}
        </Panel>
        <Panel title="Répartition par sévérité">
          {bySeverity.length ? <HorizontalBars data={bySeverity} labelKey="name" valueKey="value" color={C.amber} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun événement enregistré</p>}
        </Panel>
      </div>
      <Panel title="Registre des événements sécurité" subtitle="Cliquez une ligne pour ouvrir l'enquête et le plan d'actions.">
        {sorted.length
          ? <DataTable columns={['Type', 'Titre', 'Date', 'Sévérité', 'Arrêt', 'Statut']} rows={sorted.map((e) => [e.type, e.title, new Date(e.occurredAt).toLocaleDateString('fr-FR'), e.severity, e.withLostTime ? `${e.lostDays || 0} j` : '—', e.statut || 'DECLARE'])}
              onRowClick={(i) => setDetailFor(sorted[i].id)} />
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
  const [tab, setTab] = useState('dashboard');
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
  const maintenances = useCollection('/epi/maintenance');
  const [showMaintenanceForm, setShowMaintenanceForm] = useState(false);
  const [ncPrefill, setNcPrefill] = useState(null);
  const [showTrainingForm, setShowTrainingForm] = useState(false);
  const [selectedTraining, setSelectedTraining] = useState(null);
  const auditLogs = useCollection('/audit-logs');

  if (dash.loading || renewals.loading || renewalBuckets.loading || assignments.loading || trainings.loading || catalog.loading || employees.loading || epiCategories.loading || epcCategories.loading || epcList.loading || epiInspections.loading || epcInspections.loading || matrix.loading || maintenances.loading || auditLogs.loading) return <LoadingPanel />;
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
  const equippedEmployeeIds = new Set(assignmentList.map((a) => a.employeeId));
  const nonEquippedEmployees = employeeList.filter((e) => e.active && !equippedEmployeeIds.has(e.id));
  const criticalStockEpi = catalogList.filter((e) => (e.stock ?? 0) <= (e.minStock ?? 0));
  const epcNonConformesList = epcs.filter((e) => e.status === 'NON_CONFORME');
  const epcToInspect = epcs.filter((e) => e.nextInspectionAt && new Date(e.nextInspectionAt) < new Date());
  const epiInspList = epiInspections.data || [];
  const epcInspList = epcInspections.data || [];
  const reformedCount = [...epiInspList, ...epcInspList].filter((i) => i.result === 'A_REFORMER').length;
  const auditLogList = (auditLogs.data || []).filter((l) => ['Epi', 'Epc', 'EpiCategory', 'EpcCategory', 'EpiAssignment', 'EpiInspection', 'EpcInspection', 'EpcMaintenance', 'JobRiskProtection'].includes(l.module));

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
      {showMaintenanceForm && <EpcMaintenanceForm epcOptions={epcList.data || []} onClose={() => setShowMaintenanceForm(false)} onCreated={() => { maintenances.reload(); epcList.reload(); }} />}
      {ncPrefill && <NonConformityForm prefill={ncPrefill} onClose={() => setNcPrefill(null)} onCreated={() => setNcPrefill(null)} />}
      {(showTrainingForm || selectedTraining) && <TrainingForm record={selectedTraining} onClose={() => { setShowTrainingForm(false); setSelectedTraining(null); }} onCreated={trainings.reload} />}
      <div className="flex items-center justify-between"><LiveBadge /></div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="EPI au catalogue" value={catalogList.length} objectif={`${enRupture} en rupture de stock`} color={enRupture > 0 ? C.red : C.green} icon={ShieldCheck} />
        <KpiCard label="EPC enregistrés" value={epcs.length} objectif={`${epcNonConformes} non conforme(s)`} color={epcNonConformes > 0 ? C.red : C.green} icon={Cog} />
        <KpiCard label="Personnel actif" value={activeEmployees} objectif={`${employeeList.length} au total`} color={C.blue} icon={Users} />
        <KpiCard label="Renouvellements à venir" value={(renewals.data || []).length} color={C.amber} icon={AlertTriangle} />
      </div>

      <div className="flex flex-wrap gap-2">
        {[['dashboard', 'Tableau de bord'], ['stock', 'Stock EPI'], ['epc', 'Bibliothèque EPC'], ['categories', 'Catégories'], ['attribution', 'Attribution'], ['inspections', 'Inspections'], ['maintenance', 'Maintenance EPC'], ['matrice', 'Matrice Poste/Risque'], ['personnel', 'Personnel'], ['renouvellements', 'Renouvellements'], ['formations', 'Formations'], ['audit', "Journal d'audit"]].map(([id, label]) => (
          <button key={id} onClick={() => setTab(id)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: tab === id ? C.blue : 'transparent', color: tab === id ? '#fff' : C.textMuted }}>{label}</button>
        ))}
      </div>

      {tab === 'dashboard' && (
        <div className="space-y-6">
          <div className="flex flex-wrap gap-3">
            <KpiCard label="EPI au catalogue" value={catalogList.length} color={C.blue} icon={ShieldCheck} />
            <KpiCard label="EPC enregistrés" value={epcs.length} color={C.blue} icon={Cog} />
            <KpiCard label="EPI attribués" value={assignmentList.length} objectif="dotations enregistrées" color={C.green} icon={Users} />
            <KpiCard label="EPI expirés" value={buckets.expired.length} color={C.red} icon={AlertTriangle} />
            <KpiCard label="EPI à renouveler (90j)" value={buckets.within30.length + buckets.within60.length + buckets.within90.length} color={C.amber} icon={AlertTriangle} />
            <KpiCard label="Employés non équipés" value={nonEquippedEmployees.length} color={nonEquippedEmployees.length > 0 ? C.red : C.green} icon={Users} />
            <KpiCard label="Stock EPI critique" value={criticalStockEpi.length} color={criticalStockEpi.length > 0 ? C.red : C.green} icon={AlertTriangle} />
            <KpiCard label="EPC non conformes" value={epcNonConformesList.length} color={epcNonConformesList.length > 0 ? C.red : C.green} icon={ShieldCheck} />
            <KpiCard label="EPC à inspecter" value={epcToInspect.length} color={epcToInspect.length > 0 ? C.amber : C.green} icon={ClipboardList} />
            <KpiCard label="Équipements à réformer" value={reformedCount} color={reformedCount > 0 ? C.red : C.green} icon={AlertTriangle} />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <Panel title="EPI par catégorie">
              {catalogList.length ? <DonutChart data={groupCount(catalogList, (e) => e.category?.name || 'Sans catégorie')} colors={[C.blue, C.green, C.amber, C.red, '#8B5CF6', '#EC4899']} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun EPI enregistré</p>}
            </Panel>
            <Panel title="Statut des inspections EPI/EPC">
              {(epiInspList.length + epcInspList.length) ? <DonutChart data={groupCount([...epiInspList, ...epcInspList], (i) => i.result === 'CONFORME' ? 'Conforme' : i.result === 'NON_CONFORME' ? 'Non conforme' : i.result === 'A_SURVEILLER' ? 'À surveiller' : 'À réformer')} colors={[C.green, C.red, C.amber, '#8B5CF6']} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucune inspection enregistrée</p>}
            </Panel>
          </div>
          <p className="text-[11px]" style={{ color: C.textMuted }}>Les pertes et détériorations enregistrées via les mouvements de stock ne sont pas encore comptabilisées séparément ici — dites-moi si vous voulez que je les ajoute.</p>
        </div>
      )}

      {tab === 'formations' && (
        <Panel title="Formations" right={<button onClick={() => setShowTrainingForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvelle formation</button>}>
          {trainingsList.length
            ? <DataTable columns={['Intitulé', 'Formateur', 'Date', 'Statut', 'Expiration', 'Processus']}
                rows={trainingsList.map((t) => {
                  const expired = t.expiryAt && new Date(t.expiryAt) < new Date();
                  return [
                    t.title, t.trainer || '—', new Date(t.scheduledAt).toLocaleDateString('fr-FR'),
                    t.status === 'DONE' ? 'Réalisée' : t.status === 'CANCELLED' ? 'Annulée' : 'Planifiée',
                    t.expiryAt ? <span style={{ color: expired ? C.red : C.textMuted }}>{new Date(t.expiryAt).toLocaleDateString('fr-FR')}{expired ? ' (expirée)' : ''}</span> : '—',
                    t.processus?.nom || '—',
                  ];
                })}
                onRowClick={(i) => setSelectedTraining(trainingsList[i])} />
            : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune formation enregistrée pour le moment</p>}
        </Panel>
      )}

      {tab === 'audit' && (
        <Panel title="Journal d'audit — module EPI/EPC" subtitle="200 dernières actions, toutes traçées automatiquement">
          {auditLogList.length
            ? <DataTable columns={['Date', 'Utilisateur', 'Action', 'Module', 'Élément']}
                rows={auditLogList.map((l) => [
                  new Date(l.createdAt).toLocaleString('fr-FR'),
                  l.user ? `${l.user.firstName} ${l.user.lastName}` : 'Système',
                  l.action === 'CREATE' ? 'Création' : l.action === 'UPDATE' ? 'Modification' : 'Suppression',
                  l.module, l.entityId || '—',
                ])} />
            : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune action enregistrée pour le moment</p>}
        </Panel>
      )}

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
              ? <DataTable columns={['EPI', 'Date', 'Résultat', 'Observations', '']} rows={epiInspections.data.map((i) => [
                  i.epi?.name || '—', new Date(i.inspectedAt).toLocaleDateString('fr-FR'),
                  <StatusChip statut={i.result === 'CONFORME' ? 'Conforme' : i.result === 'NON_CONFORME' ? 'Non conforme' : i.result} />,
                  i.observations || '—',
                  (i.result === 'NON_CONFORME' || i.result === 'A_REFORMER')
                    ? <button onClick={(e) => { e.stopPropagation(); setNcPrefill({ title: `EPI non conforme — ${i.epi?.name || ''}`, description: i.observations || '', source: 'EPI', severity: i.result === 'A_REFORMER' ? 3 : 2, epiId: i.epiId }); }} className="text-xs" style={{ color: C.red }}>Créer une NC</button>
                    : null,
                ])} />
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune inspection EPI enregistrée</p>}
          </Panel>
          <Panel title="Inspections EPC" right={<button onClick={() => setShowEpcInspForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvelle inspection</button>}>
            {(epcInspections.data || []).length
              ? <DataTable columns={['EPC', 'Date', 'Résultat', 'Observations', '']} rows={epcInspections.data.map((i) => [
                  i.epc?.name || '—', new Date(i.inspectedAt).toLocaleDateString('fr-FR'),
                  <StatusChip statut={i.result === 'CONFORME' ? 'Conforme' : i.result === 'NON_CONFORME' ? 'Non conforme' : i.result} />,
                  i.observations || '—',
                  (i.result === 'NON_CONFORME' || i.result === 'A_REFORMER')
                    ? <button onClick={(e) => { e.stopPropagation(); setNcPrefill({ title: `EPC non conforme — ${i.epc?.name || ''}`, description: i.observations || '', source: 'EPC', severity: i.result === 'A_REFORMER' ? 3 : 2, epcId: i.epcId }); }} className="text-xs" style={{ color: C.red }}>Créer une NC</button>
                    : null,
                ])} />
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune inspection EPC enregistrée</p>}
          </Panel>
        </div>
      )}

      {tab === 'maintenance' && (
        <Panel title="Historique de maintenance EPC" right={<button onClick={() => setShowMaintenanceForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvelle intervention</button>}>
          {(maintenances.data || []).length
            ? <DataTable columns={['EPC', 'Type', 'Date', 'Description', 'Coût', 'Prochaine échéance']}
                rows={maintenances.data.map((m) => [
                  m.epc?.name || '—', m.type === 'PREVENTIVE' ? 'Préventive' : 'Corrective',
                  new Date(m.date).toLocaleDateString('fr-FR'), m.description || '—',
                  m.cost != null ? `${m.cost.toLocaleString('fr-FR')} FCFA` : '—',
                  m.nextMaintenanceAt ? new Date(m.nextMaintenanceAt).toLocaleDateString('fr-FR') : '—',
                ])} />
            : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune intervention enregistrée — utilisez « + Nouvelle intervention » pour commencer</p>}
        </Panel>
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
  const risques = useCollection('/business/risques-sanitaires');
  const ergonomies = useCollection('/business/analyses-ergonomiques');
  const tmsList = useCollection('/business/tms-signalements');
  const alertesQ = useCollection('/business/hygiene-alertes');
  const indiceQ = useCollection('/business/hygiene-indice-global');
  const facteursQ = useCollection('/business/penibilite-facteurs');
  const expositionsQ = useCollection('/business/penibilite-expositions');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  const [showRisqueForm, setShowRisqueForm] = useState(false);
  const [selectedRisque, setSelectedRisque] = useState(null);
  const [showErgonomieForm, setShowErgonomieForm] = useState(false);
  const [selectedErgonomie, setSelectedErgonomie] = useState(null);
  const [showTmsForm, setShowTmsForm] = useState(false);
  const [selectedTms, setSelectedTms] = useState(null);
  const [showFacteurForm, setShowFacteurForm] = useState(false);
  const [showExpositionForm, setShowExpositionForm] = useState(false);
  const [nouveauFacteur, setNouveauFacteur] = useState('');
  const [tab, setTab] = useState('medecine');
  if (visites.loading || risques.loading || ergonomies.loading || tmsList.loading || alertesQ.loading || indiceQ.loading || facteursQ.loading || expositionsQ.loading) return <LoadingPanel />;
  if (visites.error) return <ErrorPanel message={visites.error} onRetry={visites.reload} />;
  const list = visites.data || [];
  const risqueList = risques.data || [];
  const ergonomieList = ergonomies.data || [];
  const tmsSignalements = tmsList.data || [];
  const alertes = alertesQ.data || [];
  const indice = indiceQ.data || { indice: null, detail: [] };
  const facteurs = facteursQ.data || [];
  const expositions = expositionsQ.data || [];
  const now = new Date();
  const enRetard = list.filter((v) => v.prochaineVisite && new Date(v.prochaineVisite) < now).length;
  const avecReserves = list.filter((v) => v.aptitude === 'Apte avec réserves').length;
  const inaptes = list.filter((v) => v.aptitude === 'Inapte').length;
  const parAptitude = groupCount(list.filter((v) => v.aptitude), (v) => v.aptitude);
  const sorted = [...list].sort((a, b) => (a.prochaineVisite ? new Date(a.prochaineVisite) : Infinity) - (b.prochaineVisite ? new Date(b.prochaineVisite) : Infinity));
  const risquesCritiques = risqueList.filter((r) => r.criticite >= 12 && r.statut === 'ACTIVE').length;
  const niveauColor = (c) => (c >= 12 ? C.red : c >= 6 ? C.amber : C.green);
  const niveauLabel = (c) => (c >= 12 ? 'Critique' : c >= 6 ? 'Élevé' : 'Faible/Modéré');
  const scoreErgoColor = { FAIBLE: C.green, MODERE: C.amber, ELEVE: C.red, CRITIQUE: C.red };
  const scoreErgoLabel = { FAIBLE: 'Faible', MODERE: 'Modéré', ELEVE: 'Élevé', CRITIQUE: 'Critique' };
  const parZoneCorporelle = groupCount(tmsSignalements, (t) => t.zoneCorporelle);
  const alerteNiveauColor = { CRITIQUE: C.red, URGENT: C.red, ATTENTION: C.amber };
  const indiceLevel = indice.indice == null ? null : indice.indice >= 90 ? { label: 'Excellent', color: C.green } : indice.indice >= 75 ? { label: 'Bon', color: C.green } : indice.indice >= 60 ? { label: 'À améliorer', color: C.amber } : indice.indice >= 40 ? { label: 'Insuffisant', color: C.red } : { label: 'Critique', color: C.red };

  async function creerFacteur() {
    if (!nouveauFacteur.trim()) return;
    try { await api.post('/business/penibilite-facteurs', { nom: nouveauFacteur.trim() }); setNouveauFacteur(''); facteursQ.reload(); }
    catch (e) { alert(e.message); }
  }

  return (
    <div className="space-y-6">
      {(showForm || selected) && <VisiteMedicaleForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={visites.reload} />}
      {(showRisqueForm || selectedRisque) && <RisqueSanitaireForm record={selectedRisque} onClose={() => { setShowRisqueForm(false); setSelectedRisque(null); }} onCreated={risques.reload} />}
      {(showErgonomieForm || selectedErgonomie) && <AnalyseErgonomiqueForm record={selectedErgonomie} onClose={() => { setShowErgonomieForm(false); setSelectedErgonomie(null); }} onCreated={ergonomies.reload} />}
      {(showTmsForm || selectedTms) && <TmsSignalementForm record={selectedTms} onClose={() => { setShowTmsForm(false); setSelectedTms(null); }} onCreated={tmsList.reload} />}
      {showExpositionForm && <PenibiliteExpositionForm facteurs={facteurs} onClose={() => setShowExpositionForm(false)} onCreated={expositionsQ.reload} />}

      <div className="flex flex-wrap gap-2">
        {[['medecine', 'Médecine du travail'], ['risques', 'Risques sanitaires'], ['ergonomie', 'Ergonomie & TMS'], ['pilotage', 'Pilotage']].map(([id, label]) => (
          <button key={id} onClick={() => setTab(id)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: tab === id ? C.blue : 'transparent', color: tab === id ? '#fff' : C.textMuted }}>{label}</button>
        ))}
      </div>

      {tab === 'medecine' && (
        <div className="space-y-6">
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
      )}

      {tab === 'risques' && (
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <LiveBadge />
            <button onClick={() => setShowRisqueForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Évaluer un risque</button>
          </div>
          <div className="flex flex-wrap gap-3">
            <KpiCard label="Risques sanitaires" value={risqueList.length} color={C.blue} icon={HeartPulse} />
            <KpiCard label="Critiques" value={risquesCritiques} color={risquesCritiques > 0 ? C.red : C.green} icon={AlertTriangle} />
            <KpiCard label="Personnes exposées" value={risqueList.reduce((s, r) => s + (r.nombrePersonnesExposees || 0), 0)} color={C.amber} icon={ClipboardList} />
          </div>
          <Panel title="Évaluation des risques sanitaires">
            {risqueList.length
              ? <DataTable columns={['Danger', 'Catégorie', 'Poste/Zone', 'Personnes exposées', 'Criticité', 'Statut']}
                  rows={risqueList.map((r) => [
                    r.danger, r.categorie || '—', [r.poste, r.zone].filter(Boolean).join(' / ') || '—', r.nombrePersonnesExposees ?? '—',
                    <span style={{ color: niveauColor(r.criticite), fontWeight: 600 }}>{r.criticite} ({niveauLabel(r.criticite)})</span>,
                    <StatusChip statut={r.statut === 'ACTIVE' ? 'Actif' : r.statut === 'MAITRISE' ? 'Maîtrisé' : 'Clôturé'} />,
                  ])}
                  onRowClick={(i) => setSelectedRisque(risqueList[i])} />
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun risque sanitaire évalué pour le moment</p>}
          </Panel>
        </div>
      )}

      {tab === 'ergonomie' && (
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <LiveBadge />
            <div className="flex gap-2">
              <button onClick={() => setShowTmsForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.amber, color: '#3a2600' }}>+ Signaler une situation TMS</button>
              <button onClick={() => setShowErgonomieForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Analyser un poste</button>
            </div>
          </div>
          <div className="flex flex-wrap gap-3">
            <KpiCard label="Postes analysés" value={ergonomieList.length} color={C.blue} icon={ClipboardList} />
            <KpiCard label="Postes critiques/élevés" value={ergonomieList.filter((e) => e.scoreErgonomique === 'CRITIQUE' || e.scoreErgonomique === 'ELEVE').length} color={C.red} icon={AlertTriangle} />
            <KpiCard label="Signalements TMS" value={tmsSignalements.length} color={C.amber} icon={HeartPulse} />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <Panel title="Analyses ergonomiques">
              {ergonomieList.length
                ? <div className="space-y-2">{ergonomieList.map((e) => (
                    <div key={e.id} onClick={() => setSelectedErgonomie(e)} className="flex justify-between items-center text-sm py-1.5 cursor-pointer" style={{ borderTop: `1px solid ${C.border}` }}>
                      <span style={{ color: C.text }}>{e.poste}</span>
                      <span style={{ color: scoreErgoColor[e.scoreErgonomique] }}>{scoreErgoLabel[e.scoreErgonomique]}</span>
                    </div>
                  ))}</div>
                : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun poste analysé pour le moment</p>}
            </Panel>
            <Panel title="TMS par zone corporelle">
              {parZoneCorporelle.length ? <DonutChart data={parZoneCorporelle} colors={[C.red, '#F97316', C.amber, '#8B5CF6', C.blue, C.green, '#EC4899', '#14B8A6', '#6366F1']} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun signalement pour le moment</p>}
            </Panel>
          </div>
          {tmsSignalements.length > 0 && (
            <Panel title="Registre des signalements TMS">
              <DataTable columns={['Zone corporelle', 'Poste', 'Activité', 'Date', 'Statut']}
                rows={tmsSignalements.map((t) => [t.zoneCorporelle, t.poste || '—', t.activite || '—', new Date(t.dateSignalement).toLocaleDateString('fr-FR'), t.statut === 'SIGNALE' ? 'Signalé' : t.statut === 'EN_ANALYSE' ? 'En analyse' : 'Traité'])}
                onRowClick={(i) => setSelectedTms(tmsSignalements[i])} />
            </Panel>
          )}
        </div>
      )}

      {tab === 'pilotage' && (
        <div className="space-y-6">
          <LiveBadge />
          <Panel title="Indice Hygiène au travail" subtitle="Moyenne pondérée — pondérations partagées avec les autres indices de l'application.">
            <div className="flex items-center gap-6">
              <div>
                <p className="text-5xl font-bold" style={{ color: indiceLevel?.color || C.text }}>{indice.indice != null ? indice.indice : '—'}<span className="text-lg" style={{ color: C.textMuted }}>/100</span></p>
                {indiceLevel && <p className="text-xs font-medium" style={{ color: indiceLevel.color }}>{indiceLevel.label}</p>}
              </div>
              <div className="grid grid-cols-2 gap-2 flex-1">
                {(indice.detail || []).map((d) => (
                  <div key={d.key} className="p-2 rounded-lg text-center" style={{ backgroundColor: C.cardAlt }}>
                    <p className="text-[10px]" style={{ color: C.textMuted }}>{d.nom}</p>
                    <p className="text-sm font-bold" style={{ color: C.text }}>{d.valeur != null ? `${d.valeur}%` : '—'}</p>
                  </div>
                ))}
              </div>
            </div>
          </Panel>

          <Panel title="Alertes automatiques" subtitle={`${alertes.length} point(s) nécessitant l'attention du Responsable QHSE`}>
            {alertes.length
              ? <div className="space-y-2">{alertes.map((a, i) => (
                  <div key={i} className="flex items-center justify-between py-2" style={{ borderTop: `1px solid ${C.border}` }}>
                    <span className="text-sm" style={{ color: C.text }}>{a.label}</span>
                    <span className="text-[11px] px-2 py-1 rounded-full font-medium" style={{ backgroundColor: `${alerteNiveauColor[a.niveau]}22`, color: alerteNiveauColor[a.niveau] }}>{a.niveau}</span>
                  </div>
                ))}</div>
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune alerte — tout est sous contrôle</p>}
          </Panel>

          <Panel title="Pénibilité" subtitle="Facteurs configurables — jamais une liste réglementaire unique imposée.">
            <div className="flex gap-2 mb-4">
              <input value={nouveauFacteur} onChange={(e) => setNouveauFacteur(e.target.value)} placeholder="Nouveau facteur (ex. Travail de nuit)" className="flex-1 px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} />
              <button onClick={creerFacteur} className="px-3 py-2 rounded-lg text-xs font-medium" style={{ backgroundColor: C.blue, color: '#fff' }}>+ Ajouter</button>
              {facteurs.length > 0 && <button onClick={() => setShowExpositionForm(true)} className="px-3 py-2 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Exposition</button>}
            </div>
            {expositions.length
              ? <DataTable columns={['Facteur', 'Employé', 'Poste', 'Niveau', 'Prochaine réévaluation']}
                  rows={expositions.map((ex) => [ex.facteur?.nom || '—', ex.employee ? `${ex.employee.firstName} ${ex.employee.lastName}` : '—', ex.poste || '—', ex.niveauExposition || '—', ex.prochaineReevaluation ? new Date(ex.prochaineReevaluation).toLocaleDateString('fr-FR') : '—'])} />
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>{facteurs.length === 0 ? 'Ajoutez un facteur de pénibilité pour commencer' : 'Aucune exposition enregistrée pour le moment'}</p>}
          </Panel>
        </div>
      )}
    </div>
  );
}

function EnvironnementPage() {
  const C = useTheme();
  const records = useCollection('/business/environment');
  const aspects = useCollection('/business/environnement-aspects');
  const dashboardQ = useCollection('/business/environnement-dashboard');
  const alertesQ = useCollection('/business/environnement-alertes');
  const tendancesQ = useCollection('/business/environnement-tendances');
  const veilleQ = useCollection('/business/veille-reglementaire');
  const produitsQ = useCollection('/business/produits-chimiques');
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState(null);
  const [showAspectForm, setShowAspectForm] = useState(false);
  const [selectedAspect, setSelectedAspect] = useState(null);
  const [showVeilleForm, setShowVeilleForm] = useState(false);
  const [selectedVeille, setSelectedVeille] = useState(null);
  const [showProduitForm, setShowProduitForm] = useState(false);
  const [selectedProduit, setSelectedProduit] = useState(null);
  const [tab, setTab] = useState('apercu');
  if (records.loading || aspects.loading || dashboardQ.loading || alertesQ.loading || tendancesQ.loading || veilleQ.loading || produitsQ.loading) return <LoadingPanel />;
  if (records.error) return <ErrorPanel message={records.error} onRetry={records.reload} />;
  const list = records.data || [];
  const aspectList = aspects.data || [];
  const dash = dashboardQ.data || {};
  const alertes = alertesQ.data || [];
  const tendances = tendancesQ.data || [];
  const veilleEnv = (veilleQ.data || []).filter((v) => v.domaine === 'Environnement');
  const produits = produitsQ.data || [];
  const now2 = new Date();
  const byCategorie = groupCount(list.filter((r) => r.categorie), (r) => r.categorie);
  const sorted = [...list].sort((a, b) => new Date(b.recordedAt) - new Date(a.recordedAt));
  const aspectsSignificatifs = aspectList.filter((a) => a.significatif && a.statut === 'ACTIVE').length;
  const nonConformes = list.filter((r) => r.conforme === false).length;
  const criticiteColor = (c) => (c >= 12 ? C.red : c >= 6 ? C.amber : C.green);
  const situationLabel = { NORMALE: 'Normale', ANORMALE: 'Anormale', URGENCE: "Situation d'urgence" };
  const niveauColor = { CRITIQUE: C.red, URGENT: C.red, ATTENTION: C.amber };
  const dv = (v, suffix = '') => (v == null ? 'Aucune donnée disponible' : `${v}${suffix}`);
  const scoreLevel = dash.score == null ? null : dash.score >= 80 ? { label: 'Bon', color: C.green } : dash.score >= 60 ? { label: 'À améliorer', color: C.amber } : { label: 'Critique', color: C.red };
  const veilleStatutLabel = { A_TRAITER: 'À traiter', EN_COURS: 'En cours', INTEGREE: 'Intégrée', CONFORME: 'Conforme', PARTIELLEMENT_CONFORME: 'Partiellement conforme', NON_CONFORME: 'Non conforme', NON_APPLICABLE: 'Non applicable', A_VERIFIER: 'À vérifier' };
  const veilleStatutColor = { CONFORME: C.green, INTEGREE: C.green, PARTIELLEMENT_CONFORME: C.amber, NON_CONFORME: C.red, NON_APPLICABLE: C.textMuted, A_VERIFIER: C.amber, A_TRAITER: C.amber, EN_COURS: C.blue };

  return (
    <div className="space-y-6">
      {(showForm || selected) && <EnvironmentForm record={selected} onClose={() => { setShowForm(false); setSelected(null); }} onCreated={records.reload} />}
      {(showAspectForm || selectedAspect) && <EnvironnementAspectForm record={selectedAspect} onClose={() => { setShowAspectForm(false); setSelectedAspect(null); }} onCreated={aspects.reload} />}
      {(showVeilleForm || selectedVeille) && <VeilleForm record={selectedVeille ? { ...selectedVeille } : { domaine: 'Environnement' }} onClose={() => { setShowVeilleForm(false); setSelectedVeille(null); }} onCreated={veilleQ.reload} />}
      {(showProduitForm || selectedProduit) && <ProduitChimiqueForm record={selectedProduit} onClose={() => { setShowProduitForm(false); setSelectedProduit(null); }} onCreated={produitsQ.reload} />}

      <div className="flex flex-wrap gap-2">
        {[['apercu', "Vue d'ensemble"], ['releves', 'Relevés'], ['aspects', 'Aspects & Impacts'], ['conformite', 'Conformité réglementaire'], ['chimiques', 'Produits chimiques'], ['indicateurs', 'Indicateurs']].map(([id, label]) => (
          <button key={id} onClick={() => setTab(id)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: tab === id ? C.blue : 'transparent', color: tab === id ? '#fff' : C.textMuted }}>{label}</button>
        ))}
      </div>

      {tab === 'apercu' && (
        <div className="space-y-6">
          <LiveBadge />
          <Panel title="Score environnemental global" subtitle="Moyenne pondérée — pondérations partagées avec les autres indices de l'application.">
            {dash.score == null
              ? <p className="text-sm py-4" style={{ color: C.textMuted }}>Aucune donnée disponible pour calculer le score</p>
              : <div className="flex items-center gap-6">
                  <div>
                    <p className="text-5xl font-bold" style={{ color: scoreLevel?.color || C.text }}>{dash.score}<span className="text-lg" style={{ color: C.textMuted }}>/100</span></p>
                    {scoreLevel && <p className="text-xs font-medium" style={{ color: scoreLevel.color }}>{scoreLevel.label}</p>}
                  </div>
                  <div className="grid grid-cols-2 gap-2 flex-1">
                    {(dash.scoreDetail || []).map((d) => (
                      <div key={d.key} className="p-2 rounded-lg text-center" style={{ backgroundColor: C.cardAlt }}>
                        <p className="text-[10px]" style={{ color: C.textMuted }}>{d.nom}</p>
                        <p className="text-sm font-bold" style={{ color: C.text }}>{d.valeur != null ? `${d.valeur}%` : 'Aucune donnée'}</p>
                      </div>
                    ))}
                  </div>
                </div>}
          </Panel>

          <div className="flex flex-wrap gap-3">
            <KpiCard label="Taux de conformité" value={dv(dash.tauxConformite, '%')} color={C.blue} icon={ShieldCheck} />
            <KpiCard label="Déchets (somme des relevés)" value={dv(dash.dechets)} color={C.amber} icon={Leaf} />
            <KpiCard label="Eau (somme des relevés)" value={dv(dash.eau)} color={C.blue} icon={Activity} />
            <KpiCard label="Énergie (somme des relevés)" value={dv(dash.energie)} color={C.amber} icon={Activity} />
            <KpiCard label="GES / Carbone (somme des relevés)" value={dv(dash.ges)} color={C.textMuted} icon={Leaf} />
            <KpiCard label="Taux de valorisation des déchets" value={dv(dash.tauxValorisationDechets, '%')} color={C.green} icon={Leaf} />
            <KpiCard label="Conformité réglementaire" value={dv(dash.tauxConformiteReglementaire, '%')} color={C.blue} icon={ShieldCheck} />
            <KpiCard label="Aspects significatifs" value={dash.aspectsSignificatifs ?? 0} color={dash.aspectsSignificatifs > 0 ? C.red : C.green} icon={AlertTriangle} />
            <KpiCard label="Actions en retard" value={dash.actionsEnRetard ?? 0} color={dash.actionsEnRetard > 0 ? C.red : C.green} icon={AlertTriangle} />
          </div>

          <Panel title="Alertes environnementales" subtitle={`${alertes.length} point(s) nécessitant attention`}>
            {alertes.length
              ? <div className="space-y-2">{alertes.map((a, i) => (
                  <div key={i} className="flex items-center justify-between py-2" style={{ borderTop: `1px solid ${C.border}` }}>
                    <span className="text-sm" style={{ color: C.text }}>{a.label}</span>
                    <span className="text-[11px] px-2 py-1 rounded-full font-medium" style={{ backgroundColor: `${niveauColor[a.niveau]}22`, color: niveauColor[a.niveau] }}>{a.niveau}</span>
                  </div>
                ))}</div>
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune alerte — tout est sous contrôle</p>}
          </Panel>

          <Panel title="Tendances mensuelles par catégorie" subtitle="Calculées uniquement sur les mois où des relevés existent réellement.">
            {tendances.length
              ? <div className="space-y-6">
                  {tendances.map((t) => (
                    <div key={t.categorie}>
                      <p className="text-xs font-semibold mb-2" style={{ color: C.textMuted }}>{t.categorie}</p>
                      <ResponsiveContainer width="100%" height={140}>
                        <LineChart data={t.points}>
                          <CartesianGrid strokeDasharray="3 3" stroke={C.border} />
                          <XAxis dataKey="mois" tick={{ fontSize: 10, fill: C.textMuted }} />
                          <YAxis tick={{ fontSize: 10, fill: C.textMuted }} />
                          <Tooltip contentStyle={{ backgroundColor: C.card, border: `1px solid ${C.border}`, fontSize: 12 }} />
                          <Line type="monotone" dataKey="valeur" stroke={C.blue} strokeWidth={2} dot={{ r: 3 }} />
                        </LineChart>
                      </ResponsiveContainer>
                    </div>
                  ))}
                </div>
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune donnée disponible pour tracer une tendance</p>}
          </Panel>
        </div>
      )}

      {tab === 'releves' && (
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <LiveBadge />
            <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouveau relevé</button>
          </div>
          <div className="flex flex-wrap gap-3">
            <KpiCard label="Relevés enregistrés" value={list.length} color={C.blue} icon={ClipboardList} />
            <KpiCard label="Catégories suivies" value={byCategorie.length} color={C.green} icon={Leaf} />
            <KpiCard label="Non conformes" value={nonConformes} color={nonConformes > 0 ? C.red : C.green} icon={AlertTriangle} />
            <KpiCard label="Dernier relevé" value={sorted[0] ? new Date(sorted[0].recordedAt).toLocaleDateString('fr-FR') : '—'} color={C.amber} icon={Activity} />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <Panel title="Répartition par catégorie">
              {byCategorie.length ? <DonutChart data={byCategorie} colors={[C.red, C.amber, C.blue, C.green, '#8B5CF6', C.textMuted, '#EC4899', '#14B8A6', '#6366F1', '#F97316', '#84CC16']} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucune catégorie renseignée</p>}
            </Panel>
            <Panel title="Détail par catégorie"><HorizontalBars data={byCategorie} labelKey="name" valueKey="value" color={C.blue} /></Panel>
          </div>
          <Panel title="Registre des relevés environnementaux">
            {sorted.length
              ? <DataTable columns={['Catégorie', 'Type', 'Valeur', 'Unité', 'Site', 'Date', 'Conforme']}
                  rows={sorted.map((r) => [r.categorie || '—', r.type, r.value ?? '—', r.unit || '—', r.site || '—', new Date(r.recordedAt).toLocaleDateString('fr-FR'), r.conforme == null ? '—' : <StatusChip statut={r.conforme ? 'Conforme' : 'Non conforme'} />])}
                  onRowClick={(i) => setSelected(sorted[i])} />
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun relevé enregistré pour le moment</p>}
          </Panel>
        </div>
      )}

      {tab === 'aspects' && (
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <LiveBadge />
            <button onClick={() => setShowAspectForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvel aspect</button>
          </div>
          <div className="flex flex-wrap gap-3">
            <KpiCard label="Aspects identifiés" value={aspectList.length} color={C.blue} icon={Leaf} />
            <KpiCard label="Significatifs" value={aspectsSignificatifs} color={aspectsSignificatifs > 0 ? C.red : C.green} icon={AlertTriangle} />
          </div>
          <Panel title="Registre des aspects & impacts environnementaux" subtitle="Criticité = Fréquence × Gravité × Probabilité ÷ Maîtrise — significatif à partir de 12.">
            {aspectList.length
              ? <DataTable columns={['Aspect', 'Milieu', 'Situation', 'Criticité', 'Significatif', 'Statut']}
                  rows={aspectList.map((a) => [
                    a.aspect, a.milieu || '—', situationLabel[a.situation] || a.situation,
                    <span style={{ color: criticiteColor(a.criticite), fontWeight: 600 }}>{a.criticite}</span>,
                    a.significatif ? <span style={{ color: C.red }}>Oui</span> : 'Non',
                    <StatusChip statut={a.statut === 'ACTIVE' ? 'Actif' : a.statut === 'MAITRISE' ? 'Maîtrisé' : 'Clôturé'} />,
                  ])}
                  onRowClick={(i) => setSelectedAspect(aspectList[i])} />
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun aspect environnemental identifié pour le moment</p>}
          </Panel>
        </div>
      )}

      {tab === 'conformite' && (
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <LiveBadge />
            <button onClick={() => setShowVeilleForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouvelle exigence</button>
          </div>
          <div className="flex flex-wrap gap-3">
            <KpiCard label="Exigences suivies" value={veilleEnv.length} color={C.blue} icon={ClipboardList} />
            <KpiCard label="Non conformes" value={veilleEnv.filter((v) => v.statut === 'NON_CONFORME').length} color={C.red} icon={AlertTriangle} />
            <KpiCard label="À vérifier" value={veilleEnv.filter((v) => v.statut === 'A_VERIFIER').length} color={C.amber} icon={AlertTriangle} />
          </div>
          <Panel title="Registre de conformité réglementaire environnementale">
            {veilleEnv.length
              ? <DataTable columns={['Texte', "Date d'application", 'Responsable', 'Statut']}
                  rows={veilleEnv.map((v) => [v.texte.slice(0, 60), v.dateApplication ? new Date(v.dateApplication).toLocaleDateString('fr-FR') : '—', v.responsable ? `${v.responsable.firstName} ${v.responsable.lastName}` : '—', <span style={{ color: veilleStatutColor[v.statut] || C.textMuted, fontWeight: 600 }}>{veilleStatutLabel[v.statut] || v.statut}</span>])}
                  onRowClick={(i) => setSelectedVeille(veilleEnv[i])} />
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune exigence réglementaire environnementale enregistrée pour le moment</p>}
          </Panel>
        </div>
      )}

      {tab === 'chimiques' && (
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <LiveBadge />
            <button onClick={() => setShowProduitForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouveau produit</button>
          </div>
          <div className="flex flex-wrap gap-3">
            <KpiCard label="Produits suivis" value={produits.length} color={C.blue} icon={ClipboardList} />
            <KpiCard label="FDS manquantes" value={produits.filter((p) => !p.fdsDisponible).length} color={C.amber} icon={AlertTriangle} />
            <KpiCard label="Expirés" value={produits.filter((p) => p.dateExpiration && new Date(p.dateExpiration) < now2).length} color={C.red} icon={AlertTriangle} />
            <KpiCard label="Sans rétention (dangereux)" value={produits.filter((p) => p.dangerEnvironnemental && !p.retention).length} color={C.red} icon={AlertTriangle} />
          </div>
          <Panel title="Registre des produits chimiques">
            {produits.length
              ? <DataTable columns={['Nom', 'Classification', 'Stock', 'FDS', 'Rétention', 'Expiration']}
                  rows={produits.map((p) => [
                    p.nom, p.classification || '—', p.quantiteStockee != null ? `${p.quantiteStockee}${p.unite || ''}` : '—',
                    p.fdsDisponible ? <StatusChip statut="Disponible" /> : <span style={{ color: C.amber }}>Manquante</span>,
                    p.retention ? 'Oui' : <span style={{ color: p.dangerEnvironnemental ? C.red : C.textMuted }}>Non</span>,
                    p.dateExpiration ? <span style={{ color: new Date(p.dateExpiration) < now2 ? C.red : C.text }}>{new Date(p.dateExpiration).toLocaleDateString('fr-FR')}</span> : '—',
                  ])}
                  onRowClick={(i) => setSelectedProduit(produits[i])} />
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun produit chimique enregistré pour le moment</p>}
          </Panel>
        </div>
      )}

      {tab === 'indicateurs' && <IndicateurDomainPanel domaine="ENVIRONNEMENT" titre="Indicateurs environnementaux" />}
    </div>
  );
}

// Hiérarchie de prévention (point 9 du cahier des charges) — texte libre côté
// base, mais une liste suggérée ici pour guider la saisie sans l'enfermer.
const RISK_MEASURE_TYPES = [
  ['SUPPRESSION', 'Suppression du danger'], ['SUBSTITUTION', 'Substitution'],
  ['PROTECTION_COLLECTIVE', 'Protection collective'], ['TECHNIQUE', 'Mesure technique'],
  ['ORGANISATIONNELLE', 'Mesure organisationnelle'], ['PROCEDURE', 'Procédure / instruction'],
  ['FORMATION', 'Formation / information'], ['SIGNALISATION', 'Signalisation'], ['EPI', 'EPI'], ['AUTRE', 'Autre'],
];

function RiskDetailModal({ risk, onClose, onChanged, onEdit }) {
  const C = useTheme();
  const detailQ = useCollection(`/business/risks/${risk.id}`);
  const [showAddMeasure, setShowAddMeasure] = useState(false);
  const [form, setForm] = useState({ description: '', type: 'TECHNIQUE', efficacite: 3, justificatif: '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  if (detailQ.loading) return <Modal title={risk.hazard} onClose={onClose}><LoadingPanel /></Modal>;
  const d = detailQ.data || risk;
  const measures = d.riskMeasures || [];
  const evaluations = [...(d.evaluations || [])].sort((a, b) => new Date(a.evaluatedAt) - new Date(b.evaluatedAt));
  const niveauColor = { CRITIQUE: C.red, ELEVE: C.amber, MODERE: '#B45309', FAIBLE: C.green };

  async function addMeasure(e) {
    e.preventDefault(); setSaving(true); setError(null);
    try {
      await api.post('/business/risk-measures', { ...form, efficacite: Number(form.efficacite), riskId: risk.id });
      setForm({ description: '', type: 'TECHNIQUE', efficacite: 3, justificatif: '' }); setShowAddMeasure(false);
      detailQ.reload(); onChanged();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function deleteMeasure(id) {
    try { await api.del(`/business/risk-measures/${id}`); detailQ.reload(); onChanged(); }
    catch (err) { alert(err.message); }
  }

  return (
    <Modal title={d.hazard} onClose={onClose} wide>
      <div className="flex items-center justify-between mb-3">
        <p className="text-xs" style={{ color: C.textMuted }}>{d.category?.label || 'Sans catégorie'} · {d.workUnit?.name || 'Sans unité de travail'}</p>
        <button onClick={onEdit} className="text-xs px-2 py-1 rounded-lg" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}`, color: C.text }}>Modifier le risque</button>
      </div>
      <div className="grid grid-cols-3 gap-3 mb-5">
        <div className="p-2.5 rounded-lg text-center" style={{ backgroundColor: C.cardAlt }}>
          <p className="text-[10px]" style={{ color: C.textMuted }}>Risque brut</p>
          <p className="text-lg font-bold" style={{ color: niveauColor[d.grossLevel] || C.text }}>{d.grossScore ?? d.score}</p>
          <p className="text-[10px]" style={{ color: niveauColor[d.grossLevel] || C.textMuted }}>{d.grossLevel || '—'}</p>
        </div>
        <div className="p-2.5 rounded-lg text-center" style={{ backgroundColor: C.cardAlt }}>
          <p className="text-[10px]" style={{ color: C.textMuted }}>Risque résiduel</p>
          <p className="text-lg font-bold" style={{ color: d.residualScore != null ? (niveauColor[d.residualLevel] || C.text) : C.textMuted }}>{d.residualScore ?? '—'}</p>
          <p className="text-[10px]" style={{ color: niveauColor[d.residualLevel] || C.textMuted }}>{d.residualLevel || '—'}</p>
        </div>
        <div className="p-2.5 rounded-lg text-center" style={{ backgroundColor: C.cardAlt }}>
          <p className="text-[10px]" style={{ color: C.textMuted }}>Statut de maîtrise</p>
          <p className="text-sm font-bold mt-1.5" style={{ color: d.controlStatus === 'MAITRISE' ? C.green : d.controlStatus === 'PARTIELLEMENT_MAITRISE' ? C.amber : C.red }}>{d.controlStatus === 'MAITRISE' ? 'Maîtrisé' : d.controlStatus === 'PARTIELLEMENT_MAITRISE' ? 'Partiel' : 'Non maîtrisé'}</p>
        </div>
      </div>

      <div className="flex items-center justify-between mb-2">
        <p className="text-sm font-semibold" style={{ color: C.text }}>Mesures de prévention ({measures.length})</p>
        <button onClick={() => setShowAddMeasure((s) => !s)} className="text-xs px-2 py-1 rounded-lg" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Mesure</button>
      </div>
      {showAddMeasure && (
        <form onSubmit={addMeasure} className="p-3 rounded-lg mb-3" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}` }}>
          <FormField label="Description"><textarea required value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} rows={2} className="w-full px-3 py-2 rounded-lg text-sm outline-none resize-none" style={inputStyle(C)} /></FormField>
          <div className="grid grid-cols-2 gap-3">
            <FormField label="Type (hiérarchie de prévention)">
              <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>
                {RISK_MEASURE_TYPES.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
              </select>
            </FormField>
            <FormField label="Efficacité (1-5)"><select value={form.efficacite} onChange={(e) => setForm({ ...form, efficacite: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)}>{[1, 2, 3, 4, 5].map((n) => <option key={n} value={n}>{n}</option>)}</select></FormField>
          </div>
          <FormField label="Justificatif (optionnel)"><input value={form.justificatif} onChange={(e) => setForm({ ...form, justificatif: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          {error && <p className="text-xs mb-2" style={{ color: C.red }}>{error}</p>}
          <button type="submit" disabled={saving} className="w-full py-2 rounded-lg text-xs font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : 'Ajouter la mesure'}</button>
        </form>
      )}
      {measures.length
        ? <div className="space-y-2 mb-5">
            {measures.map((m) => (
              <div key={m.id} className="p-2.5 rounded-lg" style={{ backgroundColor: C.cardAlt, border: `1px solid ${C.border}` }}>
                <div className="flex items-start justify-between gap-2">
                  <p className="text-sm flex-1" style={{ color: C.text }}>{m.description}</p>
                  <button onClick={() => deleteMeasure(m.id)} className="text-xs" style={{ color: C.red }}>×</button>
                </div>
                <p className="text-[10px] mt-1" style={{ color: C.textMuted }}>{RISK_MEASURE_TYPES.find(([v]) => v === m.type)?.[1] || m.type} · Efficacité {m.efficacite}/5{m.responsable ? ` · ${m.responsable.firstName} ${m.responsable.lastName}` : ''}</p>
              </div>
            ))}
          </div>
        : <p className="text-sm text-center py-4 mb-5" style={{ color: C.textMuted }}>Aucune mesure de prévention enregistrée</p>}

      <p className="text-sm font-semibold mb-2" style={{ color: C.text }}>Historique des évaluations ({evaluations.length})</p>
      {evaluations.length > 1 && (
        <div className="mb-3">
          <ResponsiveContainer width="100%" height={160}>
            <LineChart data={evaluations.map((ev) => ({ date: new Date(ev.evaluatedAt).toLocaleDateString('fr-FR'), brut: ev.grossScore, residuel: ev.residualScore }))}>
              <CartesianGrid strokeDasharray="3 3" stroke={C.border} />
              <XAxis dataKey="date" tick={{ fontSize: 10, fill: C.textMuted }} />
              <YAxis tick={{ fontSize: 10, fill: C.textMuted }} />
              <Tooltip contentStyle={{ backgroundColor: C.card, border: `1px solid ${C.border}`, fontSize: 12 }} />
              <Line type="monotone" dataKey="brut" stroke={C.red} strokeWidth={2} dot />
              <Line type="monotone" dataKey="residuel" stroke={C.green} strokeWidth={2} dot />
            </LineChart>
          </ResponsiveContainer>
        </div>
      )}
      {evaluations.length
        ? <DataTable columns={['Date', 'Score brut', 'Niveau', 'Score résiduel', 'Note']}
            rows={evaluations.slice().reverse().map((ev) => [new Date(ev.evaluatedAt).toLocaleDateString('fr-FR'), ev.grossScore, ev.grossLevel, ev.residualScore ?? '—', ev.note || '—'])} />
        : <p className="text-sm text-center py-4" style={{ color: C.textMuted }}>Aucune évaluation enregistrée</p>}
    </Modal>
  );
}

function RiskCategoryForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ code: record?.code || '', label: record?.label || '', order: record?.order ?? 0 });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault();
    setSaving(true); setError(null);
    try {
      const payload = { ...form, order: Number(form.order) || 0 };
      if (editing) await api.patch(`/business/risk-categories/${record.id}`, payload);
      else await api.post('/business/risk-categories', payload);
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  async function del() {
    setSaving(true);
    try { await confirmAndDelete(record.label, `/business/risk-categories/${record.id}`, () => { onCreated(); onClose(); }); }
    catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? 'Modifier la catégorie' : 'Nouvelle catégorie de risque'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Code"><input required value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. MECANIQUE" /></FormField>
        <FormField label="Libellé"><input required value={form.label} onChange={(e) => setForm({ ...form, label: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Risque mécanique" /></FormField>
        <FormField label="Ordre d'affichage"><input type="number" value={form.order} onChange={(e) => setForm({ ...form, order: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <div className="flex gap-2">
          {editing && <button type="button" onClick={del} disabled={saving} className="px-4 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: `${C.red}22`, color: C.red }}>Supprimer</button>}
          <button type="submit" disabled={saving} className="flex-1 py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : 'Enregistrer'}</button>
        </div>
      </form>
    </Modal>
  );
}

function WorkUnitForm({ record, onClose, onCreated }) {
  const C = useTheme();
  const editing = !!record;
  const [form, setForm] = useState({ code: record?.code || '', name: record?.name || '', department: record?.department || '', service: record?.service || '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  async function submit(e) {
    e.preventDefault();
    setSaving(true); setError(null);
    try {
      if (editing) await api.patch(`/business/work-units/${record.id}`, form);
      else await api.post('/business/work-units', { ...form, code: form.code || genCode('WU') });
      onCreated(); onClose();
    } catch (err) { setError(err.message); }
    setSaving(false);
  }
  return (
    <Modal title={editing ? "Modifier l'unité de travail" : 'Nouvelle unité de travail'} onClose={onClose}>
      <form onSubmit={submit}>
        <FormField label="Nom"><input required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} placeholder="Ex. Ligne Bouteille" /></FormField>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Département"><input value={form.department} onChange={(e) => setForm({ ...form, department: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
          <FormField label="Service"><input value={form.service} onChange={(e) => setForm({ ...form, service: e.target.value })} className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle(C)} /></FormField>
        </div>
        {error && <p className="text-xs mb-3" style={{ color: C.red }}>{error}</p>}
        <button type="submit" disabled={saving} className="w-full py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: saving ? 0.7 : 1 }}>{saving ? 'Enregistrement…' : 'Enregistrer'}</button>
      </form>
    </Modal>
  );
}

function RisquesPage() {
  const C = useTheme();
  const risks = useCollection('/business/risks');
  const dashboardQ = useCollection('/business/risk-dashboard');
  const top10Q = useCollection('/business/risk-top10');
  const alertesQ = useCollection('/business/risk-alertes');
  const categoriesQ = useCollection('/business/risk-categories');
  const workUnitsQ = useCollection('/business/work-units');
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState(null);
  const [viewing, setViewing] = useState(null);
  const [showCategoryForm, setShowCategoryForm] = useState(false);
  const [selectedCategory, setSelectedCategory] = useState(null);
  const [showWorkUnitForm, setShowWorkUnitForm] = useState(false);
  const [tab, setTab] = useState('apercu');
  if (risks.loading || dashboardQ.loading) return <LoadingPanel />;
  if (risks.error) return <ErrorPanel message={risks.error} onRetry={risks.reload} />;
  const list = risks.data || [];
  const dash = dashboardQ.data || {};
  const top10 = top10Q.data || [];
  const alertes = alertesQ.data || [];
  const categories = categoriesQ.data || [];
  const workUnits = workUnitsQ.data || [];
  const niveauColor = { CRITIQUE: C.red, ELEVE: C.amber, MODERE: '#B45309', FAIBLE: C.green };
  const alerteColor = { CRITIQUE: C.red, URGENT: C.red, ATTENTION: C.amber };
  const dv = (v, suffix = '') => (v == null ? '—' : `${v}${suffix}`);
  const reloadAll = () => { risks.reload(); dashboardQ.reload(); top10Q.reload(); alertesQ.reload(); };
  // Hiérarchisation (point 12) — un risque a une action en retard s'il porte
  // au moins une action ouverte dont l'échéance est dépassée.
  const hasActionEnRetard = (r) => (r.actions || []).some((a) => a.dueDate && new Date(a.dueDate) < new Date() && a.status !== 'CLOSED');
  const priorites = [
    { id: 'CRITIQUE', label: 'Priorité immédiate — Risques critiques', color: C.red },
    { id: 'ELEVE', label: 'Priorité haute — Risques élevés', color: C.amber },
    { id: 'MODERE', label: 'Priorité moyenne — Risques modérés', color: '#B45309' },
    { id: 'FAIBLE', label: 'Surveillance — Risques faibles', color: C.green },
  ].map((p) => ({ ...p, risques: list.filter((r) => (r.grossLevel || 'FAIBLE') === p.id).sort((a, b) => (hasActionEnRetard(b) - hasActionEnRetard(a)) || (b.grossScore - a.grossScore)) }));

  return (
    <div className="space-y-6">
      {(showForm || editing) && <RiskForm record={editing} onClose={() => { setShowForm(false); setEditing(null); }} onCreated={reloadAll} />}
      {viewing && <RiskDetailModal risk={viewing} onClose={() => setViewing(null)} onChanged={reloadAll} onEdit={() => { setEditing(viewing); setViewing(null); }} />}
      {(showCategoryForm || selectedCategory) && <RiskCategoryForm record={selectedCategory} onClose={() => { setShowCategoryForm(false); setSelectedCategory(null); }} onCreated={categoriesQ.reload} />}
      {showWorkUnitForm && <WorkUnitForm onClose={() => setShowWorkUnitForm(false)} onCreated={workUnitsQ.reload} />}

      <div className="flex flex-wrap gap-2">
        {[['apercu', "Vue d'ensemble"], ['registre', 'Registre complet'], ['hierarchisation', 'Hiérarchisation'], ['cartographie', 'Cartographie'], ['top10', 'Top 10'], ['parametrage', 'Paramétrage']].map(([id, label]) => (
          <button key={id} onClick={() => setTab(id)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: tab === id ? C.blue : 'transparent', color: tab === id ? '#fff' : C.textMuted }}>{label}</button>
        ))}
      </div>

      {tab === 'apercu' && (
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <LiveBadge />
            <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouveau risque</button>
          </div>
          <div className="flex flex-wrap gap-3">
            <KpiCard label="Risques recensés" value={dv(dash.total)} color={C.blue} icon={AlertTriangle} />
            <KpiCard label="Critiques" value={dv(dash.critiques)} color={C.red} icon={AlertTriangle} />
            <KpiCard label="Élevés" value={dv(dash.eleves)} color={C.amber} icon={AlertTriangle} />
            <KpiCard label="Modérés" value={dv(dash.moderes)} color="#B45309" icon={AlertTriangle} />
            <KpiCard label="Faibles" value={dv(dash.faibles)} color={C.green} icon={ShieldCheck} />
            <KpiCard label="Non maîtrisés" value={dv(dash.nonMaitrises)} color={dash.nonMaitrises > 0 ? C.red : C.green} icon={AlertTriangle} />
            <KpiCard label="Avec action ouverte" value={dv(dash.avecActionsOuvertes)} color={C.blue} icon={ClipboardList} />
            <KpiCard label="Actions en retard" value={dv(dash.actionsEnRetard)} color={dash.actionsEnRetard > 0 ? C.red : C.green} icon={AlertTriangle} />
            <KpiCard label="À réévaluer" value={dv(dash.aReevaluer)} color={dash.aReevaluer > 0 ? C.amber : C.green} icon={RefreshCw} />
            <KpiCard label="Taux de maîtrise" value={dv(dash.tauxMaitrise, '%')} color={C.blue} icon={ShieldCheck} />
            <KpiCard label="Taux de mise à jour" value={dv(dash.tauxMiseAJour, '%')} color={C.blue} icon={Activity} />
            <KpiCard label="Taux de clôture des actions" value={dv(dash.tauxClotureActions, '%')} color={C.blue} icon={ClipboardList} />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <Panel title="Matrice de criticité 5×5 (gravité × probabilité)">
              {list.length ? <RiskMatrix5x5 risques={list.map((r) => ({ gravite: r.severity, probabilite: r.probability }))} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun risque enregistré</p>}
            </Panel>
            <Panel title="Alertes" subtitle={`${alertes.length} point(s) nécessitant attention`}>
              {alertes.length
                ? <div className="space-y-2 max-h-64 overflow-y-auto">{alertes.map((a, i) => (
                    <div key={i} className="flex items-center justify-between py-2" style={{ borderTop: `1px solid ${C.border}` }}>
                      <span className="text-sm" style={{ color: C.text }}>{a.label}</span>
                      <span className="text-[11px] px-2 py-1 rounded-full font-medium" style={{ backgroundColor: `${alerteColor[a.niveau]}22`, color: alerteColor[a.niveau] }}>{a.niveau}</span>
                    </div>
                  ))}</div>
                : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune alerte — tout est sous contrôle</p>}
            </Panel>
          </div>
        </div>
      )}

      {tab === 'registre' && (
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <LiveBadge />
            <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Nouveau risque</button>
          </div>
          <Panel title="Registre complet des risques">
            {list.length
              ? <DataTable columns={['Risque', 'Catégorie', 'Unité de travail', 'Score brut', 'Résiduel', 'Statut de maîtrise']}
                  rows={list.map((r) => [
                    r.hazard, r.category?.label || '—', r.workUnit?.name || '—',
                    <span style={{ color: niveauColor[r.grossLevel] || C.text, fontWeight: 600 }}>{r.grossScore ?? r.score} ({r.grossLevel || '—'})</span>,
                    r.residualScore != null ? <span style={{ color: niveauColor[r.residualLevel] || C.text, fontWeight: 600 }}>{r.residualScore} ({r.residualLevel})</span> : '—',
                    <StatusChip statut={r.controlStatus === 'MAITRISE' ? 'Conforme' : r.controlStatus === 'PARTIELLEMENT_MAITRISE' ? 'Sous surveillance' : 'Non conforme'} />,
                  ])}
                  onRowClick={(i) => setViewing(list[i])} />
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun risque enregistré pour le moment</p>}
          </Panel>
        </div>
      )}

      {tab === 'hierarchisation' && (
        <div className="space-y-6">
          <LiveBadge />
          {priorites.map((p) => (
            <Panel key={p.id} title={`${p.label} (${p.risques.length})`}>
              {p.risques.length
                ? <div className="space-y-2">
                    {p.risques.map((r) => (
                      <div key={r.id} onClick={() => setViewing(r)} className="flex items-center justify-between py-2 px-2 rounded-lg cursor-pointer" style={{ borderLeft: `3px solid ${p.color}`, backgroundColor: C.cardAlt }}>
                        <div>
                          <p className="text-sm font-medium" style={{ color: C.text }}>{r.hazard}</p>
                          <p className="text-[11px]" style={{ color: C.textMuted }}>{r.workUnit?.name || 'Sans unité'} · {(r.actions || []).length} action(s){hasActionEnRetard(r) ? ' · action en retard' : ''}</p>
                        </div>
                        <span className="text-sm font-bold" style={{ color: p.color }}>{r.grossScore ?? r.score}</span>
                      </div>
                    ))}
                  </div>
                : <p className="text-sm text-center py-4" style={{ color: C.textMuted }}>Aucun risque dans cette catégorie</p>}
            </Panel>
          ))}
        </div>
      )}

      {tab === 'cartographie' && (
        <div className="space-y-6">
          <LiveBadge />
          <div className="grid grid-cols-2 gap-4">
            <Panel title="Répartition par catégorie">
              {list.length ? <DonutChart data={groupCount(list, (r) => r.category?.label)} colors={[C.blue, C.green, C.amber, C.red, '#8B5CF6', '#EC4899', '#14B8A6']} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun risque enregistré</p>}
            </Panel>
            <Panel title="Répartition par niveau de criticité">
              {list.length ? <DonutChart data={groupCount(list, (r) => r.grossLevel)} colors={[C.red, C.amber, '#B45309', C.green]} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun risque enregistré</p>}
            </Panel>
          </div>
          <Panel title="Répartition par unité de travail">
            {list.length ? <HorizontalBars data={groupCount(list, (r) => r.workUnit?.name)} labelKey="name" valueKey="value" color={C.blue} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun risque enregistré</p>}
          </Panel>
          <Panel title="Pareto des risques (par score brut)">
            {list.length ? <ParetoChart causes={list.map((r) => ({ cause: r.hazard, occurrences: r.grossScore ?? r.score ?? 0 }))} /> : <p className="text-sm text-center py-8" style={{ color: C.textMuted }}>Aucun risque enregistré</p>}
          </Panel>
        </div>
      )}

      {tab === 'top10' && (
        <div className="space-y-6">
          <LiveBadge />
          <Panel title="Top 10 des risques les plus critiques">
            {top10.length
              ? <DataTable columns={['Rang', 'Risque', 'Unité de travail', 'Catégorie', 'Score', 'Actions']}
                  rows={top10.map((r, i) => [
                    i + 1, r.hazard, r.workUnit?.name || '—', r.category?.label || '—',
                    <span style={{ color: niveauColor[r.grossLevel] || C.text, fontWeight: 600 }}>{r.grossScore}</span>,
                    (r.actions || []).length ? `${r.actions.length} action(s)` : 'Aucune',
                  ])}
                  onRowClick={(i) => setViewing(top10[i])} />
              : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucun risque enregistré</p>}
          </Panel>
        </div>
      )}

      {tab === 'parametrage' && (
        <div className="space-y-6">
          <div className="grid grid-cols-2 gap-4">
            <Panel title="Catégories de risques" right={<button onClick={() => setShowCategoryForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Ajouter</button>}>
              {categories.length
                ? <DataTable columns={['Code', 'Libellé']} rows={categories.map((c) => [c.code, c.label])} onRowClick={(i) => setSelectedCategory(categories[i])} />
                : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune catégorie définie — la liste reste entièrement libre</p>}
            </Panel>
            <Panel title="Unités de travail" right={<button onClick={() => setShowWorkUnitForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Ajouter</button>}>
              {workUnits.length
                ? <DataTable columns={['Nom', 'Département', 'Service']} rows={workUnits.map((w) => [w.name, w.department || '—', w.service || '—'])} />
                : <p className="text-sm text-center py-6" style={{ color: C.textMuted }}>Aucune unité de travail définie</p>}
            </Panel>
          </div>
        </div>
      )}
    </div>
  );
}

function AuditsPage() {
  const C = useTheme();
  const audits = useCollection('/business/audits');
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState(null);
  const [viewing, setViewing] = useState(null);
  if (audits.loading) return <LoadingPanel />;
  if (audits.error) return <ErrorPanel message={audits.error} onRetry={audits.reload} />;
  const list = audits.data || [];
  const planifies = list.filter((a) => a.status === 'PLANNED').length;
  const scores = list.filter((a) => a.score != null);
  const sorted = [...list].sort((a, b) => new Date(b.auditDate) - new Date(a.auditDate));
  const ncGenerees = list.reduce((s, a) => s + (a.auditFindings || []).filter((f) => f.nonConformityId).length, 0);

  return (
    <div className="space-y-6">
      {(showForm || editing) && <AuditForm record={editing} onClose={() => { setShowForm(false); setEditing(null); }} onCreated={audits.reload} />}
      {viewing && <AuditDetailModal audit={viewing} onClose={() => setViewing(null)} onChanged={audits.reload} onEdit={() => { setEditing(viewing); setViewing(null); }} />}
      <div className="flex items-center justify-between">
        <LiveBadge />
        <button onClick={() => setShowForm(true)} className="px-3 py-1.5 rounded-lg text-xs font-medium" style={{ backgroundColor: C.green, color: '#052e1f' }}>+ Planifier un audit</button>
      </div>
      <div className="flex flex-wrap gap-3">
        <KpiCard label="Audits au programme" value={list.length} color={C.blue} icon={ClipboardCheck} />
        <KpiCard label="Planifiés" value={planifies} color={C.amber} icon={Activity} />
        <KpiCard label="Réalisés / en cours" value={list.length - planifies} color={C.green} icon={ShieldCheck} />
        <KpiCard label="Score moyen" value={scores.length ? `${Math.round(scores.reduce((s, a) => s + a.score, 0) / scores.length)}%` : '—'} color={C.blue} icon={ClipboardList} />
        <KpiCard label="NC générées depuis des constats" value={ncGenerees} color={ncGenerees > 0 ? C.red : C.green} icon={FileWarning} />
      </div>
      <p className="text-xs" style={{ color: C.textMuted }}>Cliquez une ligne pour consulter et gérer ses constats.</p>
      <Panel title="Programme d'audits">
        {sorted.length
          ? <DataTable columns={['Titre', 'Référence', 'Date', 'Statut', 'Score', 'Constats']} rows={sorted.map((a) => [a.title, a.reference || '—', new Date(a.auditDate).toLocaleDateString('fr-FR'), <StatusChip statut={a.status} />, a.score != null ? `${a.score}%` : '—', (a.auditFindings || []).length])}
              onRowClick={(i) => setViewing(sorted[i])} />
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
      {viewing && <DocumentViewerModal doc={viewing} onClose={() => setViewing(null)} onNewVersion={() => { setAddingVersionTo(viewing); setViewing(null); }} onDeleted={docs.reload} onChanged={docs.reload} />}
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
  const assignmentsQ = useCollection('/epi/assignments');
  const employeesQ = useCollection('/epi/employees');
  const epcListQ = useCollection('/epi/epc');
  const renewalBucketsQ = useCollection('/epi/renewal-buckets');
  const qualityControlsQ = useCollection('/quality/controls');
  const processusQ = useCollection('/business/processus');
  const indicateursAutoCompareQ = useCollection('/business/indicateurs-auto-compare');
  const indicateursQualiteQ = useCollection('/business/indicateurs-qualite');
  const indiceGlobalQ = useCollection('/business/indice-global-qualite');
  const reclamationsQ = useCollection('/business/reclamations');
  const reclamationsStatsQ = useCollection('/business/reclamations-stats');
  const reclamationsScoreQ = useCollection('/business/reclamations-score');
  const safetyEventsStatsQ = useCollection('/business/safety-events-stats');
  const safetyEventsRecidivesQ = useCollection('/business/safety-events-recidives');
  const fournisseursQ = useCollection('/business/fournisseurs');
  const fournisseursClassementQ = useCollection('/business/fournisseurs-classement');
  const fournisseursAlertesQ = useCollection('/business/fournisseurs-alertes');
  const fournisseursMatriceRisqueQ = useCollection('/business/fournisseurs-matrice-risque');
  const visitesMedicalesQ = useCollection('/business/visites-medicales');
  const risquesSanitairesQ = useCollection('/business/risques-sanitaires');
  const analysesErgonomiquesQ = useCollection('/business/analyses-ergonomiques');
  const tmsSignalementsQ = useCollection('/business/tms-signalements');
  const hygieneIndiceGlobalQ = useCollection('/business/hygiene-indice-global');
  const hygieneAlertesQ = useCollection('/business/hygiene-alertes');
  const loading = [dashboardQ, auditsQ, risksQ, actionsQ, environmentQ, safetyEventsQ, epiQ, assignmentsQ, employeesQ, epcListQ, renewalBucketsQ, qualityControlsQ, processusQ, indicateursAutoCompareQ, indicateursQualiteQ, indiceGlobalQ, reclamationsQ, reclamationsStatsQ, reclamationsScoreQ, safetyEventsStatsQ, safetyEventsRecidivesQ, fournisseursQ, fournisseursClassementQ, fournisseursAlertesQ, fournisseursMatriceRisqueQ, visitesMedicalesQ, risquesSanitairesQ, analysesErgonomiquesQ, tmsSignalementsQ, hygieneIndiceGlobalQ, hygieneAlertesQ].some((q) => q.loading);

  if (loading) return <LoadingPanel />;

  const reports = reportDefinitions({
    dashboardData: dashboardQ.data, audits: auditsQ.data, risks: risksQ.data, actions: actionsQ.data,
    environment: environmentQ.data, safetyEvents: safetyEventsQ.data, epi: epiQ.data,
    assignments: assignmentsQ.data, employees: employeesQ.data, epcList: epcListQ.data, renewalBuckets: renewalBucketsQ.data,
    qualityControls: qualityControlsQ.data, processus: processusQ.data,
    indicateursAutoCompare: indicateursAutoCompareQ.data, indicateursQualite: indicateursQualiteQ.data, indiceGlobal: indiceGlobalQ.data,
    reclamations: reclamationsQ.data, reclamationsStats: reclamationsStatsQ.data, reclamationsScore: reclamationsScoreQ.data,
    safetyEventsStats: safetyEventsStatsQ.data, safetyEventsRecidives: safetyEventsRecidivesQ.data,
    fournisseurs: fournisseursQ.data, fournisseursClassement: fournisseursClassementQ.data, fournisseursAlertes: fournisseursAlertesQ.data, fournisseursMatriceRisque: fournisseursMatriceRisqueQ.data,
    visitesMedicales: visitesMedicalesQ.data, risquesSanitaires: risquesSanitairesQ.data, analysesErgonomiques: analysesErgonomiquesQ.data, tmsSignalements: tmsSignalementsQ.data,
    hygieneIndiceGlobal: hygieneIndiceGlobalQ.data, hygieneAlertes: hygieneAlertesQ.data,
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
