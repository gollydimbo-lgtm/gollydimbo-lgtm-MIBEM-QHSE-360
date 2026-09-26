import { IsArray,IsDateString,IsInt,IsOptional,IsString,IsBoolean } from 'class-validator';

// DTOs du module Sécurité — Événements (finding #2). eventCreate/eventUpdate
// faisaient un passthrough brut stripSystemFields(b), sans aucun recalcul
// serveur (comme QhseAudit) : un client pouvait donc positionner directement
// statut/dateCloture/archivedAt. Champs volontairement absents :
// id/createdAt/updatedAt (système), archivedAt (jamais de suppression
// définitive — géré par eventDelete), dateCloture (posé par le workflow de
// clôture dédié, jamais en création/modification directe).
export class CreateSafetyEventDto {
  @IsString() type!: string;
  @IsOptional() @IsString() categorie?: string;
  @IsString() title!: string;
  @IsOptional() @IsString() description?: string;
  @IsDateString() occurredAt!: string;
  @IsOptional() @IsInt() severity?: number;
  @IsOptional() @IsBoolean() withLostTime?: boolean;
  @IsOptional() @IsInt() lostDays?: number;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() zone?: string;
  @IsOptional() @IsString() atelier?: string;
  @IsOptional() @IsString() poste?: string;
  @IsOptional() @IsString() activite?: string;
  @IsOptional() @IsString() employeeId?: string;
  @IsOptional() @IsString() personneNom?: string;
  @IsOptional() @IsString() personneFonction?: string;
  @IsOptional() @IsString() typePersonnel?: string;
  @IsOptional() @IsArray() temoinIds?: string[];
  @IsOptional() @IsString() typeLesion?: string;
  @IsOptional() @IsString() siegeLesion?: string;
  @IsOptional() @IsString() consequenceMaterielle?: string;
  @IsOptional() @IsString() consequenceEnvironnementale?: string;
  @IsOptional() @IsString() mecanisme?: string;
  @IsOptional() @IsString() potentielGravite?: string;
  @IsOptional() @IsString() enqueteurId?: string;
  @IsOptional() @IsDateString() dateEnquete?: string;
  @IsOptional() @IsString() methodeAnalyse?: string;
  @IsOptional() @IsString() causeHumaine?: string;
  @IsOptional() @IsString() causeMethode?: string;
  @IsOptional() @IsString() causeMachine?: string;
  @IsOptional() @IsString() causeMatiere?: string;
  @IsOptional() @IsString() causeMilieu?: string;
  @IsOptional() @IsString() causeManagement?: string;
  @IsOptional() @IsString() causeRacine?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() riskId?: string;
  @IsOptional() @IsString() epiId?: string;
  @IsOptional() @IsString() epcId?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() fournisseurId?: string;
  @IsOptional() @IsString() nonConformityId?: string;
  @IsOptional() @IsString() equipmentId?: string;
}
export class UpdateSafetyEventDto {
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() categorie?: string;
  @IsOptional() @IsString() title?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsDateString() occurredAt?: string;
  @IsOptional() @IsInt() severity?: number;
  @IsOptional() @IsBoolean() withLostTime?: boolean;
  @IsOptional() @IsInt() lostDays?: number;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() zone?: string;
  @IsOptional() @IsString() atelier?: string;
  @IsOptional() @IsString() poste?: string;
  @IsOptional() @IsString() activite?: string;
  @IsOptional() @IsString() employeeId?: string;
  @IsOptional() @IsString() personneNom?: string;
  @IsOptional() @IsString() personneFonction?: string;
  @IsOptional() @IsString() typePersonnel?: string;
  @IsOptional() @IsArray() temoinIds?: string[];
  @IsOptional() @IsString() typeLesion?: string;
  @IsOptional() @IsString() siegeLesion?: string;
  @IsOptional() @IsString() consequenceMaterielle?: string;
  @IsOptional() @IsString() consequenceEnvironnementale?: string;
  @IsOptional() @IsString() mecanisme?: string;
  @IsOptional() @IsString() potentielGravite?: string;
  @IsOptional() @IsString() enqueteurId?: string;
  @IsOptional() @IsDateString() dateEnquete?: string;
  @IsOptional() @IsString() methodeAnalyse?: string;
  @IsOptional() @IsString() causeHumaine?: string;
  @IsOptional() @IsString() causeMethode?: string;
  @IsOptional() @IsString() causeMachine?: string;
  @IsOptional() @IsString() causeMatiere?: string;
  @IsOptional() @IsString() causeMilieu?: string;
  @IsOptional() @IsString() causeManagement?: string;
  @IsOptional() @IsString() causeRacine?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() riskId?: string;
  @IsOptional() @IsString() epiId?: string;
  @IsOptional() @IsString() epcId?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() fournisseurId?: string;
  @IsOptional() @IsString() nonConformityId?: string;
  @IsOptional() @IsString() equipmentId?: string;
}
