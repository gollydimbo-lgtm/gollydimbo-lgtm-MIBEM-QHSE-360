import { IsBoolean,IsDateString,IsInt,IsNumber,IsOptional,IsString } from 'class-validator';

// DTOs du module Actions CAPA (finding #2). Champs volontairement absents :
// id/createdAt/updatedAt (système), completedAt/dateValidation/dateCloture
// (posés par les endpoints dédiés close/soumettre/approuver-validation),
// effectivenessResult/effectivenessCheckedAt/effectivenessNotes (endpoint
// dédié /effectiveness), reopenedCount (endpoint dédié /reopen),
// archivedAt (jamais de suppression définitive — géré par actionDelete),
// validationStatus/validationDemandeeParId/validationDemandeeLe/
// valideParId/valideLe/commentaireValidation (workflow de validation
// multi-niveaux, endpoints dédiés).
export class CreateActionDto {
  @IsString() code!: string;
  @IsString() title!: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsInt() priority?: number;
  @IsOptional() @IsDateString() dueDate?: string;
  @IsOptional() @IsString() responsibleId?: string;
  @IsOptional() @IsString() nonConformityId?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() reclamationId?: string;
  @IsOptional() @IsString() fournisseurId?: string;
  @IsOptional() @IsString() safetyEventId?: string;
  @IsOptional() @IsString() risqueSanitaireId?: string;
  @IsOptional() @IsString() ergonomieId?: string;
  @IsOptional() @IsString() environnementAspectId?: string;
  @IsOptional() @IsString() riskId?: string;
  @IsOptional() @IsString() auditFindingId?: string;
  @IsOptional() @IsString() equipmentId?: string;
  @IsOptional() @IsString() regulatoryRequirementId?: string;
  @IsOptional() @IsString() objectifQhseId?: string;
  @IsOptional() @IsString() trainingId?: string;
  @IsOptional() @IsString() actionType?: string;
  @IsOptional() @IsString() criticite?: string;
  @IsOptional() @IsString() source?: string;
  @IsOptional() @IsString() workUnitId?: string;
  @IsOptional() @IsString() parentActionId?: string;
  @IsOptional() @IsInt() avancement?: number;
  @IsOptional() @IsDateString() dateDebutPrevue?: string;
  @IsOptional() @IsDateString() dateDebutReelle?: string;
}
export class UpdateActionDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() title?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsInt() priority?: number;
  @IsOptional() @IsDateString() dueDate?: string;
  @IsOptional() @IsString() responsibleId?: string;
  @IsOptional() @IsString() nonConformityId?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() reclamationId?: string;
  @IsOptional() @IsString() fournisseurId?: string;
  @IsOptional() @IsString() safetyEventId?: string;
  @IsOptional() @IsString() risqueSanitaireId?: string;
  @IsOptional() @IsString() ergonomieId?: string;
  @IsOptional() @IsString() environnementAspectId?: string;
  @IsOptional() @IsString() riskId?: string;
  @IsOptional() @IsString() auditFindingId?: string;
  @IsOptional() @IsString() equipmentId?: string;
  @IsOptional() @IsString() regulatoryRequirementId?: string;
  @IsOptional() @IsString() objectifQhseId?: string;
  @IsOptional() @IsString() trainingId?: string;
  @IsOptional() @IsString() actionType?: string;
  @IsOptional() @IsString() criticite?: string;
  @IsOptional() @IsString() source?: string;
  @IsOptional() @IsString() workUnitId?: string;
  @IsOptional() @IsString() parentActionId?: string;
  @IsOptional() @IsInt() avancement?: number;
  @IsOptional() @IsDateString() dateDebutPrevue?: string;
  @IsOptional() @IsDateString() dateDebutReelle?: string;
}

export class CreateActionCauseDto {
  @IsString() actionId!: string;
  @IsString() methode!: string;
  @IsOptional() @IsString() niveau?: string;
  @IsOptional() @IsString() categorie?: string;
  @IsString() description!: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsBoolean() estRacine?: boolean;
}
export class UpdateActionCauseDto {
  @IsOptional() @IsString() methode?: string;
  @IsOptional() @IsString() niveau?: string;
  @IsOptional() @IsString() categorie?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsBoolean() estRacine?: boolean;
}

// actionId vient du :id de l'URL, jamais du corps — absent du DTO.
export class CreateActionExtensionDto {
  @IsOptional() @IsDateString() ancienneEcheance?: string;
  @IsDateString() nouvelleEcheance!: string;
  @IsString() motif!: string;
  @IsOptional() @IsString() demandeurId?: string;
  @IsOptional() @IsString() validateurId?: string;
}
