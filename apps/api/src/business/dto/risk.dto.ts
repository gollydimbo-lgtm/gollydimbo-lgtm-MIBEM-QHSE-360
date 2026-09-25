import { IsDateString,IsInt,IsNumber,IsOptional,IsString } from 'class-validator';

// DTOs du module Risques (finding #2). Champs volontairement absents :
// id/createdAt/updatedAt (système), score/grossScore/grossLevel/
// residualScore/residualLevel/controlStatus/nextReviewDate/method (tous
// recalculés par calculerRisque à partir des champs bruts ci-dessous,
// jamais lus tels quels depuis le corps de la requête), archivedAt (jamais
// de suppression définitive — géré par riskDelete), validationStatus/
// validationDemandeeParId/validationDemandeeLe/valideParId/valideLe/
// commentaireValidation (workflow de validation multi-niveaux, endpoints
// dédiés). evaluatedById et method/residual* sont conservés : lus tels
// quels par calculerRisque/riskCreate pour l'évaluation initiale.
export class CreateRiskDto {
  @IsString() code!: string;
  @IsString() hazard!: string;
  @IsInt() severity!: number;
  @IsInt() probability!: number;
  @IsOptional() @IsString() activity?: string;
  @IsOptional() @IsInt() control?: number;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsString() measures?: string;
  @IsOptional() @IsDateString() reviewedAt?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() fournisseurId?: string;
  @IsOptional() @IsString() workUnitId?: string;
  @IsOptional() @IsString() categoryId?: string;
  @IsOptional() @IsString() hazardousSituation?: string;
  @IsOptional() @IsString() hazardousEvent?: string;
  @IsOptional() @IsString() potentialDamage?: string;
  @IsOptional() @IsString() exposedPersons?: string;
  @IsOptional() @IsInt() exposedPersonCount?: number;
  @IsOptional() @IsString() method?: string;
  @IsOptional() @IsInt() exposure?: number;
  @IsOptional() @IsInt() residualSeverity?: number;
  @IsOptional() @IsInt() residualProbability?: number;
  @IsOptional() @IsInt() residualExposure?: number;
  @IsOptional() @IsString() equipmentId?: string;
  @IsOptional() @IsInt() reviewPeriodDays?: number;
  @IsOptional() @IsString() evaluatedById?: string;
}
export class UpdateRiskDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() hazard?: string;
  @IsOptional() @IsInt() severity?: number;
  @IsOptional() @IsInt() probability?: number;
  @IsOptional() @IsString() activity?: string;
  @IsOptional() @IsInt() control?: number;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsString() measures?: string;
  @IsOptional() @IsDateString() reviewedAt?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() fournisseurId?: string;
  @IsOptional() @IsString() workUnitId?: string;
  @IsOptional() @IsString() categoryId?: string;
  @IsOptional() @IsString() hazardousSituation?: string;
  @IsOptional() @IsString() hazardousEvent?: string;
  @IsOptional() @IsString() potentialDamage?: string;
  @IsOptional() @IsString() exposedPersons?: string;
  @IsOptional() @IsInt() exposedPersonCount?: number;
  @IsOptional() @IsString() method?: string;
  @IsOptional() @IsInt() exposure?: number;
  @IsOptional() @IsInt() residualSeverity?: number;
  @IsOptional() @IsInt() residualProbability?: number;
  @IsOptional() @IsInt() residualExposure?: number;
  @IsOptional() @IsString() equipmentId?: string;
  @IsOptional() @IsInt() reviewPeriodDays?: number;
}

export class CreateRiskMeasureDto {
  @IsString() riskId!: string;
  @IsString() description!: string;
  @IsString() type!: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsDateString() datePrise?: string;
  @IsOptional() @IsInt() efficacite?: number;
  @IsOptional() @IsString() justificatif?: string;
  @IsOptional() @IsString() epiId?: string;
  @IsOptional() @IsString() trainingId?: string;
}
export class UpdateRiskMeasureDto {
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsDateString() datePrise?: string;
  @IsOptional() @IsInt() efficacite?: number;
  @IsOptional() @IsString() justificatif?: string;
  @IsOptional() @IsString() epiId?: string;
  @IsOptional() @IsString() trainingId?: string;
}
