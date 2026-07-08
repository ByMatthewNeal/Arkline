'use client';

/**
 * Model Portfolio card on the Portfolio page — mirrors the iOS
 * ModelPortfolioCard on the Portfolio › Overview tab. Shows the followed
 * strategy (or the first one), its return over the past month, and opens
 * the full strategies detail (tabs, follow, NAV vs SPY, trade log).
 */

import { useState } from 'react';
import { LineChart, Check, ChevronRight } from 'lucide-react';
import { GlassCard, Badge, Skeleton, DetailDrawer } from '@/components/ui';
import {
  useModelPortfolios,
  useModelPortfolioNav,
  useFollowedModelPortfolio,
} from '@/lib/hooks/use-model-portfolios';
import { ModelPortfoliosDetail } from '@/components/dashboard/home/model-portfolios-detail';
import { Spark } from '@/components/dashboard/shared/bento-primitives';
import { formatPercent, cn } from '@/lib/utils/format';

export function ModelPortfolioCard() {
  const [open, setOpen] = useState(false);
  const { data: portfolios, isLoading } = useModelPortfolios();
  const { data: followed } = useFollowedModelPortfolio();

  const shown = portfolios?.find((p) => p.strategy === followed) ?? portfolios?.[0];
  const { data: nav } = useModelPortfolioNav(shown?.id, 30);

  const points = (nav ?? []).map((p) => p.nav);
  const start = points[0] || 1;
  const last = points[points.length - 1];
  const monthReturn = last != null ? ((last - start) / start) * 100 : null;
  const latest = (nav ?? [])[nav ? nav.length - 1 : 0];
  const isFollowing = !!followed && shown?.strategy === followed;
  const up = (monthReturn ?? 0) >= 0;

  if (!isLoading && !shown) return null;

  return (
    <>
      <GlassCard
        className="group flex h-full cursor-pointer flex-col transition-shadow hover:shadow-md"
        onClick={() => setOpen(true)}
      >
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <LineChart className="h-3.5 w-3.5 text-ark-text-tertiary transition-colors duration-300 group-hover:text-ark-primary" />
            <h3 className="text-sm font-semibold text-ark-text">Model Portfolio</h3>
          </div>
          {isFollowing && (
            <span className="flex items-center gap-1 rounded-full bg-ark-primary/10 px-2 py-0.5 text-[10px] font-semibold text-ark-primary">
              <Check className="h-2.5 w-2.5" /> Following
            </span>
          )}
        </div>

        {isLoading || !shown ? (
          <Skeleton className="mt-3 h-24 w-full" />
        ) : (
          <>
            <div className="mt-3 flex items-baseline justify-between">
              <div>
                <p className="text-base font-semibold capitalize text-ark-text">{shown.name}</p>
                {monthReturn != null && (
                  <p className={cn('fig mt-0.5 text-sm font-bold', up ? 'text-ark-success' : 'text-ark-error')}>
                    {formatPercent(monthReturn)} <span className="font-normal text-ark-text-tertiary">past month</span>
                  </p>
                )}
              </div>
              {latest?.macro_regime && <Badge variant="default">{latest.macro_regime}</Badge>}
            </div>

            {/* Chart fills the card's flexible middle */}
            {points.length > 1 && (
              <div className="mt-4 min-h-16 flex-1">
                <Spark
                  data={points}
                  color={up ? 'var(--ark-success)' : 'var(--ark-error)'}
                  format={(v) => v.toFixed(0)}
                  interactive={false}
                  className="h-full"
                />
              </div>
            )}

            {/* Footer anchored to the card's bottom edge */}
            <div className="mt-4 flex items-center justify-between border-t border-ark-divider/60 pt-3">
              <span className="text-[10px] font-medium uppercase tracking-wider text-ark-text-tertiary">Past 30 days</span>
              <span className="flex items-center gap-0.5 text-xs font-medium text-ark-primary">
                View strategies <ChevronRight className="h-3.5 w-3.5 transition-transform group-hover:translate-x-0.5" />
              </span>
            </div>
          </>
        )}
      </GlassCard>

      <DetailDrawer open={open} onClose={() => setOpen(false)} title="Model Portfolios">
        <ModelPortfoliosDetail />
      </DetailDrawer>
    </>
  );
}
