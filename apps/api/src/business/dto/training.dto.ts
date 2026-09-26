import { IsBoolean,IsDateString,IsInt,IsNumber,IsOptional,IsString } from 'class-validator';

// DTOs du module Formation (finding #2). Champs volontairement absents :
// id/createdAt/updatedAt (système).
export class CreateTrainingDto {
  @IsString() code!: string;
  @IsString() title!: string;
  @IsOptional() @IsString() trainer?: string;
  @IsDateString() scheduledAt!: string;
  @IsOptional() @IsNumber() durationHours?: number;
  @IsOptional() @IsString() status?: string;
  @IsOptional() participants?: unknown;
  @IsOptional() @IsDateString() expiryAt?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() categoryId?: string;
  @IsOptional() @IsBoolean() obligatoire?: boolean;
  @IsOptional() @IsString() domaine?: string;
  @IsOptional() @IsString() publicCible?: string;
  @IsOptional() @IsString() objectif?: string;
  @IsOptional() @IsString() organisme?: string;
  @IsOptional() @IsString() interneExterne?: string;
  @IsOptional() @IsString() referenceReglementaire?: string;
  @IsOptional() @IsString() competenceVisee?: string;
  @IsOptional() @IsNumber() coutPrevu?: number;
  @IsOptional() @IsNumber() coutReel?: number;
  @IsOptional() @IsNumber() budgetAlloue?: number;
  @IsOptional() @IsString() priorite?: string;
  @IsOptional() @IsString() motifBesoin?: string;
  @IsOptional() @IsInt() periodiciteMois?: number;
  @IsOptional() @IsBoolean() recyclageNecessaire?: boolean;
  @IsOptional() @IsString() service?: string;
  @IsOptional() @IsString() evaluationType?: string;
  @IsOptional() @IsInt() delaiEvaluationEfficaciteJours?: number;
}
export class UpdateTrainingDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() title?: string;
  @IsOptional() @IsString() trainer?: string;
  @IsOptional() @IsDateString() scheduledAt?: string;
  @IsOptional() @IsNumber() durationHours?: number;
  @IsOptional() @IsString() status?: string;
  @IsOptional() participants?: unknown;
  @IsOptional() @IsDateString() expiryAt?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() categoryId?: string;
  @IsOptional() @IsBoolean() obligatoire?: boolean;
  @IsOptional() @IsString() domaine?: string;
  @IsOptional() @IsString() publicCible?: string;
  @IsOptional() @IsString() objectif?: string;
  @IsOptional() @IsString() organisme?: string;
  @IsOptional() @IsString() interneExterne?: string;
  @IsOptional() @IsString() referenceReglementaire?: string;
  @IsOptional() @IsString() competenceVisee?: string;
  @IsOptional() @IsNumber() coutPrevu?: number;
  @IsOptional() @IsNumber() coutReel?: number;
  @IsOptional() @IsNumber() budgetAlloue?: number;
  @IsOptional() @IsString() priorite?: string;
  @IsOptional() @IsString() motifBesoin?: string;
  @IsOptional() @IsInt() periodiciteMois?: number;
  @IsOptional() @IsBoolean() recyclageNecessaire?: boolean;
  @IsOptional() @IsString() service?: string;
  @IsOptional() @IsString() evaluationType?: string;
  @IsOptional() @IsInt() delaiEvaluationEfficaciteJours?: number;
}

export class CreateTrainingCategoryDto {
  @IsString() code!: string;
  @IsString() label!: string;
  @IsOptional() @IsString() groupe?: string;
  @IsOptional() @IsInt() order?: number;
  @IsOptional() @IsBoolean() active?: boolean;
}
export class UpdateTrainingCategoryDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() label?: string;
  @IsOptional() @IsString() groupe?: string;
  @IsOptional() @IsInt() order?: number;
  @IsOptional() @IsBoolean() active?: boolean;
}

// Singleton — pas de création exposée, seulement une mise à jour.
export class UpdateTrainingSettingsDto {
  @IsOptional() @IsBoolean() alerteJ90?: boolean;
  @IsOptional() @IsBoolean() alerteJ60?: boolean;
  @IsOptional() @IsBoolean() alerteJ30?: boolean;
  @IsOptional() @IsBoolean() alerteJ15?: boolean;
  @IsOptional() @IsNumber() ponderationScoreGlobal?: number;
}

// statut est conservé : lu tel quel par habilitationStatutCalcule (cas
// SUSPENDUE/EN_ATTENTE), puis toujours réécrit par le calcul serveur avant
// persistance — jamais falsifiable par le client, mais l'entrée reste utile.
export class CreateHabilitationDto {
  @IsString() code!: string;
  @IsString() employeeId!: string;
  @IsOptional() @IsString() categoryId?: string;
  @IsString() intitule!: string;
  @IsOptional() @IsString() organisme?: string;
  @IsOptional() @IsString() numeroDocument?: string;
  @IsOptional() @IsDateString() dateObtention?: string;
  @IsOptional() @IsDateString() dateExpiration?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() trainingId?: string;
  @IsOptional() @IsString() notes?: string;
}
export class UpdateHabilitationDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() categoryId?: string;
  @IsOptional() @IsString() intitule?: string;
  @IsOptional() @IsString() organisme?: string;
  @IsOptional() @IsString() numeroDocument?: string;
  @IsOptional() @IsDateString() dateObtention?: string;
  @IsOptional() @IsDateString() dateExpiration?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() trainingId?: string;
  @IsOptional() @IsString() notes?: string;
}

export class CreateHabilitationCategoryDto {
  @IsString() code!: string;
  @IsString() label!: string;
  @IsOptional() @IsInt() dureeValiditeMois?: number;
  @IsOptional() @IsInt() order?: number;
  @IsOptional() @IsBoolean() active?: boolean;
}
export class UpdateHabilitationCategoryDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() label?: string;
  @IsOptional() @IsInt() dureeValiditeMois?: number;
  @IsOptional() @IsInt() order?: number;
  @IsOptional() @IsBoolean() active?: boolean;
}

export class CreateCompetenceNiveauDto {
  @IsString() code!: string;
  @IsString() label!: string;
  @IsInt() ordre!: number;
  @IsOptional() @IsBoolean() active?: boolean;
}
export class UpdateCompetenceNiveauDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() label?: string;
  @IsOptional() @IsInt() ordre?: number;
  @IsOptional() @IsBoolean() active?: boolean;
}

export class CreateCompetenceDto {
  @IsString() code!: string;
  @IsString() label!: string;
  @IsOptional() @IsString() domaine?: string;
  @IsOptional() @IsInt() order?: number;
  @IsOptional() @IsBoolean() active?: boolean;
}
export class UpdateCompetenceDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() label?: string;
  @IsOptional() @IsString() domaine?: string;
  @IsOptional() @IsInt() order?: number;
  @IsOptional() @IsBoolean() active?: boolean;
}

// employeeCompetenceUpsert faisait un passthrough total {...b} SANS MÊME
// stripSystemFields — le pire cas rencontré dans ce chantier avant
// correction. employeeId/competenceId servent de clé d'upsert (requis).
export class UpsertEmployeeCompetenceDto {
  @IsString() employeeId!: string;
  @IsString() competenceId!: string;
  @IsOptional() @IsString() poste?: string;
  @IsOptional() @IsString() niveauRequisId?: string;
  @IsOptional() @IsString() niveauActuelId?: string;
  @IsOptional() @IsDateString() dateEvaluation?: string;
  @IsOptional() @IsString() formationAssocieeId?: string;
  @IsOptional() @IsString() habilitationAssocieeId?: string;
  @IsOptional() @IsString() notes?: string;
}

// besoinFormationUpdate faisait aussi un passthrough total {...b} sans
// aucun filtrage. Champs volontairement absents : id/createdAt/updatedAt,
// sourceModule/sourceKey/sourceEntityId (posés uniquement par le moteur de
// détection detecterBesoinsFormation), trainingId (posé uniquement par
// besoinFormationTransformer), traiteLe (recalculé serveur quand le statut
// passe à VALIDE/REJETE), traiteParId (jamais alimenté par aucune méthode
// métier actuelle — absent par prudence).
export class UpdateBesoinFormationDto {
  @IsOptional() @IsString() titre?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() competenceVisee?: string;
  @IsOptional() @IsString() employeeId?: string;
  @IsOptional() @IsString() posteConcerne?: string;
  @IsOptional() @IsString() priorite?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() motif?: string;
}

// besoinGenereId absent : posé uniquement par la logique serveur
// (formation jugée inefficace -> proposition automatique de besoin).
export class CreateTrainingEfficaciteEvaluationDto {
  @IsString() trainingId!: string;
  @IsOptional() @IsString() employeeId?: string;
  @IsInt() delaiJours!: number;
  @IsOptional() @IsDateString() dateEvaluation?: string;
  @IsOptional() @IsString() niveauEfficacite?: string;
  @IsOptional() @IsBoolean() applicationConnaissances?: boolean;
  @IsOptional() @IsBoolean() respectProcedures?: boolean;
  @IsOptional() @IsBoolean() changementComportement?: boolean;
  @IsOptional() @IsBoolean() autonomie?: boolean;
  @IsOptional() @IsBoolean() reductionErreurs?: boolean;
  @IsOptional() @IsBoolean() reductionNc?: boolean;
  @IsOptional() @IsBoolean() reductionIncidents?: boolean;
  @IsOptional() @IsString() commentaire?: string;
  @IsOptional() @IsString() evaluateurId?: string;
}
export class UpdateTrainingEfficaciteEvaluationDto {
  @IsOptional() @IsString() employeeId?: string;
  @IsOptional() @IsInt() delaiJours?: number;
  @IsOptional() @IsDateString() dateEvaluation?: string;
  @IsOptional() @IsString() niveauEfficacite?: string;
  @IsOptional() @IsBoolean() applicationConnaissances?: boolean;
  @IsOptional() @IsBoolean() respectProcedures?: boolean;
  @IsOptional() @IsBoolean() changementComportement?: boolean;
  @IsOptional() @IsBoolean() autonomie?: boolean;
  @IsOptional() @IsBoolean() reductionErreurs?: boolean;
  @IsOptional() @IsBoolean() reductionNc?: boolean;
  @IsOptional() @IsBoolean() reductionIncidents?: boolean;
  @IsOptional() @IsString() commentaire?: string;
  @IsOptional() @IsString() evaluateurId?: string;
}
