-- Additif uniquement : crée un type enum et ajoute une colonne NULLABLE.
-- Aucune table existante n'est modifiée en profondeur, aucune ligne n'est
-- supprimée. Les documents déjà en base gardent toutes leurs données ;
-- documentGroup vaudra simplement NULL jusqu'à la reclassification.
CREATE TYPE "DocumentGroup" AS ENUM (
  'STRATEGIE_CONTEXTE',
  'RISQUES_SECURITE_CONFORMITE',
  'SUPPORTS_MAITRISE_DOCUMENTAIRE',
  'OPERATIONS_MAITRISE_TERRAIN',
  'EVALUATION_CONTROLE_AMELIORATION'
);

ALTER TABLE "Document" ADD COLUMN "documentGroup" "DocumentGroup";
