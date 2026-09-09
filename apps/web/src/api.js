// Couche d'accès à l'API réelle de MIBEM QHSE 360 (NestJS).
// Gère maintenant deux jetons : un accès court (15 min) et un
// rafraîchissement long (30 jours). Un minuteur renouvelle l'accès tout
// seul un peu avant son expiration — en usage normal, l'utilisateur ne
// devrait jamais voir passer un 401 lié à l'expiration du jeton.

const DEFAULT_BASE_URL = 'http://localhost:3000/api/v4';

export function getBaseUrl() {
  return localStorage.getItem('qhse_api_url') || DEFAULT_BASE_URL;
}
export function setBaseUrl(url) {
  localStorage.setItem('qhse_api_url', url.replace(/\/+$/, ''));
}
export function getToken() {
  return localStorage.getItem('qhse_token');
}
function setToken(token) {
  localStorage.setItem('qhse_token', token);
}
export function getRefreshToken() {
  return localStorage.getItem('qhse_refresh_token');
}
function setRefreshToken(token) {
  localStorage.setItem('qhse_refresh_token', token);
}
export function clearSession() {
  localStorage.removeItem('qhse_token');
  localStorage.removeItem('qhse_refresh_token');
  localStorage.removeItem('qhse_user');
  clearProactiveRefresh();
}
export function getStoredUser() {
  const raw = localStorage.getItem('qhse_user');
  return raw ? JSON.parse(raw) : null;
}

// Décode la partie centrale d'un jeton JWT (aucune vérification de
// signature ici — seulement pour lire la date d'expiration côté client).
function decodeJwtExpiry(token) {
  try {
    const payload = JSON.parse(atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
    return payload.exp ? payload.exp * 1000 : null;
  } catch { return null; }
}

let proactiveRefreshTimer = null;
function clearProactiveRefresh() {
  if (proactiveRefreshTimer) { clearTimeout(proactiveRefreshTimer); proactiveRefreshTimer = null; }
}
function scheduleProactiveRefresh(accessToken) {
  clearProactiveRefresh();
  const exp = decodeJwtExpiry(accessToken);
  if (!exp) return;
  const delay = Math.max(exp - Date.now() - 60_000, 5_000); // 1 minute avant expiration
  proactiveRefreshTimer = setTimeout(() => { doRefresh().catch(() => {}); }, delay);
}

let refreshInFlight = null;
async function doRefresh() {
  if (refreshInFlight) return refreshInFlight;
  const refreshToken = getRefreshToken();
  if (!refreshToken) throw new Error('Aucun jeton de rafraîchissement');
  refreshInFlight = fetch(`${getBaseUrl()}/auth/refresh`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ refreshToken }),
  }).then(async (res) => {
    if (!res.ok) throw new Error('Rafraîchissement refusé');
    const data = await res.json();
    setToken(data.accessToken);
    setRefreshToken(data.refreshToken);
    localStorage.setItem('qhse_user', JSON.stringify(data.user));
    scheduleProactiveRefresh(data.accessToken);
    return data;
  }).finally(() => { refreshInFlight = null; });
  return refreshInFlight;
}

async function request(path, options = {}, retried = false) {
  const token = getToken();
  const res = await fetch(`${getBaseUrl()}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.headers || {}),
    },
  });
  // Filet de sécurité réactif : si le renouvellement automatique n'a pas eu
  // lieu à temps (onglet resté en arrière-plan, etc.), on rattrape ici avant
  // d'abandonner et de demander une reconnexion.
  if (res.status === 401 && !retried && path !== '/auth/login' && path !== '/auth/refresh') {
    try {
      await doRefresh();
      return request(path, options, true);
    } catch {
      clearSession();
      window.dispatchEvent(new Event('qhse:session-expired'));
      throw new Error('Session expirée — veuillez vous reconnecter');
    }
  }
  const text = await res.text();
  let body;
  try { body = text ? JSON.parse(text) : null; } catch { body = text; }
  if (!res.ok) {
    const message = (body && body.message) ? body.message : `${res.status} ${res.statusText}`;
    throw new Error(Array.isArray(message) ? message.join(', ') : message);
  }
  return body;
}

export const api = {
  get: (path) => request(path, { method: 'GET' }),
  post: (path, data) => request(path, { method: 'POST', body: JSON.stringify(data) }),
  patch: (path, data) => request(path, { method: 'PATCH', body: JSON.stringify(data) }),
  del: (path) => request(path, { method: 'DELETE' }),
};

export async function login(email, password) {
  const result = await request('/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) });
  setToken(result.accessToken);
  setRefreshToken(result.refreshToken);
  localStorage.setItem('qhse_user', JSON.stringify(result.user));
  scheduleProactiveRefresh(result.accessToken);
  return result.user;
}

// Révoque le jeton de rafraîchissement côté serveur (pas juste local) avant
// d'effacer la session — sans ça, le jeton restait valide 30 jours de plus.
export async function logout() {
  const refreshToken = getRefreshToken();
  if (refreshToken) {
    try { await request('/auth/logout', { method: 'POST', body: JSON.stringify({ refreshToken }) }); } catch { /* best-effort */ }
  }
  clearSession();
}

// Si l'utilisateur avait déjà une session ouverte avant de recharger la
// page, on programme quand même le renouvellement automatique.
const existingToken = getToken();
if (existingToken) scheduleProactiveRefresh(existingToken);

export async function checkHealth() {
  const res = await fetch(`${getBaseUrl()}/health`);
  if (!res.ok) throw new Error('Le serveur ne répond pas');
  return res.json();
}
