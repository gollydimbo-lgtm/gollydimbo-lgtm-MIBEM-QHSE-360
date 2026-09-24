-- Finding #38 — référentiel réglementaire paramétrable par pays/secteur,
-- première brique (table de paramétrage, seedée avec les valeurs MIBEM
-- actuelles comme défauts pour ne rien casser).
CREATE TABLE "OrganisationSettings" (
    "id" TEXT NOT NULL,
    "pays" TEXT NOT NULL DEFAULT 'Côte d''Ivoire',
    "secteurActivite" TEXT NOT NULL DEFAULT 'Agroalimentaire',
    "normesApplicables" TEXT[] NOT NULL DEFAULT ARRAY['ISO 9001', 'ISO 14001', 'ISO 45001']::TEXT[],
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "OrganisationSettings_pkey" PRIMARY KEY ("id")
);
