import { PrismaClient } from '@prisma/client';
const db = new PrismaClient();

const epiCategories = [
  'Protection de la tête', 'Protection des yeux', 'Protection du visage', 'Protection auditive',
  'Protection respiratoire', 'Protection des mains', 'Protection des bras', 'Protection des pieds',
  'Protection des jambes', 'Protection du corps', 'Protection contre les chutes de hauteur',
  'Protection électrique', 'Protection chimique', 'Protection thermique',
  'Protection contre les risques biologiques', 'Protection haute visibilité', 'Protection spécifique',
];

const epcCategories = [
  'Protection contre les chutes', 'Protection des machines', 'Protection contre les risques mécaniques',
  'Protection contre les produits chimiques', 'Protection incendie', 'Protection électrique',
  'Protection contre le bruit', 'Protection contre les poussières', 'Protection contre les fumées',
  'Ventilation', 'Extraction', 'Circulation', 'Séparation piétons/véhicules', 'Signalisation',
  'Évacuation', 'Secours', 'Confinement', 'Protection environnementale',
];

async function main() {
  for (const name of epiCategories) {
    await db.epiCategory.upsert({ where: { name }, update: {}, create: { name } });
  }
  for (const name of epcCategories) {
    await db.epcCategory.upsert({ where: { name }, update: {}, create: { name } });
  }
  console.log(`${epiCategories.length} catégories EPI et ${epcCategories.length} catégories EPC prêtes.`);
}

main().finally(() => db.$disconnect());
