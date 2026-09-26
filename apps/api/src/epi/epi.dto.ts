import { IsBoolean,IsDateString,IsIn,IsInt,IsNumber,IsOptional,IsString } from 'class-validator';

// DTOs du module EPI/EPC/Employés (finding #2). Champs volontairement
// absents partout : id/createdAt/updatedAt (système).
export class CreateEmployeeDto {
  @IsString() matricule!: string;
  @IsString() firstName!: string;
  @IsString() lastName!: string;
  @IsOptional() @IsString() department?: string;
  @IsOptional() @IsString() position?: string;
  @IsOptional() @IsBoolean() active?: boolean;
}
export class UpdateEmployeeDto {
  @IsOptional() @IsString() matricule?: string;
  @IsOptional() @IsString() firstName?: string;
  @IsOptional() @IsString() lastName?: string;
  @IsOptional() @IsString() department?: string;
  @IsOptional() @IsString() position?: string;
  @IsOptional() @IsBoolean() active?: boolean;
}

// Catalogue EPI (entité Epi).
export class CreateEpiDto {
  @IsString() code!: string;
  @IsString() name!: string;
  @IsString() frequency!: string;
  @IsOptional() @IsString() unit?: string;
  @IsOptional() @IsInt() annualValidityDays?: number;
  @IsOptional() @IsInt() minStock?: number;
  @IsOptional() @IsBoolean() active?: boolean;
  @IsOptional() @IsString() categoryId?: string;
  @IsOptional() @IsString() reference?: string;
  @IsOptional() @IsString() subcategory?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() manufacturer?: string;
  @IsOptional() @IsString() model?: string;
  @IsOptional() @IsString() size?: string;
  @IsOptional() @IsString() color?: string;
  @IsOptional() @IsString() material?: string;
  @IsOptional() @IsString() standard?: string;
  @IsOptional() @IsString() durationMode?: string;
  @IsOptional() @IsInt() durationValueDays?: number;
  @IsOptional() @IsBoolean() disposable?: boolean;
  @IsOptional() @IsBoolean() shared?: boolean;
  @IsOptional() @IsInt() maxStock?: number;
  @IsOptional() @IsString() location?: string;
  @IsOptional() @IsString() status?: string;
}
export class UpdateEpiDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() frequency?: string;
  @IsOptional() @IsString() unit?: string;
  @IsOptional() @IsInt() annualValidityDays?: number;
  @IsOptional() @IsInt() minStock?: number;
  @IsOptional() @IsBoolean() active?: boolean;
  @IsOptional() @IsString() categoryId?: string;
  @IsOptional() @IsString() reference?: string;
  @IsOptional() @IsString() subcategory?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() manufacturer?: string;
  @IsOptional() @IsString() model?: string;
  @IsOptional() @IsString() size?: string;
  @IsOptional() @IsString() color?: string;
  @IsOptional() @IsString() material?: string;
  @IsOptional() @IsString() standard?: string;
  @IsOptional() @IsString() durationMode?: string;
  @IsOptional() @IsInt() durationValueDays?: number;
  @IsOptional() @IsBoolean() disposable?: boolean;
  @IsOptional() @IsBoolean() shared?: boolean;
  @IsOptional() @IsInt() maxStock?: number;
  @IsOptional() @IsString() location?: string;
  @IsOptional() @IsString() status?: string;
}

// Mouvement de stock EPI — pas d'endpoint de modification (create seul).
export class CreateEpiMovementDto {
  @IsString() epiId!: string;
  @IsString() type!: string;
  @IsInt() quantity!: number;
  @IsOptional() @IsString() employeeId?: string;
  @IsOptional() @IsDateString() distributionDate?: string;
  @IsOptional() @IsString() userId?: string;
  @IsOptional() @IsString() note?: string;
}

export class CreateEpiCategoryDto {
  @IsString() name!: string;
}
export class UpdateEpiCategoryDto {
  @IsOptional() @IsString() name?: string;
}

export class CreateEpcCategoryDto {
  @IsString() name!: string;
}
export class UpdateEpcCategoryDto {
  @IsOptional() @IsString() name?: string;
}

export class CreateEpcDto {
  @IsString() code!: string;
  @IsString() name!: string;
  @IsOptional() @IsString() categoryId?: string;
  @IsOptional() @IsString() location?: string;
  @IsOptional() @IsString() zone?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() manufacturer?: string;
  @IsOptional() @IsString() model?: string;
  @IsOptional() @IsString() reference?: string;
  @IsOptional() @IsDateString() installedAt?: string;
  @IsOptional() @IsString() responsibleId?: string;
  @IsOptional() @IsString() condition?: string;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsInt() inspectionFrequencyDays?: number;
  @IsOptional() @IsDateString() lastInspectionAt?: string;
  @IsOptional() @IsDateString() nextInspectionAt?: string;
  @IsOptional() @IsString() notes?: string;
}
export class UpdateEpcDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() categoryId?: string;
  @IsOptional() @IsString() location?: string;
  @IsOptional() @IsString() zone?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() manufacturer?: string;
  @IsOptional() @IsString() model?: string;
  @IsOptional() @IsString() reference?: string;
  @IsOptional() @IsDateString() installedAt?: string;
  @IsOptional() @IsString() responsibleId?: string;
  @IsOptional() @IsString() condition?: string;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsInt() inspectionFrequencyDays?: number;
  @IsOptional() @IsDateString() lastInspectionAt?: string;
  @IsOptional() @IsDateString() nextInspectionAt?: string;
  @IsOptional() @IsString() notes?: string;
}

export class CreateEpiInspectionDto {
  @IsString() epiId!: string;
  @IsOptional() @IsString() employeeId?: string;
  @IsOptional() @IsDateString() inspectedAt?: string;
  @IsString() result!: string;
  @IsOptional() @IsString() observations?: string;
  @IsOptional() @IsString() inspectedById?: string;
}

// epcId reste dans le DTO : lu par le service pour mettre à jour la fiche
// EPC associée (lastInspectionAt/nextInspectionAt), aucun recalcul ne
// l'écrase, mais c'est une donnée métier légitime du relevé.
export class CreateEpcInspectionDto {
  @IsString() epcId!: string;
  @IsOptional() @IsDateString() inspectedAt?: string;
  @IsString() result!: string;
  @IsOptional() @IsString() observations?: string;
  @IsOptional() @IsString() inspectedById?: string;
  @IsOptional() @IsDateString() nextInspectionAt?: string;
}

export class CreateJobRiskProtectionDto {
  @IsString() code!: string;
  @IsString() jobTitle!: string;
  @IsOptional() @IsString() activity?: string;
  @IsString() hazard!: string;
  @IsOptional() @IsString() riskDescription?: string;
  @IsOptional() @IsString() preventionMeasure?: string;
  @IsOptional() @IsString() epiId?: string;
  @IsOptional() @IsString() epcId?: string;
  @IsOptional() @IsString() usageFrequency?: string;
  @IsOptional() @IsString() controlCriteria?: string;
}
export class UpdateJobRiskProtectionDto {
  @IsOptional() @IsString() jobTitle?: string;
  @IsOptional() @IsString() activity?: string;
  @IsOptional() @IsString() hazard?: string;
  @IsOptional() @IsString() riskDescription?: string;
  @IsOptional() @IsString() preventionMeasure?: string;
  @IsOptional() @IsString() epiId?: string;
  @IsOptional() @IsString() epcId?: string;
  @IsOptional() @IsString() usageFrequency?: string;
  @IsOptional() @IsString() controlCriteria?: string;
}

export class CreateEpiAssignmentDto {
  @IsString() code!: string;
  @IsString() employeeId!: string;
  @IsString() epiId!: string;
  @IsInt() quantity!: number;
  @IsOptional() @IsString() size?: string;
  @IsDateString() distributedAt!: string;
  @IsOptional() @IsDateString() renewalAt?: string;
  @IsOptional() @IsInt() expectedDurationDays?: number;
  @IsOptional() @IsString() condition?: string;
  @IsOptional() @IsString() reason?: string;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsString() responsibleId?: string;
  @IsOptional() @IsString() employeeSignature?: string;
  @IsOptional() @IsString() responsibleSignature?: string;
}
export class UpdateEpiAssignmentDto {
  @IsOptional() @IsString() size?: string;
  @IsOptional() @IsDateString() distributedAt?: string;
  @IsOptional() @IsDateString() renewalAt?: string;
  @IsOptional() @IsInt() expectedDurationDays?: number;
  @IsOptional() @IsString() condition?: string;
  @IsOptional() @IsString() reason?: string;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsString() responsibleId?: string;
  @IsOptional() @IsString() employeeSignature?: string;
  @IsOptional() @IsString() responsibleSignature?: string;
}

export class CreateEpcMaintenanceDto {
  @IsString() epcId!: string;
  @IsOptional() @IsDateString() date?: string;
  @IsString() type!: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsNumber() cost?: number;
  @IsOptional() @IsString() performedById?: string;
  @IsOptional() @IsDateString() nextMaintenanceAt?: string;
  @IsOptional() @IsString() status?: string;
}
export class UpdateEpcMaintenanceDto {
  @IsOptional() @IsDateString() date?: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsNumber() cost?: number;
  @IsOptional() @IsString() performedById?: string;
  @IsOptional() @IsDateString() nextMaintenanceAt?: string;
  @IsOptional() @IsString() status?: string;
}
