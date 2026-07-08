'use client';

import { useCallback, useSyncExternalStore } from 'react';

/**
 * Read/unread state for news articles — mirrors iOS `ReadArticlesStore`.
 * localStorage-backed, capped so it can't grow unbounded, and shared across
 * all subscribed components via a tiny external store (marking an article
 * read in one tile updates every other news list instantly).
 */

const LS_KEY = 'arkline-read-articles';
const MAX_ENTRIES = 500;

let cache: Set<string> | null = null;
const listeners = new Set<() => void>();

function load(): Set<string> {
  if (cache) return cache;
  if (typeof window === 'undefined') return new Set();
  try {
    const raw = localStorage.getItem(LS_KEY);
    cache = raw ? new Set(JSON.parse(raw) as string[]) : new Set();
  } catch {
    cache = new Set();
  }
  return cache;
}

function persist(next: Set<string>) {
  cache = next;
  try {
    // Keep the newest MAX_ENTRIES (Set preserves insertion order).
    const arr = [...next];
    localStorage.setItem(LS_KEY, JSON.stringify(arr.slice(-MAX_ENTRIES)));
  } catch { /* quota — ignore */ }
  listeners.forEach((l) => l());
}

function subscribe(onChange: () => void) {
  listeners.add(onChange);
  return () => listeners.delete(onChange);
}

// Snapshot must be referentially stable between changes.
let snapshotVersion = 0;
const getSnapshot = () => snapshotVersion;
const getServerSnapshot = () => 0;

export function useReadArticles() {
  useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);

  const isRead = useCallback((id: string) => load().has(id), []);

  const markRead = useCallback((id: string) => {
    const current = load();
    if (current.has(id)) return;
    const next = new Set(current);
    next.add(id);
    snapshotVersion++;
    persist(next);
  }, []);

  return { isRead, markRead };
}
