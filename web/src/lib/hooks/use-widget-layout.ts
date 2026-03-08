'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import type { ResponsiveLayouts, Layout, LayoutItem } from 'react-grid-layout';
import { useAuth } from './use-auth';
import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';

const LS_PREFIX = 'arkline-layout-';

/**
 * Merges saved layouts with defaults so new widgets aren't lost.
 * Any widget key present in defaults but missing from saved gets appended.
 */
function mergeWithDefaults(saved: ResponsiveLayouts, defaults: ResponsiveLayouts): ResponsiveLayouts {
  const merged: Record<string, readonly LayoutItem[]> = {};
  for (const bp of Object.keys(defaults)) {
    const defaultItems = defaults[bp] ?? [];
    const savedItems = saved[bp] ?? [];
    const savedKeys = new Set(savedItems.map((item) => item.i));
    merged[bp] = [
      ...savedItems,
      ...defaultItems.filter((item) => !savedKeys.has(item.i)),
    ];
  }
  return merged;
}

export function useWidgetLayout(layoutKey: string, defaultLayouts: ResponsiveLayouts) {
  const [layouts, setLayouts] = useState<ResponsiveLayouts>(defaultLayouts);
  const [isReady, setIsReady] = useState(false);
  const { profile } = useAuth();
  const supabaseTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const localTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Load saved layout on mount
  useEffect(() => {
    let active = true;

    const load = async () => {
      // Try Supabase first for logged-in users
      if (profile?.id && isSupabaseConfigured()) {
        try {
          const supabase = createClient();
          const { data } = await supabase
            .from('profiles')
            .select('dashboard_layouts')
            .eq('id', profile.id)
            .single();

          if (active && data?.dashboard_layouts?.[layoutKey]) {
            setLayouts(mergeWithDefaults(data.dashboard_layouts[layoutKey], defaultLayouts));
            setIsReady(true);
            return;
          }
        } catch {
          // fall through to localStorage
        }
      }

      // Fall back to localStorage
      try {
        const stored = localStorage.getItem(`${LS_PREFIX}${layoutKey}`);
        if (active && stored) {
          const parsed = JSON.parse(stored) as ResponsiveLayouts;
          setLayouts(mergeWithDefaults(parsed, defaultLayouts));
        }
      } catch {
        // use defaults
      }

      if (active) setIsReady(true);
    };

    load();
    return () => { active = false; };
  }, [layoutKey, profile?.id]); // eslint-disable-line react-hooks/exhaustive-deps

  // Save layout on change (debounced)
  const onLayoutChange = useCallback((_layout: Layout, allLayouts: ResponsiveLayouts) => {
    setLayouts(allLayouts);

    // Debounced localStorage save (500ms)
    if (localTimerRef.current) clearTimeout(localTimerRef.current);
    localTimerRef.current = setTimeout(() => {
      try {
        localStorage.setItem(`${LS_PREFIX}${layoutKey}`, JSON.stringify(allLayouts));
      } catch { /* quota exceeded — ignore */ }
    }, 500);

    // Debounced Supabase save (1500ms)
    if (profile?.id && isSupabaseConfigured()) {
      if (supabaseTimerRef.current) clearTimeout(supabaseTimerRef.current);
      supabaseTimerRef.current = setTimeout(async () => {
        try {
          const supabase = createClient();
          const { data: current } = await supabase
            .from('profiles')
            .select('dashboard_layouts')
            .eq('id', profile.id)
            .single();

          const existing = current?.dashboard_layouts ?? {};
          await supabase
            .from('profiles')
            .update({ dashboard_layouts: { ...existing, [layoutKey]: allLayouts } })
            .eq('id', profile.id);
        } catch {
          // silent fail — localStorage is the primary store
        }
      }, 1500);
    }
  }, [layoutKey, profile?.id]);

  const resetLayout = useCallback(() => {
    setLayouts(defaultLayouts);
    try {
      localStorage.removeItem(`${LS_PREFIX}${layoutKey}`);
    } catch { /* ignore */ }

    if (profile?.id && isSupabaseConfigured()) {
      const supabase = createClient();
      supabase
        .from('profiles')
        .select('dashboard_layouts')
        .eq('id', profile.id)
        .single()
        .then(({ data: currentProfile }: { data: { dashboard_layouts?: Record<string, unknown> } | null }) => {
          const existing = currentProfile?.dashboard_layouts ?? {};
          const { [layoutKey]: _, ...rest } = existing;
          supabase
            .from('profiles')
            .update({ dashboard_layouts: Object.keys(rest).length ? rest : null })
            .eq('id', profile.id);
        });
    }
  }, [layoutKey, defaultLayouts, profile?.id]);

  // Cleanup timers
  useEffect(() => {
    return () => {
      if (localTimerRef.current) clearTimeout(localTimerRef.current);
      if (supabaseTimerRef.current) clearTimeout(supabaseTimerRef.current);
    };
  }, []);

  return { layouts, onLayoutChange, resetLayout, isReady };
}
