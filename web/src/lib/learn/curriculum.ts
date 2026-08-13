'use client';

// The guided "path" — one ordered spine through the trails so we can tell a
// user "what's next" instead of leaving them to browse a flat library. Mirrors
// the iOS Curriculum. Not a hard gate; users can open any trail directly.

import { LESSONS } from './content';
import { getCompleted } from './progress';

export const PATH: string[] = [
  'beforeInvesting',
  'foundations',
  'behavioral',
  'scams',
  'crypto',
  'markets',
  'hedging',
  'trading',
  'macro',
  'fees',
  'sizing',
];

export interface NextLesson {
  trailKey: string;
  position: number;
  title: string;
}

/** First not-yet-complete lesson in path order — the "up next" target. */
export function nextLesson(): NextLesson | null {
  for (const trailKey of PATH) {
    const lessons = LESSONS[trailKey] ?? [];
    const done = getCompleted(trailKey);
    const l = lessons.find((x) => !done.has(x.position));
    if (l) return { trailKey, position: l.position, title: l.title };
  }
  return null;
}

/** Completed vs total lessons across the whole path. */
export function overall(): { done: number; total: number } {
  let done = 0;
  let total = 0;
  for (const trailKey of PATH) {
    const lessons = LESSONS[trailKey] ?? [];
    total += lessons.length;
    const c = getCompleted(trailKey);
    done += lessons.filter((l) => c.has(l.position)).length;
  }
  return { done, total };
}
