'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import { useAuth } from './use-auth';
import {
  loadDashboardPref,
  saveDashboardPref,
  PREFS_APPLIED_EVENT,
} from '@/lib/api/dashboard-prefs';

const LS_PREFIX = 'arkline-hidden-';

function loadHidden(layoutKey: string): Set<string> {
  if (typeof window === 'undefined') return new Set();
  try {
    const stored = localStorage.getItem(`${LS_PREFIX}${layoutKey}`);
    return stored ? new Set<string>(JSON.parse(stored) as string[]) : new Set();
  } catch {
    return new Set();
  }
}

/**
 * Tracks which widgets are enabled (the "Customize" layer mirroring the iOS
 * Customize sheet). We persist the *hidden* set, so any newly-added widget is
 * enabled by default. localStorage renders instantly; the set also syncs to
 * `profiles.dashboard_layouts.hidden_<key>` so it follows the user across
 * devices (iOS preferences-sync parity). Listens for preset-apply events and
 * re-hydrates without a page reload.
 */
export function useWidgetVisibility(layoutKey: string, allKeys: readonly string[]) {
  const [hidden, setHidden] = useState<Set<string>>(() => loadHidden(layoutKey));
  const { profile } = useAuth();
  const profileId = profile?.id ?? null;
  const cloudTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const isReady = true;

  // Hydrate from Supabase when the profile loads (cloud wins over local —
  // matches useWidgetLayout's precedence).
  useEffect(() => {
    let active = true;
    if (!profileId) return;
    loadDashboardPref<string[]>(profileId, `hidden_${layoutKey}`).then((cloud) => {
      if (!active || !cloud) return;
      setHidden(new Set(cloud));
      try {
        localStorage.setItem(`${LS_PREFIX}${layoutKey}`, JSON.stringify(cloud));
      } catch { /* ignore */ }
    });
    return () => { active = false; };
  }, [profileId, layoutKey]);

  // Re-hydrate from localStorage when a preset is applied (no reload).
  useEffect(() => {
    const onApplied = (e: Event) => {
      const detail = (e as CustomEvent<{ layoutKey: string }>).detail;
      if (detail?.layoutKey === layoutKey) setHidden(loadHidden(layoutKey));
    };
    window.addEventListener(PREFS_APPLIED_EVENT, onApplied);
    return () => window.removeEventListener(PREFS_APPLIED_EVENT, onApplied);
  }, [layoutKey]);

  const persist = useCallback((next: Set<string>) => {
    try {
      localStorage.setItem(`${LS_PREFIX}${layoutKey}`, JSON.stringify([...next]));
    } catch { /* ignore quota */ }

    if (profileId) {
      if (cloudTimerRef.current) clearTimeout(cloudTimerRef.current);
      cloudTimerRef.current = setTimeout(() => {
        saveDashboardPref(profileId, `hidden_${layoutKey}`, [...next]);
      }, 1500);
    }
  }, [layoutKey, profileId]);

  useEffect(() => () => {
    if (cloudTimerRef.current) clearTimeout(cloudTimerRef.current);
  }, []);

  const toggle = useCallback((key: string) => {
    setHidden((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      persist(next);
      return next;
    });
  }, [persist]);

  const setAll = useCallback((on: boolean) => {
    const next = on ? new Set<string>() : new Set(allKeys);
    setHidden(next);
    persist(next);
  }, [allKeys, persist]);

  const reset = useCallback(() => {
    const next = new Set<string>();
    setHidden(next);
    try {
      localStorage.removeItem(`${LS_PREFIX}${layoutKey}`);
    } catch { /* ignore */ }
    if (profileId) saveDashboardPref(profileId, `hidden_${layoutKey}`, []);
  }, [layoutKey, profileId]);

  const isEnabled = useCallback((key: string) => !hidden.has(key), [hidden]);

  return { hidden, isReady, toggle, setAll, reset, isEnabled };
}
