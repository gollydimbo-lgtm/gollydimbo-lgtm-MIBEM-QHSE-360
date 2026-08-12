import { PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();

const IDS = {
  employee: "00000000-0000-0000-0000-000000000001",
  site: "00000000-0000-0000-0000-000000000100",
  line: "00000000-0000-0000-0000-000000000101",
  machine: "00000000-0000-0000-0000-000000000102",
  product: "00000000-0000-0000-0000-000000000201",
  format: "00000000-0000-0000-0000-000000000202",
  shift: "00000000-0000-0000-0000-000000000301",
  template: "00000000-0000-0000-0000-000000000400",
  pointCap: "00000000-0000-0000-0000-000000000401",
  pointVolume: "00000000-0000-0000-0000-000000000402",
  pointEtiquette: "00000000-0000-0000-0000-000000000403",
  pointPhoto: "00000000-0000-0000-0000-000000000404",
};

async function main() {
  const employee = await prisma.employee.upsert({
    where: { id: IDS.employee },
    update: {},
    create: {
      id: IDS.employee,
      employeeNumber: "MIBEM-DEMO-001",
      firstName: "Contrôleur",
      lastName: "QHSE",
      email: "controleur@mibem.local",
    },
  });

  await prisma.user.upsert({
    where: { employeeId: employee.id },
    update: {},
    create: {
      employeeId: employee.id,
      email: "controleur@mibem.local",
      passwordHash: await bcrypt.hash("Mibem@2026", 10),
      role: "QHSE_MANAGER",
    },
  });

  const site = await prisma.site.upsert({
    where: { id: IDS.site },
    update: {},
    create: { id: IDS.site, code: "MIBEM-01", name: "Site MIBEM" },
  });

  const line = await prisma.productionLine.upsert({
    where: { id: IDS.line },
    update: {},
    create: {
      id: IDS.line,
      code: "L-PET-120",
      name: "Ligne PET 120 ml",
      siteId: site.id,
    },
  });

  await prisma.machine.upsert({
    where: { id: IDS.machine },
    update: {},
    create: {
      id: IDS.machine,
      code: "M-PET-CAP",
      name: "Boucheuse PET",
      productionLineId: line.id,
    },
  });

  const product = await prisma.product.upsert({
    where: { id: IDS.product },
    update: {},
    create: { id: IDS.product, code: "LIQ-001", name: "Liqueur" },
  });

  await prisma.productFormat.upsert({
    where: { id: IDS.format },
    update: {},
    create: {
      id: IDS.format,
      productId: product.id,
      volumeMl: 120,
      label: "120 ml",
    },
  });

  await prisma.shift.upsert({
    where: { id: IDS.shift },
    update: {},
    create: {
      id: IDS.shift,
      siteId: site.id,
      name: "Matin",
      startTime: "06:00",
      endTime: "14:00",
    },
  });

  const template = await prisma.controlTemplate.upsert({
    where: { id: IDS.template },
    update: {},
    create: {
      id: IDS.template,
      code: "CTRL-PET-120",
      name: "Contrôle ligne PET 120 ml",
    },
  });

  // Rattachement explicite du template à la ligne PET 120 ml.
  await prisma.controlTemplateLine.upsert({
    where: { templateId_productionLineId: { templateId: template.id, productionLineId: line.id } },
    update: {},
    create: { templateId: template.id, productionLineId: line.id },
  });

  // Checklist type : un point booléen critique, un point numérique avec
  // bornes, un point à choix multiple, un point exigeant une photo.
  await prisma.controlPoint.upsert({
    where: { id: IDS.pointCap },
    update: {},
    create: {
      id: IDS.pointCap,
      templateId: template.id,
      code: "CP-CAP-001",
      description: "Positionnement et étanchéité du bouchonnage",
      sequence: 1,
      type: "BOOLEEN",
      isCritical: true,
    },
  });

  await prisma.controlPoint.upsert({
    where: { id: IDS.pointVolume },
    update: {},
    create: {
      id: IDS.pointVolume,
      templateId: template.id,
      code: "CP-VOL-001",
      description: "Niveau de remplissage",
      sequence: 2,
      type: "NUMERIQUE",
      unit: "ml",
      minValue: 117,
      maxValue: 123,
      isCritical: false,
    },
  });

  await prisma.controlPoint.upsert({
    where: { id: IDS.pointEtiquette },
    update: {},
    create: {
      id: IDS.pointEtiquette,
      templateId: template.id,
      code: "CP-ETQ-001",
      description: "Qualité et positionnement de l'étiquette",
      sequence: 3,
      type: "CHOIX_MULTIPLE",
      options: "Correct|Décentrée|Froissée|Absente",
      isCritical: false,
    },
  });

  await prisma.controlPoint.upsert({
    where: { id: IDS.pointPhoto },
    update: {},
    create: {
      id: IDS.pointPhoto,
      templateId: template.id,
      code: "CP-ASPECT-001",
      description: "Aspect général du produit fini (preuve photo)",
      sequence: 4,
      type: "PHOTO",
      requiresPhoto: true,
      isCritical: false,
    },
  });

  console.log("Seed MIBEM QHSE 360 V2 terminé.");
  console.log("Compte de démo : controleur@mibem.local / Mibem@2026");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
