import { IsArray, IsBoolean, IsDateString, IsIn, IsInt, IsObject, IsOptional, IsString, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

// DTOs du module Quart d'heure sécurité / safety-talks (finding #2). Champs
// système toujours exclus : id/createdAt/updatedAt.
// Champs workflow exclus des DTOs de contenu (create/update) car posés
// uniquement par des endpoits dédiés : status, approvedAt (approve()),
// scheduledAt/duree/frequence (schedule()/postpone()), origineType/
// origineRaison/origineModules (générés par create()/generateFromRecommendation()),
// generatedAt, realisedAt (jamais alimentés par le service, champ non piloté).

export class CreateSafetyTalkDto {
  @IsOptional() @IsDateString() weekStart?: string;
  @IsOptional() @IsDateString() weekEnd?: string;
  @IsString() title!: string;
  @IsString() summary!: string;
  @IsOptional() @IsString() theme?: string;
  @IsOptional() @IsString() objectif?: string;
  @IsOptional() @IsString() contexte?: string;
  @IsOptional() @IsString() risquesConcernes?: string;
  @IsOptional() @IsString() personnesExposees?: string;
  @IsOptional() @IsString() messagePrincipal?: string;
  @IsOptional() @IsString() pointsEssentiels?: string;
  @IsOptional() @IsString() bonnesPratiques?: string;
  @IsOptional() @IsString() mauvaisesPratiques?: string;
  @IsOptional() @IsString() questions?: string;
  @IsOptional() @IsString() exemplesTerrain?: string;
  @IsOptional() @IsString() mesuresPrevention?: string;
  @IsOptional() @IsString() conduiteATenir?: string;
  @IsOptional() @IsString() conclusion?: string;
  @IsOptional() @IsString() engagementAttendu?: string;
  @IsOptional() @IsObject() quiz?: Record<string, any>;
  @IsOptional() @IsString() priorite?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() service?: string;
  @IsOptional() @IsString() zone?: string;
  @IsOptional() @IsString() equipe?: string;
  @IsOptional() @IsString() workUnitId?: string;
  @IsOptional() @IsString() responsableAnimationId?: string;
  @IsOptional() @IsString() createdById?: string;
  @IsOptional() @IsString() userId?: string; // attribution du log d'audit uniquement
}

export class UpdateSafetyTalkDto {
  @IsOptional() @IsDateString() weekStart?: string;
  @IsOptional() @IsDateString() weekEnd?: string;
  @IsOptional() @IsString() title?: string;
  @IsOptional() @IsString() summary?: string;
  @IsOptional() @IsString() theme?: string;
  @IsOptional() @IsString() objectif?: string;
  @IsOptional() @IsString() contexte?: string;
  @IsOptional() @IsString() risquesConcernes?: string;
  @IsOptional() @IsString() personnesExposees?: string;
  @IsOptional() @IsString() messagePrincipal?: string;
  @IsOptional() @IsString() pointsEssentiels?: string;
  @IsOptional() @IsString() bonnesPratiques?: string;
  @IsOptional() @IsString() mauvaisesPratiques?: string;
  @IsOptional() @IsString() questions?: string;
  @IsOptional() @IsString() exemplesTerrain?: string;
  @IsOptional() @IsString() mesuresPrevention?: string;
  @IsOptional() @IsString() conduiteATenir?: string;
  @IsOptional() @IsString() conclusion?: string;
  @IsOptional() @IsString() engagementAttendu?: string;
  @IsOptional() @IsObject() quiz?: Record<string, any>;
  @IsOptional() @IsString() priorite?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() service?: string;
  @IsOptional() @IsString() zone?: string;
  @IsOptional() @IsString() equipe?: string;
  @IsOptional() @IsString() workUnitId?: string;
  @IsOptional() @IsString() responsableAnimationId?: string;
  @IsOptional() @IsString() createdById?: string;
  @IsOptional() @IsString() userId?: string;
}

// generateFromRecommendation : seul weekStart/weekEnd sont légitimement
// pilotables par le client. Avant ce DTO, `...b` était étalé en dernier sur
// l'objet `data` et pouvait donc écraser title/status/origineType/etc.
// déjà déterminés par la recommandation — faille de mass assignment corrigée
// ici par le whitelist du ValidationPipe global.
export class CreateSafetyTalkFromRecommendationDto {
  @IsOptional() @IsDateString() weekStart?: string;
  @IsOptional() @IsDateString() weekEnd?: string;
}

export class ScheduleSafetyTalkDto {
  @IsDateString() scheduledAt!: string;
  @IsOptional() @IsString() frequence?: string;
  @IsOptional() @IsInt() duree?: number;
}

export class PostponeSafetyTalkDto {
  @IsDateString() scheduledAt!: string;
}

export class CancelSafetyTalkDto {
  @IsOptional() @IsString() userId?: string;
}

export class AddSafetyTalkParticipantDto {
  @IsOptional() @IsString() employeeId?: string;
  @IsOptional() @IsString() userId?: string;
  @IsOptional() @IsBoolean() present?: boolean;
  @IsOptional() @IsString() motifAbsence?: string;
  @IsOptional() @IsString() signature?: string;
}

export class BulkAddParticipantsDto {
  @IsArray() @IsString({ each: true }) employeeIds!: string[];
}

// Champs workflow exclus : status/transformedIntoModule/transformedIntoId,
// posés uniquement par transformFeedback().
export class AddSafetyTalkFeedbackDto {
  @IsString() type!: string;
  @IsString() description!: string;
  @IsOptional() @IsString() localisation?: string;
  @IsOptional() @IsString() criticite?: string;
  @IsOptional() @IsString() reportedById?: string;
  @IsOptional() @IsString() photoUrl?: string;
  @IsOptional() @IsString() commentaire?: string;
  @IsOptional() @IsString() mesureImmediate?: string;
}

export class QuizSubmitDto {
  @IsOptional() @IsString() participantId?: string;
  @IsInt() score!: number;
  @IsInt() total!: number;
}

export class RecommendationDecisionDto {
  @IsIn(['ACCEPTER', 'REPORTER', 'IGNORER']) decision!: 'ACCEPTER' | 'REPORTER' | 'IGNORER';
}

export class UpsertSafetyTalkRuleDto {
  @IsString() code!: string;
  @IsString() label!: string;
  @IsOptional() @IsInt() seuil?: number;
  @IsOptional() @IsInt() periodeJours?: number;
  @IsOptional() @IsBoolean() active?: boolean;
}

// overrides : union des champs légitimement modifiables par l'humain lors de
// la transformation d'une remontée terrain en Action/NC/SafetyEvent. `id` et
// tout autre champ système/inconnu sont exclus par le whitelist global —
// avant ce DTO, `...overrides` était étalé en dernier et pouvait écraser
// n'importe quel champ, y compris l'id généré par Prisma.
export class SafetyTalkFeedbackOverridesDto {
  @IsOptional() @IsString() title?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() actionType?: string;
  @IsOptional() @IsString() criticite?: string;
  @IsOptional() @IsDateString() dueDate?: string;
  @IsOptional() @IsString() source?: string;
  @IsOptional() @IsString() classification?: string;
  @IsOptional() @IsDateString() occurredAt?: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() categorie?: string;
  @IsOptional() @IsInt() severity?: number;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsString() zone?: string;
}

export class TransformFeedbackDto {
  @IsIn(['ACTION', 'NON_CONFORMITY', 'SAFETY_EVENT']) targetModule!: 'ACTION' | 'NON_CONFORMITY' | 'SAFETY_EVENT';
  @IsOptional() @IsString() userId?: string;
  @IsOptional() @ValidateNested() @Type(() => SafetyTalkFeedbackOverridesDto) overrides?: SafetyTalkFeedbackOverridesDto;
}
