'use client';

/**
 * News ticker — a slim, continuously-scrolling crawl under the topbar that
 * blends the app's freshest signals into one stream: curated headlines,
 * today's positioning-signal changes, and the latest broadcast.
 *
 * Deliberately simple: pure CSS marquee (no timers, no measurement), pauses
 * on hover and honors prefers-reduced-motion. Items are clickable.
 */

import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { useNews, useSignalChanges } from '@/lib/hooks/use-market';
import { fetchBroadcasts } from '@/lib/api/broadcasts';
import { isSupabaseConfigured } from '@/lib/supabase/client';
import { formatRelativeTime, cn } from '@/lib/utils/format';

interface TickerItem {
  key: string;
  tag: 'NEWS' | 'SIGNAL' | 'INSIGHT';
  text: string;
  meta?: string;
  href?: string;      // internal route
  external?: string;  // external url
}

const TAG_STYLES: Record<TickerItem['tag'], string> = {
  NEWS: 'bg-ark-violet/10 text-ark-violet',
  SIGNAL: 'bg-ark-warning/10 text-ark-warning',
  INSIGHT: 'bg-ark-primary/10 text-ark-primary',
};

export function NewsTicker() {
  const { data: news } = useNews(8);
  const { data: signalChanges } = useSignalChanges();
  const { data: broadcasts } = useQuery({
    queryKey: ['broadcasts'],
    queryFn: fetchBroadcasts,
    enabled: isSupabaseConfigured(),
    staleTime: 300_000,
  });

  const items: TickerItem[] = [];

  // Latest broadcast leads — it's Arkline's own voice.
  const latestBroadcast = (broadcasts ?? [])[0];
  if (latestBroadcast) {
    items.push({
      key: `b-${latestBroadcast.id}`,
      tag: 'INSIGHT',
      text: latestBroadcast.title,
      meta: formatRelativeTime(latestBroadcast.published_at ?? latestBroadcast.created_at),
      href: '/dashboard/broadcasts',
    });
  }

  // Today's positioning changes.
  for (const c of (signalChanges ?? []).slice(0, 5)) {
    items.push({
      key: `s-${c.asset}`,
      tag: 'SIGNAL',
      text: `${c.asset}: ${cap(c.prev_signal)} → ${cap(c.signal)}`,
      href: '/dashboard',
    });
  }

  // Freshest curated headlines.
  for (const n of (news ?? []).slice(0, 6)) {
    items.push({
      key: `n-${n.id}`,
      tag: 'NEWS',
      text: n.title,
      meta: n.source,
      external: n.url !== '#' ? n.url : undefined,
    });
  }

  if (items.length < 3) return null; // not enough content for a crawl yet

  return (
    <div className="hidden items-center border-b border-ark-divider/60 bg-ark-card/60 backdrop-blur-sm md:flex">
      {/* LIVE tab */}
      <div className="flex shrink-0 items-center gap-1.5 border-r border-ark-divider/60 px-4 py-2">
        <span className="h-1.5 w-1.5 animate-status rounded-full bg-ark-success" />
        <span className="text-[10px] font-bold uppercase tracking-widest text-ark-text-secondary">Live</span>
      </div>

      {/* Crawl — content duplicated for a seamless loop */}
      <div className="group relative flex-1 overflow-hidden">
        <div className="pointer-events-none absolute inset-y-0 left-0 z-10 w-8 bg-gradient-to-r from-ark-card/80 to-transparent" />
        <div className="pointer-events-none absolute inset-y-0 right-0 z-10 w-8 bg-gradient-to-l from-ark-card/80 to-transparent" />
        <div className="flex w-max animate-ticker items-center group-hover:[animation-play-state:paused] motion-reduce:animate-none">
          {[0, 1].map((copy) => (
            <div key={copy} className="flex items-center" aria-hidden={copy === 1}>
              {items.map((item) => (
                <TickerEntry key={`${copy}-${item.key}`} item={item} />
              ))}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function TickerEntry({ item }: { item: TickerItem }) {
  const inner = (
    <>
      <span className={cn('rounded px-1.5 py-0.5 text-[8px] font-bold tracking-wider', TAG_STYLES[item.tag])}>
        {item.tag}
      </span>
      <span className="text-xs text-ark-text-secondary transition-colors group-hover/item:text-ark-text">{item.text}</span>
      {item.meta && <span className="text-[10px] text-ark-text-tertiary">· {item.meta}</span>}
      <span className="mx-4 h-0.5 w-0.5 rounded-full bg-ark-text-disabled" />
    </>
  );
  const className = 'group/item flex shrink-0 items-center gap-2 whitespace-nowrap py-2';

  if (item.external) {
    return <a href={item.external} target="_blank" rel="noopener noreferrer" className={className}>{inner}</a>;
  }
  if (item.href) {
    return <Link href={item.href} className={className}>{inner}</Link>;
  }
  return <div className={className}>{inner}</div>;
}

function cap(s: string) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}
