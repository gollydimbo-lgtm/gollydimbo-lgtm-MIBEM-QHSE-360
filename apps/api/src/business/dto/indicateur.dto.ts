import { IsBoolean,IsDateString,IsNumber,IsOptional,IsString } from 'class-validator';

// DTOs du module Indicateurs Qualité / KPI (finding #2). Champs
// volontairement absents : id/createdAt/updatedAt (système). actuel est
// conservé dans CreateIndicateurQualiteDto (saisie manuelle initiale) mais
// n'a pas de sens dans Update — il est recalculé automatiquement par
// indicateurMesureCreate à chaque nouvelle mesure, jamais ressaisi
// directement lors d'une modification de la fiche.
export class CreateIndicateurQualiteDto {
  @IsString() code!: string;
  @IsString() indicateur!: string;
  @IsNumber() actuel!: number;
  @IsNumber() cible!: number;
  @IsOptional() @IsString() unite?: string;
  @IsOptional() @IsBoolean() sensInverse?: boolean;
  @IsOptional() @IsString() domaine?: string;
  @IsOptional() @IsString() categorie?: string;
  @IsOptional() @IsString() formule?: string;
  @IsOptional() @IsString() frequence?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsNumber() seuilVert?: number;
  @IsOptional() @IsNumber() seuilOrange?: number;
  @IsOptional() @IsNumber() poids?: number;
  @IsOptional() @IsString() source?: string;
  @IsOptional() @IsString() autoKey?: string;
}
export class UpdateIndicateurQualiteDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() indicateur?: string;
  @IsOptional() @IsString() unite?: string;
  @IsOptional() @IsBoolean() sensInverse?: boolean;
  @IsOptional() @IsString() domaine?: string;
  @IsOptional() @IsString() categorie?: string;
  @IsOptional() @IsString() formule?: string;
  @IsOptional() @IsString() frequence?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsNumber() seuilVert?: number;
  @IsOptional() @IsNumber() seuilOrange?: number;
  @IsOptional() @IsNumber() poids?: number;
  @IsOptional() @IsString() source?: string;
  @IsOptional() @IsString() autoKey?: string;
}

// indicateurId vient du :id de l'URL, jamais du corps — absent du DTO.
export class CreateIndicateurMesureDto {
  @IsNumber() valeur!: number;
  @IsOptional() @IsDateString() periode?: string;
  @IsOptional() @IsString() commentaire?: string;
}
