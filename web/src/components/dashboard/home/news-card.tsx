'use client';

import { Newspaper, ExternalLink, ArrowUpRight } from 'lucide-react';
import { GlassCard, Skeleton } from '@/components/ui';
import { useNews } from '@/lib/hooks/use-market';
import { formatRelativeTime, cn } from '@/lib/utils/format';

export function NewsCard() {
  const { data: news, isLoading } = useNews(4);
  const articles = news ?? [];

  return (
    <GlassCard className="relative overflow-hidden">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-violet/20 to-transparent" />

      <div className="mb-4 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-violet/10">
            <Newspaper className="h-5 w-5 text-ark-violet" />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-ark-text">Headlines</h3>
            <p className="text-[10px] text-ark-text-disabled">Latest crypto news</p>
          </div>
        </div>
      </div>

      {isLoading ? (
        <div className="space-y-2">
          {[0, 1, 2].map((i) => (
            <Skeleton key={i} className="h-14 w-full" />
          ))}
        </div>
      ) : articles.length === 0 ? (
        <div className="flex flex-col items-center py-6 text-center">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-ark-fill-secondary">
            <Newspaper className="h-6 w-6 text-ark-text-tertiary" />
          </div>
          <p className="mt-3 text-sm text-ark-text-tertiary">No news available</p>
          <p className="mt-1 text-xs text-ark-text-disabled">Check back soon</p>
        </div>
      ) : (
        <div className="space-y-2">
          {articles.map((article, i) => (
            <a
              key={article.id}
              href={article.url !== '#' ? article.url : undefined}
              target="_blank"
              rel="noopener noreferrer"
              className={cn(
                'group flex items-start gap-3 rounded-xl border px-3.5 py-2.5 transition-all hover:bg-ark-fill-secondary',
                i === 0 ? 'border-ark-violet/15 bg-ark-violet/[0.02]' : 'border-transparent',
              )}
            >
              <div className="min-w-0 flex-1">
                <p className={cn(
                  'font-medium leading-snug text-ark-text line-clamp-2 group-hover:text-ark-primary transition-colors',
                  i === 0 ? 'text-sm' : 'text-xs',
                )}>
                  {article.title}
                </p>
                <div className="mt-1.5 flex items-center gap-1.5 text-[10px] text-ark-text-disabled">
                  <span className="font-semibold text-ark-text-tertiary">{article.source}</span>
                  <span className="h-0.5 w-0.5 rounded-full bg-ark-text-disabled" />
                  <span>{formatRelativeTime(article.published_at)}</span>
                </div>
              </div>
              <ArrowUpRight className="mt-0.5 h-3.5 w-3.5 shrink-0 text-ark-text-disabled opacity-0 transition-all group-hover:opacity-100 group-hover:text-ark-primary" />
            </a>
          ))}
        </div>
      )}
    </GlassCard>
  );
}
