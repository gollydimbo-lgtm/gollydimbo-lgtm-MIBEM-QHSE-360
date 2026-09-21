import { Roles } from '../common/roles.decorator';
import { RoleName } from '@prisma/client';
import { Body, Controller, Delete, Get, Param, Patch, Post } from '@nestjs/common';
import { HaccpService } from './haccp.service';

@Controller('haccp')
export class HaccpController {
  constructor(private s: HaccpService) {}

  // --- Dashboard / matrice ---
  @Get('dashboard') dashboard() { return this.s.dashboard(); }
  @Get('matrice') matrice() { return this.s.matrice(); }

  // --- Études ---
  @Get('studies') studiesList() { return this.s.studiesList(); }
  @Post('studies') studyCreate(@Body() b: any) { return this.s.studyCreate(b); }
  @Get('studies/:id') studyGet(@Param('id') id: string) { return this.s.studyGet(id); }
  @Patch('studies/:id') studyUpdate(@Param('id') id: string, @Body() b: any) { return this.s.studyUpdate(id, b); }
  @Delete('studies/:id') @Roles(RoleName.ADMINISTRATEUR,RoleName.RESPONSABLE_QHSE) studyDelete(@Param('id') id: string) { return this.s.studyDelete(id); }
  @Post('studies/:id/validate') studyValidate(@Param('id') id: string, @Body() b: any) { return this.s.studyValidate(id, b); }
  @Post('studies/:id/revise') studyRevise(@Param('id') id: string, @Body() b: any) { return this.s.studyRevise(id, b); }

  // --- Équipe ---
  @Get('studies/:id/team') teamList(@Param('id') id: string) { return this.s.teamList(id); }
  @Post('studies/:id/team') teamAdd(@Param('id') id: string, @Body() b: any) { return this.s.teamAdd(id, b); }
  @Delete('team/:memberId') @Roles(RoleName.ADMINISTRATEUR,RoleName.RESPONSABLE_QHSE) teamRemove(@Param('memberId') memberId: string) { return this.s.teamRemove(memberId); }

  // --- Diagramme de flux (étapes) ---
  @Get('studies/:id/steps') stepsList(@Param('id') id: string) { return this.s.stepsList(id); }
  @Post('studies/:id/steps') stepCreate(@Param('id') id: string, @Body() b: any) { return this.s.stepCreate(id, b); }
  @Post('studies/:id/steps/reorder') stepsReorder(@Param('id') id: string, @Body() b: any) { return this.s.stepsReorder(id, b); }
  @Patch('steps/:id') stepUpdate(@Param('id') id: string, @Body() b: any) { return this.s.stepUpdate(id, b); }
  @Delete('steps/:id') @Roles(RoleName.ADMINISTRATEUR,RoleName.RESPONSABLE_QHSE) stepDelete(@Param('id') id: string) { return this.s.stepDelete(id); }

  // --- Analyse des dangers ---
  @Get('studies/:id/hazards') hazardsByStudy(@Param('id') id: string) { return this.s.hazardsByStudy(id); }
  @Post('steps/:stepId/hazards') hazardCreate(@Param('stepId') stepId: string, @Body() b: any) { return this.s.hazardCreate(stepId, b); }
  @Patch('hazards/:id') hazardUpdate(@Param('id') id: string, @Body() b: any) { return this.s.hazardUpdate(id, b); }
  @Delete('hazards/:id') @Roles(RoleName.ADMINISTRATEUR,RoleName.RESPONSABLE_QHSE) hazardDelete(@Param('id') id: string) { return this.s.hazardDelete(id); }

  // --- CCP / CP ---
  @Get('studies/:id/ccps') ccpsByStudy(@Param('id') id: string) { return this.s.ccpsByStudy(id); }
  @Post('hazards/:hazardId/ccps') ccpCreate(@Param('hazardId') hazardId: string, @Body() b: any) { return this.s.ccpCreate(hazardId, b); }
  @Patch('ccps/:id') ccpUpdate(@Param('id') id: string, @Body() b: any) { return this.s.ccpUpdate(id, b); }
  @Delete('ccps/:id') @Roles(RoleName.ADMINISTRATEUR,RoleName.RESPONSABLE_QHSE) ccpDelete(@Param('id') id: string) { return this.s.ccpDelete(id); }

  // --- Surveillance CCP (le geste terrain le plus important) ---
  @Get('ccps/:ccpId/monitoring') monitoringByCcp(@Param('ccpId') ccpId: string) { return this.s.monitoringByCcp(ccpId); }
  @Post('ccps/:ccpId/monitoring') monitoringCreate(@Param('ccpId') ccpId: string, @Body() b: any) { return this.s.monitoringCreate(ccpId, b); }
  @Patch('monitoring/:id') monitoringUpdate(@Param('id') id: string, @Body() b: any) { return this.s.monitoringUpdate(id, b); }
  @Get('monitoring/today') monitoringToday() { return this.s.monitoringToday(); }
  @Get('monitoring/overdue') monitoringOverdue() { return this.s.monitoringOverdue(); }

  // --- PRP ---
  @Get('prps') prpsList() { return this.s.prpsList(); }
  @Post('prps') prpCreate(@Body() b: any) { return this.s.prpCreate(b); }
  @Patch('prps/:id') prpUpdate(@Param('id') id: string, @Body() b: any) { return this.s.prpUpdate(id, b); }
  @Delete('prps/:id') @Roles(RoleName.ADMINISTRATEUR,RoleName.RESPONSABLE_QHSE) prpDelete(@Param('id') id: string) { return this.s.prpDelete(id); }
}
