'use client';

import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { Radio, Search, Pin, Eye, Heart, Bookmark, Sparkles, ChevronDown, Video, CalendarClock, MessagesSquare, BookOpen } from 'lucide-react';
import { useQuery } from '@tanstack/react-query';
import { GlassCard, Skeleton } from '@/components/ui';
import { fetchBroadcasts, recordBroadcastImpression, recordBroadcastOpen, type Broadcast } from '@/lib/api/broadcasts';
import { isSupabaseConfigured } from '@/lib/supabase/client';
import { useBroadcastSocial } from '@/lib/hooks/use-broadcast-social';
import { useAuth } from '@/lib/hooks/use-auth';

// Broadcast IDs we've already logged an impression for this session, so a card
// scrolling in and out of view only records reach once per page load.
const recordedImpressions = new Set<string>();
import { formatRelativeTime, cn } from '@/lib/utils/format';
import { Markdown } from '@/components/dashboard/shared/markdown';
import { ImageGallery, AudioPlayer } from '@/components/dashboard/shared/media';
import { QuickAskModal } from '@/components/dashboard/shared/quick-ask';

type Social = ReturnType<typeof useBroadcastSocial>;

const DATE_FILTERS = ['All', 'Today', 'This Week', 'This Month'] as const;
type DateFilter = (typeof DATE_FILTERS)[number];

/** Plain-text preview for the collapsed card (markdown stripped). */
function previewText(md: string): string {
  return md.replace(/\*\*(.*?)\*\*/g, '$1').replace(/`/g, '').replace(/^#{1,6}\s*/gm, '').replace(/^>\s?/gm, '').trim();
}

function matchesDate(b: Broadcast, filter: DateFilter): boolean {
  if (filter === 'All') return true;
  const d = new Date(b.published_at ?? b.created_at);
  const now = new Date();
  const diffDays = (now.getTime() - d.getTime()) / 86_400_000;
  if (filter === 'Today') return d.toDateString() === now.toDateString();
  if (filter === 'This Week') return diffDays <= 7;
  return diffDays <= 31;
}

function BroadcastCard({ b, social, uid }: { b: Broadcast; social: Social; uid?: string }) {
  const [expanded, setExpanded] = useState(false);
  const cardRef = useRef<HTMLDivElement>(null);
  const openRecorded = useRef(false);

  // Open (read) tracking: expanding the card counts as reading it, same as
  // iOS opening the detail. Feeds broadcast_reads → view_count + Seen-by.
  const toggleExpanded = () => {
    if (!expanded && !openRecorded.current && uid) {
      openRecorded.current = true;
      void recordBroadcastOpen(b.id, uid);
    }
    setExpanded((v) => !v);
  };
  const preview = previewText(b.content).split('\n').filter(Boolean).slice(0, 3);
  const when = b.published_at ?? b.created_at;
  const liked = social.isReacted(b.id);
  const saved = social.isBookmarked(b.id);
  const likeCount = b.reaction_count + (liked ? 1 : 0);

  // Reach: record a "seen in feed" impression the first time this card scrolls
  // into view (matches iOS onAppear). Deduped per session + by the DB constraint.
  useEffect(() => {
    const el = cardRef.current;
    if (!el || !uid || recordedImpressions.has(b.id)) return;
    const obs = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          recordedImpressions.add(b.id);
          void recordBroadcastImpression(b.id, uid);
          obs.disconnect();
        }
      },
      { threshold: 0.5 },
    );
    obs.observe(el);
    return () => obs.disconnect();
  }, [b.id, uid]);

  return (
    <GlassCard
      ref={cardRef}
      className={cn('relative cursor-pointer overflow-hidden transition-shadow hover:shadow-md', b.is_pinned && 'border-ark-primary/30')}
      onClick={toggleExpanded}
    >
      {b.is_pinned && <div className="pointer-events-none absolute inset-x-0 top-0 h-0.5 bg-gradient-to-r from-transparent via-ark-primary/60 to-transparent" />}
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            {b.is_pinned && <Pin className="h-3.5 w-3.5 text-ark-primary" />}
            <h3 className="text-base font-semibold text-ark-text">{b.title}</h3>
          </div>
          <p className="mt-0.5 text-[11px] text-ark-text-disabled">{when ? formatRelativeTime(when) : ''}</p>
        </div>
        <ChevronDown className={cn('h-4 w-4 shrink-0 text-ark-text-tertiary transition-transform', expanded && 'rotate-180')} />
      </div>

      {b.tags.length > 0 && (
        <div className="mt-2 flex flex-wrap gap-1.5">
          {b.tags.map((t) => (
            <span key={t} className="rounded-full bg-ark-fill-secondary px-2 py-0.5 text-[10px] font-medium text-ark-text-tertiary">{t}</span>
          ))}
        </div>
      )}

      {expanded ? (
        <>
          {/* Full content: rendered markdown + media (iOS parity) */}
          <Markdown content={b.content} className="mt-2" />
          {b.audio_url && <AudioPlayer src={b.audio_url} />}
          <ImageGallery images={b.images} title={b.title} />
          {(b.video_url || b.meeting_link) && (
            <div className="mt-3 flex flex-wrap gap-2">
              {b.video_url && (
                <a
                  href={b.video_url} target="_blank" rel="noopener noreferrer"
                  onClick={(e) => e.stopPropagation()}
                  className="flex items-center gap-1.5 rounded-lg border border-ark-divider px-3 py-1.5 text-xs font-medium text-ark-text-secondary transition-colors hover:bg-ark-fill-secondary"
                >
                  <Video className="h-3.5 w-3.5 text-ark-primary" /> Watch video
                </a>
              )}
              {b.meeting_link && (
                <a
                  href={b.meeting_link} target="_blank" rel="noopener noreferrer"
                  onClick={(e) => e.stopPropagation()}
                  className="flex items-center gap-1.5 rounded-lg border border-ark-divider px-3 py-1.5 text-xs font-medium text-ark-text-secondary transition-colors hover:bg-ark-fill-secondary"
                >
                  <CalendarClock className="h-3.5 w-3.5 text-ark-primary" /> Join meeting
                </a>
              )}
            </div>
          )}
        </>
      ) : (
        <div className="mt-3 space-y-2 text-sm leading-relaxed text-ark-text-secondary line-clamp-3">
          {preview.map((p, i) => <p key={i}>{p}</p>)}
        </div>
      )}

      <div className="mt-3 flex items-center gap-3 text-[11px] text-ark-text-disabled">
        <span className="flex items-center gap-1"><Eye className="h-3 w-3" />{b.view_count}</span>
        <button
          onClick={(e) => { e.stopPropagation(); social.toggleReact(b.id); }}
          className={cn('flex items-center gap-1 rounded-md px-1.5 py-0.5 transition-colors hover:bg-ark-fill-secondary', liked ? 'text-ark-error' : 'text-ark-text-disabled')}
        >
          <Heart className={cn('h-3.5 w-3.5', liked && 'fill-current')} />{likeCount}
        </button>
        <button
          onClick={(e) => { e.stopPropagation(); social.toggleBookmark(b.id); }}
          title={saved ? 'Remove bookmark' : 'Save'}
          className={cn('flex items-center gap-1 rounded-md px-1.5 py-0.5 transition-colors hover:bg-ark-fill-secondary', saved ? 'text-ark-primary' : 'text-ark-text-disabled')}
        >
          <Bookmark className={cn('h-3.5 w-3.5', saved && 'fill-current')} />
        </button>
        {/* Dictionary: friction-free jump to the glossary, right where a reader hits an unfamiliar term */}
        <Link
          href="/dashboard/dictionary"
          onClick={(e) => e.stopPropagation()}
          title="Look up a term in the dictionary"
          className="flex items-center gap-1 rounded-md px-1.5 py-0.5 text-ark-text-disabled transition-colors hover:bg-ark-fill-secondary hover:text-ark-primary"
        >
          <BookOpen className="h-3.5 w-3.5" /> Dictionary
        </Link>
        <span className="ml-auto font-medium text-ark-primary">{expanded ? 'Show less ↑' : 'Read more →'}</span>
      </div>
    </GlassCard>
  );
}

export default function BroadcastsPage() {
  const isDemo = !isSupabaseConfigured();
  const [search, setSearch] = useState('');
  const [dateFilter, setDateFilter] = useState<DateFilter>('All');
  const [savedOnly, setSavedOnly] = useState(false);
  const [askOpen, setAskOpen] = useState(false);
  const social = useBroadcastSocial();
  const { authUser } = useAuth();
  const uid = authUser?.id;

  const { data: broadcasts, isLoading } = useQuery({
    queryKey: ['broadcasts'],
    queryFn: fetchBroadcasts,
    enabled: !isDemo,
    staleTime: 300_000,
  });

  const all = broadcasts ?? [];
  const filtered = all.filter((b) => {
    if (savedOnly && !social.isBookmarked(b.id)) return false;
    if (!matchesDate(b, dateFilter)) return false;
    if (search) {
      const q = search.toLowerCase();
      return b.title.toLowerCase().includes(q) || b.content.toLowerCase().includes(q) || b.tags.some((t) => t.toLowerCase().includes(q));
    }
    return true;
  });
  const pinned = filtered.filter((b) => b.is_pinned);
  const rest = filtered.filter((b) => !b.is_pinned);

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      {/* Header */}
      <div className="flex items-center gap-3">
        <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-ark-primary/10">
          <Radio className="h-5 w-5 text-ark-primary" />
        </div>
        <div className="flex-1">
          <h1 className="font-[family-name:var(--font-urbanist)] text-2xl font-bold text-ark-text">Broadcasts</h1>
          <p className="text-sm text-ark-text-tertiary">Market insights & updates from Arkline</p>
        </div>
        {/* Dictionary entry — always-visible jump to the glossary */}
        <Link
          href="/dashboard/dictionary"
          className="flex shrink-0 items-center gap-2 rounded-xl border border-ark-divider px-3.5 py-2.5 text-sm font-semibold text-ark-text-secondary transition-colors hover:bg-ark-fill-secondary hover:text-ark-text"
        >
          <BookOpen className="h-4 w-4 text-ark-primary" />
          <span className="hidden sm:inline">Dictionary</span>
        </Link>
        {/* Member Q&A entry — mirrors the iOS floating Q&A button on Insights */}
        <button
          onClick={() => setAskOpen(true)}
          className="flex shrink-0 items-center gap-2 rounded-xl bg-ark-primary px-4 py-2.5 text-sm font-semibold text-white shadow-md shadow-ark-primary/25 transition-all hover:brightness-110"
        >
          <MessagesSquare className="h-4 w-4" />
          <span className="hidden sm:inline">Ask a Question</span>
        </button>
      </div>

      <QuickAskModal open={askOpen} onClose={() => setAskOpen(false)} />

      {/* Search + date filters */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-ark-text-tertiary" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search broadcasts…"
            className="h-10 w-full rounded-xl border border-ark-divider bg-ark-fill-secondary pl-9 pr-3 text-sm text-ark-text outline-none placeholder:text-ark-text-tertiary focus:border-ark-primary"
          />
        </div>
        <div className="flex gap-1 overflow-x-auto rounded-full bg-ark-fill-secondary/60 p-1">
          {DATE_FILTERS.map((f) => (
            <button
              key={f}
              onClick={() => setDateFilter(f)}
              className={cn(
                'shrink-0 rounded-full px-3 py-1.5 text-[11px] font-semibold transition-colors',
                dateFilter === f ? 'bg-ark-primary text-white shadow-sm' : 'text-ark-text-tertiary hover:text-ark-text',
              )}
            >
              {f}
            </button>
          ))}
        </div>
        <button
          onClick={() => setSavedOnly((v) => !v)}
          className={cn('flex shrink-0 items-center gap-1 rounded-full border px-3 py-1.5 text-[11px] font-semibold transition-colors',
            savedOnly ? 'border-ark-primary bg-ark-primary/10 text-ark-primary' : 'border-ark-divider text-ark-text-tertiary hover:text-ark-text')}
        >
          <Bookmark className={cn('h-3.5 w-3.5', savedOnly && 'fill-current')} /> Saved
        </button>
      </div>

      {/* Feed */}
      {isLoading ? (
        <div className="space-y-4">{[0, 1, 2].map((i) => <Skeleton key={i} className="h-32 w-full rounded-2xl" />)}</div>
      ) : filtered.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-16 text-center">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-ark-fill-secondary"><Sparkles className="h-6 w-6 text-ark-text-tertiary" /></div>
          <p className="mt-3 text-sm text-ark-text-tertiary">{search || dateFilter !== 'All' ? 'No broadcasts match your filters.' : 'No broadcasts yet.'}</p>
        </div>
      ) : (
        <div className="space-y-4">
          {pinned.length > 0 && (
            <div className="space-y-3">
              <p className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Pinned</p>
              {pinned.map((b) => <BroadcastCard key={b.id} b={b} social={social} uid={uid} />)}
            </div>
          )}
          <div className="space-y-3">
            {pinned.length > 0 && <p className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Latest</p>}
            {rest.map((b) => <BroadcastCard key={b.id} b={b} social={social} uid={uid} />)}
          </div>
        </div>
      )}
    </div>
  );
}
