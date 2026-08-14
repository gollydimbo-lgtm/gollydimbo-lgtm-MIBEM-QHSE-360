import { RiskLevel } from "@prisma/client";

/**
 * Score = gravité × probabilité × exposition (exposition = 1 si omise,
 * ce qui revient à gravité × probabilité seul).
 * Seuils repris du document de conception V3 :
 *   1-10 FAIBLE · 11-25 MODERE · 26-50 ELEVE · >50 CRITIQUE
 */
export function computeRiskLevel(severity: number, probability: number, exposure?: number): { score: number; level: RiskLevel } {
  const score = severity * probability * (exposure ?? 1);
  let level: RiskLevel;
  if (score <= 10) level = RiskLevel.FAIBLE;
  else if (score <= 25) level = RiskLevel.MODERE;
  else if (score <= 50) level = RiskLevel.ELEVE;
  else level = RiskLevel.CRITIQUE;
  return { score, level };
}

/** Un risque ELEVE ou CRITIQUE déclenche automatiquement une action de traitement. */
export function requiresAutoAction(level: RiskLevel): boolean {
  return level === RiskLevel.ELEVE || level === RiskLevel.CRITIQUE;
}
