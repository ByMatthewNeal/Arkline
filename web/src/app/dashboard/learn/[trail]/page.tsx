'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import {
  ArrowLeft,
  ChevronRight,
  ChevronLeft,
  CheckCircle2,
  Circle,
  Eye,
  Brain,
  Lightbulb,
  Sparkles,
} from 'lucide-react';
import { TRAILS, type Lesson } from '@/lib/learn/content';
import { useTrailLessons } from '@/lib/learn/db';
import { markComplete, firstIncompleteIndex } from '@/lib/learn/progress';
import { useCompletedSet } from '@/lib/learn/hooks';
import { cn } from '@/lib/utils/format';

/** Callout block used for "In the app", "Mindset check", "One more thing". */
function Callout({
  icon: Icon,
  label,
  text,
  accent,
}: {
  icon: typeof Eye;
  label: string;
  text: string;
  accent: string;
}) {
  return (
    <div className={cn('rounded-xl border-l-2 bg-ark-fill-secondary/40 px-3 py-2.5', accent)}>
      <div className="flex items-center gap-1.5">
        <Icon className="h-3.5 w-3.5 text-ark-text-tertiary" />
        <p className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">
          {label}
        </p>
      </div>
      <p className="mt-1 text-[13px] leading-relaxed text-ark-text-secondary">{text}</p>
    </div>
  );
}

export default function TrailPage() {
  const params = useParams<{ trail: string }>();
  const trailKey = params.trail;
  const trail = TRAILS.find((t) => t.key === trailKey);
  // Seed shown instantly; published trail_lessons rows (edited in the iOS
  // admin Trail editor) overlay by position once fetched.
  const { data } = useTrailLessons(trailKey);
  const lessons = useMemo(() => data ?? [], [data]);

  const done = useCompletedSet(trailKey);
  const [mode, setMode] = useState<'list' | 'reader'>('list');
  const [index, setIndex] = useState(0);

  // Arriving from the "Continue" card (?open=1) drops straight into the next
  // incomplete lesson instead of the list. Consumed once — the DB-overlay
  // refetch must not yank the user back into the reader later.
  const openConsumed = useRef(false);
  useEffect(() => {
    if (typeof window === 'undefined' || lessons.length === 0 || openConsumed.current) return;
    if (new URLSearchParams(window.location.search).get('open') !== '1') return;
    openConsumed.current = true;
    const id = requestAnimationFrame(() => {
      setIndex(firstIncompleteIndex(lessons.map((l) => l.position), trailKey));
      setMode('reader');
    });
    return () => cancelAnimationFrame(id);
  }, [trailKey, lessons]);

  if (!trail || lessons.length === 0) {
    return (
      <div className="mx-auto max-w-3xl">
        <Link href="/dashboard/learn" className="inline-flex items-center gap-1.5 text-sm text-ark-info">
          <ArrowLeft className="h-4 w-4" /> Learn
        </Link>
        <p className="mt-8 text-center text-sm text-ark-text-secondary">Trail not found.</p>
      </div>
    );
  }

  const total = lessons.length;
  const doneCount = lessons.filter((l) => done.has(l.position)).length;
  const finished = doneCount >= total;

  const openReader = (i: number) => {
    setIndex(i);
    setMode('reader');
  };

  // ---------- LIST ----------
  if (mode === 'list') {
    return (
      <div className="mx-auto max-w-3xl space-y-5">
        <Link href="/dashboard/learn" className="inline-flex items-center gap-1.5 text-sm text-ark-info">
          <ArrowLeft className="h-4 w-4" /> Learn
        </Link>

        <div>
          <p className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">
            {trail.eyebrow}
          </p>
          <h1 className="mt-1 font-[family-name:var(--font-urbanist)] text-2xl font-bold text-ark-text">
            {trail.navTitle}
          </h1>
          <p className="mt-2 text-[14px] leading-relaxed text-ark-text-secondary">{trail.intro}</p>
        </div>

        <button
          onClick={() => openReader(firstIncompleteIndex(lessons.map((l) => l.position), trailKey))}
          className="w-full rounded-xl bg-ark-info py-3 text-sm font-semibold text-white transition-opacity hover:opacity-90"
        >
          {doneCount === 0 ? 'Start' : finished ? 'Review from the start' : 'Continue'}
          <span className="ml-2 opacity-80">
            {doneCount} / {total}
          </span>
        </button>

        <div className="divide-y divide-ark-divider/60 overflow-hidden rounded-2xl border border-ark-divider/60 bg-ark-fill-secondary/40">
          {lessons.map((l, i) => {
            const isDone = done.has(l.position);
            return (
              <button
                key={l.position}
                onClick={() => openReader(i)}
                className="flex w-full items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-ark-fill-secondary/60"
              >
                {isDone ? (
                  <CheckCircle2 className="h-5 w-5 shrink-0 text-emerald-500" />
                ) : (
                  <Circle className="h-5 w-5 shrink-0 text-ark-text-disabled" />
                )}
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium text-ark-text">{l.title}</p>
                  <p className="truncate text-[12px] text-ark-text-tertiary">{l.preview}</p>
                </div>
                <ChevronRight className="h-4 w-4 shrink-0 text-ark-text-tertiary" />
              </button>
            );
          })}
        </div>
      </div>
    );
  }

  // ---------- READER ----------
  const lesson: Lesson = lessons[index];
  const isLast = index === total - 1;
  const paragraphs = lesson.idea.split('\n').map((s) => s.trim()).filter(Boolean);

  const completeAndAdvance = () => {
    markComplete(trailKey, lesson.position);
    if (isLast) setMode('list');
    else setIndex((i) => Math.min(i + 1, total - 1));
  };

  return (
    <div className="mx-auto max-w-2xl">
      {/* top bar */}
      <div className="mb-4 flex items-center justify-between">
        <button
          onClick={() => setMode('list')}
          className="inline-flex items-center gap-1.5 text-sm text-ark-info"
        >
          <ArrowLeft className="h-4 w-4" /> {trail.navTitle}
        </button>
        <span className="text-[12px] text-ark-text-tertiary">
          Lesson {index + 1} of {total}
        </span>
      </div>

      {/* progress bar */}
      <div className="mb-5 h-1 w-full overflow-hidden rounded-full bg-ark-fill-secondary">
        <div
          className="h-full rounded-full bg-ark-info transition-all"
          style={{ width: `${((index + 1) / total) * 100}%` }}
        />
      </div>

      <p className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">
        {trail.eyebrow}
      </p>
      <h1 className="mt-1 font-[family-name:var(--font-urbanist)] text-xl font-bold text-ark-text">
        {lesson.title}
      </h1>

      <div className="mt-4 space-y-3">
        {paragraphs.map((p, i) => (
          <p key={i} className="text-[14px] leading-relaxed text-ark-text-secondary">
            {p}
          </p>
        ))}
      </div>

      <div className="mt-4 space-y-2.5">
        {lesson.seeInApp && (
          <Callout icon={Eye} label="In the app" text={lesson.seeInApp} accent="border-ark-info/40" />
        )}
        {lesson.mindsetCheck && (
          <Callout
            icon={Brain}
            label="Mindset check"
            text={lesson.mindsetCheck}
            accent="border-amber-500/40"
          />
        )}
      </div>

      {/* takeaway */}
      <div className="mt-4 rounded-xl border border-ark-info/30 bg-ark-info/5 px-4 py-3">
        <div className="flex items-center gap-1.5">
          <Lightbulb className="h-4 w-4 text-ark-info" />
          <p className="text-[11px] font-semibold uppercase tracking-wider text-ark-info">Takeaway</p>
        </div>
        <p className="mt-1 text-[14px] font-medium leading-relaxed text-ark-text">{lesson.takeaway}</p>
      </div>

      {lesson.oneMoreThing && (
        <div className="mt-3">
          <Callout
            icon={Sparkles}
            label="One more thing"
            text={lesson.oneMoreThing}
            accent="border-ark-divider"
          />
        </div>
      )}

      {/* bottom nav */}
      <div className="mt-6 flex items-center gap-3">
        <button
          onClick={() => setIndex((i) => Math.max(0, i - 1))}
          disabled={index === 0}
          className="inline-flex items-center gap-1 rounded-xl border border-ark-divider px-3 py-2.5 text-sm text-ark-text-secondary transition-colors hover:text-ark-text disabled:opacity-40"
        >
          <ChevronLeft className="h-4 w-4" /> Prev
        </button>
        <button
          onClick={completeAndAdvance}
          className="flex-1 rounded-xl bg-ark-info py-2.5 text-sm font-semibold text-white transition-opacity hover:opacity-90"
        >
          {done.has(lesson.position)
            ? isLast
              ? 'Finish'
              : 'Next'
            : isLast
              ? 'Mark complete & finish'
              : 'Mark complete & continue'}
        </button>
      </div>
    </div>
  );
}
