'use client';

import { Brain, Sparkles, Clock, ChevronDown } from 'lucide-react';
import { GlassCard, Skeleton } from '@/components/ui';
import { useMarketBriefing, useCryptoPositioning } from '@/lib/hooks/use-market';
import { useState, useEffect, useRef } from 'react';

export function BriefingCard() {
  const { data: briefing, isLoading } = useMarketBriefing();
  const { data: positioning } = useCryptoPositioning();
  const [today, setToday] = useState('');
  const [isScrolled, setIsScrolled] = useState(false);
  const [canScroll, setCanScroll] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setToday(
      new Date().toLocaleDateString('en-US', {
        weekday: 'long',
        month: 'long',
        day: 'numeric',
        year: 'numeric',
      }),
    );
  }, []);

  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    setCanScroll(el.scrollHeight > el.clientHeight);
    const handler = () => {
      setIsScrolled(el.scrollTop + el.clientHeight >= el.scrollHeight - 4);
    };
    el.addEventListener('scroll', handler);
    return () => el.removeEventListener('scroll', handler);
  }, [briefing]);

  // Extract first sentence as the headline
  const headline = briefing?.split(/\.\s/)?.[0];
  const rest = briefing && headline ? briefing.slice(headline.length + 2) : briefing;

  return (
    <GlassCard className="relative flex h-full flex-col overflow-hidden">
      {/* Top accent line */}
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-primary/30 to-transparent" />

      <div className="mb-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-primary/10">
            <Brain className="h-5 w-5 text-ark-primary" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h3 className="text-sm font-semibold text-ark-text">Daily Briefing</h3>
              <span className="flex items-center gap-1 rounded-full bg-ark-primary/8 px-2 py-0.5">
                <Sparkles className="h-2.5 w-2.5 text-ark-primary" />
                <span className="text-[9px] font-semibold uppercase tracking-wider text-ark-primary">
                  AI
                </span>
              </span>
            </div>
            {today && (
              <p className="mt-0.5 flex items-center gap-1 text-[10px] text-ark-text-disabled">
                <Clock className="h-2.5 w-2.5" />
                {today}
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
              <span className={`text-[10px] font-bold uppercase tracking-wider ${textColor}`}>
                {label}
              </span>
            </span>
          );
        })()}
      </div>

      {isLoading ? (
        <div className="space-y-3">
          <Skeleton className="h-4 w-full" />
          <Skeleton className="h-4 w-[95%]" />
          <Skeleton className="h-4 w-[88%]" />
          <Skeleton className="h-4 w-[75%]" />
          <div className="h-2" />
          <Skeleton className="h-4 w-full" />
          <Skeleton className="h-4 w-[90%]" />
        </div>
      ) : briefing ? (
        <div className="relative flex-1">
          {/* Headline pull-out */}
          {headline && (
            <p className="mb-3 text-sm font-semibold leading-snug text-ark-text">
              {headline}.
            </p>
          )}

          <div
            ref={scrollRef}
            className="max-h-44 overflow-y-auto pr-1 scrollbar-thin"
          >
            <div className="space-y-3 text-sm leading-[1.75] text-ark-text-secondary">
              {(rest ?? briefing).split('\n\n').map((paragraph, i) => (
                <p key={i}>{paragraph}</p>
              ))}
            </div>
          </div>

          {/* Scroll fade hint */}
          {canScroll && !isScrolled && (
            <div className="pointer-events-none absolute inset-x-0 bottom-0 flex flex-col items-center">
              <div className="h-10 w-full bg-gradient-to-t from-[var(--ark-glass-bg)] to-transparent" />
              <ChevronDown className="pointer-events-auto -mt-3 h-4 w-4 animate-bounce text-ark-text-disabled" />
            </div>
          )}
        </div>
      ) : (
        <div className="flex flex-1 flex-col items-center justify-center py-8 text-center">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-ark-fill-secondary">
            <Brain className="h-6 w-6 text-ark-text-tertiary" />
          </div>
          <p className="mt-3 text-sm text-ark-text-tertiary">No briefing available yet</p>
          <p className="mt-1 text-xs text-ark-text-disabled">
            Briefings are generated daily before market open
          </p>
        </div>
      )}
    </GlassCard>
  );
}
