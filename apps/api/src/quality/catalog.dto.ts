import { IsArray, IsBoolean, IsInt, IsOptional, IsString, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

// DTOs du contrôleur quality/catalog.controller.ts (finding #2) — catalogue
// production : Site, Product/ProductFormat, ProductionLine, Machine, Shift.
// Chaque endpoint construisait déjà sa donnée champ par champ (pas de
// spread `...b`), donc pas de faille de mass assignment réelle ; l'apport
// est la validation d'entrée absente avec `@Body()b:any`.

export class CreateSiteDto {
  @IsString() code!: string;
  @IsString() name!: string;
  @IsOptional() @IsString() location?: string;
}

export class ProductFormatInputDto {
  @IsString() code!: string;
  @IsString() label!: string;
  @IsOptional() @IsInt() volumeMl?: number;
}
export class CreateProductDto {
  @IsString() code!: string;
  @IsString() name!: string;
  @IsOptional() @IsString() category?: string;
  @IsOptional() @IsArray() @ValidateNested({ each: true }) @Type(() => ProductFormatInputDto) formats?: ProductFormatInputDto[];
}

export class CreateProductionLineDto {
  @IsString() siteId!: string;
  @IsString() code!: string;
  @IsString() name!: string;
  @IsOptional() @IsString() area?: string;
}
export class UpdateProductionLineDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() area?: string;
  @IsOptional() @IsString() siteId?: string;
  @IsOptional() @IsBoolean() active?: boolean;
}

export class CreateMachineDto {
  @IsString() lineId!: string;
  @IsString() code!: string;
  @IsString() name!: string;
  @IsOptional() @IsString() category?: string;
}

export class CreateShiftDto {
  @IsString() code!: string;
  @IsString() name!: string;
  @IsOptional() @IsString() startTime?: string;
  @IsOptional() @IsString() endTime?: string;
}
