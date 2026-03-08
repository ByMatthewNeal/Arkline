'use client';

import { Globe, AlertTriangle, Radio } from 'lucide-react';
import { Area, AreaChart, ResponsiveContainer } from 'recharts';
import { GlassCard, Badge, Skeleton } from '@/components/ui';
import { useMacroIndicators, useRegimeData, useCryptoPositioning } from '@/lib/hooks/use-market';
import { formatNumber, formatPercent, cn } from '@/lib/utils/format';

const indicatorMeta: Record<string, { label: string; color: string; unit?: string }> = {
  VIX: { label: 'VIX', color: 'var(--ark-warning)' },
  vix: { label: 'VIX', color: 'var(--ark-warning)' },
  DXY: { label: 'DXY', color: 'var(--ark-primary)' },
  dxy: { label: 'DXY', color: 'var(--ark-primary)' },
  M2: { label: 'M2', color: 'var(--ark-success)', unit: 'T' },
  m2: { label: 'M2', color: 'var(--ark-success)', unit: 'T' },
  WTI: { label: 'WTI', color: 'var(--ark-error)' },
  wti: { label: 'WTI', color: 'var(--ark-error)' },
};

function isExtreme(zScore: number | undefined): boolean {
  return zScore !== undefined && Math.abs(zScore) >= 1.5;
}

export function MacroDashboard() {
  const { data: indicators, isLoading } = useMacroIndicators();
  const { data: regime } = useRegimeData();
  const { data: positioning } = useCryptoPositioning();

  return (
    <GlassCard className="relative overflow-hidden">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-success/20 to-transparent" />

      <div className="mb-4 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-success/10">
            <Globe className="h-5 w-5 text-ark-success" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h3 className="text-sm font-semibold text-ark-text">Macro</h3>
              <span className="flex items-center gap-1 rounded-full bg-ark-success/10 px-2 py-0.5">
                <span className="h-1.5 w-1.5 rounded-full bg-ark-success animate-pulse" />
                <span className="text-[9px] font-bold uppercase tracking-wider text-ark-success">Live</span>
              </span>
            </div>
            <p className="text-[10px] text-ark-text-disabled">Key market drivers</p>
          </div>
        </div>
        {regime && (
          <Badge variant={regime.regime === 'risk-on' ? 'success' : regime.regime === 'risk-off' ? 'error' : 'default'}>
            {regime.regime === 'risk-on' ? 'Risk On' : regime.regime === 'risk-off' ? 'Risk Off' : 'Neutral'}
          </Badge>
        )}
      </div>

      {isLoading ? (
        <div className="space-y-4">
          {[0, 1, 2, 3].map((i) => (
            <Skeleton key={i} className="h-12 w-full" />
          ))}
        </div>
      ) : (
        <div className="space-y-2">
          {(indicators ?? []).map((ind) => {
            const meta = indicatorMeta[ind.name] ?? { label: ind.name, color: 'var(--ark-primary)' };
            const sparkData = ind.sparkline?.map((v, i) => ({ i, v })) ?? [];
            const isPositive = ind.change_percentage >= 0;
            const extreme = isExtreme(ind.z_score);
            return (
              <div
                key={ind.name}
                className={cn(
                  'flex items-center gap-3 rounded-xl border border-transparent px-3 py-2.5 transition-all hover:bg-ark-fill-secondary',
                  extreme && 'border-ark-warning/20 bg-ark-warning/[0.03]',
                )}
              >
                {/* Color bar */}
                <div
                  className="h-8 w-1 shrink-0 rounded-full"
                  style={{ backgroundColor: meta.color }}
                />
                <div className="w-9">
                  <div className="flex items-center gap-1">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-ark-text-tertiary">
                      {meta.label}
                    </span>
                    {extreme && <AlertTriangle className="h-2.5 w-2.5 text-ark-warning" />}
                  </div>
                </div>
                <div className="w-14 text-right">
                  <span className="fig text-sm font-bold text-ark-text">
                    {formatNumber(ind.value, 1)}
                  </span>
                </div>
                <div className="h-10 flex-1">
                  {sparkData.length > 1 && (
                    <ResponsiveContainer width="100%" height="100%">
                      <AreaChart data={sparkData}>
                        <defs>
                          <linearGradient id={`grad-${ind.name}`} x1="0" y1="0" x2="0" y2="1">
                            <stop offset="0%" stopColor={meta.color} stopOpacity={0.2} />
                            <stop offset="100%" stopColor={meta.color} stopOpacity={0} />
                          </linearGradient>
                        </defs>
                        <Area
                          type="monotone"
                          dataKey="v"
                          stroke={meta.color}
                          strokeWidth={1.5}
                          fill={`url(#grad-${ind.name})`}
                          dot={false}
                        />
                      </AreaChart>
                    </ResponsiveContainer>
                  )}
                </div>
                <div className="w-16 text-right">
                  <span
                    className={cn(
                      'fig text-xs font-semibold',
                      isPositive ? 'text-ark-success' : 'text-ark-error',
                    )}
                  >
                    {formatPercent(ind.change_percentage, 1)}
                  </span>
                  {ind.z_score !== undefined && (
                    <div className={cn(
                      'fig text-[9px]',
                      extreme ? 'font-semibold text-ark-warning' : 'text-ark-text-disabled',
                    )}>
                      z {ind.z_score > 0 ? '+' : ''}{ind.z_score.toFixed(1)}
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Regime description + investment insight */}
      {positioning && (
        <div className="mt-4 space-y-2.5 border-t border-ark-divider/50 pt-4">
          <div className="flex items-start gap-2">
            <Radio className="mt-0.5 h-3.5 w-3.5 shrink-0 text-ark-text-tertiary" />
            <div>
              <p className="text-[11px] font-semibold text-ark-text-secondary">
                {positioning.regime_label}
              </p>
              <p className="mt-0.5 text-[10px] leading-relaxed text-ark-text-disabled">
                {positioning.regime_description}
              </p>
            </div>
          </div>
        </div>
      )}
    </GlassCard>
  );
}
