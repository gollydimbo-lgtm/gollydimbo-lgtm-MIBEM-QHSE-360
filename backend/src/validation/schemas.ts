import { z } from "zod";

export const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});

export const refreshSchema = z.object({
  refreshToken: z.string().min(10),
});

const controlResultInputSchema = z.object({
  controlPointId: z.string().uuid(),
  result: z.enum(["CONFORME", "OBSERVATION", "NON_CONFORME", "NON_APPLICABLE"]),
  numericValue: z.number().optional(),
  textValue: z.string().optional(),
  observation: z.string().optional(),
  category: z.string().optional(),
  severity: z.enum(["MINEURE", "MAJEURE", "CRITIQUE"]).optional(),
  responsibleId: z.string().uuid().optional(),
  dueDate: z.string().datetime().optional(),
  action: z.string().optional(),
  solutionId: z.string().uuid().optional(),
});

export const createControlSchema = z.object({
  // clientLocalId : UUID généré côté mobile avant la synchronisation.
  // Permet à l'API de reconnaître un renvoi du même contrôle (idempotence).
  clientLocalId: z.string().uuid().optional(),
  // Note : le contrôleur n'est plus saisi ici — il est dérivé du token JWT
  // par le serveur (voir routes/controls.routes.ts) pour éviter qu'un
  // appareil ne puisse déclarer un contrôle au nom d'un autre employé.
  productionLineId: z.string().uuid().optional(),
  machineId: z.string().uuid().optional(),
  productId: z.string().uuid().optional(),
  formatId: z.string().uuid().optional(),
  packagingTypeId: z.string().uuid().optional(),
  shiftId: z.string().uuid().optional(),
  comments: z.string().optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  deviceId: z.string().optional(),
  controlDate: z.string().datetime().optional(),
  results: z.array(controlResultInputSchema).min(1, "Au moins un résultat est requis"),
});

export const syncControlsSchema = z.object({
  controls: z.array(createControlSchema).min(1).max(200),
});

export const ncStatusTransitionSchema = z.object({
  toStatus: z.enum(["OUVERTE", "EN_ANALYSE", "ACTION_EN_COURS", "A_VERIFIER", "CLOTUREE", "REJETEE"]),
  comment: z.string().optional(),
});

export const actionStatusTransitionSchema = z.object({
  toStatus: z.enum(["OUVERTE", "EN_COURS", "TERMINEE", "A_VERIFIER", "CLOTUREE", "EN_RETARD"]),
  effectiveness: z.string().optional(),
  verificationComment: z.string().optional(),
  effectivenessStatus: z.enum(["NON_EVALUEE", "EFFICACE", "PARTIELLEMENT_EFFICACE", "INEFFICACE"]).optional(),
  comment: z.string().optional(),
});

export const attachmentMetaSchema = z.object({
  ownerType: z.enum(["CONTROL", "CONTROL_RESULT", "NON_CONFORMITY", "ACTION", "RISK", "SAFETY_EVENT", "AUDIT", "INSPECTION", "DOCUMENT"]),
  ownerId: z.string().uuid(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  deviceId: z.string().optional(),
  clientLocalId: z.string().uuid().optional(),
  capturedAt: z.string().datetime().optional(),
});

// ---- V3 Phase 2 : Risques ----

export const createRiskSchema = z.object({
  title: z.string().min(1),
  description: z.string().optional(),
  category: z.enum([
    "SECURITE", "SANTE", "QUALITE", "ENVIRONNEMENT", "SECURITE_ALIMENTAIRE",
    "OPERATIONNEL", "INCENDIE", "CHIMIQUE", "ELECTRIQUE", "MECANIQUE", "ERGONOMIQUE", "AUTRE",
  ]),
  siteId: z.string().uuid().optional(),
  productionLineId: z.string().uuid().optional(),
  machineId: z.string().uuid().optional(),
  ownerId: z.string().uuid().optional(),
  severity: z.number().int().min(1).max(5),
  probability: z.number().int().min(1).max(5),
  exposure: z.number().int().min(1).max(5).optional(),
  comment: z.string().optional(),
  actionDueDate: z.string().datetime().optional(),
  solutionId: z.string().uuid().optional(),
}); = z.object({
  toStatus: z.enum(["IDENTIFIE", "EVALUE", "TRAITEMENT_REQUIS", "TRAITEMENT_EN_COURS", "ACCEPTE", "MAITRISE", "CLOTURE"]),
  comment: z.string().optional(),
});

export const createRiskControlSchema = z.object({
  type: z.enum(["ELIMINATION", "SUBSTITUTION", "INGENIERIE", "ADMINISTRATIF", "EPI", "SURVEILLANCE"]),
  title: z.string().min(1),
  description: z.string().optional(),
});

export const updateRiskControlSchema = z.object({
  implemented: z.boolean(),
});

// ---- V3 Phase 2 : Événements Sécurité ----

export const createSafetyEventSchema = z.object({
  type: z.enum([
    "SITUATION_DANGEREUSE", "CONDITION_DANGEREUSE", "ACTE_DANGEREUX",
    "PRESQU_ACCIDENT", "INCIDENT", "ACCIDENT",
  ]),
  title: z.string().min(1),
  description: z.string().min(1),
  severity: z.enum(["NEGLIGEABLE", "MINEURE", "MODEREE", "MAJEURE", "CATASTROPHIQUE"]),
  probability: z.enum(["RARE", "PEU_PROBABLE", "POSSIBLE", "PROBABLE", "QUASI_CERTAIN"]).optional(),
  siteId: z.string().uuid().optional(),
  productionLineId: z.string().uuid().optional(),
  machineId: z.string().uuid().optional(),
  locationDescription: z.string().optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  injuryType: z.enum(["AUCUNE", "PREMIERS_SECOURS", "SOINS_MEDICAUX", "ARRET_TRAVAIL", "INVALIDITE_PERMANENTE", "DECES"]).optional(),
  lostWorkDays: z.number().int().min(0).optional(),
  actionDueDate: z.string().datetime().optional(),
  solutionId: z.string().uuid().optional(),
});

export const safetyEventStatusTransitionSchema = z.object({
  toStatus: z.enum(["SIGNALE", "EN_EXAMEN", "EN_INVESTIGATION", "ACTION_REQUISE", "RESOLU", "CLOTURE", "REJETE"]),
  comment: z.string().optional(),
});

export const createSafetyEventWitnessSchema = z.object({
  employeeId: z.string().uuid().optional(),
  name: z.string().optional(),
  phone: z.string().optional(),
  statement: z.string().optional(),
});

export const createSafetyEventInjurySchema = z.object({
  employeeId: z.string().uuid().optional(),
  personName: z.string().optional(),
  injuryType: z.enum(["AUCUNE", "PREMIERS_SECOURS", "SOINS_MEDICAUX", "ARRET_TRAVAIL", "INVALIDITE_PERMANENTE", "DECES"]),
  bodyPart: z.string().optional(),
  description: z.string().optional(),
  workStopped: z.boolean().optional(),
  lostWorkDays: z.number().int().min(0).optional(),
});

export const createSafetyEventCauseSchema = z.object({
  category: z.enum(["HUMAIN", "MACHINE", "METHODE", "MATERIEL", "ENVIRONNEMENT", "MANAGEMENT", "AUTRE"]),
  description: z.string().min(1),
  isRootCause: z.boolean().optional(),
  parentCauseId: z.string().uuid().optional(),
});

// ---- V3 Phase 3 : Audits & Inspections ----

export const createAuditSchema = z.object({
  programId: z.string().uuid().optional(),
  templateId: z.string().uuid().optional(),
  type: z.enum(["INTERNE", "FOURNISSEUR", "REGLEMENTAIRE", "CERTIFICATION"]),
  title: z.string().min(1),
  scope: z.string().optional(),
  siteId: z.string().uuid().optional(),
  plannedDate: z.string().datetime(),
});

export const auditStatusTransitionSchema = z.object({
  toStatus: z.enum(["PLANIFIE", "EN_COURS", "TERMINE", "ANNULE"]),
});

export const submitAuditChecklistItemSchema = z.object({
  questionId: z.string().uuid(),
  result: z.enum(["CONFORME", "OBSERVATION", "NC_MINEURE", "NC_MAJEURE"]),
  comment: z.string().optional(),
});

export const createAuditFindingSchema = z.object({
  checklistItemId: z.string().uuid().optional(),
  type: z.enum(["CONFORME", "OBSERVATION", "NC_MINEURE", "NC_MAJEURE"]),
  description: z.string().min(1),
  responsibleId: z.string().uuid().optional(),
  dueDate: z.string().datetime().optional(),
});

const inspectionResultInputSchema = z.object({
  inspectionPointId: z.string().uuid(),
  result: z.enum(["CONFORME", "OBSERVATION", "NON_CONFORME", "NON_APPLICABLE"]),
  observation: z.string().optional(),
});

export const createInspectionSchema = z.object({
  templateId: z.string().uuid(),
  siteId: z.string().uuid().optional(),
  productionLineId: z.string().uuid().optional(),
  machineId: z.string().uuid().optional(),
  comments: z.string().optional(),
  results: z.array(inspectionResultInputSchema).min(1),
});

// ---- V3 Phase 3 : Formation & Compétences ----

export const createTrainingSchema = z.object({
  code: z.string().min(1),
  title: z.string().min(1),
  description: z.string().optional(),
  category: z.string().optional(),
  durationHours: z.number().positive().optional(),
  validityMonths: z.number().int().positive().optional(),
});

export const createTrainingSessionSchema = z.object({
  sessionDate: z.string().datetime(),
  location: z.string().optional(),
  trainerName: z.string().optional(),
});

export const recordAttendanceSchema = z.object({
  employeeId: z.string().uuid(),
  attended: z.boolean().optional(),
  evaluationScore: z.number().min(0).max(20).optional(),
  evaluationComment: z.string().optional(),
});

// ---- V3 Phase 3 : EPI ----

export const createPPEItemSchema = z.object({
  categoryId: z.string().uuid(),
  name: z.string().min(1),
  reference: z.string().optional(),
  defaultLifespanMonths: z.number().int().positive().optional(),
});

export const createPPEAssignmentSchema = z.object({
  itemId: z.string().uuid(),
  employeeId: z.string().uuid(),
  expectedReplacementAt: z.string().datetime().optional(),
});

export const createPPEInspectionSchema = z.object({
  result: z.enum(["CONFORME", "OBSERVATION", "NON_CONFORME", "NON_APPLICABLE"]),
  comment: z.string().optional(),
});

export const updatePPEStockSchema = z.object({
  itemId: z.string().uuid(),
  siteId: z.string().uuid().optional(),
  quantity: z.number().int().min(0),
});

// ---- V3 Phase 3 : GED ----

export const createDocumentSchema = z.object({
  code: z.string().min(1),
  title: z.string().min(1),
  category: z.string().optional(),
  fileUrl: z.string().min(1),
});

export const documentStatusTransitionSchema = z.object({
  toStatus: z.enum(["BROUILLON", "VALIDATION", "APPROBATION", "PUBLIE", "REVISION", "ARCHIVE"]),
});

export const createDocumentVersionSchema = z.object({
  fileUrl: z.string().min(1),
  changeNote: z.string().optional(),
});

export const decideDocumentApprovalSchema = z.object({
  approved: z.boolean(),
  comment: z.string().optional(),
});

export const distributeDocumentSchema = z.object({
  employeeIds: z.array(z.string().uuid()).min(1),
});

// ---- V3 Phase 4 : Bibliothèque de solutions ----

export const createSolutionSchema = z.object({
  title: z.string().min(1),
  description: z.string().min(1),
  sourceType: z.enum([
    "NON_CONFORMITY", "RISK", "HAZARD_REPORT", "SAFETY_EVENT",
    "INSPECTION", "AUDIT", "ENVIRONMENTAL_EVENT", "MANUAL",
  ]),
  category: z.string().min(1),
  keywords: z.string().optional(),
});

export const updateSolutionSchema = z.object({
  title: z.string().min(1).optional(),
  description: z.string().min(1).optional(),
  keywords: z.string().optional(),
  isValidated: z.boolean().optional(),
});

// ---- V3 Phase 4 : Quarts d'heure sécurité ----

export const createSafetyBriefingSchema = z.object({
  title: z.string().min(1),
  scheduledDate: z.string().datetime(),
  siteId: z.string().uuid().optional(),
  productionLineId: z.string().uuid().optional(),
  topics: z
    .array(
      z.object({
        title: z.string().min(1),
        content: z.string().min(1),
        sourceType: z
          .enum(["NON_CONFORMITY", "RISK", "HAZARD_REPORT", "SAFETY_EVENT", "INSPECTION", "AUDIT", "ENVIRONMENTAL_EVENT", "MANUAL"])
          .optional(),
        sourceId: z.string().uuid().optional(),
      })
    )
    .min(1),
});

export const briefingStatusTransitionSchema = z.object({
  toStatus: z.enum(["PLANIFIE", "REALISE", "ANNULE"]),
  summary: z.string().optional(),
});

export const recordBriefingAttendanceSchema = z.object({
  employeeId: z.string().uuid(),
  comment: z.string().optional(),
});
