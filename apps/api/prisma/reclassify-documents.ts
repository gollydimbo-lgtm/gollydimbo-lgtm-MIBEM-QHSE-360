// Reclassification du référentiel documentaire QHSE en 5 groupes.
// STRICTEMENT ADDITIF : ce script ne fait que UPDATE le champ documentGroup
// des documents déjà présents en base qui correspondent à l'un des 19 types
// connus (par mots-clés dans le code ou le titre). Il ne supprime rien, ne
// crée rien, et n'écrase aucun autre champ (title, category, versions,
// attachments... restent intacts). Ré-exécutable sans risque.
import { PrismaClient, DocumentGroup } from '@prisma/client';
const db = new PrismaClient();

// Règles dans l'ordre de votre classification (1 à 19). Chaque règle teste
// des mots-clés (insensibles à la casse) dans le code OU le titre du document.
type Rule = { keywords: string[]; group: DocumentGroup; label: string };
const RULES: Rule[] = [
  // 1. Stratégie et Contexte
  { keywords: ['prise de fonction'], group: 'STRATEGIE_CONTEXTE', label: '01 Documents prise de fonction' },
  { keywords: ['manuel qhse', 'manuel qualité'], group: 'STRATEGIE_CONTEXTE', label: '02 Manuel QHSE' },
  { keywords: ['politique', 'objectifs', 'organigramme'], group: 'STRATEGIE_CONTEXTE', label: '03 Politique / Objectifs / Organigramme' },

  // 2. Risques, Sécurité et Conformité
  { keywords: ['gestion des risques', 'duerp'], group: 'RISQUES_SECURITE_CONFORMITE', label: '07 Gestion des risques DUERP' },
  { keywords: ['registre des risques', 'matrice des risques', 'matrice risque'], group: 'RISQUES_SECURITE_CONFORMITE', label: '08 DUERP registre / matrice' },
  { keywords: ['haccp'], group: 'RISQUES_SECURITE_CONFORMITE', label: '09 Plan HACCP boissons alcoolisées' },

  // 3. Supports et Maîtrise Documentaire
  { keywords: ['procédure', 'procedure'], group: 'SUPPORTS_MAITRISE_DOCUMENTAIRE', label: '04 Procédures QHSE' },
  { keywords: ['formulaire'], group: 'SUPPORTS_MAITRISE_DOCUMENTAIRE', label: '05 Formulaires QHSE' },
  { keywords: ['liste maîtresse', 'liste maitresse'], group: 'SUPPORTS_MAITRISE_DOCUMENTAIRE', label: '12 Liste maîtresse des documents' },
  { keywords: ['gestion documentaire', 'iso'], group: 'SUPPORTS_MAITRISE_DOCUMENTAIRE', label: '17 Gestion documentaire ISO' },

  // 4. Opérations et Maîtrise Terrain
  { keywords: ["plan d'urgence", 'plans urgence', "plans d'urgence"], group: 'OPERATIONS_MAITRISE_TERRAIN', label: "10 Plans d'urgence" },
  { keywords: ['gestion hse générale', 'gestion hse generale'], group: 'OPERATIONS_MAITRISE_TERRAIN', label: '11 Gestion HSE générale' },
  { keywords: ['contrôle qualité mp', 'controle qualite mp', 'contrôle qualité mp/pf'], group: 'OPERATIONS_MAITRISE_TERRAIN', label: '14/15 Contrôle qualité MP/PF' },

  // 5. Évaluation, Contrôle et Amélioration
  { keywords: ['tableau de bord', 'registres qhse', 'registre qhse'], group: 'EVALUATION_CONTROLE_AMELIORATION', label: '06 Registres / Tableaux de bord' },
  { keywords: ['registre audit', 'registre formation', 'registre équipement', 'registre equipement'], group: 'EVALUATION_CONTROLE_AMELIORATION', label: '13 Registres audits / formation / équipements' },
  { keywords: ['indicateur de performance', 'indicateurs performance'], group: 'EVALUATION_CONTROLE_AMELIORATION', label: '16 Indicateurs performance QHSE' },
  { keywords: ['non-conformité', 'non conformité', 'gestion des non-conformités'], group: 'EVALUATION_CONTROLE_AMELIORATION', label: '18/19 Gestion des non-conformités' },
];

function normalize(s: string) {
  return s.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

async function main() {
  const documents = await db.document.findMany({ select: { id: true, code: true, title: true, category: true, documentGroup: true } });
  console.log(`${documents.length} document(s) trouvé(s) en base.\n`);

  let matched = 0;
  const unmatched: string[] = [];

  for (const doc of documents) {
    const haystack = normalize(`${doc.code} ${doc.title} ${doc.category}`);
    const rule = RULES.find(r => r.keywords.some(k => haystack.includes(normalize(k))));
    if (rule) {
      if (doc.documentGroup !== rule.group) {
        await db.document.update({ where: { id: doc.id }, data: { documentGroup: rule.group } });
        console.log(`✔ ${doc.code} — "${doc.title}" -> ${rule.label} [${rule.group}]`);
      } else {
        console.log(`= ${doc.code} — "${doc.title}" déjà classé [${rule.group}]`);
      }
      matched++;
    } else {
      unmatched.push(`${doc.code} — "${doc.title}" (catégorie: "${doc.category}")`);
    }
  }

  console.log(`\n${matched} document(s) reclassé(s) ou déjà à jour.`);
  if (unmatched.length) {
    console.log(`${unmatched.length} document(s) sans correspondance automatique (à classer manuellement dans le GED) :`);
    for (const u of unmatched) console.log('  -', u);
  }
}

main().catch(e => { console.error(e); process.exit(1); }).finally(() => db.$disconnect());
