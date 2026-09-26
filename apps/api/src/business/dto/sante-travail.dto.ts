import { IsBoolean, IsDateString, IsInt, IsNumber, IsOptional, IsString } from 'class-validator';

// DTOs du module Hygiène/Santé au travail (VisiteMedicale, RisqueSanitaire,
// ExpositionSurveillance, AnalyseErgonomique, TmsSignalement,
// PenibiliteFactor, PenibiliteExposition) — finding #2. Champs système
// toujours exclus : id/createdAt/updatedAt.

export class CreateVisiteMedicaleDto {
  @IsString() code!: string;
  @IsString() employeNom!: string;
  @IsOptional() @IsString() employeeId?: string;
  @IsOptional() @IsString() poste?: string;
  @IsOptional() @IsString() service?: string;
  @IsOptional() @IsString() typeVisite?: string;
  @IsOptional() @IsDateString() dateDerniereVisite?: string;
  @IsOptional() @IsString() aptitude?: string;
  @IsOptional() @IsString() restrictions?: string;
  @IsOptional() @IsString() amenagementPoste?: string;
  @IsOptional() @IsString() medecinService?: string;
  @IsOptional() @IsBoolean() suiviParticulier?: boolean;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsDateString() prochaineVisite?: string;
}
export class UpdateVisiteMedicaleDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() employeNom?: string;
  @IsOptional() @IsString() employeeId?: string;
  @IsOptional() @IsString() poste?: string;
  @IsOptional() @IsString() service?: string;
  @IsOptional() @IsString() typeVisite?: string;
  @IsOptional() @IsDateString() dateDerniereVisite?: string;
  @IsOptional() @IsString() aptitude?: string;
  @IsOptional() @IsString() restrictions?: string;
  @IsOptional() @IsString() amenagementPoste?: string;
  @IsOptional() @IsString() medecinService?: string;
  @IsOptional() @IsBoolean() suiviParticulier?: boolean;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsDateString() prochaineVisite?: string;
}

// criticite exclu — recalculée à chaque écriture (gravite*probabilite) par
// risqueSanitaireCreate()/risqueSanitaireUpdate() ; gravite/probabilite
// conservés comme entrées brutes du calcul.
export class CreateRisqueSanitaireDto {
  @IsString() code!: string;
  @IsOptional() @IsString() categorie?: string;
  @IsString() danger!: string;
  @IsOptional() @IsString() source?: string;
  @IsOptional() @IsString() activite?: string;
  @IsOptional() @IsString() poste?: string;
  @IsOptional() @IsString() zone?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() personnelExpose?: string;
  @IsOptional() @IsInt() nombrePersonnesExposees?: number;
  @IsOptional() @IsString() dureeExposition?: string;
  @IsOptional() @IsString() frequenceExposition?: string;
  @IsOptional() @IsString() voieExposition?: string;
  @IsOptional() @IsString() niveauExposition?: string;
  @IsOptional() @IsInt() gravite?: number;
  @IsOptional() @IsInt() probabilite?: number;
  @IsOptional() @IsString() mesuresExistantes?: string;
  @IsOptional() @IsString() mesuresSupplementaires?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsDateString() echeance?: string;
  @IsOptional() @IsString() statut?: string;
}
export class UpdateRisqueSanitaireDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() categorie?: string;
  @IsOptional() @IsString() danger?: string;
  @IsOptional() @IsString() source?: string;
  @IsOptional() @IsString() activite?: string;
  @IsOptional() @IsString() poste?: string;
  @IsOptional() @IsString() zone?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() personnelExpose?: string;
  @IsOptional() @IsInt() nombrePersonnesExposees?: number;
  @IsOptional() @IsString() dureeExposition?: string;
  @IsOptional() @IsString() frequenceExposition?: string;
  @IsOptional() @IsString() voieExposition?: string;
  @IsOptional() @IsString() niveauExposition?: string;
  @IsOptional() @IsInt() gravite?: number;
  @IsOptional() @IsInt() probabilite?: number;
  @IsOptional() @IsString() mesuresExistantes?: string;
  @IsOptional() @IsString() mesuresSupplementaires?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsDateString() echeance?: string;
  @IsOptional() @IsString() statut?: string;
}

// conforme : conservé comme repli légitime (le service ne le recalcule que
// si valeurMesuree ET valeurLimite sont fournies, sinon reprend la valeur
// envoyée par le client — comportement volontairement inchangé).
export class CreateExpositionSurveillanceDto {
  @IsString() risqueSanitaireId!: string;
  @IsOptional() @IsString() employeeId?: string;
  @IsOptional() @IsString() agentDangereux?: string;
  @IsOptional() @IsString() poste?: string;
  @IsOptional() @IsString() niveauExposition?: string;
  @IsOptional() @IsString() frequence?: string;
  @IsOptional() @IsString() duree?: string;
  @IsOptional() @IsDateString() dateMesure?: string;
  @IsOptional() @IsNumber() valeurMesuree?: number;
  @IsOptional() @IsNumber() valeurLimite?: number;
  @IsOptional() @IsString() unite?: string;
  @IsOptional() @IsBoolean() conforme?: boolean;
  @IsOptional() @IsString() commentaire?: string;
}

// scoreErgonomique exclu — recalculé à chaque écriture par
// calculerScoreErgonomique() à partir des facteurs booléens ci-dessous,
// jamais ressaisi séparément.
export class CreateAnalyseErgonomiqueDto {
  @IsString() code!: string;
  @IsString() poste!: string;
  @IsOptional() @IsString() zone?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsBoolean() stationDeboutProlongee?: boolean;
  @IsOptional() @IsBoolean() stationAssiseProlongee?: boolean;
  @IsOptional() @IsBoolean() travailRepetitif?: boolean;
  @IsOptional() @IsBoolean() manutentionChargesLourdes?: boolean;
  @IsOptional() @IsBoolean() posturesContraignantes?: boolean;
  @IsOptional() @IsBoolean() ecranInformatiquePosture?: boolean;
  @IsOptional() @IsBoolean() vibrations?: boolean;
  @IsOptional() @IsBoolean() eclairageInsuffisant?: boolean;
  @IsOptional() @IsBoolean() espaceInsuffisant?: boolean;
  @IsOptional() @IsString() observations?: string;
  @IsOptional() @IsString() actionsProposees?: string;
  @IsOptional() @IsDateString() dateEvaluation?: string;
  @IsOptional() @IsString() evaluateurId?: string;
}
export class UpdateAnalyseErgonomiqueDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() poste?: string;
  @IsOptional() @IsString() zone?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsBoolean() stationDeboutProlongee?: boolean;
  @IsOptional() @IsBoolean() stationAssiseProlongee?: boolean;
  @IsOptional() @IsBoolean() travailRepetitif?: boolean;
  @IsOptional() @IsBoolean() manutentionChargesLourdes?: boolean;
  @IsOptional() @IsBoolean() posturesContraignantes?: boolean;
  @IsOptional() @IsBoolean() ecranInformatiquePosture?: boolean;
  @IsOptional() @IsBoolean() vibrations?: boolean;
  @IsOptional() @IsBoolean() eclairageInsuffisant?: boolean;
  @IsOptional() @IsBoolean() espaceInsuffisant?: boolean;
  @IsOptional() @IsString() observations?: string;
  @IsOptional() @IsString() actionsProposees?: string;
  @IsOptional() @IsDateString() dateEvaluation?: string;
  @IsOptional() @IsString() evaluateurId?: string;
}

export class CreateTmsSignalementDto {
  @IsString() code!: string;
  @IsOptional() @IsString() employeeId?: string;
  @IsOptional() @IsString() poste?: string;
  @IsString() zoneCorporelle!: string;
  @IsOptional() @IsString() activite?: string;
  @IsOptional() @IsString() frequence?: string;
  @IsOptional() @IsDateString() dateSignalement?: string;
  @IsOptional() @IsString() analyseErgonomiqueId?: string;
  @IsOptional() @IsString() statut?: string;
}
export class UpdateTmsSignalementDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() employeeId?: string;
  @IsOptional() @IsString() poste?: string;
  @IsOptional() @IsString() zoneCorporelle?: string;
  @IsOptional() @IsString() activite?: string;
  @IsOptional() @IsString() frequence?: string;
  @IsOptional() @IsDateString() dateSignalement?: string;
  @IsOptional() @IsString() analyseErgonomiqueId?: string;
  @IsOptional() @IsString() statut?: string;
}

export class CreatePenibiliteFactorDto {
  @IsString() nom!: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsBoolean() actif?: boolean;
}

export class CreatePenibiliteExpositionDto {
  @IsOptional() @IsString() employeeId?: string;
  @IsString() facteurId!: string;
  @IsOptional() @IsString() poste?: string;
  @IsOptional() @IsString() niveauExposition?: string;
  @IsOptional() @IsString() duree?: string;
  @IsOptional() @IsString() frequence?: string;
  @IsOptional() @IsString() mesuresPrevention?: string;
  @IsOptional() @IsDateString() dateEvaluation?: string;
  @IsOptional() @IsDateString() prochaineReevaluation?: string;
}
