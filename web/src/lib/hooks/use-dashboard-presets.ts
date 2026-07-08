'use client';

import { useState, useEffect, useCallback } from 'react';
import { useAuth } from './use-auth';
import {
  loadDashboardPref,
  saveDashboardPref,
  saveDashboardPrefs,
  notifyPrefsApplied,
} from '@/lib/api/dashboard-prefs';

// Saveable dashboard presets (mirrors iOS "Dashboard Presets" — up to 2 named
// snapshots of layout + which widgets are shown). A preset captures the two
// localStorage stores the dashboard already uses:
//   arkline-layout-<key>  (grid layout, written by useWidgetLayout)
//   arkline-hidden-<key>  (hidden widgets, written by useWidgetVisibility)
// Applying a preset writes both stores and broadcasts a prefs-applied event —
// the layout/visibility hooks re-hydrate live, no page reload. Presets also
// sync to `profiles.dashboard_layouts.presets_<key>` for cross-device parity.

const MAX_PRESETS = 2;

export interface DashboardPreset {
  name: string;
  layouts: unknown;
  hidden: string[];
}

function presetsKey(layoutKey: string) { return `arkline-presets-${layoutKey}`; }
function layoutLSKey(layoutKey: string) { return `arkline-layout-${layoutKey}`; }
function hiddenLSKey(layoutKey: string) { return `arkline-hidden-${layoutKey}`; }

function load(layoutKey: string): DashboardPreset[] {
  if (typeof window === 'undefined') return [];
  try {
    const raw = localStorage.getItem(presetsKey(layoutKey));
    return raw ? (JSON.parse(raw) as DashboardPreset[]) : [];
  } catch {
    return [];
  }
}

export function useDashboardPresets(layoutKey: string) {
  const [presets, setPresets] = useState<DashboardPreset[]>(() => load(layoutKey));
  const { profile } = useAuth();
  const profileId = profile?.id ?? null;

  // Hydrate presets from Supabase when the profile loads.
  useEffect(() => {
    let active = true;
    if (!profileId) return;
    loadDashboardPref<DashboardPreset[]>(profileId, `presets_${layoutKey}`).then((cloud) => {
      if (!active || !cloud?.length) return;
      setPresets(cloud);
      try { localStorage.setItem(presetsKey(layoutKey), JSON.stringify(cloud)); } catch { /* ignore */ }
    });
    return () => { active = false; };
  }, [profileId, layoutKey]);

  const persist = useCallback((next: DashboardPreset[]) => {
    setPresets(next);
    try { localStorage.setItem(presetsKey(layoutKey), JSON.stringify(next)); } catch { /* ignore */ }
    if (profileId) saveDashboardPref(profileId, `presets_${layoutKey}`, next);
  }, [layoutKey, profileId]);

  const saveCurrent = useCallback((name: string) => {
    const trimmed = name.trim();
    if (!trimmed) return;
    let layouts: unknown = null;
    let hidden: string[] = [];
    try {
      const l = localStorage.getItem(layoutLSKey(layoutKey));
      if (l) layouts = JSON.parse(l);
      const h = localStorage.getItem(hiddenLSKey(layoutKey));
      if (h) hidden = JSON.parse(h) as string[];
    } catch { /* ignore */ }
    const preset: DashboardPreset = { name: trimmed, layouts, hidden };
    const without = presets.filter((p) => p.name !== trimmed);
    const next = [...without, preset].slice(-MAX_PRESETS);
    persist(next);
  }, [layoutKey, presets, persist]);

  const apply = useCallback((name: string) => {
    const preset = presets.find((p) => p.name === name);
    if (!preset) return;
    try {
      if (preset.layouts) localStorage.setItem(layoutLSKey(layoutKey), JSON.stringify(preset.layouts));
      localStorage.setItem(hiddenLSKey(layoutKey), JSON.stringify(preset.hidden ?? []));
    } catch { /* ignore */ }
    // Live re-hydration — useWidgetLayout/useWidgetVisibility listen for this.
    notifyPrefsApplied(layoutKey);
    // Persist the applied state to the cloud too (single merged write).
    if (profileId) {
      const entries: Record<string, unknown> = { [`hidden_${layoutKey}`]: preset.hidden ?? [] };
      if (preset.layouts) entries[layoutKey] = preset.layouts;
      saveDashboardPrefs(profileId, entries);
    }
  }, [layoutKey, presets, profileId]);

  const remove = useCallback((name: string) => {
    persist(presets.filter((p) => p.name !== name));
  }, [presets, persist]);

  return { presets, saveCurrent, apply, remove, canSave: presets.length < MAX_PRESETS, max: MAX_PRESETS };
}
