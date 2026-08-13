'use client';

// Per-trail lesson progress, stored in localStorage and position-based so it
// survives content edits. Keys match the iOS app (UserDefaults) so a user who
// has an account on both sees consistent keys where applicable.

function storageKey(trailKey: string): string {
  // Foundations kept its original iOS key.
  return trailKey === 'foundations'
    ? 'start_here_completed_v1'
    : `trail_completed_${trailKey}_v1`;
}

export function getCompleted(trailKey: string): Set<number> {
  if (typeof window === 'undefined') return new Set();
  try {
    const raw = localStorage.getItem(storageKey(trailKey));
    return new Set<number>(raw ? (JSON.parse(raw) as number[]) : []);
  } catch {
    return new Set();
  }
}

export function markComplete(trailKey: string, position: number): void {
  if (typeof window === 'undefined') return;
  const set = getCompleted(trailKey);
  set.add(position);
  localStorage.setItem(
    storageKey(trailKey),
    JSON.stringify([...set].sort((a, b) => a - b)),
  );
  window.dispatchEvent(new Event('trail-progress'));
}

export function completedCount(trailKey: string): number {
  return getCompleted(trailKey).size;
}

/** Index into `positions` of the first lesson not yet completed (0 if all done). */
export function firstIncompleteIndex(positions: number[], trailKey: string): number {
  const done = getCompleted(trailKey);
  const idx = positions.findIndex((p) => !done.has(p));
  return idx < 0 ? 0 : idx;
}
