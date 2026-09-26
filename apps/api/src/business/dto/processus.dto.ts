import { IsBoolean,IsInt,IsOptional,IsNumber,IsString } from 'class-validator';

// DTOs du module Processus / cartographie (finding #2). Tous les endpoints
// concernés faisaient un passthrough brut stripSystemFields(b) (ou, pour
// ProcessusLink, une reconstruction manuelle déjà limitée à 3 champs).
// Champs volontairement absents : id/createdAt/updatedAt (système).
// suppliers/inputs/outputs/customers sont des Json libres (SIPOC) —
// validés comme unknown, pas de forme imposée.
export class CreateProcessusDto {
  @IsString() code!: string;
  @IsString() nom!: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() domaine?: string;
  @IsOptional() @IsString() departement?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() version?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() criticite?: string;
  @IsOptional() @IsString() piloteId?: string;
  @IsOptional() @IsString() suppleantId?: string;
  @IsOptional() @IsString() finalite?: string;
  @IsOptional() @IsString() objectifPrincipal?: string;
  @IsOptional() @IsString() perimetreDebut?: string;
  @IsOptional() @IsString() perimetreFin?: string;
  @IsOptional() suppliers?: unknown;
  @IsOptional() inputs?: unknown;
  @IsOptional() outputs?: unknown;
  @IsOptional() customers?: unknown;
  @IsOptional() @IsNumber() positionX?: number;
  @IsOptional() @IsNumber() positionY?: number;
  @IsOptional() @IsString() proprietaire?: string;
  @IsOptional() @IsString() objectifs?: string;
  @IsOptional() @IsString() kpi?: string;
}
export class UpdateProcessusDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() nom?: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() domaine?: string;
  @IsOptional() @IsString() departement?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() version?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() criticite?: string;
  @IsOptional() @IsString() piloteId?: string;
  @IsOptional() @IsString() suppleantId?: string;
  @IsOptional() @IsString() finalite?: string;
  @IsOptional() @IsString() objectifPrincipal?: string;
  @IsOptional() @IsString() perimetreDebut?: string;
  @IsOptional() @IsString() perimetreFin?: string;
  @IsOptional() suppliers?: unknown;
  @IsOptional() inputs?: unknown;
  @IsOptional() outputs?: unknown;
  @IsOptional() customers?: unknown;
  @IsOptional() @IsNumber() positionX?: number;
  @IsOptional() @IsNumber() positionY?: number;
  @IsOptional() @IsString() proprietaire?: string;
  @IsOptional() @IsString() objectifs?: string;
  @IsOptional() @IsString() kpi?: string;
}

export class CreateProcessusActivityDto {
  @IsString() processusId!: string;
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsInt() order?: number;
  @IsString() name!: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() responsibleId?: string;
  @IsOptional() @IsString() inputs?: string;
  @IsOptional() @IsString() outputs?: string;
  @IsOptional() @IsString() resources?: string;
  @IsOptional() @IsString() equipment?: string;
  @IsOptional() @IsString() frequency?: string;
  @IsOptional() @IsString() criticality?: string;
}
export class UpdateProcessusActivityDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsInt() order?: number;
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() responsibleId?: string;
  @IsOptional() @IsString() inputs?: string;
  @IsOptional() @IsString() outputs?: string;
  @IsOptional() @IsString() resources?: string;
  @IsOptional() @IsString() equipment?: string;
  @IsOptional() @IsString() frequency?: string;
  @IsOptional() @IsString() criticality?: string;
}

export class CreateProcessusExigenceDto {
  @IsString() processusId!: string;
  @IsString() exigence!: string;
  @IsOptional() @IsString() origine?: string;
  @IsOptional() @IsString() reference?: string;
  @IsOptional() @IsBoolean() applicable?: boolean;
  @IsOptional() @IsString() preuveConformite?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() frequenceVerification?: string;
  @IsOptional() derniereVerification?: string;
  @IsOptional() prochaineEcheance?: string;
  @IsOptional() @IsString() statutConformite?: string;
}
export class UpdateProcessusExigenceDto {
  @IsOptional() @IsString() exigence?: string;
  @IsOptional() @IsString() origine?: string;
  @IsOptional() @IsString() reference?: string;
  @IsOptional() @IsBoolean() applicable?: boolean;
  @IsOptional() @IsString() preuveConformite?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() frequenceVerification?: string;
  @IsOptional() derniereVerification?: string;
  @IsOptional() prochaineEcheance?: string;
  @IsOptional() @IsString() statutConformite?: string;
}

// Le service reconstruit déjà manuellement data:{sourceId,targetId,label} —
// ce DTO documente formellement ce qui était jusqu'ici un allow-list implicite.
export class CreateProcessusLinkDto {
  @IsString() sourceId!: string;
  @IsString() targetId!: string;
  @IsOptional() @IsString() label?: string;
}
