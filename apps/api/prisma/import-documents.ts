// Importe automatiquement les fichiers déposés dans les 5 sous-dossiers
// locaux (montés en lecture seule dans /app/import) vers le GED de
// l'application : création d'un Document + d'une DocumentVersion pointant
// vers une copie persistée du fichier (volume qhse_uploads). STRICTEMENT
// ADDITIF et IDEMPOTENT : si un document du même code existe déjà, le
// fichier est ré-importé seulement s'il a changé (nouvelle version créée),
// jamais de suppression.
import { PrismaClient, DocumentGroup, DocumentStatus } from '@prisma/client';
import { readdirSync, statSync, readFileSync, mkdirSync, copyFileSync } from 'fs';
import { join, extname, basename } from 'path';
import { createHash } from 'crypto';

const db = new PrismaClient();
const IMPORT_ROOT = '/app/import';
const UPLOAD_DIR = process.env.UPLOAD_DIR || '/app/uploads';

// Fait le lien entre le nom exact de vos 5 sous-dossiers et le groupe GED.
const FOLDER_TO_GROUP: Record<string, DocumentGroup> = {
  '1_Strategie_et_Contexte': 'STRATEGIE_CONTEXTE',
  '2_Risques_Securite_Conformite': 'RISQUES_SECURITE_CONFORMITE',
  '3_Supports_Maitrise_Documentaire': 'SUPPORTS_MAITRISE_DOCUMENTAIRE',
  '4_Operations_Maitrise_Terrain': 'OPERATIONS_MAITRISE_TERRAIN',
  '5_Evaluation_Controle_Amelioration': 'EVALUATION_CONTROLE_AMELIORATION',
};

function slugCode(fileName: string): string {
  const base = basename(fileName, extname(fileName));
  return 'DOC-' + base
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .toUpperCase().replace(/[^A-Z0-9]+/g, '-').replace(/^-+|-+$/g, '')
    .slice(0, 60);
}

function sha256(buf: Buffer): string {
  return createHash('sha256').update(buf).digest('hex');
}

async function main() {
  mkdirSync(UPLOAD_DIR, { recursive: true });
  let created = 0, newVersions = 0, unchanged = 0, skippedFolders = 0;

  for (const [folder, group] of Object.entries(FOLDER_TO_GROUP)) {
    const folderPath = join(IMPORT_ROOT, folder);
    let entries: string[];
    try {
      entries = readdirSync(folderPath);
    } catch {
      console.log(`(dossier absent, ignoré : ${folder})`);
      skippedFolders++;
      continue;
    }

    for (const fileName of entries) {
      const fullPath = join(folderPath, fileName);
      if (!statSync(fullPath).isFile()) continue;
      if (fileName.startsWith('.') || fileName.startsWith('~$')) continue; // fichiers cachés / verrous Office

      const buffer = readFileSync(fullPath);
      const checksum = sha256(buffer);
      const code = slugCode(fileName);
      const title = basename(fileName, extname(fileName)).replace(/[_-]+/g, ' ').trim();

      let doc = await db.document.findUnique({ where: { code }, include: { versions: { orderBy: { version: 'desc' }, take: 1 } } });

      if (!doc) {
        doc = await db.document.create({
          data: { code, title, category: folder, documentGroup: group, status: DocumentStatus.ACTIVE },
          include: { versions: { orderBy: { version: 'desc' }, take: 1 } },
        });
        created++;
        console.log(`+ Document créé : ${code} — "${title}" [${group}]`);
      } else if (doc.documentGroup !== group) {
        await db.document.update({ where: { id: doc.id }, data: { documentGroup: group } });
        console.log(`~ Groupe mis à jour pour ${code} -> ${group}`);
      }

      const lastVersion = doc.versions[0];
      if (lastVersion && lastVersion.checksum === checksum) {
        unchanged++;
        continue; // fichier identique déjà importé, on ne duplique pas
      }

      const nextVersionNumber = (lastVersion?.version ?? 0) + 1;
      const storedName = `${code}-v${nextVersionNumber}${extname(fileName)}`;
      const storagePath = join(UPLOAD_DIR, storedName);
      copyFileSync(fullPath, storagePath);

      await db.documentVersion.create({
        data: { documentId: doc.id, version: nextVersionNumber, fileName, storagePath, checksum, status: DocumentStatus.ACTIVE },
      });
      await db.document.update({ where: { id: doc.id }, data: { currentVersion: nextVersionNumber, status: DocumentStatus.ACTIVE } });
      newVersions++;
      console.log(`  -> fichier importé (version ${nextVersionNumber}) : ${fileName}`);
    }
  }

  console.log(`\n${created} document(s) créé(s), ${newVersions} version(s) de fichier importée(s), ${unchanged} déjà à jour (inchangés), ${skippedFolders} dossier(s) introuvable(s).`);
}

main().catch(e => { console.error(e); process.exit(1); }).finally(() => db.$disconnect());
