'use client';

import { useEffect, useRef } from 'react';
import { Skeleton } from '@/components/ui';
import { useLiquidationHeatmap } from '@/lib/hooks/use-market';
import type { LiquidationHeatmap } from '@/types';

// Two-tone palette: blue for clusters below current price, warm for above.
const BG: [number, number, number] = [14, 14, 18];
const BELOW: [number, number, number][] = [BG, [22, 34, 78], [51, 105, 255], [127, 176, 255]];
const ABOVE: [number, number, number][] = [BG, [90, 30, 42], [224, 83, 58], [255, 200, 97]];

function lerp(a: number, b: number, f: number) { return a + (b - a) * f; }
function ramp(stops: [number, number, number][], t: number): string {
  const x = Math.max(0, Math.min(1, t)) * (stops.length - 1);
  const i = Math.min(stops.length - 2, Math.floor(x));
  const f = x - i;
  const r = Math.round(lerp(stops[i][0], stops[i + 1][0], f));
  const g = Math.round(lerp(stops[i][1], stops[i + 1][1], f));
  const b = Math.round(lerp(stops[i][2], stops[i + 1][2], f));
  return `rgb(${r},${g},${b})`;
}

function fmtK(v: number): string {
  return v >= 1000 ? `$${(v / 1000).toFixed(1)}k` : `$${Math.round(v)}`;
}

/** Canvas renderer for the liquidation heatmap grid. */
function HeatmapCanvas({ data, height, axes }: { data: LiquidationHeatmap; height: number; axes: boolean }) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const wrap = wrapRef.current;
    const canvas = canvasRef.current;
    if (!wrap || !canvas) return;

    const draw = () => {
      const cssW = wrap.clientWidth;
      const cssH = height;
      const dpr = window.devicePixelRatio || 1;
      canvas.width = Math.round(cssW * dpr);
      canvas.height = Math.round(cssH * dpr);
      canvas.style.width = `${cssW}px`;
      canvas.style.height = `${cssH}px`;
      const ctx = canvas.getContext('2d');
      if (!ctx) return;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, cssW, cssH);

      const padL = axes ? 46 : 0;
      const padB = axes ? 20 : 0;
      const plotW = cssW - padL;
      const plotH = cssH - padB;

      const { grid, prices, closes, price_min: pmin, price_max: pmax, current_price: cur } = data;
      const B = grid.length;
      const D = grid[0]?.length ?? 0;
      if (!B || !D) return;

      // contrast: gamma + clip at ~96th percentile of nonzero values
      const vals: number[] = [];
      for (let b = 0; b < B; b++) for (let t = 0; t < D; t++) {
        const v = grid[b][t]; if (v > 0) vals.push(Math.pow(v / 1000, 0.6));
      }
      vals.sort((a, b) => a - b);
      const vmax = vals.length ? vals[Math.floor(vals.length * 0.96)] || vals[vals.length - 1] : 1;

      const cellW = plotW / D;
      const cellH = plotH / B;
      // Snap every cell edge to a whole device pixel so neighbouring bands don't
      // bleed into each other through sub-pixel anti-aliasing. Cells share exact
      // integer edges, so they tile with no gaps and no overlap.
      const snap = (v: number) => Math.round(v * dpr) / dpr;
      const xEdges: number[] = [];
      for (let t = 0; t <= D; t++) xEdges[t] = snap(padL + t * cellW);
      const yEdges: number[] = [];
      for (let b = 0; b <= B; b++) yEdges[b] = snap(plotH - b * cellH);
      for (let b = 0; b < B; b++) {
        const below = prices[b] < cur;
        const yTop = yEdges[b + 1];
        const h = yEdges[b] - yTop;
        for (let t = 0; t < D; t++) {
          const v = grid[b][t];
          if (v <= 0) continue;
          const tt = Math.min(1, Math.pow(v / 1000, 0.6) / vmax);
          ctx.fillStyle = ramp(below ? BELOW : ABOVE, tt);
          ctx.fillRect(xEdges[t], yTop, xEdges[t + 1] - xEdges[t], h);
        }
      }

      const yOf = (p: number) => plotH - ((p - pmin) / (pmax - pmin)) * plotH;

      // price line
      if (closes?.length === D) {
        ctx.beginPath();
        ctx.lineWidth = 1.3; ctx.strokeStyle = 'rgba(255,255,255,0.9)';
        for (let t = 0; t < D; t++) {
          const x = padL + (t + 0.5) * cellW; const y = yOf(closes[t]);
          t === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
        }
        ctx.stroke();
      }

      // now line
      const ny = yOf(cur);
      ctx.setLineDash([4, 3]); ctx.lineWidth = 1; ctx.strokeStyle = 'rgba(51,105,255,0.9)';
      ctx.beginPath(); ctx.moveTo(padL, ny); ctx.lineTo(cssW, ny); ctx.stroke();
      ctx.setLineDash([]);

      if (axes) {
        ctx.fillStyle = '#6E6E7A'; ctx.font = '10px -apple-system, sans-serif'; ctx.textAlign = 'right';
        const ticks = 5;
        for (let i = 0; i <= ticks; i++) {
          const p = pmin + ((pmax - pmin) * i) / ticks;
          ctx.fillText(fmtK(p), padL - 6, yOf(p) + 3);
        }
        ctx.textAlign = 'left'; ctx.fillStyle = '#8fb0ff';
        ctx.fillText(`Now ${fmtK(cur)}`, padL + 4, ny - 4);
      }
    };

    draw();
    const ro = new ResizeObserver(draw);
    ro.observe(wrap);
    return () => ro.disconnect();
  }, [data, height, axes]);

  return (
    <div ref={wrapRef} className="w-full" style={{ height }}>
      <canvas ref={canvasRef} />
    </div>
  );
}

/** Full detail view. */
export function LiquidationHeatmapDetail() {
  const { data, isLoading } = useLiquidationHeatmap();
  if (isLoading) return <Skeleton className="h-72 w-full" />;
  if (!data) return <p className="py-8 text-center text-sm text-ark-text-tertiary">Heatmap unavailable right now.</p>;

  // Sorted by price, nearest to current price first: below descends, above ascends.
  const below = data.clusters.filter((c) => c.side === 'below').sort((a, b) => b.price - a.price);
  const above = data.clusters.filter((c) => c.side === 'above').sort((a, b) => a.price - b.price);

  return (
    <div className="space-y-4 pb-2">
      <div className="rounded-2xl border border-ark-divider bg-ark-card p-3">
        <HeatmapCanvas data={data} height={300} axes />
        <div className="mt-2 flex flex-wrap justify-center gap-x-4 gap-y-1 text-[10px] text-ark-text-tertiary">
          <span className="flex items-center gap-1"><span className="h-2 w-3 rounded" style={{ background: 'rgb(51,105,255)' }} /> Clusters below price</span>
          <span className="flex items-center gap-1"><span className="h-2 w-3 rounded" style={{ background: 'rgb(224,83,58)' }} /> Clusters above price</span>
          <span className="flex items-center gap-1"><span className="h-0.5 w-3 rounded bg-white" /> Price</span>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/20 p-3">
          <p className="mb-1 text-[10px] font-bold uppercase tracking-wider" style={{ color: 'rgb(127,176,255)' }}>Magnets below</p>
          {below.length ? below.map((c, i) => (
            <div key={i} className="flex justify-between py-0.5 text-sm">
              <span className="fig font-semibold text-ark-text">{fmtK(c.price)}</span>
              <span className="fig text-xs text-ark-text-secondary">{(((c.price - data.current_price) / data.current_price) * 100).toFixed(1)}%</span>
            </div>
          )) : <p className="text-xs text-ark-text-tertiary">None standing.</p>}
        </div>
        <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/20 p-3">
          <p className="mb-1 text-[10px] font-bold uppercase tracking-wider" style={{ color: 'rgb(255,170,90)' }}>Magnets above</p>
          {above.length ? above.map((c, i) => (
            <div key={i} className="flex justify-between py-0.5 text-sm">
              <span className="fig font-semibold text-ark-text">{fmtK(c.price)}</span>
              <span className="fig text-xs text-ark-text-secondary">+{(((c.price - data.current_price) / data.current_price) * 100).toFixed(1)}%</span>
            </div>
          )) : <p className="text-xs text-ark-text-tertiary">None standing.</p>}
        </div>
      </div>

      <div>
        <h4 className="mb-1.5 text-sm font-semibold text-ark-text">How the Liquidation Heatmap Works</h4>
        <div className="space-y-1 text-[13px] leading-relaxed text-ark-text-secondary">
          <p>Bright bands mark price levels where leveraged positions would likely be liquidated. Blue sits below the current price, warm sits above.</p>
          <p>A band persists until price trades through it, so a cluster that is still glowing has not been hit yet and can act as a magnet.</p>
          <p>This is an estimate modeled from open positions and typical leverage, not exchange liquidation data. Guides, not guarantees. Source: Coinalyze.</p>
        </div>
      </div>
    </div>
  );
}

/** Compact tile for Home / Market grids. */
export function LiquidationHeatmapTile({ onOpen }: { onOpen: () => void }) {
  const { data, isLoading } = useLiquidationHeatmap();
  if (isLoading) return <Skeleton className="h-full w-full" />;
  if (!data) return null;
  const top = data.clusters[0];
  return (
    <button onClick={onOpen} className="flex h-full w-full flex-col overflow-hidden rounded-2xl border border-ark-divider bg-ark-card p-3 text-left">
      <div className="flex items-center justify-between">
        <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Liquidation Heatmap</span>
        <span className="fig text-[11px] text-ark-text-secondary">BTC {fmtK(data.current_price)}</span>
      </div>
      <div className="mt-2 flex-1">
        <HeatmapCanvas data={data} height={120} axes={false} />
      </div>
      {top && (
        <p className="mt-2 text-[11px] text-ark-text-secondary">
          Largest cluster {top.side} at <span className="fig font-semibold text-ark-text">{fmtK(top.price)}</span>
        </p>
      )}
    </button>
  );
}
