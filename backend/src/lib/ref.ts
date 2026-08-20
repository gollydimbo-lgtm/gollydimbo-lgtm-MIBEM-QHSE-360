/**
 * Génère une référence lisible du type PREFIX-ANNEE-XXXXXX.
 * Le suffixe aléatoire suffit pour un volume MIBEM (quelques centaines
 * de contrôles/jour) ; à remplacer par un compteur séquentiel en base
 * si un jour une numérotation strictement continue est exigée par un audit.
 */
export function ref(prefix: string): string {
  const year = new Date().getFullYear();
  const random = Math.floor(Math.random() * 900000) + 100000;
  return `${prefix}-${year}-${random}`;
}
