import React, { useState } from 'react';
import { ShieldCheck } from 'lucide-react';
import { login, getBaseUrl, setBaseUrl, checkHealth } from './api';

const C = { bg: '#0B0F19', card: '#111827', border: '#1F2937', text: '#FFFFFF', textMuted: '#9CA3AF', blue: '#3B82F6', red: '#EF4444' };

export default function LoginPage({ onLoggedIn }) {
  const [serverUrl, setServerUrl] = useState(getBaseUrl());
  const [email, setEmail] = useState('admin@qhse.local');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);
  const [checking, setChecking] = useState(false);
  const [serverStatus, setServerStatus] = useState(null);

  async function testServer() {
    setChecking(true); setServerStatus(null); setError(null);
    setBaseUrl(serverUrl);
    try {
      await checkHealth();
      setServerStatus('ok');
    } catch {
      setServerStatus('down');
    }
    setChecking(false);
  }

  async function submit(e) {
    e.preventDefault();
    setLoading(true); setError(null);
    setBaseUrl(serverUrl);
    try {
      const user = await login(email, password);
      onLoggedIn(user);
    } catch (err) {
      setError(err.message || 'Connexion impossible');
    }
    setLoading(false);
  }

  return (
    <div className="min-h-screen flex items-center justify-center" style={{ backgroundColor: C.bg, fontFamily: 'Inter, system-ui, sans-serif' }}>
      <form onSubmit={submit} className="w-full max-w-sm rounded-xl p-6" style={{ backgroundColor: C.card, border: `1px solid ${C.border}` }}>
        <div className="flex items-center gap-2 mb-6">
          <div className="w-9 h-9 rounded-lg flex items-center justify-center" style={{ backgroundColor: C.blue }}><ShieldCheck size={20} color="#fff" /></div>
          <div>
            <div className="text-sm font-semibold" style={{ color: C.text }}>Gestion QHSE 360</div>
            <div className="text-[10px]" style={{ color: C.textMuted }}>Connexion à votre serveur</div>
          </div>
        </div>

        <label className="block text-xs mb-1" style={{ color: C.textMuted }}>Adresse du serveur API</label>
        <div className="flex gap-2 mb-4">
          <input value={serverUrl} onChange={(e) => setServerUrl(e.target.value)} className="flex-1 px-3 py-2 rounded-lg text-sm outline-none"
            style={{ backgroundColor: C.bg, border: `1px solid ${C.border}`, color: C.text }} placeholder="http://localhost:3000/api/v4" />
          <button type="button" onClick={testServer} className="px-3 py-2 rounded-lg text-xs" style={{ backgroundColor: C.bg, border: `1px solid ${C.border}`, color: C.text }}>
            {checking ? '...' : 'Tester'}
          </button>
        </div>
        {serverStatus === 'ok' && <p className="text-xs mb-4" style={{ color: '#10B981' }}>✔ Serveur joignable</p>}
        {serverStatus === 'down' && <p className="text-xs mb-4" style={{ color: C.red }}>✘ Serveur injoignable à cette adresse</p>}

        <label className="block text-xs mb-1" style={{ color: C.textMuted }}>Email</label>
        <input value={email} onChange={(e) => setEmail(e.target.value)} type="email" required className="w-full px-3 py-2 rounded-lg text-sm outline-none mb-4"
          style={{ backgroundColor: C.bg, border: `1px solid ${C.border}`, color: C.text }} />

        <label className="block text-xs mb-1" style={{ color: C.textMuted }}>Mot de passe</label>
        <input value={password} onChange={(e) => setPassword(e.target.value)} type="password" required className="w-full px-3 py-2 rounded-lg text-sm outline-none mb-4"
          style={{ backgroundColor: C.bg, border: `1px solid ${C.border}`, color: C.text }} />

        {error && <p className="text-xs mb-4" style={{ color: C.red }}>{error}</p>}

        <button type="submit" disabled={loading} className="w-full py-2.5 rounded-lg text-sm font-medium" style={{ backgroundColor: C.blue, color: '#fff', opacity: loading ? 0.7 : 1 }}>
          {loading ? 'Connexion…' : 'Se connecter'}
        </button>
        <p className="text-[11px] mt-4 text-center" style={{ color: C.textMuted }}>
          Assurez-vous que <code>docker compose up -d</code> tourne sur le serveur avant de vous connecter.
        </p>
      </form>
    </div>
  );
}
