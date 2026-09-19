-- Objectifs QHSE — Phase 1 : fondations, classification SMART, cibles,
-- KPI (manuels ou auto-alimentes), actions/risques lies, commentaires,
-- revues et checklist de recette CA-01..CA-49.

ALTER TABLE "ObjectifQhse"
  ADD COLUMN "description" TEXT,
  ADD COLUMN "famille" TEXT NOT NULL DEFAULT 'TRANSVERSAL',
  ADD COLUMN "classification" TEXT,
  ADD COLUMN "categorie" TEXT,
  ADD COLUMN "activiteConcernee" TEXT,
  ADD COLUMN "zone" TEXT,
  ADD COLUMN "dateReference" TIMESTAMP(3),
  ADD COLUMN "seuilMin" DOUBLE PRECISION,
  ADD COLUMN "seuilMax" DOUBLE PRECISION,
  ADD COLUMN "frequenceMesure" TEXT,
  ADD COLUMN "dateDebut" TIMESTAMP(3),
  ADD COLUMN "contributeurIds" TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN "valideurId" TEXT,
  ADD COLUMN "directionResponsable" TEXT,
  ADD COLUMN "priorite" TEXT,
  ADD COLUMN "importanceStrategique" TEXT,
  ADD COLUMN "statutManuel" TEXT,
  ADD COLUMN "annee" INTEGER,
  ADD COLUMN "dupliqueDeId" TEXT,
  ADD COLUMN "archivedAt" TIMESTAMP(3),
  ADD COLUMN "createdById" TEXT,
  ADD COLUMN "updatedById" TEXT,
  ADD COLUMN "siteId" TEXT,
  ADD COLUMN "workUnitId" TEXT;

ALTER TABLE "ObjectifQhse" ADD CONSTRAINT "ObjectifQhse_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "Site"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "ObjectifQhse" ADD CONSTRAINT "ObjectifQhse_workUnitId_fkey" FOREIGN KEY ("workUnitId") REFERENCES "WorkUnit"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "Action" ADD COLUMN "objectifQhseId" TEXT;
ALTER TABLE "Action" ADD CONSTRAINT "Action_objectifQhseId_fkey" FOREIGN KEY ("objectifQhseId") REFERENCES "ObjectifQhse"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "ObjectifKpi" (
  "id" TEXT NOT NULL,
  "objectifId" TEXT NOT NULL,
  "nom" TEXT NOT NULL,
  "definition" TEXT,
  "formule" TEXT,
  "unite" TEXT,
  "frequence" TEXT,
  "sourceType" TEXT NOT NULL DEFAULT 'MANUEL',
  "sourceKey" TEXT,
  "sourceModule" TEXT,
  "responsableId" TEXT,
  "valeurInitiale" DOUBLE PRECISION,
  "cible" DOUBLE PRECISION,
  "valeurActuelle" DOUBLE PRECISION,
  "sensInverse" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "ObjectifKpi_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "ObjectifKpi" ADD CONSTRAINT "ObjectifKpi_objectifId_fkey" FOREIGN KEY ("objectifId") REFERENCES "ObjectifQhse"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "ObjectifRisk" (
  "id" TEXT NOT NULL,
  "objectifId" TEXT NOT NULL,
  "riskId" TEXT NOT NULL,
  "type" TEXT NOT NULL DEFAULT 'RISQUE',
  "niveauRisque" TEXT,
  "mesuresMaitrise" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ObjectifRisk_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "ObjectifRisk" ADD CONSTRAINT "ObjectifRisk_objectifId_fkey" FOREIGN KEY ("objectifId") REFERENCES "ObjectifQhse"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ObjectifRisk" ADD CONSTRAINT "ObjectifRisk_riskId_fkey" FOREIGN KEY ("riskId") REFERENCES "Risk"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ObjectifRisk" ADD CONSTRAINT "ObjectifRisk_objectifId_riskId_key" UNIQUE ("objectifId", "riskId");

CREATE TABLE "ObjectifComment" (
  "id" TEXT NOT NULL,
  "objectifId" TEXT NOT NULL,
  "type" TEXT NOT NULL DEFAULT 'SUIVI',
  "contenu" TEXT NOT NULL,
  "auteurId" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ObjectifComment_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "ObjectifComment" ADD CONSTRAINT "ObjectifComment_objectifId_fkey" FOREIGN KEY ("objectifId") REFERENCES "ObjectifQhse"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "ObjectifReview" (
  "id" TEXT NOT NULL,
  "objectifId" TEXT NOT NULL,
  "periodicite" TEXT,
  "dateRevue" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "resultats" TEXT,
  "ecarts" TEXT,
  "analyseCauses" TEXT,
  "decision" TEXT,
  "nouvelleCible" DOUBLE PRECISION,
  "actionsProposees" TEXT,
  "commentaire" TEXT,
  "createdById" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ObjectifReview_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "ObjectifReview" ADD CONSTRAINT "ObjectifReview_objectifId_fkey" FOREIGN KEY ("objectifId") REFERENCES "ObjectifQhse"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "ObjectifRecetteCriterion" (
  "id" TEXT NOT NULL,
  "code" TEXT NOT NULL,
  "categorie" TEXT,
  "libelle" TEXT NOT NULL,
  "statut" TEXT NOT NULL DEFAULT 'NON_TESTE',
  "dateTest" TIMESTAMP(3),
  "testeurId" TEXT,
  "commentaire" TEXT,
  "anomalie" TEXT,
  "dateCorrection" TIMESTAMP(3),
  "resultatRetest" TEXT,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "ObjectifRecetteCriterion_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "ObjectifRecetteCriterion" ADD CONSTRAINT "ObjectifRecetteCriterion_code_key" UNIQUE ("code");

-- Seed des 49 criteres d'acceptation du cahier des charges (section 32).
INSERT INTO "ObjectifRecetteCriterion" ("id","code","categorie","libelle","statut","updatedAt") VALUES
('objrec-ca01','CA-01','Creation','Creation minimale : champs obligatoires verifies (intitule, pilier, responsable, valeur de reference, cible, unite, dates)','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca02','CA-02','Creation','Enregistrement valide avec identifiant unique, date de creation, createur, statut initial','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca03','CA-03','SMART','Controle SMART : objectif sans cible mesurable signale comme a ameliorer','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca04','CA-04','Piliers','Selection du pilier parmi Qualite/Hygiene/Securite/Environnement/Transversal','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca05','CA-05','KPI','Creation d''un KPI associe a un objectif (nom, unite, valeurs, frequence, sens)','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca06','CA-06','KPI','Mise a jour du KPI : avancement recalcule automatiquement (ex. 50%)','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca07','CA-07','KPI','Objectif "plus est mieux" : avancement correctement calcule','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca08','CA-08','KPI','Objectif "moins est mieux" : avancement correctement calcule','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca09','CA-09','KPI','Depassement de cible : calcul borne, objectif reconnu atteint','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca10','CA-10','Dates','Date cible anterieure a la date de debut : enregistrement refuse','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca11','CA-11','Dates','Objectif a echeance depassee et cible non atteinte classe "En retard"','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca12','CA-12','Dates','Alerte generee quand la date cible approche (delai configurable)','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca13','CA-13','Statut','Statut initial "Non demarre" a la creation','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca14','CA-14','Statut','Statut "En cours" quand progression enregistree mais cible non atteinte','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca15','CA-15','Statut','Statut "Atteint" visible fiche/tableau/KPI tableau de bord','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca16','CA-16','Statut','Statut "A risque" avec cause/signal affiche quand disponible','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca17','CA-17','Actions','Creation d''une action depuis un objectif, visible objectif + Actions CAPA','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca18','CA-18','Actions','Liaison d''une action CAPA existante sans doublon','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca19','CA-19','Actions','Action liee cloturee : fiche objectif mise a jour automatiquement','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca20','CA-20','Liaisons','Accident enregistre -> KPI objectif Securite actualise','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca21','CA-21','Liaisons','NC creee -> KPI objectif Qualite actualise si configure','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca22','CA-22','Liaisons','Reclamation -> KPI Nombre de reclamations actualise','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca23','CA-23','Liaisons','Modification niveau de risque -> KPI associe actualise si configure','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca24','CA-24','Dashboard','Compteur Total objectifs correct selon filtres appliques','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca25','CA-25','Dashboard','Compteur Objectifs atteints correct','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca26','CA-26','Dashboard','Compteur Objectifs en retard calcule automatiquement','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca27','CA-27','Dashboard','Taux global d''atteinte calcule selon formule documentee','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca28','CA-28','Filtres','Filtre par pilier (ex. Securite) recalcule aussi les KPI du dashboard','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca29','CA-29','Filtres','Filtre par responsable fonctionnel','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca30','CA-30','Filtres','Filtre par periode fonctionnel','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca31','CA-31','Recherche','Recherche par mot-cle insensible a la casse','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca32','CA-32','Permissions','Administrateur : acces complet (creer/modifier/archiver/consulter/configurer)','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca33','CA-33','Permissions','Responsable QHSE : creation/modification/suivi/actions/revues/rapports','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca34','CA-34','Permissions','Utilisateur sans droit : consultation seule, boutons masques, API bloquee','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca35','CA-35','Tracabilite','Modification d''un objectif historisee (ancienne/nouvelle valeur, utilisateur, date)','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca36','CA-36','Tracabilite','Suppression definitive interdite si KPI/actions/revues/historique lies -> archivage','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca37','CA-37','Revues','Creation d''une revue (date/resultat/ecart/cause/decision/actions/commentaire)','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca38','CA-38','Revues','Historique des revues conserve dans l''ordre chronologique, jamais ecrase','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca39','CA-39','Alertes','Alerte d''echeance generee selon le delai configure','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca40','CA-40','Alertes','Action en retard signalee (fiche objectif, dashboard, Actions CAPA)','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca41','CA-41','Rapport','Generation PDF du rapport des objectifs QHSE','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca42','CA-42','Rapport','Export Excel respectant les filtres actifs','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca43','CA-43','Coherence','Modification visible sur tous les ecrans apres synchronisation','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca44','CA-44','Coherence','Mode hors connexion : creation/modification locale puis synchronisation sans duplication','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca45','CA-45','Coherence','Conflit de synchronisation gere selon regle definie, tracabilite conservee','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca46','CA-46','Performance','Chargement exploitable avec volume important (pagination/recherche serveur)','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca47','CA-47','Performance','Mise a jour d''un KPI sans recalcul inutile de toute la base','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca48','CA-48','Securite','Autorisation backend verifiee, requete API refusee sans droit','NON_TESTE',CURRENT_TIMESTAMP),
('objrec-ca49','CA-49','Securite','Isolation des donnees par perimetre (site/entite) pour utilisateur multi-sites','NON_TESTE',CURRENT_TIMESTAMP);
