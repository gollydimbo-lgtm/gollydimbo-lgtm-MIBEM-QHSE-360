import { IsArray, IsBoolean, IsDateString, IsIn, IsInt, IsObject, IsOptional, IsString, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

// DTOs du module GED/Documents (finding #2). Champs système toujours
// exclus : id/createdAt/updatedAt. Le service documents.service.ts
// pratiquait déjà un allow-list manuel dans create()/update() (liste
// `champsSimples`) — ces DTOs formalisent la même liste au niveau du
// contrôleur (défense en profondeur, cohérence avec les autres modules) et
// referment le seul vrai vide restant : typeCreate/typeUpdate/
// categoryCreate/categoryUpdate ne faisaient que `stripSystemFields(b)`,
// sans allow-list de champs.

// Champs volontairement exclus des DTOs Document : status (piloté par
// submit/verify/approve/archive/reopen), currentVersion (piloté par
// addVersion), qrToken (généré par randomUUID(), voir regenerateQr()).
export class CreateDocumentDto {
  @IsString() code!: string;
  @IsString() title!: string;
  @IsString() category!: string;
  @IsOptional() @IsString() documentGroup?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsDateString() nextReviewAt?: string;
  @IsOptional() @IsString() createdById?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() documentType?: string;
  @IsOptional() @IsString() domaine?: string;
  @IsOptional() @IsString() service?: string;
  @IsOptional() @IsString() activite?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() responsibleId?: string;
  @IsOptional() @IsString() verificateurId?: string;
  @IsOptional() @IsString() approbateurId?: string;
  @IsOptional() @IsDateString() dateEntreeVigueur?: string;
  @IsOptional() @IsString() frequenceRevision?: string;
  @IsOptional() @IsString() criticite?: string;
  @IsOptional() @IsString() motifCreation?: string;
  @IsOptional() @IsString() referencesReglementaires?: string;
  @IsOptional() @IsString() referencesNormatives?: string;
  @IsOptional() @IsString() motsCles?: string;
  @IsOptional() @IsString() workUnitId?: string;
  @IsOptional() @IsBoolean() external?: boolean;
  @IsOptional() @IsString() sourceOrganisme?: string;
  @IsOptional() @IsString() externalReference?: string;
  @IsOptional() @IsBoolean() diffusionAccuseRequis?: boolean;
  @IsOptional() @IsString() veilleReglementaireId?: string;
  // Version 1 optionnelle à la création (voir addVersion pour les suivantes).
  @IsOptional() @IsString() fileName?: string;
  @IsOptional() @IsString() base64?: string;
}

export class UpdateDocumentDto {
  @IsOptional() @IsString() title?: string;
  @IsOptional() @IsString() category?: string;
  @IsOptional() @IsString() documentGroup?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() documentType?: string;
  @IsOptional() @IsString() domaine?: string;
  @IsOptional() @IsString() service?: string;
  @IsOptional() @IsString() activite?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() responsibleId?: string;
  @IsOptional() @IsString() verificateurId?: string;
  @IsOptional() @IsString() approbateurId?: string;
  @IsOptional() @IsDateString() dateEntreeVigueur?: string;
  @IsOptional() @IsString() frequenceRevision?: string;
  @IsOptional() @IsString() criticite?: string;
  @IsOptional() @IsString() motifCreation?: string;
  @IsOptional() @IsString() referencesReglementaires?: string;
  @IsOptional() @IsString() referencesNormatives?: string;
  @IsOptional() @IsString() motsCles?: string;
  @IsOptional() @IsString() workUnitId?: string;
  @IsOptional() @IsBoolean() external?: boolean;
  @IsOptional() @IsString() sourceOrganisme?: string;
  @IsOptional() @IsString() externalReference?: string;
  @IsOptional() @IsBoolean() diffusionAccuseRequis?: boolean;
  @IsOptional() @IsString() veilleReglementaireId?: string;
  @IsOptional() @IsDateString() nextReviewAt?: string;
  @IsOptional() @IsString() updatedById?: string; // attribution du log d'audit uniquement
}

export class AddDocumentVersionDto {
  @IsString() fileName!: string;
  @IsOptional() @IsString() mimeType?: string;
  @IsString() base64!: string;
  @IsOptional() @IsString() motifModification?: string;
}

export class SubmitDocumentDto {
  @IsOptional() @IsString() userId?: string;
}

export class VerifyDocumentDto {
  @IsIn(['APPROUVE', 'DEMANDE_MODIFICATION']) decision!: 'APPROUVE' | 'DEMANDE_MODIFICATION';
  @IsOptional() @IsString() comment?: string;
  @IsOptional() @IsString() userId?: string;
}

export class ApproveDocumentDto {
  @IsIn(['APPROUVE', 'REFUSE']) decision!: 'APPROUVE' | 'REFUSE';
  @IsOptional() @IsString() comment?: string;
  @IsOptional() @IsString() userId?: string;
}

export class ArchiveDocumentDto {
  @IsOptional() @IsString() userId?: string;
}

export class ReopenDocumentDto {
  @IsOptional() @IsString() userId?: string;
}

export class DiffusionRecipientInputDto {
  @IsOptional() @IsString() userId?: string;
  @IsOptional() @IsString() label?: string;
  @IsOptional() @IsBoolean() accuseRequis?: boolean;
}

export class DiffuseDocumentDto {
  @IsOptional() @IsInt() version?: number;
  @IsArray() @ValidateNested({ each: true }) @Type(() => DiffusionRecipientInputDto) recipients!: DiffusionRecipientInputDto[];
  @IsOptional() @IsString() createdById?: string;
}

export class AccuseLectureDto {
  @IsOptional() @IsString() userId?: string;
}

export class DocumentLinkCreateDto {
  @IsString() sourceModule!: string;
  @IsString() sourceEntityId!: string;
  @IsOptional() @IsString() relationType?: string;
  @IsOptional() @IsObject() metadata?: Record<string, any>;
  @IsOptional() @IsString() createdById?: string;
}

export class RequestRevisionDto {
  @IsString() sourceModule!: string;
  @IsString() sourceEntityId!: string;
  @IsString() motif!: string;
  @IsOptional() @IsString() createdById?: string;
}

export class LinkVeilleDto {
  @IsOptional() @IsString() veilleReglementaireId!: string | null;
}

export class CreateDocumentTypeDto {
  @IsString() code!: string;
  @IsString() name!: string;
  @IsOptional() @IsString() prefix?: string;
  @IsOptional() @IsBoolean() active?: boolean;
}
export class UpdateDocumentTypeDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() prefix?: string;
  @IsOptional() @IsBoolean() active?: boolean;
}

export class CreateDocumentCategoryDto {
  @IsString() name!: string;
  @IsOptional() @IsString() parentId?: string;
  @IsOptional() @IsInt() ordre?: number;
}
export class UpdateDocumentCategoryDto {
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() parentId?: string;
  @IsOptional() @IsInt() ordre?: number;
}
