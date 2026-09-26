import { IsBoolean,IsDateString,IsInt,IsOptional,IsString } from 'class-validator';

// DTOs du module Fournisseurs (finding #2). fournisseurCreate/Update et
// fournisseurCertificationCreate/Update faisaient un passthrough brut
// stripSystemFields(b), sans aucun recalcul serveur : un client pouvait
// falsifier directement les scores par domaine (scoreQualite, etc.).
// Champs volontairement absents : id/createdAt/updatedAt (système).
// Les scores par domaine sont conservés (aucun recalcul serveur identifié
// pour ce module — saisis manuellement par l'évaluateur, comme documenté
// dans le schéma : "le score global se calcule à partir de ceux-ci").
export class CreateFournisseurDto {
  @IsString() code!: string;
  @IsString() nom!: string;
  @IsOptional() @IsString() nomCommercial?: string;
  @IsOptional() @IsString() typeFournisseur?: string;
  @IsOptional() @IsString() categorie?: string;
  @IsOptional() @IsString() familleAchat?: string;
  @IsOptional() @IsString() produitsServices?: string;
  @IsOptional() @IsString() adresse?: string;
  @IsOptional() @IsString() pays?: string;
  @IsOptional() @IsString() region?: string;
  @IsOptional() @IsString() ville?: string;
  @IsOptional() @IsString() contactNom?: string;
  @IsOptional() @IsString() contactTelephone?: string;
  @IsOptional() @IsString() contactEmail?: string;
  @IsOptional() @IsString() siteWeb?: string;
  @IsOptional() @IsString() responsableInterneId?: string;
  @IsOptional() @IsDateString() dateDebutRelation?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() niveauRisque?: string;
  @IsOptional() @IsBoolean() criticite?: boolean;
  @IsOptional() @IsString() capaciteTechnique?: string;
  @IsOptional() @IsString() capaciteCommerciale?: string;
  @IsOptional() @IsString() situationFinanciere?: string;
  @IsOptional() @IsDateString() dateHomologation?: string;
  @IsOptional() @IsDateString() dateProchaineReevaluation?: string;
  @IsOptional() @IsString() motifDemande?: string;
  @IsOptional() @IsString() avisQhse?: string;
  @IsOptional() @IsString() avisAchats?: string;
  @IsOptional() @IsString() avisTechnique?: string;
  @IsOptional() @IsString() decisionFinale?: string;
  @IsOptional() @IsString() conditionsParticulieres?: string;
  @IsOptional() @IsBoolean() monoSource?: boolean;
  @IsOptional() @IsBoolean() solutionSecours?: boolean;
  @IsOptional() @IsInt() delaiRemplacementJours?: number;
  @IsOptional() @IsString() planContinuite?: string;
  @IsOptional() @IsInt() scoreQualite?: number;
  @IsOptional() @IsInt() scoreLivraison?: number;
  @IsOptional() @IsInt() scoreQhse?: number;
  @IsOptional() @IsInt() scoreCommercial?: number;
  @IsOptional() @IsInt() scoreReactivite?: number;
  @IsOptional() @IsInt() scoreEnvironnemental?: number;
  @IsOptional() @IsInt() scoreSecurite?: number;
  @IsOptional() @IsDateString() derniereEvaluation?: string;
}
export class UpdateFournisseurDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() nom?: string;
  @IsOptional() @IsString() nomCommercial?: string;
  @IsOptional() @IsString() typeFournisseur?: string;
  @IsOptional() @IsString() categorie?: string;
  @IsOptional() @IsString() familleAchat?: string;
  @IsOptional() @IsString() produitsServices?: string;
  @IsOptional() @IsString() adresse?: string;
  @IsOptional() @IsString() pays?: string;
  @IsOptional() @IsString() region?: string;
  @IsOptional() @IsString() ville?: string;
  @IsOptional() @IsString() contactNom?: string;
  @IsOptional() @IsString() contactTelephone?: string;
  @IsOptional() @IsString() contactEmail?: string;
  @IsOptional() @IsString() siteWeb?: string;
  @IsOptional() @IsString() responsableInterneId?: string;
  @IsOptional() @IsDateString() dateDebutRelation?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() niveauRisque?: string;
  @IsOptional() @IsBoolean() criticite?: boolean;
  @IsOptional() @IsString() capaciteTechnique?: string;
  @IsOptional() @IsString() capaciteCommerciale?: string;
  @IsOptional() @IsString() situationFinanciere?: string;
  @IsOptional() @IsDateString() dateHomologation?: string;
  @IsOptional() @IsDateString() dateProchaineReevaluation?: string;
  @IsOptional() @IsString() motifDemande?: string;
  @IsOptional() @IsString() avisQhse?: string;
  @IsOptional() @IsString() avisAchats?: string;
  @IsOptional() @IsString() avisTechnique?: string;
  @IsOptional() @IsString() decisionFinale?: string;
  @IsOptional() @IsString() conditionsParticulieres?: string;
  @IsOptional() @IsBoolean() monoSource?: boolean;
  @IsOptional() @IsBoolean() solutionSecours?: boolean;
  @IsOptional() @IsInt() delaiRemplacementJours?: number;
  @IsOptional() @IsString() planContinuite?: string;
  @IsOptional() @IsInt() scoreQualite?: number;
  @IsOptional() @IsInt() scoreLivraison?: number;
  @IsOptional() @IsInt() scoreQhse?: number;
  @IsOptional() @IsInt() scoreCommercial?: number;
  @IsOptional() @IsInt() scoreReactivite?: number;
  @IsOptional() @IsInt() scoreEnvironnemental?: number;
  @IsOptional() @IsInt() scoreSecurite?: number;
  @IsOptional() @IsDateString() derniereEvaluation?: string;
}

export class CreateFournisseurCertificationDto {
  @IsString() fournisseurId!: string;
  @IsString() type!: string;
  @IsOptional() @IsString() numero?: string;
  @IsOptional() @IsString() organismeCertificateur?: string;
  @IsOptional() @IsDateString() dateEmission?: string;
  @IsOptional() @IsDateString() dateExpiration?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() commentaire?: string;
}
export class UpdateFournisseurCertificationDto {
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() numero?: string;
  @IsOptional() @IsString() organismeCertificateur?: string;
  @IsOptional() @IsDateString() dateEmission?: string;
  @IsOptional() @IsDateString() dateExpiration?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() commentaire?: string;
}
