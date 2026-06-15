'use client';

import { useState } from 'react';
import { ArrowUpRight, ArrowDownRight, ChevronLeft, ChevronRight } from 'lucide-react';
import { Badge, Skeleton } from '@/components/ui';
import { cn, formatPercent } from '@/lib/utils/format';
import { useTradeSignals, useRotationSignal, useModelPortfolioUpdate, useWeeklyDeck } from '@/lib/hooks/use-market';
import type { DeckSlide } from '@/types';

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-3">
      <p className="text-[10px] uppercase tracking-wider text-ark-text-disabled">{label}</p>
      <p className="fig mt-0.5 text-sm font-bold text-ark-text">{value}</p>
    </div>
  );
}

function Info({ title, lines }: { title: string; lines: string[] }) {
  return (
    <div>
      <h4 className="mb-1.5 text-sm font-semibold text-ark-text">{title}</h4>
      <div className="space-y-1 text-[13px] leading-relaxed text-ark-text-secondary">
        {lines.map((l, i) => <p key={i}>{l}</p>)}
      </div>
    </div>
  );
}

// ── Trade Signals ───────────────────────────────────────────────────────────
export function TradeSignalsDetail() {
  const { data, isLoading } = useTradeSignals();
  if (isLoading) return <Skeleton className="h-64 w-full" />;
  const signals = data ?? [];
  const outcome = (s: string) => s === 'target_hit' ? { label: 'Win', color: 'var(--ark-success)' } : s === 'invalidated' ? { label: 'Stopped', color: 'var(--ark-error)' } : { label: s.charAt(0).toUpperCase() + s.slice(1), color: 'var(--ark-warning)' };

  return (
    <div className="space-y-4 pb-4">
      {signals.length === 0 ? (
        <p className="py-8 text-center text-sm text-ark-text-tertiary">No recent signals.</p>
      ) : (
        <div className="space-y-2">
          {signals.map((s) => {
            const o = outcome(s.status);
            return (
              <div key={s.id} className="flex items-center gap-3 rounded-xl border border-ark-divider p-3">
                <span className={cn('rounded px-2 py-0.5 text-[10px] font-bold text-white', s.signal_type === 'buy' ? 'bg-ark-success' : 'bg-ark-error')}>{s.signal_type.toUpperCase()}</span>
                <span className="w-14 text-sm font-semibold text-ark-text">{s.asset}</span>
                {s.timeframe && <span className="text-xs text-ark-text-disabled">{s.timeframe}</span>}
                {s.risk_reward_ratio != null && <span className="fig text-xs text-ark-text-tertiary">{s.risk_reward_ratio.toFixed(1)}x R:R</span>}
                <span className="ml-auto text-xs font-semibold" style={{ color: o.color }}>{o.label}</span>
              </div>
            );
          })}
        </div>
      )}
      <Info title="How signals work" lines={[
        'Fibonacci-based pattern detection runs across 1H and 4H candles, requiring multi-timeframe confluence, EMA trend alignment, and at least a 1:1 risk-to-reward ratio.',
        'Win = first target hit; Stopped = stop loss / invalidation. For educational purposes only.',
      ]} />
    </div>
  );
}

// ── Rotation ────────────────────────────────────────────────────────────────
export function RotationDetail() {
  const { data, isLoading } = useRotationSignal();
  if (isLoading) return <Skeleton className="h-64 w-full" />;
  if (!data) return <p className="py-8 text-center text-sm text-ark-text-tertiary">No rotation data.</p>;

  const score = data.rotation_score;
  const favors = score < 0 ? 'Crypto' : score > 0 ? 'Equities' : 'Neutral';
  const color = score < 0 ? 'var(--ark-primary)' : score > 0 ? 'var(--ark-violet)' : 'var(--ark-text-tertiary)';
  const pos = ((score + 100) / 200) * 100; // -100..100 → 0..100

  return (
    <div className="space-y-6 pb-4">
      <div className="flex flex-col items-center gap-1 pt-2">
        <span className="font-[family-name:var(--font-urbanist)] text-4xl font-bold" style={{ color }}>→ {favors}</span>
        <span className="text-xs text-ark-text-disabled">Rotation score {score > 0 ? '+' : ''}{score}</span>
      </div>

      {/* Crypto ↔ Equities scale */}
      <div>
        <div className="flex justify-between text-[10px] font-semibold uppercase tracking-wider text-ark-text-disabled">
          <span>Crypto</span><span>Equities</span>
        </div>
        <div className="relative mt-1 h-2 rounded-full bg-gradient-to-r from-ark-primary via-ark-text-tertiary to-ark-violet">
          <div className="absolute top-1/2 h-3.5 w-3.5 -translate-y-1/2 -translate-x-1/2 rounded-full border-2 border-ark-card bg-ark-text" style={{ left: `${pos}%` }} />
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-3 text-center">
          <p className="text-[10px] uppercase tracking-wider text-ark-text-disabled">BTC 30d</p>
          <p className={cn('fig mt-0.5 text-sm font-bold', (data.btc_30d_return ?? 0) >= 0 ? 'text-ark-success' : 'text-ark-error')}>{formatPercent(data.btc_30d_return ?? 0)}</p>
        </div>
        <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-3 text-center">
          <p className="text-[10px] uppercase tracking-wider text-ark-text-disabled">SPY 30d</p>
          <p className={cn('fig mt-0.5 text-sm font-bold', (data.spy_30d_return ?? 0) >= 0 ? 'text-ark-success' : 'text-ark-error')}>{formatPercent(data.spy_30d_return ?? 0)}</p>
        </div>
      </div>

      {data.narrative && <Info title="Narrative" lines={[data.narrative]} />}

      {data.sectors.length > 0 && (
        <div>
          <h4 className="mb-2 text-sm font-semibold text-ark-text">Top Sectors</h4>
          <div className="space-y-1.5">
            {data.sectors.map((s) => (
              <div key={s.name} className="flex items-center justify-between text-sm">
                <span className="text-ark-text-secondary">{s.name}</span>
                <span className="fig font-semibold text-ark-success">{formatPercent(s.return_30d)}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// ── Model Portfolio ─────────────────────────────────────────────────────────
export function ModelPortfolioDetail() {
  const { data, isLoading } = useModelPortfolioUpdate();
  if (isLoading) return <Skeleton className="h-64 w-full" />;
  if (!data) return <p className="py-8 text-center text-sm text-ark-text-tertiary">No updates.</p>;
  const fmt = (d: string) => new Date(d + 'T00:00:00').toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });

  return (
    <div className="space-y-5 pb-4">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-lg font-semibold text-ark-text">{data.portfolio_name}</p>
          <p className="text-xs text-ark-text-disabled">{fmt(data.trade_date)}</p>
        </div>
        <Badge variant="default">{data.trigger}</Badge>
      </div>

      {data.changes.length === 0 ? (
        <p className="text-sm text-ark-text-tertiary">No allocation changes in this update.</p>
      ) : (
        <div>
          <h4 className="mb-2 text-sm font-semibold text-ark-text">Allocation Changes</h4>
          <div className="space-y-2">
            {data.changes.map((c) => {
              const up = c.to >= c.from;
              return (
                <div key={c.asset} className="flex items-center gap-3 rounded-xl border border-ark-divider p-2.5">
                  <span className="w-16 text-sm font-semibold text-ark-text">{c.asset}</span>
                  <span className="fig text-sm text-ark-text-disabled">{c.from.toFixed(1)}%</span>
                  {up ? <ArrowUpRight className="h-4 w-4 text-ark-success" /> : <ArrowDownRight className="h-4 w-4 text-ark-error" />}
                  <span className="fig text-sm font-semibold text-ark-text">{c.to.toFixed(1)}%</span>
                  <span className={cn('fig ml-auto text-xs font-semibold', up ? 'text-ark-success' : 'text-ark-error')}>{up ? '+' : ''}{(c.to - c.from).toFixed(1)}%</span>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

// ── Weekly Update (slide viewer) ─────────────────────────────────────────────
function asStr(v: unknown): string {
  return v == null ? '' : String(v);
}

function SlideBody({ slide }: { slide: DeckSlide }) {
  const p = slide.payload ?? {};
  switch (slide.type) {
    case 'cover':
      return (
        <div className="text-center">
          <p className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Weekly Market Update</p>
          {p.regime != null && <p className="mt-2 text-2xl font-bold text-ark-text">{asStr(p.regime)}</p>}
          <div className="mt-4 grid grid-cols-2 gap-3 text-left">
            {p.btc_price != null && <Stat label="BTC" value={`$${Number(p.btc_price).toLocaleString()}`} />}
            {p.btc_weekly_change != null && <Stat label="BTC Weekly" value={`${Number(p.btc_weekly_change) >= 0 ? '+' : ''}${Number(p.btc_weekly_change).toFixed(1)}%`} />}
            {p.fear_greed_start != null && <Stat label="F&G Start" value={asStr(p.fear_greed_start)} />}
            {p.fear_greed_end != null && <Stat label="F&G End" value={asStr(p.fear_greed_end)} />}
          </div>
        </div>
      );
    case 'sectionTitle':
      return (
        <div className="flex h-full flex-col items-center justify-center text-center">
          <p className="font-[family-name:var(--font-urbanist)] text-2xl font-bold text-ark-text">{slide.title}</p>
          {p.subtitle != null && <p className="mt-2 text-sm text-ark-text-secondary">{asStr(p.subtitle)}</p>}
        </div>
      );
    case 'editorial':
      return (
        <div>
          {p.category != null && <p className="text-[10px] font-bold uppercase tracking-wider text-ark-primary">{asStr(p.category)}</p>}
          <h4 className="mt-1 text-base font-semibold text-ark-text">{slide.title}</h4>
          {Array.isArray(p.bullets) && (
            <ul className="mt-2 space-y-1.5">
              {(p.bullets as unknown[]).map((b, i) => (
                <li key={i} className="flex gap-2 text-sm leading-relaxed text-ark-text-secondary">
                  <span className="mt-1.5 h-1 w-1 shrink-0 rounded-full bg-ark-primary" />{asStr(b)}
                </li>
              ))}
            </ul>
          )}
        </div>
      );
    case 'weeklyOutlook':
      return (
        <div className="space-y-2">
          {p.tone != null && <Badge variant="default">{asStr(p.tone)}</Badge>}
          {p.headline != null && <h4 className="text-base font-semibold text-ark-text">{asStr(p.headline)}</h4>}
          {p.look_ahead != null && <p className="text-sm leading-relaxed text-ark-text-secondary">{asStr(p.look_ahead)}</p>}
          {p.risk_asset_impact != null && (
            <div><p className="mt-1 text-[10px] font-bold uppercase tracking-wider text-ark-primary">Risk Asset Impact</p>
              <p className="text-sm leading-relaxed text-ark-text-secondary">{asStr(p.risk_asset_impact)}</p></div>
          )}
        </div>
      );
    default:
      return (
        <div className="space-y-2">
          <h4 className="text-base font-semibold text-ark-text">{slide.title}</h4>
          {Object.entries(p).filter(([, v]) => typeof v === 'string' || typeof v === 'number').slice(0, 8).map(([k, v]) => (
            <div key={k} className="flex justify-between text-sm">
              <span className="capitalize text-ark-text-tertiary">{k.replace(/_/g, ' ')}</span>
              <span className="fig font-medium text-ark-text">{asStr(v)}</span>
            </div>
          ))}
        </div>
      );
  }
}

export function WeeklyUpdateDetail() {
  const { data, isLoading } = useWeeklyDeck();
  const [idx, setIdx] = useState(0);
  if (isLoading) return <Skeleton className="h-72 w-full" />;
  if (!data) return <p className="py-8 text-center text-sm text-ark-text-tertiary">No deck published yet.</p>;
  const fmt = (d: string) => new Date(d + 'T00:00:00').toLocaleDateString('en-US', { month: 'long', day: 'numeric' });
  const slides = data.slides ?? [];
  if (!slides.length) return <p className="py-8 text-center text-sm text-ark-text-tertiary">This deck has no slides.</p>;
  const i = Math.min(idx, slides.length - 1);
  const slide = slides[i];

  return (
    <div className="space-y-3 pb-4">
      <div className="flex items-center justify-between">
        <span className="text-sm font-semibold text-ark-text">{fmt(data.week_start)} – {fmt(data.week_end)}</span>
        <span className="rounded-full bg-ark-violet/10 px-2.5 py-0.5 text-[10px] font-semibold capitalize text-ark-violet">{data.status}</span>
      </div>

      {/* Slide */}
      <div className="flex min-h-[260px] flex-col rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-5">
        <SlideBody slide={slide} />
      </div>

      {/* Controls */}
      <div className="flex items-center justify-between">
        <button onClick={() => setIdx(Math.max(0, i - 1))} disabled={i === 0}
          className="flex h-9 w-9 items-center justify-center rounded-full bg-ark-fill-secondary text-ark-text-secondary transition-colors hover:bg-ark-divider disabled:opacity-30">
          <ChevronLeft className="h-4 w-4" />
        </button>
        <div className="flex items-center gap-1.5">
          {slides.map((_, j) => (
            <button key={j} onClick={() => setIdx(j)} aria-label={`Slide ${j + 1}`}
              className={cn('h-1.5 rounded-full transition-all', j === i ? 'w-4 bg-ark-primary' : 'w-1.5 bg-ark-divider')} />
          ))}
        </div>
        <button onClick={() => setIdx(Math.min(slides.length - 1, i + 1))} disabled={i === slides.length - 1}
          className="flex h-9 w-9 items-center justify-center rounded-full bg-ark-fill-secondary text-ark-text-secondary transition-colors hover:bg-ark-divider disabled:opacity-30">
          <ChevronRight className="h-4 w-4" />
        </button>
      </div>
      <p className="text-center text-[11px] text-ark-text-disabled">{slide.title || `Slide ${i + 1}`} · {i + 1} / {slides.length}</p>
    </div>
  );
}
