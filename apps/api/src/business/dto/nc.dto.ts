import { IsArray,IsBoolean,IsDateString,IsIn,IsInt,IsNumber,IsOptional,IsString } from 'class-validator';

// DTOs du module Non-conformités (finding #2 de l'audit — mass assignment).
// Champs volontairement absents (donc retirés automatiquement par
// ValidationPipe({whitelist:true}) quel que soit ce qu'envoie le client) :
// id/createdAt (système), criticiteScore/criticiteNiveau/tauxNc (recalculés
// par calculerCriticiteNc, jamais lus depuis le corps de la requête),
// closedAt/reopenedCount/causeRacineIdentifiee/effectivenessResult/
// effectivenessCheckedAt/effectivenessNotes (workflow de clôture dédié),
// validationStatus/validationDemandeeParId/validationDemandeeLe/
// valideParId/valideLe/commentaireValidation (workflow de validation
// multi-niveaux, endpoints dédiés soumettre/approuver/rejeter),
// haccpMonitoringRecordId/regulatoryRequirementId (liens auto posés par
// HACCP/Veille réglementaire, jamais par une création manuelle),
// archivedAt (archivage géré par ncDelete lui-même).
export class CreateNcDto {
  @IsString() code!: string;
  @IsString() title!: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsInt() severity?: number;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsString() source?: string;
  @IsOptional() @IsString() classification?: string;
  @IsOptional() @IsDateString() occurredAt?: string;
  @IsOptional() @IsString() qualityControlId?: string;
  @IsOptional() @IsString() epiId?: string;
  @IsOptional() @IsString() epcId?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() fournisseurId?: string;
  @IsOptional() @IsString() riskId?: string;
  @IsOptional() @IsString() equipmentId?: string;
  @IsOptional() @IsString() workUnitId?: string;
  @IsOptional() @IsString() declarantId?: string;
  @IsOptional() @IsString() responsibleId?: string;
  @IsOptional() @IsInt() gravite?: number;
  @IsOptional() @IsInt() probabilite?: number;
  @IsOptional() @IsInt() etendue?: number;
  @IsOptional() @IsNumber() quantiteNc?: number;
  @IsOptional() @IsNumber() quantiteControlee?: number;
  @IsOptional() @IsNumber() quantiteBloquee?: number;
  @IsOptional() @IsNumber() quantiteLiberee?: number;
  @IsOptional() @IsNumber() quantiteDetruite?: number;
  @IsOptional() @IsNumber() quantiteReparee?: number;
  @IsOptional() @IsDateString() dueDate?: string;
}

export class UpdateNcDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() title?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsInt() severity?: number;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsString() source?: string;
  @IsOptional() @IsString() classification?: string;
  @IsOptional() @IsDateString() occurredAt?: string;
  @IsOptional() @IsString() qualityControlId?: string;
  @IsOptional() @IsString() epiId?: string;
  @IsOptional() @IsString() epcId?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() fournisseurId?: string;
  @IsOptional() @IsString() riskId?: string;
  @IsOptional() @IsString() equipmentId?: string;
  @IsOptional() @IsString() workUnitId?: string;
  @IsOptional() @IsString() declarantId?: string;
  @IsOptional() @IsString() responsibleId?: string;
  @IsOptional() @IsInt() gravite?: number;
  @IsOptional() @IsInt() probabilite?: number;
  @IsOptional() @IsInt() etendue?: number;
  @IsOptional() @IsNumber() quantiteNc?: number;
  @IsOptional() @IsNumber() quantiteControlee?: number;
  @IsOptional() @IsNumber() quantiteBloquee?: number;
  @IsOptional() @IsNumber() quantiteLiberee?: number;
  @IsOptional() @IsNumber() quantiteDetruite?: number;
  @IsOptional() @IsNumber() quantiteReparee?: number;
  @IsOptional() @IsDateString() dueDate?: string;
}

export class CreateNcContainmentActionDto {
  @IsString() nonConformityId!: string;
  @IsString() type!: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsDateString() date?: string;
  @IsOptional() @IsDateString() echeance?: string;
  @IsOptional() @IsString() resultat?: string;
  @IsOptional() @IsNumber() cout?: number;
}
export class UpdateNcContainmentActionDto {
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsDateString() date?: string;
  @IsOptional() @IsDateString() echeance?: string;
  @IsOptional() @IsString() resultat?: string;
  @IsOptional() @IsNumber() cout?: number;
}

export class CreateNcCauseDto {
  @IsString() nonConformityId!: string;
  @IsString() methode!: string;
  @IsOptional() @IsString() niveau?: string;
  @IsOptional() @IsString() categorie?: string;
  @IsString() description!: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsBoolean() estRacine?: boolean;
}
export class UpdateNcCauseDto {
  @IsOptional() @IsString() methode?: string;
  @IsOptional() @IsString() niveau?: string;
  @IsOptional() @IsString() categorie?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsBoolean() estRacine?: boolean;
}

export class CreateNcCostDto {
  @IsString() nonConformityId!: string;
  @IsString() type!: string;
  @IsNumber() montant!: number;
  @IsOptional() @IsString() description?: string;
}
export class UpdateNcCostDto {
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsNumber() montant?: number;
  @IsOptional() @IsString() description?: string;
}
