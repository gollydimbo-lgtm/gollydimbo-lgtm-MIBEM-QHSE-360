import { IsArray, IsBoolean, IsDateString, IsIn, IsInt, IsOptional, IsString } from 'class-validator';

// DTOs du module Veille réglementaire (finding #2) — catalogue simple
// (VeilleReglementaire) + sous-système "fondations et chaîne centrale"
// (RegulatoryDomain/Settings/Text/Requirement/Evaluation/Evidence,
// RegulatoryRiskReevaluationRequest). Champs système toujours exclus :
// id/createdAt/updatedAt/archivedAt.

export class CreateVeilleDto {
  @IsString() code!: string;
  @IsString() texte!: string;
  @IsOptional() @IsString() domaine?: string;
  @IsOptional() @IsDateString() dateApplication?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() responsableId?: string;
}
export class UpdateVeilleDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() texte?: string;
  @IsOptional() @IsString() domaine?: string;
  @IsOptional() @IsDateString() dateApplication?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() responsableId?: string;
}

export class CreateRegulatoryDomainDto {
  @IsString() code!: string;
  @IsString() label!: string;
  @IsOptional() @IsBoolean() actif?: boolean;
  @IsOptional() @IsInt() order?: number;
}
export class UpdateRegulatoryDomainDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() label?: string;
  @IsOptional() @IsBoolean() actif?: boolean;
  @IsOptional() @IsInt() order?: number;
}

export class UpdateRegulatorySettingsDto {
  @IsOptional() @IsBoolean() alerteJ90?: boolean;
  @IsOptional() @IsBoolean() alerteJ60?: boolean;
  @IsOptional() @IsBoolean() alerteJ30?: boolean;
  @IsOptional() @IsBoolean() alerteJ15?: boolean;
  @IsOptional() @IsBoolean() alerteJ7?: boolean;
  @IsOptional() @IsString() methodeCalculTaux?: string;
}

export class UpdateOrganisationSettingsDto {
  @IsOptional() @IsString() pays?: string;
  @IsOptional() @IsString() secteurActivite?: string;
  @IsOptional() @IsArray() @IsString({ each: true }) normesApplicables?: string[];
}

export class CreateRegulatoryTextDto {
  @IsString() code!: string;
  @IsOptional() @IsString() reference?: string;
  @IsString() titre!: string;
  @IsOptional() @IsString() typeTexte?: string;
  @IsOptional() @IsString() domainId?: string;
  @IsOptional() @IsString() sousDomaine?: string;
  @IsOptional() @IsString() pays?: string;
  @IsOptional() @IsString() autoriteEmettrice?: string;
  @IsOptional() @IsDateString() datePublication?: string;
  @IsOptional() @IsDateString() dateEntreeVigueur?: string;
  @IsOptional() @IsDateString() dateDerniereModification?: string;
  @IsOptional() @IsDateString() dateAbrogation?: string;
  @IsOptional() @IsString() version?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() sourceOfficielle?: string;
  @IsOptional() @IsString() lienSource?: string;
  @IsOptional() @IsString() resume?: string;
  @IsOptional() @IsString() objet?: string;
  @IsOptional() @IsString() articlesApplicables?: string;
  @IsOptional() @IsString() entreprisesConcernees?: string;
  @IsOptional() @IsString() sitesConcernes?: string;
  @IsOptional() @IsString() activitesConcernees?: string;
  @IsOptional() @IsDateString() derniereVerificationSource?: string;
  @IsOptional() @IsString() verifieParId?: string;
}
export class UpdateRegulatoryTextDto {
  @IsOptional() @IsString() reference?: string;
  @IsOptional() @IsString() titre?: string;
  @IsOptional() @IsString() typeTexte?: string;
  @IsOptional() @IsString() domainId?: string;
  @IsOptional() @IsString() sousDomaine?: string;
  @IsOptional() @IsString() pays?: string;
  @IsOptional() @IsString() autoriteEmettrice?: string;
  @IsOptional() @IsDateString() datePublication?: string;
  @IsOptional() @IsDateString() dateEntreeVigueur?: string;
  @IsOptional() @IsDateString() dateDerniereModification?: string;
  @IsOptional() @IsDateString() dateAbrogation?: string;
  @IsOptional() @IsString() version?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() sourceOfficielle?: string;
  @IsOptional() @IsString() lienSource?: string;
  @IsOptional() @IsString() resume?: string;
  @IsOptional() @IsString() objet?: string;
  @IsOptional() @IsString() articlesApplicables?: string;
  @IsOptional() @IsString() entreprisesConcernees?: string;
  @IsOptional() @IsString() sitesConcernes?: string;
  @IsOptional() @IsString() activitesConcernees?: string;
  @IsOptional() @IsDateString() derniereVerificationSource?: string;
  @IsOptional() @IsString() verifieParId?: string;
}

// Champs exclus (faille de mass assignment réelle corrigée) :
// - statutConformite, dateDerniereEvaluation, dateProchaineEvaluation,
//   statutFile : recalculés exclusivement par regulatoryEvaluationCreate()
//   à chaque évaluation ; via le endpoint générique create/update
//   (stripSystemFields uniquement, sans allow-list) un client pouvait les
//   falsifier directement, par exemple déclarer une exigence CONFORME sans
//   qu'aucune évaluation n'ait jamais été enregistrée.
// - applicabilite, justificatifApplicabilite : ne doivent transiter que par
//   regulatoryRequirementSetApplicabilite(), qui impose une justification
//   obligatoire pour NON/PARTIELLEMENT ; le endpoint générique laissait
//   contourner cette validation métier.
export class CreateRegulatoryRequirementDto {
  @IsString() code!: string;
  @IsString() textId!: string;
  @IsString() libelle!: string;
  @IsOptional() @IsString() domainId?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() workUnitId?: string;
  @IsOptional() @IsString() preuveAttendue?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsInt() frequenceEvaluationMois?: number;
  @IsOptional() @IsString() criticite?: string;
  @IsOptional() @IsString() commentaire?: string;
}
export class UpdateRegulatoryRequirementDto {
  @IsOptional() @IsString() libelle?: string;
  @IsOptional() @IsString() domainId?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() workUnitId?: string;
  @IsOptional() @IsString() preuveAttendue?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsInt() frequenceEvaluationMois?: number;
  @IsOptional() @IsString() criticite?: string;
  @IsOptional() @IsString() commentaire?: string;
}

export class SetApplicabiliteDto {
  @IsIn(['OUI', 'NON', 'PARTIELLEMENT', 'A_ANALYSER']) applicabilite!: string;
  @IsOptional() @IsString() justificatif?: string;
}

export class CreateRegulatoryEvaluationDto {
  @IsString() statut!: string;
  @IsOptional() @IsString() constat?: string;
  @IsOptional() @IsString() preuveExaminee?: string;
  @IsOptional() @IsString() observation?: string;
  @IsOptional() @IsString() personneInterrogee?: string;
  @IsOptional() @IsDateString() dateControle?: string;
  @IsOptional() @IsString() evaluateurId?: string;
  @IsOptional() @IsString() criticite?: string;
  @IsOptional() @IsString() commentaire?: string;
}

// statut exclu : recalculé à la LECTURE par regulatoryDecorateEvidences()
// depuis dateExpiration, jamais utilisé en écriture (stocker une valeur
// client ici n'aurait aucun effet réel mais entretient la confusion).
export class CreateRegulatoryEvidenceDto {
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() documentId?: string;
  @IsOptional() @IsString() nom?: string;
  @IsOptional() @IsDateString() dateEmission?: string;
  @IsOptional() @IsDateString() dateExpiration?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() commentaire?: string;
}
export class UpdateRegulatoryEvidenceDto {
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() documentId?: string;
  @IsOptional() @IsString() nom?: string;
  @IsOptional() @IsDateString() dateEmission?: string;
  @IsOptional() @IsDateString() dateExpiration?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() commentaire?: string;
}

export class CreateRiskReevaluationRequestDto {
  @IsString() riskId!: string;
  @IsOptional() @IsString() raison?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsDateString() dateLimite?: string;
}
export class UpdateRiskReevaluationRequestDto {
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() raison?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsDateString() dateLimite?: string;
}
