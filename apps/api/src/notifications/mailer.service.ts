import { Injectable, Logger } from '@nestjs/common';
import * as nodemailer from 'nodemailer';

// Envoi e-mail des notifications critiques/warning (findings #25/#26/#40).
// Configuration exclusivement par variables d'environnement (SMTP_HOST,
// SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM — voir .env.example) : choix
// du 26/09 pour ne pas coder d'identifiants en dur. Tant que SMTP_HOST
// n'est pas renseigné, le service journalise et ne bloque jamais l'appelant
// (génération des notifications toujours fonctionnelle sans SMTP configuré).
@Injectable()
export class MailerService {
  private readonly logger = new Logger(MailerService.name);
  private transporter: nodemailer.Transporter | null = null;
  private transporterTente = false;

  private getTransporter(): nodemailer.Transporter | null {
    if (this.transporterTente) return this.transporter;
    this.transporterTente = true;
    const host = process.env.SMTP_HOST;
    if (!host) return null;
    this.transporter = nodemailer.createTransport({
      host,
      port: Number(process.env.SMTP_PORT ?? 587),
      secure: process.env.SMTP_SECURE === 'true',
      auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
    });
    return this.transporter;
  }

  async envoyerNotificationsCritiques(
    destinataires: string[],
    notifications: Array<{ module: string; niveau: string; titre: string; detail?: string | null }>,
  ): Promise<{ envoye: boolean; raison?: string }> {
    if (!destinataires.length || !notifications.length) {
      return { envoye: false, raison: 'aucun destinataire ou aucune notification' };
    }
    const transporter = this.getTransporter();
    if (!transporter) {
      this.logger.warn(`SMTP non configuré (SMTP_HOST manquant) : ${notifications.length} notification(s) non envoyée(s) par e-mail.`);
      return { envoye: false, raison: 'SMTP non configuré' };
    }
    const texte = notifications.map((n) => `- [${n.niveau}] ${n.module} — ${n.titre}${n.detail ? ' : ' + n.detail : ''}`).join('\n');
    const html = `<p>${notifications.length} nouvelle(s) notification(s) QHSE nécessitent votre attention :</p><ul>${notifications
      .map((n) => `<li><strong>[${n.niveau}] ${n.module}</strong> — ${n.titre}${n.detail ? ' : ' + n.detail : ''}</li>`)
      .join('')}</ul>`;
    try {
      await transporter.sendMail({
        from: process.env.SMTP_FROM ?? process.env.SMTP_USER,
        to: destinataires,
        subject: `QHSE 360 — ${notifications.length} nouvelle(s) alerte(s)`,
        text: texte,
        html,
      });
      return { envoye: true };
    } catch (err) {
      this.logger.error(`Échec envoi e-mail notifications : ${(err as Error).message}`);
      return { envoye: false, raison: (err as Error).message };
    }
  }
}
