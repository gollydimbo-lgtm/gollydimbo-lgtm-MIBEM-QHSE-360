import { IsArray, IsBoolean, IsDateString, IsIn, IsInt, IsNumber, IsOptional, IsString } from 'class-validator';

// DTOs du module Objectifs QHSE (finding #2). Champs système toujours
// exclus : id/createdAt/updatedAt/archivedAt. createdById/updatedById
// exclus aussi (traçabilité d'audit — jamais renseignés par le client,
// sinon falsification possible de l'auteur réel d'une création/modif).
// dupliqueDeId exclu : ne doit être posé que par objectifDuplicate(),
// jamais par un create/update générique. statutCalcule/avancement/smart
// ne sont pas des colonnes stockées (recalculés à la lecture par
// objectifDecorate()) : rien à exclure côté écriture pour eux.

export class CreateObjectifDto {
  @IsString() titre!: string;
  @IsNumber() cible!: number;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() pilier?: string;
  @IsOptional() @IsString() famille?: string;
  @IsOptional() @IsString() classification?: string;
  @IsOptional() @IsString() categorie?: string;
  @IsOptional() @IsString() activiteConcernee?: string;
  @IsOptional() @IsString() zone?: string;
  @IsOptional() @IsNumber() valeurInitiale?: number;
  @IsOptional() @IsDateString() dateReference?: string;
  @IsOptional() @IsNumber() actuel?: number;
  @IsOptional() @IsBoolean() sensInverse?: boolean;
  @IsOptional() @IsString() unite?: string;
  @IsOptional() @IsNumber() seuilMin?: number;
  @IsOptional() @IsNumber() seuilMax?: number;
  @IsOptional() @IsString() frequenceMesure?: string;
  @IsOptional() @IsDateString() dateDebut?: string;
  @IsOptional() @IsDateString() echeance?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsArray() @IsString({ each: true }) contributeurIds?: string[];
  @IsOptional() @IsString() valideurId?: string;
  @IsOptional() @IsString() directionResponsable?: string;
  @IsOptional() @IsNumber() budget?: number;
  @IsOptional() @IsString() priorite?: string;
  @IsOptional() @IsString() importanceStrategique?: string;
  @IsOptional() @IsString() statutManuel?: string;
  @IsOptional() @IsInt() annee?: number;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() workUnitId?: string;
}
export class UpdateObjectifDto {
  @IsOptional() @IsString() titre?: string;
  @IsOptional() @IsNumber() cible?: number;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() pilier?: string;
  @IsOptional() @IsString() famille?: string;
  @IsOptional() @IsString() classification?: string;
  @IsOptional() @IsString() categorie?: string;
  @IsOptional() @IsString() activiteConcernee?: string;
  @IsOptional() @IsString() zone?: string;
  @IsOptional() @IsNumber() valeurInitiale?: number;
  @IsOptional() @IsDateString() dateReference?: string;
  @IsOptional() @IsNumber() actuel?: number;
  @IsOptional() @IsBoolean() sensInverse?: boolean;
  @IsOptional() @IsString() unite?: string;
  @IsOptional() @IsNumber() seuilMin?: number;
  @IsOptional() @IsNumber() seuilMax?: number;
  @IsOptional() @IsString() frequenceMesure?: string;
  @IsOptional() @IsDateString() dateDebut?: string;
  @IsOptional() @IsDateString() echeance?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsArray() @IsString({ each: true }) contributeurIds?: string[];
  @IsOptional() @IsString() valideurId?: string;
  @IsOptional() @IsString() directionResponsable?: string;
  @IsOptional() @IsNumber() budget?: number;
  @IsOptional() @IsString() priorite?: string;
  @IsOptional() @IsString() importanceStrategique?: string;
  @IsOptional() @IsString() statutManuel?: string;
  @IsOptional() @IsInt() annee?: number;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() workUnitId?: string;
}

export class CreateObjectifDuplicateDto {
  @IsOptional() @IsInt() annee?: number;
  @IsOptional() @IsNumber() cible?: number;
  @IsOptional() @IsDateString() dateDebut?: string;
  @IsOptional() @IsDateString() echeance?: string;
}

export class CreateObjectifKpiDto {
  @IsString() nom!: string;
  @IsOptional() @IsString() definition?: string;
  @IsOptional() @IsString() formule?: string;
  @IsOptional() @IsString() unite?: string;
  @IsOptional() @IsString() frequence?: string;
  @IsOptional() @IsString() sourceType?: string;
  @IsOptional() @IsString() sourceKey?: string;
  @IsOptional() @IsString() sourceModule?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsNumber() valeurInitiale?: number;
  @IsOptional() @IsNumber() cible?: number;
  @IsOptional() @IsNumber() valeurActuelle?: number;
  @IsOptional() @IsBoolean() sensInverse?: boolean;
}
export class UpdateObjectifKpiDto {
  @IsOptional() @IsString() nom?: string;
  @IsOptional() @IsString() definition?: string;
  @IsOptional() @IsString() formule?: string;
  @IsOptional() @IsString() unite?: string;
  @IsOptional() @IsString() frequence?: string;
  @IsOptional() @IsString() sourceType?: string;
  @IsOptional() @IsString() sourceKey?: string;
  @IsOptional() @IsString() sourceModule?: string;
  @IsOptional() @IsString() responsableId?: string;
  @IsOptional() @IsNumber() valeurInitiale?: number;
  @IsOptional() @IsNumber() cible?: number;
  @IsOptional() @IsNumber() valeurActuelle?: number;
  @IsOptional() @IsBoolean() sensInverse?: boolean;
}

// objectifQhseId (URL) et source (toujours 'OBJECTIF_QHSE' côté serveur)
// exclus : une action créée depuis un objectif ne doit pas pouvoir se
// déclarer venir d'ailleurs ni se rattacher à un autre objectif.
export class CreateObjectifActionDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() title?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsNumber() priority?: number;
  @IsOptional() @IsDateString() dueDate?: string;
  @IsOptional() @IsString() responsibleId?: string;
  @IsOptional() @IsString() actionType?: string;
  @IsOptional() @IsString() criticite?: string;
}

export class ObjectifRiskLinkDto {
  @IsString() riskId!: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() niveauRisque?: string;
  @IsOptional() @IsString() mesuresMaitrise?: string;
}

export class ObjectifCommentCreateDto {
  @IsOptional() @IsString() type?: string;
  @IsString() contenu!: string;
  @IsOptional() @IsString() auteurId?: string;
}

export class CreateObjectifReviewDto {
  @IsOptional() @IsString() periodicite?: string;
  @IsOptional() @IsDateString() dateRevue?: string;
  @IsOptional() @IsString() resultats?: string;
  @IsOptional() @IsString() ecarts?: string;
  @IsOptional() @IsString() analyseCauses?: string;
  @IsOptional() @IsIn(['REVISION_CIBLE', 'CLOTURE', 'ABANDON']) decision?: string;
  @IsOptional() @IsNumber() nouvelleCible?: number;
  @IsOptional() @IsString() actionsProposees?: string;
  @IsOptional() @IsString() commentaire?: string;
  @IsOptional() @IsString() createdById?: string;
}

// code/libelle/categorie exclus : identité du critère de recette fixée au
// seed de migration, jamais modifiée via l'API (comportement documenté
// dans le service : "mis à jour ici par le développeur/administrateur"
// ne concerne que le résultat des tests, pas l'identité du critère).
export class UpdateObjectifRecetteCriterionDto {
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsDateString() dateTest?: string;
  @IsOptional() @IsString() testeurId?: string;
  @IsOptional() @IsString() commentaire?: string;
  @IsOptional() @IsString() anomalie?: string;
  @IsOptional() @IsDateString() dateCorrection?: string;
  @IsOptional() @IsString() resultatRetest?: string;
}
