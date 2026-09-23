-- Point 35 — témoins d'un événement sécurité, distincts de la personne
-- concernée (employeeId). Simple tableau d'identifiants Employee, sans
-- table de jointure ni contrainte de clé étrangère.
ALTER TABLE "SafetyEvent" ADD COLUMN "temoinIds" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
