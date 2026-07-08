import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';

/**
 * Cloud persistence for dashboard preferences — mirrors iOS
 * PreferencesSyncService (layout, hidden widgets, presets follow the user
 * across devices). Everything lives in the `profiles.dashboard_layouts`
 * JSON column under namespaced keys:
 *   home / market            → grid layouts (useWidgetLayout)
 *   hidden_home / hidden_...  → hidden-widget arrays (useWidgetVisibility)
 *   presets_home / ...        → saved presets (useDashboardPresets)
 */

export const PREFS_APPLIED_EVENT = 'arkline:prefs-applied';

export function notifyPrefsApplied(layoutKey: string) {
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new CustomEvent(PREFS_APPLIED_EVENT, { detail: { layoutKey } }));
  }
}

export async function loadDashboardPref<T>(profileId: string, key: string): Promise<T | null> {
  if (!isSupabaseConfigured()) return null;
  try {
    const supabase = createClient();
    const { data } = await supabase
      .from('profiles')
      .select('dashboard_layouts')
      .eq('id', profileId)
      .single();
    return (data?.dashboard_layouts?.[key] as T) ?? null;
  } catch {
    return null;
  }
}

export async function saveDashboardPrefs(
  profileId: string,
  entries: Record<string, unknown>,
): Promise<void> {
  if (!isSupabaseConfigured()) return;
  try {
    const supabase = createClient();
    const { data: current } = await supabase
      .from('profiles')
      .select('dashboard_layouts')
      .eq('id', profileId)
      .single();
    const existing = (current?.dashboard_layouts as Record<string, unknown>) ?? {};
    await supabase
      .from('profiles')
      .update({ dashboard_layouts: { ...existing, ...entries } })
      .eq('id', profileId);
  } catch {
    // silent — localStorage remains the primary store
  }
}

export function saveDashboardPref(profileId: string, key: string, value: unknown): Promise<void> {
  return saveDashboardPrefs(profileId, { [key]: value });
}
