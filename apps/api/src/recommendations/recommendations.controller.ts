import { Body, Controller, Post } from '@nestjs/common';
import { suggestActions } from './recommendation-rules';

@Controller('recommendations')
export class RecommendationsController {
  // Le moteur propose, l'humain décide (accepter/modifier/refuser/ajouter) :
  // cet endpoint est volontairement sans effet de bord, il ne fait que suggérer.
  @Post('suggest')
  suggest(@Body() body: { title?: string; description?: string; category?: string }) {
    const text = `${body?.title || ''} ${body?.description || ''} ${body?.category || ''}`;
    return { suggestions: suggestActions(text) };
  }
}
