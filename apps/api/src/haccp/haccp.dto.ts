import { IsBoolean,IsDateString,IsInt,IsNumber,IsOptional,IsString } from 'class-validator';

// DTOs du module HACCP (finding #2). Champs volontairement absents partout :
// id/createdAt/updatedAt (système).
export class CreateHaccpStudyDto {
  @IsString() code!: string;
  @IsString() name!: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() activite?: string;
  @IsOptional() @IsString() atelier?: string;
  @IsOptional() @IsString() ligne?: string;
  @IsOptional() @IsString() produit?: string;
  @IsOptional() @IsString() categorieProduit?: string;
  @IsOptional() @IsString() descriptionProduit?: string;
  @IsOptional() @IsString() destination?: string;
  @IsOptional() @IsString() consommateurCible?: string;
  @IsOptional() @IsString() conditionsStockage?: string;
  @IsOptional() @IsString() dureeConservation?: string;
  @IsOptional() @IsString() modeDistribution?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() version?: string;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsDateString() prochaineRevision?: string;
}
// dateValidation exclu : posé uniquement par studyValidate().
// dateDerniereRevision exclue : posée uniquement par studyRevise().
export class UpdateHaccpStudyDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() activite?: string;
  @IsOptional() @IsString() atelier?: string;
  @IsOptional() @IsString() ligne?: string;
  @IsOptional() @IsString() produit?: string;
  @IsOptional() @IsString() categorieProduit?: string;
  @IsOptional() @IsString() descriptionProduit?: string;
  @IsOptional() @IsString() destination?: string;
  @IsOptional() @IsString() consommateurCible?: string;
  @IsOptional() @IsString() conditionsStockage?: string;
  @IsOptional() @IsString() dureeConservation?: string;
  @IsOptional() @IsString() modeDistribution?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() version?: string;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsDateString() prochaineRevision?: string;
}

// studyId vient du :id de l'URL, jamais du corps — absent du DTO.
export class AddHaccpTeamMemberDto {
  @IsOptional() @IsString() employeeId?: string;
  @IsOptional() @IsString() userId?: string;
  @IsOptional() @IsString() fonction?: string;
  @IsOptional() @IsString() service?: string;
  @IsOptional() @IsString() competence?: string;
  @IsOptional() @IsBoolean() formationHaccp?: boolean;
  @IsOptional() @IsDateString() dateFormation?: string;
  @IsOptional() @IsString() experience?: string;
  @IsOptional() @IsString() roleEtude?: string;
  @IsOptional() @IsString() responsabilites?: string;
  @IsOptional() @IsString() statut?: string;
}

// studyId vient du :id de l'URL, jamais du corps — absent du DTO.
export class CreateHaccpProcessStepDto {
  @IsInt() numero!: number;
  @IsString() nom!: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() zone?: string;
  @IsOptional() @IsString() equipement?: string;
  @IsOptional() @IsString() matiereEntrante?: string;
  @IsOptional() @IsString() matiereSortante?: string;
  @IsOptional() @IsString() parametresControles?: string;
  @IsOptional() @IsInt() ordre?: number;
}
export class UpdateHaccpProcessStepDto {
  @IsOptional() @IsInt() numero?: number;
  @IsOptional() @IsString() nom?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() zone?: string;
  @IsOptional() @IsString() equipement?: string;
  @IsOptional() @IsString() matiereEntrante?: string;
  @IsOptional() @IsString() matiereSortante?: string;
  @IsOptional() @IsString() parametresControles?: string;
  @IsOptional() @IsInt() ordre?: number;
}

// stepId (et studyId, dérivé de l'étape) viennent du :stepId de l'URL,
// jamais du corps. niveauRisque exclu : recalculé par calculerNiveauRisque()
// à partir de gravite/probabilite à chaque écriture.
export class CreateHaccpHazardDto {
  @IsString() type!: string;
  @IsString() libelle!: string;
  @IsOptional() @IsString() origine?: string;
  @IsOptional() @IsInt() gravite?: number;
  @IsOptional() @IsInt() probabilite?: number;
  @IsOptional() @IsInt() niveauMaitrise?: number;
  @IsOptional() @IsString() justification?: string;
  @IsOptional() @IsString() mesuresExistantes?: string;
  @IsOptional() @IsString() mesuresSupplementaires?: string;
}
export class UpdateHaccpHazardDto {
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() libelle?: string;
  @IsOptional() @IsString() origine?: string;
  @IsOptional() @IsInt() gravite?: number;
  @IsOptional() @IsInt() probabilite?: number;
  @IsOptional() @IsInt() niveauMaitrise?: number;
  @IsOptional() @IsString() justification?: string;
  @IsOptional() @IsString() mesuresExistantes?: string;
  @IsOptional() @IsString() mesuresSupplementaires?: string;
}

// hazardId (et studyId/stepId, dérivés du danger) viennent du :hazardId de
// l'URL. reference exclue : générée par genererReference(), jamais
// modifiable après coup (déjà protégé côté service pour l'update, le DTO
// formalise la même règle pour la création).
export class CreateHaccpCcpDto {
  @IsOptional() @IsString() type?: string;
  @IsOptional() arbreDecisionReponses?: unknown;
  @IsOptional() @IsString() dangerMaitrise?: string;
  @IsOptional() @IsString() causeDanger?: string;
  @IsOptional() @IsString() mesureMaitrise?: string;
  @IsOptional() @IsString() limiteCritique?: string;
  @IsOptional() @IsString() critereAcceptation?: string;
  @IsOptional() @IsString() parametre?: string;
  @IsOptional() @IsString() unite?: string;
  @IsOptional() @IsString() methode?: string;
  @IsOptional() @IsString() instrument?: string;
  @IsOptional() @IsString() frequence?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() enregistrementAssocie?: string;
  @IsOptional() @IsString() actionImmediate?: string;
  @IsOptional() @IsBoolean() active?: boolean;
}
export class UpdateHaccpCcpDto {
  @IsOptional() arbreDecisionReponses?: unknown;
  @IsOptional() @IsString() dangerMaitrise?: string;
  @IsOptional() @IsString() causeDanger?: string;
  @IsOptional() @IsString() mesureMaitrise?: string;
  @IsOptional() @IsString() limiteCritique?: string;
  @IsOptional() @IsString() critereAcceptation?: string;
  @IsOptional() @IsString() parametre?: string;
  @IsOptional() @IsString() unite?: string;
  @IsOptional() @IsString() methode?: string;
  @IsOptional() @IsString() instrument?: string;
  @IsOptional() @IsString() frequence?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() enregistrementAssocie?: string;
  @IsOptional() @IsString() actionImmediate?: string;
  @IsOptional() @IsBoolean() active?: boolean;
}

// ccpId (et studyId, dérivé du CCP) viennent du :ccpId de l'URL.
// nonConformityId exclu : posé uniquement par declencherNonConformite()
// quand un relevé est hors limite — jamais par le client.
export class CreateHaccpMonitoringRecordDto {
  @IsOptional() @IsDateString() datePrevue?: string;
  @IsOptional() @IsDateString() dateRealisee?: string;
  @IsOptional() @IsNumber() valeur?: number;
  @IsOptional() @IsString() valeurTexte?: string;
  @IsOptional() @IsBoolean() conforme?: boolean;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() lotNumero?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() commentaire?: string;
  @IsOptional() @IsString() photoUrl?: string;
  @IsOptional() @IsString() signature?: string;
}
export class UpdateHaccpMonitoringRecordDto {
  @IsOptional() @IsDateString() datePrevue?: string;
  @IsOptional() @IsDateString() dateRealisee?: string;
  @IsOptional() @IsNumber() valeur?: number;
  @IsOptional() @IsString() valeurTexte?: string;
  @IsOptional() @IsBoolean() conforme?: boolean;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() lotNumero?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() commentaire?: string;
  @IsOptional() @IsString() photoUrl?: string;
  @IsOptional() @IsString() signature?: string;
}

export class CreateHaccpPrpDto {
  @IsOptional() @IsString() studyId?: string;
  @IsString() type!: string;
  @IsString() libelle!: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() frequence?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsBoolean() active?: boolean;
}
export class UpdateHaccpPrpDto {
  @IsOptional() @IsString() studyId?: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() libelle?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() frequence?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsBoolean() active?: boolean;
}
