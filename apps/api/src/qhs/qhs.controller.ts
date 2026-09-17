import { Body, Controller, Delete, Get, Param, Patch, Post } from '@nestjs/common';
import { QhsService } from './qhs.service';

@Controller('safety-talks')
export class QhsController {
  constructor(private s: QhsService) {}
  @Post('generate') generate() { return this.s.generate(); }
  @Get() list() { return this.s.list(); }
  @Post(':id/approve') approve(@Param('id') id: string) { return this.s.approve(id); }
  @Post(':id/deliver') deliver(@Param('id') id: string) { return this.s.deliver(id); }
  @Delete(':id') remove(@Param('id') id: string) { return this.s.remove(id); }

  // --- Dashboard / matrice / bibliothèque / règles (routes littérales avant :id) ---
  @Get('dashboard') dashboard() { return this.s.dashboard(); }
  @Get('matrice') matrice() { return this.s.matrice(); }
  @Get('library') library() { return this.s.themeLibrary(); }
  @Get('rules') rulesList() { return this.s.rulesList(); }
  @Post('rules') rulesUpsert(@Body() b: any) { return this.s.rulesUpsert(b); }
  @Delete('rules/:id') rulesDelete(@Param('id') id: string) { return this.s.rulesDelete(id); }

  // --- Moteur de recommandation ---
  @Get('recommendations') recommendationsList() { return this.s.recommendationsList(); }
  @Post('recommendations/refresh') recommendationsRefresh() { return this.s.recommendations(); }
  @Post('recommendations/:id/decision') recommendationDecision(@Param('id') id: string, @Body() b: any) { return this.s.recommendationDecision(id, b); }
  @Post('recommendations/:id/generate') recommendationGenerate(@Param('id') id: string, @Body() b: any) { return this.s.generateFromRecommendation(id, b); }

  // --- Création / édition manuelle ---
  @Post() create(@Body() b: any) { return this.s.create(b); }
  @Patch(':id') update(@Param('id') id: string, @Body() b: any) { return this.s.update(id, b); }

  // --- Planification ---
  @Post(':id/schedule') schedule(@Param('id') id: string, @Body() b: any) { return this.s.schedule(id, b); }
  @Post(':id/postpone') postpone(@Param('id') id: string, @Body() b: any) { return this.s.postpone(id, b); }
  @Post(':id/cancel') cancel(@Param('id') id: string, @Body() b: any) { return this.s.cancel(id, b); }

  // --- Émargement ---
  @Get(':id/participants') participantsList(@Param('id') id: string) { return this.s.participantsList(id); }
  @Post(':id/participants') addParticipant(@Param('id') id: string, @Body() b: any) { return this.s.addParticipant(id, b); }
  @Post(':id/participants/bulk') bulkAddParticipants(@Param('id') id: string, @Body() b: any) { return this.s.bulkAddParticipants(id, b); }

  // --- Remontées terrain ---
  @Get(':id/feedbacks') feedbackList(@Param('id') id: string) { return this.s.feedbackList(id); }
  @Post(':id/feedbacks') addFeedback(@Param('id') id: string, @Body() b: any) { return this.s.addFeedback(id, b); }

  // --- Quiz ---
  @Post(':id/quiz') quizSubmit(@Param('id') id: string, @Body() b: any) { return this.s.quizSubmit(id, b); }
  @Get(':id/quiz-stats') quizStats(@Param('id') id: string) { return this.s.quizStats(id); }

  // --- Suppression participant / transformation d'une remontée terrain ---
  // Nichées sous /safety-talks (plutôt que les chemins top-level du cahier des
  // charges) pour ne pas devoir enregistrer un second contrôleur dans
  // qhs.module.ts, fichier volontairement non modifié par cette tâche.
  @Delete('participants/:participantId') removeParticipant(@Param('participantId') participantId: string) { return this.s.removeParticipant(participantId); }
  @Post('feedbacks/:feedbackId/transform') transformFeedback(@Param('feedbackId') feedbackId: string, @Body() b: any) { return this.s.transformFeedback(feedbackId, b); }
}
