import React, { createContext, useContext, useState, useCallback, useMemo } from 'react';
import fr from './fr.json';
import en from './en.json';

// Finding #39 — couche de traduction minimale, sans dépendance externe
// (choix délibéré : app mono-fichier, peu de dépendances). Un dictionnaire
// plat par langue, adressé par clé pointée ("nav.pilotage"), avec
// interpolation {{variable}} et repli sur le français puis sur la clé
// elle-même si une traduction manque — jamais un écran vide.
const DICTIONARIES = { fr, en };
const STORAGE_KEY = 'qhse_lang';
const DEFAULT_LANG = 'fr';

function getFromDict(dict, key) {
  return key.split('.').reduce((acc, part) => (acc && typeof acc === 'object' ? acc[part] : undefined), dict);
}

function interpolate(str, params) {
  if (!params) return str;
  return str.replace(/\{\{(\w+)\}\}/g, (m, name) => (params[name] !== undefined ? params[name] : m));
}

const I18nContext = createContext({ lang: DEFAULT_LANG, setLang: () => {}, t: (k) => k });

export function I18nProvider({ children }) {
  const [lang, setLangState] = useState(() => {
    try { return localStorage.getItem(STORAGE_KEY) || DEFAULT_LANG; } catch { return DEFAULT_LANG; }
  });

  const setLang = useCallback((next) => {
    setLangState(next);
    try { localStorage.setItem(STORAGE_KEY, next); } catch {}
  }, []);

  const t = useCallback((key, params) => {
    const dict = DICTIONARIES[lang] || DICTIONARIES[DEFAULT_LANG];
    let value = getFromDict(dict, key);
    if (value === undefined) value = getFromDict(DICTIONARIES[DEFAULT_LANG], key);
    if (value === undefined) return key;
    return interpolate(value, params);
  }, [lang]);

  const value = useMemo(() => ({ lang, setLang, t }), [lang, setLang, t]);

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n() {
  return useContext(I18nContext);
}
