import { IsBoolean,IsDateString,IsInt,IsNumber,IsOptional,IsString } from 'class-validator';

// DTOs du module Environnement (finding #2). Champs volontairement absents :
// id/createdAt/updatedAt (système). Pour EnvironnementAspect : criticite/
// significatif exclus (recalculés par calculerAspect() à chaque écriture,
// jamais ressaisis séparément) ; frequence/gravite/probabilite/maitrise
// conservés — lus tels quels comme entrées brutes du calcul.
export class CreateEnvironmentRecordDto {
  @IsString() code!: string;
  @IsString() type!: string;
  @IsOptional() @IsString() categorie?: string;
  @IsOptional() @IsString() sousCategorie?: string;
  @IsOptional() @IsNumber() value?: number;
  @IsOptional() @IsString() unit?: string;
  @IsOptional() @IsString() site?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsNumber() seuilReglementaire?: number;
  @IsOptional() @IsBoolean() conforme?: boolean;
  @IsOptional() @IsNumber() cout?: number;
  @IsOptional() @IsString() modeTraitement?: string;
  @IsOptional() @IsString() destination?: string;
  @IsOptional() @IsDateString() recordedAt?: string;
  @IsOptional() @IsString() notes?: string;
}
export class UpdateEnvironmentRecordDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() categorie?: string;
  @IsOptional() @IsString() sousCategorie?: string;
  @IsOptional() @IsNumber() value?: number;
  @IsOptional() @IsString() unit?: string;
  @IsOptional() @IsString() site?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsNumber() seuilReglementaire?: number;
  @IsOptional() @IsBoolean() conforme?: boolean;
  @IsOptional() @IsNumber() cout?: number;
  @IsOptional() @IsString() modeTraitement?: string;
  @IsOptional() @IsString() destination?: string;
  @IsOptional() @IsDateString() recordedAt?: string;
  @IsOptional() @IsString() notes?: string;
}

export class CreateEnvironnementAspectDto {
  @IsString() code!: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() activite?: string;
  @IsString() aspect!: string;
  @IsOptional() @IsString() source?: string;
  @IsOptional() @IsString() impact?: string;
  @IsOptional() @IsString() milieu?: string;
  @IsOptional() @IsString() situation?: string;
  @IsOptional() @IsInt() frequence?: number;
  @IsOptional() @IsInt() gravite?: number;
  @IsOptional() @IsInt() probabilite?: number;
  @IsOptional() @IsInt() maitrise?: number;
  @IsOptional() @IsString() mesuresMaitrise?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsDateString() echeance?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() riskId?: string;
}
export class UpdateEnvironnementAspectDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() activite?: string;
  @IsOptional() @IsString() aspect?: string;
  @IsOptional() @IsString() source?: string;
  @IsOptional() @IsString() impact?: string;
  @IsOptional() @IsString() milieu?: string;
  @IsOptional() @IsString() situation?: string;
  @IsOptional() @IsInt() frequence?: number;
  @IsOptional() @IsInt() gravite?: number;
  @IsOptional() @IsInt() probabilite?: number;
  @IsOptional() @IsInt() maitrise?: number;
  @IsOptional() @IsString() mesuresMaitrise?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsDateString() echeance?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() riskId?: string;
}

export class CreateProduitChimiqueDto {
  @IsString() code!: string;
  @IsString() nom!: string;
  @IsOptional() @IsString() reference?: string;
  @IsOptional() @IsString() fournisseurId?: string;
  @IsOptional() @IsNumber() quantiteStockee?: number;
  @IsOptional() @IsNumber() quantiteConsommee?: number;
  @IsOptional() @IsString() unite?: string;
  @IsOptional() @IsString() classification?: string;
  @IsOptional() @IsString() dangerEnvironnemental?: string;
  @IsOptional() @IsString() zoneStockage?: string;
  @IsOptional() @IsBoolean() retention?: boolean;
  @IsOptional() @IsBoolean() fdsDisponible?: boolean;
  @IsOptional() @IsDateString() dateControle?: string;
  @IsOptional() @IsDateString() dateExpiration?: string;
  @IsOptional() @IsNumber() seuilAlerteStock?: number;
}
export class UpdateProduitChimiqueDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() nom?: string;
  @IsOptional() @IsString() reference?: string;
  @IsOptional() @IsString() fournisseurId?: string;
  @IsOptional() @IsNumber() quantiteStockee?: number;
  @IsOptional() @IsNumber() quantiteConsommee?: number;
  @IsOptional() @IsString() unite?: string;
  @IsOptional() @IsString() classification?: string;
  @IsOptional() @IsString() dangerEnvironnemental?: string;
  @IsOptional() @IsString() zoneStockage?: string;
  @IsOptional() @IsBoolean() retention?: boolean;
  @IsOptional() @IsBoolean() fdsDisponible?: boolean;
  @IsOptional() @IsDateString() dateControle?: string;
  @IsOptional() @IsDateString() dateExpiration?: string;
  @IsOptional() @IsNumber() seuilAlerteStock?: number;
}
