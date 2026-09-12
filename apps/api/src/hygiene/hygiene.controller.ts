import { Body, Controller, Get, Param, Post, Put, Query, Req, UseGuards, ForbiddenException } from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard'; // réutiliser le guard JWT existant
import { HygieneService } from './hygiene.service';

// Rôles autorisés à voir/éditer le suivi médical nominatif — à adapter aux 8 rôles existants
const ROLES_ACCES_MEDICAL = ['ADMIN', 'RESPONSABLE_QHSE', 'RH', 'MEDECIN_TRAVAIL'];

@UseGuards(AuthGuard)
@Controller('hygiene')
export class HygieneController {
  constructor(private readonly hygiene: HygieneService) {}

  // ---------- RISQUES SANITAIRES ----------
  @Get('risques')
  listRisques(@Query() query: any) {
    return this.hygiene.listRisques(query);
  }

  @Post('risques')
  createRisque(@Body() body: any, @Req() req: any) {
    return this.hygiene.createRisque(body, req.user.id);
  }

  @Put('risques/:id')
  updateRisque(@Param('id') id: string, @Body() body: any, @Req() req: any) {
    return this.hygiene.updateRisque(id, body, req.user.id);
  }

  // ---------- EXPOSITIONS ----------
  @Get('expositions')
  listExpositions(@Query('hygieneRiskId') hygieneRiskId?: string) {
    return this.hygiene.listExpositions(hygieneRiskId);
  }

  @Post('expositions')
  createExposition(@Body() body: any) {
    return this.hygiene.createExposition(body);
  }

  // ---------- ERGONOMIE ----------
  @Get('ergonomie')
  listErgonomie(@Query() query: any) {
    return this.hygiene.listErgonomicAssessments(query);
  }

  @Post('ergonomie')
  createErgonomie(@Body() body: any, @Req() req: any) {
    return this.hygiene.createErgonomicAssessment(body, req.user.id);
  }

  @Put('ergonomie/:id')
  updateErgonomie(@Param('id') id: string, @Body() body: any) {
    return this.hygiene.updateErgonomicAssessment(id, body);
  }

  // ---------- TMS ----------
  @Get('tms')
  listTMS(@Query() query: any) {
    return this.hygiene.listTMSCases(query);
  }

  @Post('tms')
  createTMS(@Body() body: any) {
    return this.hygiene.createTMSCase(body);
  }

  // ---------- SUIVI MÉDICAL (accès restreint) ----------
  @Get('medical')
  listMedical(@Query() query: any, @Req() req: any) {
    if (!ROLES_ACCES_MEDICAL.includes(req.user.role)) {
      throw new ForbiddenException("Accès réservé aux rôles habilités (données de santé confidentielles).");
    }
    return this.hygiene.listMedicalSurveillance(query);
  }

  @Post('medical')
  createMedical(@Body() body: any, @Req() req: any) {
    if (!ROLES_ACCES_MEDICAL.includes(req.user.role)) {
      throw new ForbiddenException("Accès réservé aux rôles habilités (données de santé confidentielles).");
    }
    return this.hygiene.createMedicalSurveillance(body, req.user.id);
  }

  @Put('medical/:id')
  updateMedical(@Param('id') id: string, @Body() body: any, @Req() req: any) {
    if (!ROLES_ACCES_MEDICAL.includes(req.user.role)) {
      throw new ForbiddenException("Accès réservé aux rôles habilités (données de santé confidentielles).");
    }
    return this.hygiene.updateMedicalSurveillance(id, body, req.user.id);
  }

  // Résumé anonyme, accessible à tous les rôles QHSE pour le tableau de bord général
  @Get('medical/summary')
  medicalSummary() {
    return this.hygiene.medicalSummaryAnonyme();
  }

  // ---------- PÉNIBILITÉ ----------
  @Get('penibilite/facteurs')
  listPenibiliteFactors() {
    return this.hygiene.listPenibiliteFactors();
  }

  @Post('penibilite/facteurs')
  createPenibiliteFactor(@Body() body: any) {
    return this.hygiene.createPenibiliteFactor(body);
  }

  @Get('penibilite/expositions')
  listPenibiliteExpositions(@Query() query: any) {
    return this.hygiene.listPenibiliteExpositions(query);
  }

  @Post('penibilite/expositions')
  createPenibiliteExposition(@Body() body: any) {
    return this.hygiene.createPenibiliteExposition(body);
  }

  // ---------- TABLEAU DE BORD ----------
  @Get('dashboard')
  getDashboard(@Query() query: any) {
    return this.hygiene.getDashboard(query);
  }
}
