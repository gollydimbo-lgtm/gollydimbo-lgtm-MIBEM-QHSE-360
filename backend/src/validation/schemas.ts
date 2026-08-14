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
  ownerType: z.enum(["CONTROL", "CONTROL_RESULT", "NON_CONFORMITY", "ACTION", "RISK", "SAFETY_EVENT"]),
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
});

export const riskStatusTransitionSchema = z.object({
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
