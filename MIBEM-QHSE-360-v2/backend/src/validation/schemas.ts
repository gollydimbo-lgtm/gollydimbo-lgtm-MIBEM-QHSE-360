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
});

export const attachmentMetaSchema = z.object({
  ownerType: z.enum(["CONTROL", "CONTROL_RESULT", "NON_CONFORMITY", "ACTION"]),
  ownerId: z.string().uuid(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  deviceId: z.string().optional(),
  clientLocalId: z.string().uuid().optional(),
  capturedAt: z.string().datetime().optional(),
});
