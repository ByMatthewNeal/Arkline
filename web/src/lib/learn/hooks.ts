'use client';

import { useEffect, useState } from 'react';
import { getCompleted } from './progress';
import { nextLesson, overall, type NextLesson } from './curriculum';

// localStorage-backed progress read AFTER mount, so server render and the first
// client render match (empty), then update — no hydration mismatch. Re-reads on
// the `trail-progress` event (fired by markComplete) and cross-tab `storage`.

export function useCompletedSet(trailKey: string): Set<number> {
  const [set, setSet] = useState<Set<number>>(new Set());
  useEffect(() => {
    const load = () => setSet(getCompleted(trailKey));
    load();
    window.addEventListener('trail-progress', load);
    window.addEventListener('storage', load);
    return () => {
      window.removeEventListener('trail-progress', load);
      window.removeEventListener('storage', load);
    };
  }, [trailKey]);
  return set;
}

export interface LearnPathState {
  next: NextLesson | null;
  done: number;
  total: number;
  mounted: boolean;
}

export function useLearnPath(): LearnPathState {
  const [state, setState] = useState<LearnPathState>({
    next: null,
    done: 0,
    total: 0,
    mounted: false,
  });
  useEffect(() => {
    const load = () => {
      const o = overall();
      setState({ next: nextLesson(), done: o.done, total: o.total, mounted: true });
    };
    load();
    window.addEventListener('trail-progress', load);
    window.addEventListener('storage', load);
    return () => {
      window.removeEventListener('trail-progress', load);
      window.removeEventListener('storage', load);
    };
  }, []);
  return state;
}
