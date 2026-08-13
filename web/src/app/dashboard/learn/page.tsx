'use client';

import Link from 'next/link';
import { GraduationCap, ChevronRight, CheckCircle2, Sparkles } from 'lucide-react';
import { TRAILS, LESSONS, type TrailDifficulty } from '@/lib/learn/content';
import { useCompletedSet, useLearnPath } from '@/lib/learn/hooks';
import { cn } from '@/lib/utils/format';

const DIFFICULTY_ORDER: TrailDifficulty[] = ['beginner', 'intermediate', 'advanced'];

const DIFFICULTY_LABEL: Record<TrailDifficulty, string> = {
  beginner: 'Beginner',
  intermediate: 'Intermediate',
  advanced: 'Advanced',
};

const DIFFICULTY_BADGE: Record<TrailDifficulty, string> = {
  beginner: 'bg-emerald-500/10 text-emerald-500',
  intermediate: 'bg-ark-info/10 text-ark-info',
  advanced: 'bg-amber-500/10 text-amber-500',
};

function ContinueCard() {
  const { next, done, total, mounted } = useLearnPath();
  if (!mounted) return null; // avoid hydration mismatch; render after client mount

  const pct = total > 0 ? Math.round((done / total) * 100) : 0;

  if (!next) {
    return (
      <div className="rounded-2xl border border-emerald-500/30 bg-emerald-500/5 p-4">
        <div className="flex items-center gap-2">
          <CheckCircle2 className="h-5 w-5 text-emerald-500" />
          <p className="text-sm font-semibold text-ark-text">Path complete</p>
        </div>
        <p className="mt-1 text-[13px] text-ark-text-secondary">
          You&apos;ve finished every lesson in the guided path. Revisit any trail below anytime.
        </p>
      </div>
    );
  }

  const trail = TRAILS.find((t) => t.key === next.trailKey);

  return (
    <Link
      href={`/dashboard/learn/${next.trailKey}?open=1`}
      className="group block rounded-2xl border border-ark-info/30 bg-ark-info/5 p-4 transition-colors hover:border-ark-info/60"
    >
      <div className="flex items-center gap-1.5">
        <Sparkles className="h-3.5 w-3.5 text-ark-info" />
        <p className="text-[11px] font-semibold uppercase tracking-wider text-ark-info">
          {done === 0 ? 'Start your path' : 'Up next'}
        </p>
      </div>
      <div className="mt-1 flex items-center justify-between gap-3">
        <div className="min-w-0">
          <p className="truncate text-[15px] font-semibold text-ark-text">{next.title}</p>
          {trail && <p className="text-[12px] text-ark-text-tertiary">{trail.navTitle}</p>}
        </div>
        <span className="inline-flex shrink-0 items-center gap-1 rounded-xl bg-ark-info px-3 py-2 text-sm font-semibold text-white transition-transform group-hover:translate-x-0.5">
          {done === 0 ? 'Start' : 'Continue'}
          <ChevronRight className="h-4 w-4" />
        </span>
      </div>
      <div className="mt-3 flex items-center gap-2">
        <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-ark-fill-secondary">
          <div className="h-full rounded-full bg-ark-info" style={{ width: `${pct}%` }} />
        </div>
        <span className="shrink-0 text-[11px] text-ark-text-tertiary">
          {done} / {total}
        </span>
      </div>
    </Link>
  );
}

function TrailCard({ trailKey }: { trailKey: string }) {
  const trail = TRAILS.find((t) => t.key === trailKey)!;
  const lessons = LESSONS[trailKey] ?? [];
  const completed = useCompletedSet(trailKey);
  const done = lessons.filter((l) => completed.has(l.position)).length;
  const total = lessons.length;
  const pct = total > 0 ? Math.round((done / total) * 100) : 0;
  const finished = total > 0 && done >= total;

  return (
    <Link
      href={`/dashboard/learn/${trailKey}`}
      className="group flex flex-col rounded-2xl border border-ark-divider/60 bg-ark-fill-secondary/40 p-4 transition-colors hover:border-ark-info/50"
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-[10px] font-semibold uppercase tracking-wider text-ark-text-tertiary">
            {trail.eyebrow}
          </p>
          <h3 className="mt-0.5 text-[15px] font-semibold text-ark-text">{trail.navTitle}</h3>
        </div>
        {finished ? (
          <CheckCircle2 className="h-5 w-5 shrink-0 text-emerald-500" />
        ) : (
          <ChevronRight className="h-4 w-4 shrink-0 text-ark-text-tertiary transition-transform group-hover:translate-x-0.5" />
        )}
      </div>

      <p className="mt-2 line-clamp-3 text-[13px] leading-relaxed text-ark-text-secondary">
        {trail.intro}
      </p>

      {/* Footer pinned to the bottom so cards in a row align cleanly regardless
          of how long each intro is. */}
      <div className="mt-auto pt-3">
        <div className="flex items-center gap-2">
          <span
            className={cn(
              'rounded-full px-2 py-0.5 text-[10px] font-semibold',
              DIFFICULTY_BADGE[trail.difficulty],
            )}
          >
            {DIFFICULTY_LABEL[trail.difficulty]}
          </span>
          <span className="text-[11px] text-ark-text-tertiary">
            {finished ? `${total} lessons · done` : `${done} of ${total} lessons`}
          </span>
        </div>

        {done > 0 && !finished && (
          <div className="mt-2 h-1 w-full overflow-hidden rounded-full bg-ark-fill-secondary">
            <div className="h-full rounded-full bg-ark-info" style={{ width: `${pct}%` }} />
          </div>
        )}
      </div>
    </Link>
  );
}

export default function LearnPage() {
  return (
    <div className="mx-auto max-w-3xl space-y-6">
      {/* Header */}
      <div className="flex items-center gap-3">
        <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-ark-info/10">
          <GraduationCap className="h-5 w-5 text-ark-info" />
        </div>
        <div>
          <h1 className="font-[family-name:var(--font-urbanist)] text-2xl font-bold text-ark-text">
            Learn
          </h1>
          <p className="text-[13px] text-ark-text-secondary">
            Guided, self-paced lessons across markets, crypto, and investing. No test, no rush.
          </p>
        </div>
      </div>

      {/* Guided-path continue card */}
      <ContinueCard />

      {/* Trails grouped by difficulty */}
      {DIFFICULTY_ORDER.map((diff) => {
        const trails = TRAILS.filter((t) => t.difficulty === diff);
        if (trails.length === 0) return null;
        return (
          <section key={diff} className="space-y-3">
            <h2 className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">
              {DIFFICULTY_LABEL[diff]}
            </h2>
            <div className="grid gap-3 sm:grid-cols-2">
              {trails.map((t) => (
                <TrailCard key={t.key} trailKey={t.key} />
              ))}
            </div>
          </section>
        );
      })}

      <p className="pb-4 text-center text-[11px] leading-relaxed text-ark-text-disabled">
        Educational content only — not financial advice. Always do your own research.
      </p>
    </div>
  );
}
