export const swaggerDocument = {
  openapi: "3.0.0",
  info: { title: "MIBEM QHSE 360 API", version: "2.0.0" },
  components: {
    securitySchemes: {
      bearerAuth: { type: "http", scheme: "bearer", bearerFormat: "JWT" },
    },
  },
  security: [{ bearerAuth: [] }],
  paths: {
    "/health": { get: { security: [], responses: { "200": { description: "OK" } } } },
    "/api/auth/login": { post: { security: [], responses: { "200": { description: "Connexion" } } } },
    "/api/auth/refresh": { post: { security: [], responses: { "200": { description: "Nouveau token" } } } },
    "/api/auth/logout": { post: { security: [], responses: { "204": { description: "Déconnecté" } } } },
    "/api/control-templates/line/{productionLineId}": {
      get: { responses: { "200": { description: "Checklist dynamique de la ligne" } } },
    },
    "/api/reference-data": {
      get: { responses: { "200": { description: "Lignes, produits, emballages, équipes" } } },
    },
    "/api/controls": {
      get: { responses: { "200": { description: "Liste des contrôles" } } },
      post: { responses: { "201": { description: "Contrôle créé, NC/actions auto si NON_CONFORME" } } },
    },
    "/api/controls/sync": {
      post: { responses: { "201": { description: "Lot synchronisé" }, "207": { description: "Lot partiellement synchronisé" } } },
    },
    "/api/non-conformities": { get: { responses: { "200": { description: "Liste des NC" } } } },
    "/api/non-conformities/{id}/status": {
      patch: { responses: { "200": { description: "Statut NC mis à jour" }, "409": { description: "Transition refusée" } } },
    },
    "/api/actions": { get: { responses: { "200": { description: "Liste des actions" } } } },
    "/api/actions/{id}/status": {
      patch: { responses: { "200": { description: "Statut action mis à jour" }, "409": { description: "Transition refusée" } } },
    },
    "/api/attachments": {
      post: { responses: { "201": { description: "Pièce jointe uploadée" } } },
      get: { responses: { "200": { description: "Pièces jointes d'un élément" } } },
    },
    "/api/dashboard/overview": { get: { responses: { "200": { description: "Indicateurs globaux" } } } },
    "/api/dashboard/pareto": { get: { responses: { "200": { description: "Pareto des NC par catégorie" } } } },
    "/api/dashboard/trend": { get: { responses: { "200": { description: "Tendance de conformité" } } } },
  },
};
