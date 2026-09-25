import { IsBoolean,IsDateString,IsNumber,IsOptional,IsString } from 'class-validator';

// DTOs du module Audits (finding #2). Champs volontairement absents :
// id/createdAt (système), archivedAt (jamais de suppression définitive —
// géré par auditDelete), score/scoreMax/scoreObtenu/scorePondere/
// tauxConformite (recalculés uniquement par le moteur de notation de la
// check-list — recalculerScoreAudit/auditResponseSave — jamais lus depuis
// le corps d'une requête de création/modification directe de l'audit,
// contrairement à NC/Risque il n'existait ici AUCUN recalcul qui les
// aurait de toute façon écrasés : un client pouvait donc falsifier
// directement le score d'un audit avant ce correctif).
export class CreateAuditDto {
  @IsString() code!: string;
  @IsString() title!: string;
  @IsDateString() auditDate!: string;
  @IsOptional() @IsString() reference?: string;
  @IsOptional() @IsString() auditorId?: string;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() fournisseurId?: string;
  @IsOptional() @IsString() typeId?: string;
  @IsOptional() @IsString() referentialId?: string;
  @IsOptional() @IsString() workUnitId?: string;
  @IsOptional() @IsString() responsableAuditeId?: string;
  @IsOptional() @IsString() scope?: string;
  @IsOptional() @IsString() objectif?: string;
  @IsOptional() auditTeamIds?: unknown;
  @IsOptional() @IsNumber() dureePrevueHeures?: number;
  @IsOptional() @IsString() priorite?: string;
  @IsOptional() @IsString() checklistId?: string;
  @IsOptional() @IsString() scoringMethod?: string;
  @IsOptional() findings?: unknown;
}
export class UpdateAuditDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() title?: string;
  @IsOptional() @IsDateString() auditDate?: string;
  @IsOptional() @IsString() reference?: string;
  @IsOptional() @IsString() auditorId?: string;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() fournisseurId?: string;
  @IsOptional() @IsString() typeId?: string;
  @IsOptional() @IsString() referentialId?: string;
  @IsOptional() @IsString() workUnitId?: string;
  @IsOptional() @IsString() responsableAuditeId?: string;
  @IsOptional() @IsString() scope?: string;
  @IsOptional() @IsString() objectif?: string;
  @IsOptional() auditTeamIds?: unknown;
  @IsOptional() @IsNumber() dureePrevueHeures?: number;
  @IsOptional() @IsString() priorite?: string;
  @IsOptional() @IsString() checklistId?: string;
  @IsOptional() @IsString() scoringMethod?: string;
  @IsOptional() findings?: unknown;
}

// auditId vient du :id de l'URL, jamais du corps — absent du DTO.
export class CreateAuditFindingDto {
  @IsString() description!: string;
  @IsOptional() @IsString() classification?: string;
  @IsOptional() @IsString() criticite?: string;
  @IsOptional() @IsBoolean() critical?: boolean;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsString() nonConformityId?: string;
  @IsOptional() @IsString() riskId?: string;
  @IsOptional() @IsString() checklistItemId?: string;
  @IsOptional() @IsString() preuveObjective?: string;
  @IsOptional() @IsString() zone?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsDateString() delai?: string;
}
export class UpdateAuditFindingDto {
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() classification?: string;
  @IsOptional() @IsString() criticite?: string;
  @IsOptional() @IsBoolean() critical?: boolean;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsString() nonConformityId?: string;
  @IsOptional() @IsString() riskId?: string;
  @IsOptional() @IsString() checklistItemId?: string;
  @IsOptional() @IsString() preuveObjective?: string;
  @IsOptional() @IsString() zone?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsDateString() delai?: string;
}
