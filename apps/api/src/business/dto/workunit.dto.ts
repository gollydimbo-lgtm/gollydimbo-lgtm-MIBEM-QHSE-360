import { IsBoolean, IsOptional, IsString } from 'class-validator';

// DTOs WorkUnit (finding #2). Le service faisait
// `data:stripSystemFields(b)` (id/createdAt/updatedAt seulement retirés) :
// pas de recalcul serveur trouvé sur ce modèle, donc pas de faille réelle,
// mais aucune validation d'entrée n'existait avec `@Body()b:any`.

export class CreateWorkUnitDto {
  @IsString() code!: string;
  @IsString() name!: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() department?: string;
  @IsOptional() @IsString() service?: string;
  @IsOptional() @IsBoolean() active?: boolean;
}
export class UpdateWorkUnitDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsString() department?: string;
  @IsOptional() @IsString() service?: string;
  @IsOptional() @IsBoolean() active?: boolean;
}
