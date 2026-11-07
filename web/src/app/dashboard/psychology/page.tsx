'use client';

import { useMemo, useState } from 'react';
import { ChevronDown } from 'lucide-react';
import { cn } from '@/lib/utils/format';
import {
  CATEGORIES,
  PRINCIPLES,
  BOOKS,
  RHYTHMS,
  OVERDOING_SIGNS,
  MINDSET_INTRO,
  READING_INTRO,
  BALANCE_INTRO,
  RHYTHM_DEFAULT,
  OVERDOING_NOTE,
  BALANCE_CLOSER,
  beatOfTheDay,
  type PrincipleCategoryKey,
} from '@/lib/psychology/content';

function Masthead({ label }: { label: string }) {
  return (
    <>
      <div className="h-[3px] w-7 rounded-full bg-ark-accent/75" />
      <p className="mt-2 text-[12px] font-semibold uppercase tracking-[0.15em] text-ark-text">{label}</p>
    </>
  );
}

export default function PsychologyPage() {
  const beat = useMemo(() => beatOfTheDay(), []);
  const [cat, setCat] = useState<PrincipleCategoryKey | null>(null);
  const [openPrinciple, setOpenPrinciple] = useState<string | null>(null);
  const [rhythm, setRhythm] = useState<number | null>(null);

  const catPrinciples = cat ? PRINCIPLES.filter((p) => p.category === cat) : [];

  return (
    <div className="mx-auto max-w-3xl space-y-4 pb-24">
      <h1 className="text-2xl font-bold text-ark-text">Psychology</h1>

      {/* Mindset + today's beat */}
      <section className="rounded-2xl border border-ark-card-border bg-ark-card p-5">
        <Masthead label="Mindset" />
        <p className="mt-1.5 text-[13px] leading-relaxed text-ark-text-secondary">{MINDSET_INTRO}</p>

        <div className="mt-4 rounded-xl border-l-2 border-ark-accent/60 bg-ark-accent/5 p-4">
          <div className="flex items-center justify-between">
            <span className="text-[10px] font-semibold uppercase tracking-wider text-ark-accent">Mindset today</span>
            <span className="text-[10px] font-medium uppercase tracking-wide text-ark-text-tertiary">{beat.tag}</span>
          </div>
          <p className="mt-2 text-[16px] leading-relaxed text-ark-text">{beat.line}</p>
        </div>
      </section>

      {/* Principles */}
      <section className="rounded-2xl border border-ark-card-border bg-ark-card p-5">
        <Masthead label="Principles" />
        <p className="mt-1 text-[13px] text-ark-text-secondary">Tap a theme to dig in.</p>

        <div className="mt-3 grid grid-cols-2 gap-2.5">
          {CATEGORIES.map((c) => {
            const count = PRINCIPLES.filter((p) => p.category === c.key).length;
            const selected = cat === c.key;
            return (
              <button
                key={c.key}
                onClick={() => {
                  setCat(selected ? null : c.key);
                  setOpenPrinciple(null);
                }}
                className={cn(
                  'rounded-xl border p-3 text-left transition-colors',
                  selected
                    ? 'border-ark-accent/50 bg-ark-accent/10'
                    : 'border-ark-card-border bg-ark-fill-secondary/40 hover:border-ark-accent/30',
                )}
              >
                <p className="text-[14px] font-semibold text-ark-text">{c.title}</p>
                <p className="text-[11px] text-ark-text-secondary">{c.subtitle}</p>
                <p className={cn('mt-3 text-[10px] font-medium tabular-nums', selected ? 'text-ark-accent' : 'text-ark-text-tertiary')}>
                  {count} principles
                </p>
              </button>
            );
          })}
        </div>

        {cat && (
          <div className="mt-4">
            <p className="text-[10px] font-semibold uppercase tracking-wider text-ark-accent">
              {CATEGORIES.find((c) => c.key === cat)?.title}
            </p>
            <div className="mt-1 divide-y divide-ark-divider/60">
              {catPrinciples.map((p, i) => {
                const open = openPrinciple === p.title;
                return (
                  <div key={p.title} className="py-3">
                    <button onClick={() => setOpenPrinciple(open ? null : p.title)} className="flex w-full items-start gap-3 text-left">
                      <span className="w-6 shrink-0 text-[12px] font-medium tabular-nums text-ark-accent/70">
                        {String(i + 1).padStart(2, '0')}
                      </span>
                      <span className="flex-1 text-[13px] font-medium text-ark-text">{p.title}</span>
                      <ChevronDown className={cn('h-4 w-4 shrink-0 text-ark-text-tertiary transition-transform', open && 'rotate-180')} />
                    </button>
                    {open && <p className="mt-1.5 pl-9 text-[12px] leading-relaxed text-ark-text-secondary">{p.body}</p>}
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </section>

      {/* Balance */}
      <section className="rounded-2xl border border-ark-card-border bg-ark-card p-5">
        <Masthead label="Balance" />
        <p className="mt-1.5 text-[13px] leading-relaxed text-ark-text-secondary">{BALANCE_INTRO}</p>

        <p className="mt-4 text-[10px] font-semibold uppercase tracking-wider text-ark-text-tertiary">How much time is enough?</p>
        <div className="mt-2 grid grid-cols-3 gap-2">
          {RHYTHMS.map((r, i) => {
            const selected = rhythm === i;
            return (
              <button
                key={r.name}
                onClick={() => setRhythm(selected ? null : i)}
                className={cn(
                  'rounded-full px-2 py-2 text-[12px] font-semibold transition-colors',
                  selected ? 'bg-ark-accent text-white' : 'bg-ark-fill-secondary/60 text-ark-text-secondary hover:bg-ark-fill-secondary',
                )}
              >
                {r.name}
              </button>
            );
          })}
        </div>
        <p className="mt-2 text-[12px] leading-relaxed text-ark-text-secondary">
          {rhythm !== null ? RHYTHMS[rhythm].guide : RHYTHM_DEFAULT}
        </p>

        <p className="mt-5 text-[10px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Signs you&apos;re overdoing it</p>
        <ul className="mt-2 space-y-1.5">
          {OVERDOING_SIGNS.map((s) => (
            <li key={s} className="flex items-start gap-2.5">
              <span className="mt-[7px] h-1.5 w-1.5 shrink-0 rounded-full bg-ark-accent/50" />
              <span className="text-[12px] leading-relaxed text-ark-text-secondary">{s}</span>
            </li>
          ))}
        </ul>
        <p className="mt-2 text-[11px] leading-relaxed text-ark-text-tertiary">{OVERDOING_NOTE}</p>

        <p className="mt-5 text-[13px] font-medium leading-relaxed text-ark-text">{BALANCE_CLOSER}</p>
      </section>

      {/* Reading list */}
      <section className="rounded-2xl border border-ark-card-border bg-ark-card p-5">
        <Masthead label="Reading list" />
        <p className="mt-1.5 text-[13px] leading-relaxed text-ark-text-secondary">{READING_INTRO}</p>

        <div className="mt-3 divide-y divide-ark-divider/60">
          {BOOKS.map((b, i) => (
            <div key={b.title} className="flex items-start gap-3 py-3">
              <span className="w-6 shrink-0 text-[12px] font-medium tabular-nums text-ark-accent/70">
                {String(i + 1).padStart(2, '0')}
              </span>
              <div className="min-w-0">
                <p className="text-[13px] font-semibold text-ark-text">{b.title}</p>
                <p className="text-[11px] text-ark-text-tertiary">{b.author}</p>
                <p className="mt-0.5 text-[12px] leading-relaxed text-ark-text-secondary">{b.note}</p>
              </div>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
