'use client';

/**
 * DB-backed trail lessons — mirrors iOS `TrailContent.load`:
 * published rows from `trail_lessons` (written by the iOS Trail editor) are
 * merged OVER the built-in seed by position; extra DB positions are ignored
 * and an empty/failed fetch falls back to the seed. This keeps web in sync
 * with lesson edits made in the iOS admin editor.
 */

import { useQuery } from '@tanstack/react-query';
import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';
import { LESSONS, type Lesson } from './content';

interface TrailLessonRow {
  trail_key: string;
  position: number;
  title: string;
  idea: string;
  see_in_app: string | null;
  mindset_check: string | null;
  takeaway: string;
  one_more_thing: string | null;
  preview: string;
  deep_link: string | null;
}

function rowToLesson(r: TrailLessonRow): Lesson {
  return {
    trailKey: r.trail_key,
    position: r.position,
    title: r.title,
    idea: r.idea,
    seeInApp: r.see_in_app,
    mindsetCheck: r.mindset_check,
    takeaway: r.takeaway,
    oneMoreThing: r.one_more_thing,
    preview: r.preview,
    deepLink: r.deep_link,
  };
}

async function fetchTrailLessons(trailKey: string): Promise<Lesson[]> {
  const seed = (LESSONS[trailKey] ?? []).slice().sort((a, b) => a.position - b.position);
  if (!isSupabaseConfigured()) return seed;
  const supabase = createClient();
  const { data, error } = await supabase
    .from('trail_lessons')
    .select('trail_key, position, title, idea, see_in_app, mindset_check, takeaway, one_more_thing, preview, deep_link')
    .eq('trail_key', trailKey)
    .eq('is_published', true)
    .order('position', { ascending: true });
  if (error || !data?.length) return seed;
  const byPos = new Map((data as TrailLessonRow[]).map((r) => [r.position, rowToLesson(r)]));
  return seed.map((l) => byPos.get(l.position) ?? l);
}

/** Seed-first (instant render), DB overlay when it arrives. */
export function useTrailLessons(trailKey: string) {
  return useQuery({
    queryKey: ['trail-lessons', trailKey],
    queryFn: () => fetchTrailLessons(trailKey),
    staleTime: 300_000,
    placeholderData: (LESSONS[trailKey] ?? []).slice().sort((a, b) => a.position - b.position),
  });
}
