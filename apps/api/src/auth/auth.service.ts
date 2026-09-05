import { Injectable, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { createHash } from 'crypto';
import * as jwt from 'jsonwebtoken';
import { LoginDto } from './dto';

const REFRESH_EXPIRES_IN = '30d';
const REFRESH_EXPIRES_MS = 30 * 24 * 60 * 60 * 1000;

@Injectable()
export class AuthService {
  constructor(private db: PrismaService, private jwtSvc: JwtService, private config: ConfigService) {}

  private hashToken(token: string) {
    return createHash('sha256').update(token).digest('hex');
  }

  // Émet la paire de jetons (accès court + rafraîchissement long) et
  // enregistre le rafraîchissement en base (jamais en clair — seulement son
  // empreinte) pour pouvoir le vérifier et le révoquer plus tard.
  private async issueTokens(u: any) {
    const permissions = [...new Set(u.roles.flatMap((r: any) => r.role.permissions.map((p: any) => p.permission.code)))];
    const roles = u.roles.map((r: any) => r.role.name);
    const accessToken = this.jwtSvc.sign({ sub: u.id, email: u.email, roles, permissions });
    const refreshToken = jwt.sign({ sub: u.id }, this.config.get('REFRESH_SECRET')!, { expiresIn: REFRESH_EXPIRES_IN });
    await this.db.refreshToken.create({
      data: { userId: u.id, tokenHash: this.hashToken(refreshToken), expiresAt: new Date(Date.now() + REFRESH_EXPIRES_MS) },
    });
    return {
      accessToken, refreshToken,
      user: { id: u.id, email: u.email, firstName: u.firstName, lastName: u.lastName, roles, permissions },
    };
  }

  async login(d: LoginDto) {
    const u = await this.db.user.findUnique({
      where: { email: d.email.toLowerCase() },
      include: { roles: { include: { role: { include: { permissions: { include: { permission: true } } } } } } },
    });
    if (!u || u.status !== 'ACTIVE' || !(await bcrypt.compare(d.password, u.passwordHash))) throw new UnauthorizedException('Identifiants invalides');
    return this.issueTokens(u);
  }

  // Échange un jeton de rafraîchissement encore valide contre une nouvelle
  // paire de jetons. L'ancien rafraîchissement est immédiatement révoqué
  // (rotation) : s'il était volé et réutilisé après coup, ça ne fonctionnerait
  // plus, ce qui permet de détecter un usage frauduleux.
  async refresh(refreshToken: string) {
    if (!refreshToken) throw new UnauthorizedException('Jeton de rafraîchissement manquant');
    let payload: any;
    try { payload = jwt.verify(refreshToken, this.config.get('REFRESH_SECRET')!); }
    catch { throw new UnauthorizedException('Session expirée, reconnexion nécessaire'); }
    const tokenHash = this.hashToken(refreshToken);
    const record = await this.db.refreshToken.findFirst({ where: { userId: payload.sub, tokenHash, revokedAt: null } });
    if (!record || record.expiresAt < new Date()) throw new UnauthorizedException('Session expirée, reconnexion nécessaire');
    await this.db.refreshToken.update({ where: { id: record.id }, data: { revokedAt: new Date() } });
    const u = await this.db.user.findUnique({
      where: { id: payload.sub },
      include: { roles: { include: { role: { include: { permissions: { include: { permission: true } } } } } } },
    });
    if (!u || u.status !== 'ACTIVE') throw new UnauthorizedException('Compte introuvable ou désactivé');
    return this.issueTokens(u);
  }

  // Révoque le jeton de rafraîchissement côté serveur — sans ça, une
  // déconnexion n'était qu'un oubli local, le jeton restait valide 30 jours.
  async logout(refreshToken: string) {
    if (refreshToken) await this.db.refreshToken.updateMany({ where: { tokenHash: this.hashToken(refreshToken), revokedAt: null }, data: { revokedAt: new Date() } });
    return { success: true };
  }

  async changePassword(email: string, currentPassword: string, newPassword: string) {
    if (!newPassword || newPassword.length < 8) throw new BadRequestException('Le nouveau mot de passe doit contenir au moins 8 caractères');
    const u = await this.db.user.findUnique({ where: { email: email.toLowerCase() } });
    if (!u || !(await bcrypt.compare(currentPassword, u.passwordHash))) throw new UnauthorizedException('Mot de passe actuel incorrect');
    const passwordHash = await bcrypt.hash(newPassword, 10);
    await this.db.user.update({ where: { id: u.id }, data: { passwordHash } });
    return { success: true };
  }
}
