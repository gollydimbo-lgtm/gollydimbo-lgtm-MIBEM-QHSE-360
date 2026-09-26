import { IsBoolean,IsDateString,IsInt,IsNumber,IsOptional,IsString } from 'class-validator';

// DTOs du module Réclamations clients (finding #2). reclamationCreate/
// reclamationUpdate faisaient un passthrough brut stripSystemFields(b),
// sans aucun recalcul serveur : un client pouvait donc falsifier statut,
// dateCloture ou scoreCriticite directement. Champs volontairement
// absents : id/createdAt/updatedAt (système), archivedAt (jamais de
// suppression définitive — géré par reclamationDelete), dateCloture
// (posé par le workflow de clôture dédié), scoreCriticite (dérivé de
// gravite, jamais ressaisi directement).
export class CreateReclamationDto {
  @IsString() code!: string;
  @IsString() client!: string;
  @IsOptional() @IsString() typeClient?: string;
  @IsOptional() @IsString() clientContact?: string;
  @IsString() motif!: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() canal?: string;
  @IsOptional() @IsDateString() date?: string;
  @IsOptional() @IsDateString() dateEvenement?: string;
  @IsOptional() @IsString() produitService?: string;
  @IsOptional() @IsString() reference?: string;
  @IsOptional() @IsString() lotNumber?: string;
  @IsOptional() @IsString() commandeNumber?: string;
  @IsOptional() @IsString() factureNumber?: string;
  @IsOptional() @IsNumber() quantiteConcernee?: number;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() fournisseurId?: string;
  @IsOptional() @IsString() categorieProbleme?: string;
  @IsOptional() @IsString() gravite?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsDateString() dateAccuseReception?: string;
  @IsOptional() @IsDateString() datePremiereReponse?: string;
  @IsOptional() @IsDateString() dateResolutionPrevue?: string;
  @IsOptional() @IsDateString() dateResolutionReelle?: string;
  @IsOptional() @IsInt() delaiCibleJours?: number;
  @IsOptional() @IsString() actionCurative?: string;
  @IsOptional() @IsString() actionCurativeResponsableId?: string;
  @IsOptional() @IsDateString() actionCurativeDate?: string;
  @IsOptional() @IsNumber() actionCurativeCout?: number;
  @IsOptional() @IsString() methodeAnalyse?: string;
  @IsOptional() @IsString() pourquoi1?: string;
  @IsOptional() @IsString() pourquoi2?: string;
  @IsOptional() @IsString() pourquoi3?: string;
  @IsOptional() @IsString() pourquoi4?: string;
  @IsOptional() @IsString() pourquoi5?: string;
  @IsOptional() @IsString() categorieCauseIshikawa?: string;
  @IsOptional() @IsString() causeRacine?: string;
  @IsOptional() @IsString() efficacite?: string;
  @IsOptional() @IsString() satisfaction?: string;
  @IsOptional() @IsNumber() noteSatisfaction?: number;
  @IsOptional() @IsString() commentaireClient?: string;
  @IsOptional() @IsNumber() coutRemboursement?: number;
  @IsOptional() @IsNumber() coutRemplacement?: number;
  @IsOptional() @IsNumber() coutTransport?: number;
  @IsOptional() @IsNumber() coutMainOeuvre?: number;
  @IsOptional() @IsNumber() coutAutres?: number;
  @IsOptional() @IsBoolean() recurrente?: boolean;
  @IsOptional() @IsString() nonConformityId?: string;
}
export class UpdateReclamationDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() client?: string;
  @IsOptional() @IsString() typeClient?: string;
  @IsOptional() @IsString() clientContact?: string;
  @IsOptional() @IsString() motif?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() canal?: string;
  @IsOptional() @IsDateString() date?: string;
  @IsOptional() @IsDateString() dateEvenement?: string;
  @IsOptional() @IsString() produitService?: string;
  @IsOptional() @IsString() reference?: string;
  @IsOptional() @IsString() lotNumber?: string;
  @IsOptional() @IsString() commandeNumber?: string;
  @IsOptional() @IsString() factureNumber?: string;
  @IsOptional() @IsNumber() quantiteConcernee?: number;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() processusId?: string;
  @IsOptional() @IsString() fournisseurId?: string;
  @IsOptional() @IsString() categorieProbleme?: string;
  @IsOptional() @IsString() gravite?: string;
  @IsOptional() @IsString() statut?: string;
  @IsOptional() @IsDateString() dateAccuseReception?: string;
  @IsOptional() @IsDateString() datePremiereReponse?: string;
  @IsOptional() @IsDateString() dateResolutionPrevue?: string;
  @IsOptional() @IsDateString() dateResolutionReelle?: string;
  @IsOptional() @IsInt() delaiCibleJours?: number;
  @IsOptional() @IsString() actionCurative?: string;
  @IsOptional() @IsString() actionCurativeResponsableId?: string;
  @IsOptional() @IsDateString() actionCurativeDate?: string;
  @IsOptional() @IsNumber() actionCurativeCout?: number;
  @IsOptional() @IsString() methodeAnalyse?: string;
  @IsOptional() @IsString() pourquoi1?: string;
  @IsOptional() @IsString() pourquoi2?: string;
  @IsOptional() @IsString() pourquoi3?: string;
  @IsOptional() @IsString() pourquoi4?: string;
  @IsOptional() @IsString() pourquoi5?: string;
  @IsOptional() @IsString() categorieCauseIshikawa?: string;
  @IsOptional() @IsString() causeRacine?: string;
  @IsOptional() @IsString() efficacite?: string;
  @IsOptional() @IsString() satisfaction?: string;
  @IsOptional() @IsNumber() noteSatisfaction?: number;
  @IsOptional() @IsString() commentaireClient?: string;
  @IsOptional() @IsNumber() coutRemboursement?: number;
  @IsOptional() @IsNumber() coutRemplacement?: number;
  @IsOptional() @IsNumber() coutTransport?: number;
  @IsOptional() @IsNumber() coutMainOeuvre?: number;
  @IsOptional() @IsNumber() coutAutres?: number;
  @IsOptional() @IsBoolean() recurrente?: boolean;
  @IsOptional() @IsString() nonConformityId?: string;
}
