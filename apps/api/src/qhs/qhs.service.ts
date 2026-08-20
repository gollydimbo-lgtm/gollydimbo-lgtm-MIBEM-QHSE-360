import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';

@Injectable()
export class QhsService {
  constructor(private db: PrismaService) {}

  private mondayOf(d: Date) {
    const x = new Date(d);
    const day = x.getDay();
    const diff = (day === 0 ? -6 : 1) - day; // recule jusqu'au lundi
    x.setDate(x.getDate() + diff);
    x.setHours(0, 0, 0, 0);
    return x;
  }

  // Génère (ou régénère si déjà en brouillon) le thème du quart d'heure sécurité
  // de la semaine en cours, à partir des accidents/incidents/situations
  // dangereuses et des non-conformités critiques survenus les 7 derniers jours.
  async generate() {
    const weekStart = this.mondayOf(new Date());
    const weekEnd = new Date(weekStart); weekEnd.setDate(weekEnd.getDate() + 7);
    const since = new Date(); since.setDate(since.getDate() - 7);

    const [events, criticalNc] = await Promise.all([
      this.db.safetyEvent.findMany({ where: { occurredAt: { gte: since } }, orderBy: { severity: 'desc' } }),
      this.db.nonConformity.findMany({ where: { occurredAt: { gte: since }, severity: { gte: 4 } }, orderBy: { severity: 'desc' }, take: 5 }),
    ]);

    const byType: Record<string, number> = {};
    for (const e of events) byType[e.type] = (byType[e.type] || 0) + 1;
    const topType = Object.entries(byType).sort((a, b) => b[1] - a[1])[0];
    const mostSevere = events[0];

    const title = topType
      ? `Prévention : ${this.labelType(topType[0])}`
      : criticalNc.length > 0
      ? `Focus qualité : ${criticalNc[0].title}`
      : 'Rappel des consignes de sécurité générales';

    const lines: string[] = [];
    lines.push(`Période analysée : ${this.fmt(since)} → ${this.fmt(new Date())}.`);
    lines.push(`${events.length} événement(s) sécurité déclaré(s) cette semaine.`);
    if (topType) lines.push(`Type le plus fréquent : ${this.labelType(topType[0])} (${topType[1]} occurrence(s)).`);
    if (mostSevere) lines.push(`Événement le plus grave : « ${mostSevere.title} » (sévérité ${mostSevere.severity}).`);
    if (criticalNc.length > 0) lines.push(`${criticalNc.length} non-conformité(s) critique(s) associée(s) : ${criticalNc.map((n: { code: string }) => n.code).join(', ')}.`);
    if (events.length === 0 && criticalNc.length === 0) lines.push('Aucun événement notable cette semaine — profiter du quart d\'heure pour un rappel des bonnes pratiques et des EPI.');
    lines.push('Rappel : tout danger observé doit être déclaré immédiatement, même sans conséquence (presqu\'accident).');

    const existing = await this.db.safetyTalk.findUnique({ where: { weekStart } });
    const data = { weekStart, weekEnd, title, summary: lines.join('\n'), status: 'DRAFT' as const, generatedAt: new Date() };

    if (existing && existing.status === 'DRAFT') {
      return this.db.safetyTalk.update({ where: { weekStart }, data });
    }
    if (existing) return existing; // déjà approuvé/délivré : on ne l'écrase pas
    return this.db.safetyTalk.create({ data });
  }

  list() {
    return this.db.safetyTalk.findMany({ orderBy: { weekStart: 'desc' }, take: 20 });
  }

  approve(id: string) {
    return this.db.safetyTalk.update({ where: { id }, data: { status: 'APPROVED', approvedAt: new Date() } });
  }

  deliver(id: string) {
    return this.db.safetyTalk.update({ where: { id }, data: { status: 'DELIVERED' } });
  }

  private labelType(t: string) {
    return ({
      ACCIDENT: 'accidents',
      INCIDENT: 'incidents',
      PRESQU_ACCIDENT: 'presqu\'accidents',
      SITUATION_DANGEREUSE: 'situations dangereuses',
    } as Record<string, string>)[t] || t;
  }
  private fmt(d: Date) { return d.toISOString().slice(0, 10); }
}
