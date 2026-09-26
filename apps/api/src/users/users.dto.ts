import { IsEmail, IsIn, IsOptional, IsString, MinLength } from 'class-validator';

// DTOs du module Utilisateurs (finding #2). Le service n'a jamais fait de
// spread `...b` nulle part (chaque champ est extrait explicitement avant
// d'être écrit en base), donc aucune vraie faille de mass assignment ici :
// l'apport de ces DTOs est la validation d'entrée (format email, longueur
// de mot de passe, valeurs de statut) qui manquait avec `@Body()b:any`.

export class CreateUserDto {
  @IsEmail() email!: string;
  @IsString() @MinLength(8) password!: string;
  @IsString() firstName!: string;
  @IsString() lastName!: string;
  @IsString() role!: string;
  @IsOptional() @IsString() siteId?: string | null;
}

export class UpdateUserStatusDto {
  @IsIn(['ACTIVE', 'INACTIVE']) status!: 'ACTIVE' | 'INACTIVE';
}

export class UpdateUserSiteDto {
  @IsOptional() @IsString() siteId!: string | null;
}

export class ResetPasswordDto {
  @IsString() @MinLength(8) newPassword!: string;
}
