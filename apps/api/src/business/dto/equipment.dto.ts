import { IsBoolean,IsDateString,IsInt,IsNumber,IsOptional,IsString } from 'class-validator';

// DTOs du module Équipements (finding #2). Champs volontairement absents :
// id/createdAt/updatedAt (système), qrToken (généré par randomUUID(), jamais
// lu depuis le corps), archivedAt (jamais de suppression définitive — géré
// par equipmentDelete), criticiteScore/criticiteNiveau (recalculés par
// calculerCriticiteEquipement à partir des 4 criticités brutes ci-dessous,
// jamais lus tels quels depuis le corps de la requête).
export class CreateEquipmentDto {
  @IsString() code!: string;
  @IsString() name!: string;
  @IsOptional() @IsString() category?: string;
  @IsOptional() @IsString() location?: string;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsDateString() lastInspectionAt?: string;
  @IsOptional() @IsDateString() nextInspectionAt?: string;
  @IsOptional() @IsString() notes?: string;
  @IsOptional() @IsString() categoryId?: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() sousType?: string;
  @IsOptional() @IsString() marque?: string;
  @IsOptional() @IsString() modele?: string;
  @IsOptional() @IsString() numeroSerie?: string;
  @IsOptional() @IsString() referenceFabricant?: string;
  @IsOptional() @IsInt() anneeFabrication?: number;
  @IsOptional() @IsDateString() dateAcquisition?: string;
  @IsOptional() @IsDateString() dateMiseEnService?: string;
  @IsOptional() @IsString() fournisseurId?: string;
  @IsOptional() @IsString() constructeur?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() workUnitId?: string;
  @IsOptional() @IsString() batiment?: string;
  @IsOptional() @IsString() zone?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() utilisateursAutorises?: string;
  @IsOptional() @IsString() etat?: string;
  @IsOptional() @IsString() motifEtat?: string;
  @IsOptional() @IsDateString() dateEtat?: string;
  @IsOptional() @IsString() responsableEtatId?: string;
  @IsOptional() @IsString() risqueAssocieEtat?: string;
  @IsOptional() @IsString() mesureMaitriseEtat?: string;
  @IsOptional() @IsDateString() dateRemiseEnServicePrevue?: string;
  @IsOptional() @IsString() justificatifEtat?: string;
  @IsOptional() @IsInt() criticiteSecurite?: number;
  @IsOptional() @IsInt() criticiteQualite?: number;
  @IsOptional() @IsInt() criticiteEnvironnement?: number;
  @IsOptional() @IsInt() criticiteProduction?: number;
}
export class UpdateEquipmentDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() category?: string;
  @IsOptional() @IsString() location?: string;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsDateString() lastInspectionAt?: string;
  @IsOptional() @IsDateString() nextInspectionAt?: string;
  @IsOptional() @IsString() notes?: string;
  @IsOptional() @IsString() categoryId?: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() sousType?: string;
  @IsOptional() @IsString() marque?: string;
  @IsOptional() @IsString() modele?: string;
  @IsOptional() @IsString() numeroSerie?: string;
  @IsOptional() @IsString() referenceFabricant?: string;
  @IsOptional() @IsInt() anneeFabrication?: number;
  @IsOptional() @IsDateString() dateAcquisition?: string;
  @IsOptional() @IsDateString() dateMiseEnService?: string;
  @IsOptional() @IsString() fournisseurId?: string;
  @IsOptional() @IsString() constructeur?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() workUnitId?: string;
  @IsOptional() @IsString() batiment?: string;
  @IsOptional() @IsString() zone?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() utilisateursAutorises?: string;
  @IsOptional() @IsString() etat?: string;
  @IsOptional() @IsString() motifEtat?: string;
  @IsOptional() @IsDateString() dateEtat?: string;
  @IsOptional() @IsString() responsableEtatId?: string;
  @IsOptional() @IsString() risqueAssocieEtat?: string;
  @IsOptional() @IsString() mesureMaitriseEtat?: string;
  @IsOptional() @IsDateString() dateRemiseEnServicePrevue?: string;
  @IsOptional() @IsString() justificatifEtat?: string;
  @IsOptional() @IsInt() criticiteSecurite?: number;
  @IsOptional() @IsInt() criticiteQualite?: number;
  @IsOptional() @IsInt() criticiteEnvironnement?: number;
  @IsOptional() @IsInt() criticiteProduction?: number;
}

export class CreateEquipmentCategoryDto {
  @IsString() code!: string;
  @IsString() label!: string;
  @IsOptional() @IsString() groupe?: string;
  @IsOptional() @IsInt() order?: number;
  @IsOptional() @IsBoolean() active?: boolean;
}
export class UpdateEquipmentCategoryDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() label?: string;
  @IsOptional() @IsString() groupe?: string;
  @IsOptional() @IsInt() order?: number;
  @IsOptional() @IsBoolean() active?: boolean;
}

// Singleton — pas de création exposée, seulement une mise à jour.
export class UpdateEquipmentSettingsDto {
  @IsOptional() @IsInt() seuilCriticiteModere?: number;
  @IsOptional() @IsInt() seuilCriticiteEleve?: number;
  @IsOptional() @IsInt() seuilCriticiteCritique?: number;
  @IsOptional() @IsBoolean() alerteJ90?: boolean;
  @IsOptional() @IsBoolean() alerteJ60?: boolean;
  @IsOptional() @IsBoolean() alerteJ30?: boolean;
  @IsOptional() @IsBoolean() alerteJ7?: boolean;
  @IsOptional() @IsNumber() ponderationScoreGlobal?: number;
}

export class CreateEquipmentMaintenancePlanDto {
  @IsString() equipmentId!: string;
  @IsString() designation!: string;
  @IsOptional() @IsString() frequenceType?: string;
  @IsNumber() frequenceValeur!: number;
  @IsOptional() @IsString() uniteFrequence?: string;
  @IsOptional() @IsDateString() dateDerniere?: string;
  @IsOptional() @IsDateString() dateProchaine?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() prestataire?: string;
  @IsOptional() @IsBoolean() actif?: boolean;
  @IsOptional() @IsString() description?: string;
}
export class UpdateEquipmentMaintenancePlanDto {
  @IsOptional() @IsString() designation?: string;
  @IsOptional() @IsString() frequenceType?: string;
  @IsOptional() @IsNumber() frequenceValeur?: number;
  @IsOptional() @IsString() uniteFrequence?: string;
  @IsOptional() @IsDateString() dateDerniere?: string;
  @IsOptional() @IsDateString() dateProchaine?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() prestataire?: string;
  @IsOptional() @IsBoolean() actif?: boolean;
  @IsOptional() @IsString() description?: string;
}

export class CreateEquipmentMaintenanceRecordDto {
  @IsString() equipmentId!: string;
  @IsOptional() @IsString() planId?: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsDateString() datePanne?: string;
  @IsOptional() @IsDateString() dateDebut?: string;
  @IsOptional() @IsDateString() dateFin?: string;
  @IsOptional() @IsNumber() dureeHeures?: number;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() prestataire?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() causePanne?: string;
  @IsOptional() @IsString() piecesRemplacees?: string;
  @IsOptional() @IsNumber() cout?: number;
}
export class UpdateEquipmentMaintenanceRecordDto {
  @IsOptional() @IsString() planId?: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsDateString() datePanne?: string;
  @IsOptional() @IsDateString() dateDebut?: string;
  @IsOptional() @IsDateString() dateFin?: string;
  @IsOptional() @IsNumber() dureeHeures?: number;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() prestataire?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() causePanne?: string;
  @IsOptional() @IsString() piecesRemplacees?: string;
  @IsOptional() @IsNumber() cout?: number;
}

// nonConformityId absent : posé uniquement par equipmentControlGenerateNc.
export class CreateEquipmentControlDto {
  @IsString() equipmentId!: string;
  @IsString() designation!: string;
  @IsOptional() @IsString() organisme?: string;
  @IsOptional() @IsString() referenceReglementaire?: string;
  @IsOptional() @IsDateString() dateControle?: string;
  @IsOptional() @IsDateString() dateProchainControle?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() observations?: string;
  @IsOptional() @IsString() controleurId?: string;
  @IsOptional() @IsNumber() cout?: number;
}
export class UpdateEquipmentControlDto {
  @IsOptional() @IsString() designation?: string;
  @IsOptional() @IsString() organisme?: string;
  @IsOptional() @IsString() referenceReglementaire?: string;
  @IsOptional() @IsDateString() dateControle?: string;
  @IsOptional() @IsDateString() dateProchainControle?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() observations?: string;
  @IsOptional() @IsString() controleurId?: string;
  @IsOptional() @IsNumber() cout?: number;
}

// nonConformityId absent : posé uniquement par equipmentCalibrationGenerateNc.
// nePasUtiliser conservé : n'est réellement recalculé que si `resultat` est
// fourni (sinon la valeur brute du client fait foi, cf. equipmentCalibrationCreate/Update).
export class CreateEquipmentCalibrationDto {
  @IsString() equipmentId!: string;
  @IsOptional() @IsDateString() dateEtalonnage?: string;
  @IsOptional() @IsDateString() dateProchaineEtalonnage?: string;
  @IsOptional() @IsString() organismeEtalonneur?: string;
  @IsOptional() @IsString() certificatNumero?: string;
  @IsOptional() @IsString() resultat?: string;
  @IsOptional() @IsString() incertitude?: string;
  @IsOptional() @IsBoolean() nePasUtiliser?: boolean;
  @IsOptional() @IsNumber() cout?: number;
}
export class UpdateEquipmentCalibrationDto {
  @IsOptional() @IsDateString() dateEtalonnage?: string;
  @IsOptional() @IsDateString() dateProchaineEtalonnage?: string;
  @IsOptional() @IsString() organismeEtalonneur?: string;
  @IsOptional() @IsString() certificatNumero?: string;
  @IsOptional() @IsString() resultat?: string;
  @IsOptional() @IsString() incertitude?: string;
  @IsOptional() @IsBoolean() nePasUtiliser?: boolean;
  @IsOptional() @IsNumber() cout?: number;
}

export class CreateEquipmentInspectionDto {
  @IsString() equipmentId!: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsDateString() date?: string;
  @IsOptional() @IsString() inspecteurId?: string;
  @IsOptional() @IsString() statutGlobal?: string;
  @IsOptional() items?: unknown;
  @IsOptional() @IsString() commentaire?: string;
  @IsOptional() @IsString() signature?: string;
  @IsOptional() @IsString() localisation?: string;
}
export class UpdateEquipmentInspectionDto {
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsDateString() date?: string;
  @IsOptional() @IsString() inspecteurId?: string;
  @IsOptional() @IsString() statutGlobal?: string;
  @IsOptional() items?: unknown;
  @IsOptional() @IsString() commentaire?: string;
  @IsOptional() @IsString() signature?: string;
  @IsOptional() @IsString() localisation?: string;
}

// dateFinReelle absent : posé uniquement par equipmentConsignationLever.
// Pas d'UpdateDto : aucun endpoint PATCH générique pour cette entité.
export class CreateEquipmentConsignationDto {
  @IsString() equipmentId!: string;
  @IsOptional() @IsDateString() dateDebut?: string;
  @IsOptional() @IsDateString() dateFinPrevue?: string;
  @IsString() motif!: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsString() risqueAssocie?: string;
  @IsOptional() @IsString() mesureControle?: string;
  @IsOptional() @IsString() statut?: string;
}
