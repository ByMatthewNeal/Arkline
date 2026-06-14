'use client';

import { useState, useCallback } from 'react';

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
 * Tracks which home widgets are enabled (the "Customize" layer mirroring the iOS
 * Customize sheet). We persist the *hidden* set, so any newly-added widget is
 * enabled by default and nothing disappears until the user hides it. Stored in
 * localStorage so the selection sticks across sessions.
 */
export function useWidgetVisibility(layoutKey: string, allKeys: readonly string[]) {
  const [hidden, setHidden] = useState<Set<string>>(() => loadHidden(layoutKey));
  const isReady = true;

  const persist = useCallback((next: Set<string>) => {
    try {
      localStorage.setItem(`${LS_PREFIX}${layoutKey}`, JSON.stringify([...next]));
    } catch {
      /* ignore quota */
    }
  }, [layoutKey]);

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
    setHidden(new Set());
    try {
      localStorage.removeItem(`${LS_PREFIX}${layoutKey}`);
    } catch {
      /* ignore */
    }
  }, [layoutKey]);

  const isEnabled = useCallback((key: string) => !hidden.has(key), [hidden]);

  return { hidden, isReady, toggle, setAll, reset, isEnabled };
}
