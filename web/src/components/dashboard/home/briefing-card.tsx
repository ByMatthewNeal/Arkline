'use client';

import { Brain, Sparkles, Clock } from 'lucide-react';
import { Skeleton } from '@/components/ui';
import { useMarketBriefing, useCryptoPositioning } from '@/lib/hooks/use-market';
import { parseBriefingSections } from '@/lib/utils/format';
import { useState, useEffect } from 'react';

/**
 * Full Daily Briefing detail (rendered in the drawer). Mirrors the iOS expanded
 * briefing: greeting, regime pill, and the labeled sections (TLDR, Weekend
 * Pulse, Technical, Week Ahead, Mindset, …).
 */
export function BriefingCard() {
  const { data: briefing, isLoading } = useMarketBriefing();
  const { data: positioning } = useCryptoPositioning();
  const [today, setToday] = useState('');

  useEffect(() => {
    setToday(
      new Date().toLocaleDateString('en-US', {
        weekday: 'long', month: 'long', day: 'numeric', year: 'numeric',
      }),
    );
  }, []);

  const sections = parseBriefingSections(briefing);

  return (
    <div className="flex flex-col">
      <div className="mb-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-primary/10">
            <Brain className="h-5 w-5 text-ark-primary" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h3 className="text-sm font-semibold text-ark-text">Daily Briefing</h3>
              <span className="flex items-center gap-1 rounded-full bg-ark-primary/10 px-2 py-0.5">
                <Sparkles className="h-2.5 w-2.5 text-ark-primary" />
                <span className="text-[9px] font-semibold uppercase tracking-wider text-ark-primary">AI</span>
              </span>
            </div>
            {today && (
              <p className="mt-0.5 flex items-center gap-1 text-[10px] text-ark-text-disabled">
                <Clock className="h-2.5 w-2.5" />{today}
              </p>
            )}
          </div>
        </div>
        {positioning?.regime && (() => {
          const isRiskOn = positioning.regime.includes('risk-on');
          const isRiskOff = positioning.regime.includes('risk-off');
          const label = isRiskOn ? 'RISK-ON' : isRiskOff ? 'RISK-OFF' : 'MIXED';
          const dotColor = isRiskOn ? 'bg-ark-success' : isRiskOff ? 'bg-ark-error' : 'bg-ark-warning';
          const textColor = isRiskOn ? 'text-ark-success' : isRiskOff ? 'text-ark-error' : 'text-ark-warning';
          const bgColor = isRiskOn ? 'bg-ark-success/10' : isRiskOff ? 'bg-ark-error/10' : 'bg-ark-warning/10';
          return (
            <span className={`flex items-center gap-1.5 rounded-full px-2.5 py-1 ${bgColor}`}>
              <span className={`h-1.5 w-1.5 rounded-full ${dotColor} animate-pulse`} />
              <span className={`text-[10px] font-bold uppercase tracking-wider ${textColor}`}>{label}</span>
            </span>
          );
        })()}
      </div>

      {isLoading ? (
        <div className="space-y-3">
          {[0, 1, 2, 3, 4].map((i) => <Skeleton key={i} className="h-4 w-full" />)}
        </div>
      ) : sections.length ? (
        <div className="space-y-4">
          {sections.map((s, i) => (
            <div key={i}>
              {s.title && (
                <p className="mb-1 text-[11px] font-bold uppercase tracking-wider text-ark-primary">{s.title}</p>
              )}
              <div className="space-y-2 text-sm leading-[1.7] text-ark-text-secondary">
                {s.body.split('\n').filter(Boolean).map((line, j) => <p key={j}>{line}</p>)}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-ark-fill-secondary">
            <Brain className="h-6 w-6 text-ark-text-tertiary" />
          </div>
          <p className="mt-3 text-sm text-ark-text-tertiary">No briefing available yet</p>
          <p className="mt-1 text-xs text-ark-text-disabled">Briefings are generated daily before market open</p>
        </div>
      )}
    </div>
  );
}
