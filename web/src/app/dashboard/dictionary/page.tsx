'use client';

import { useState, useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { BookOpen, Search, ChevronDown } from 'lucide-react';
import { GlassCard, Skeleton } from '@/components/ui';
import { fetchDictionary, type DictionaryTerm } from '@/lib/api/dictionary';
import { cn } from '@/lib/utils/format';

function TermRow({ t }: { t: DictionaryTerm }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="border-b border-ark-divider/60 last:border-0">
      <button onClick={() => setOpen((v) => !v)} className="flex w-full items-center justify-between gap-3 py-3 text-left">
        <div>
          <span className="text-sm font-semibold text-ark-text">{t.term}</span>
          {t.category && <span className="ml-2 rounded-full bg-ark-fill-secondary px-2 py-0.5 text-[10px] font-medium capitalize text-ark-text-tertiary">{t.category}</span>}
        </div>
        <ChevronDown className={cn('h-4 w-4 shrink-0 text-ark-text-tertiary transition-transform', open && 'rotate-180')} />
      </button>
      {open && (
        <div className="pb-3">
          <p className="text-[13px] leading-relaxed text-ark-text-secondary">{t.definition}</p>
          {t.example && (
            <div className="mt-2 rounded-lg border-l-2 border-ark-info/40 bg-ark-fill-secondary/40 px-3 py-2">
              <p className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Example</p>
              <p className="mt-0.5 text-[13px] leading-relaxed text-ark-text-secondary">{t.example}</p>
            </div>
          )}
          {t.related_terms.length > 0 && (
            <div className="mt-2 flex flex-wrap items-center gap-1.5">
              <span className="text-[11px] text-ark-text-disabled">Related:</span>
              {t.related_terms.map((r) => <span key={r} className="rounded-md bg-ark-fill-secondary px-1.5 py-0.5 text-[11px] text-ark-text-secondary">{r}</span>)}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default function DictionaryPage() {
  const { data, isLoading } = useQuery({ queryKey: ['dictionary'], queryFn: fetchDictionary, staleTime: 600_000 });
  const [search, setSearch] = useState('');
  const [cat, setCat] = useState('All');

  const terms = data ?? [];
  const categories = useMemo(() => ['All', ...Array.from(new Set(terms.map((t) => t.category).filter(Boolean) as string[])).sort()], [terms]);
  const filtered = terms.filter((t) => {
    if (cat !== 'All' && t.category !== cat) return false;
    if (search) { const q = search.toLowerCase(); return t.term.toLowerCase().includes(q) || t.definition.toLowerCase().includes(q); }
    return true;
  });

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <div className="flex items-center gap-3">
        <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-ark-info/10"><BookOpen className="h-5 w-5 text-ark-info" /></div>
        <div>
          <h1 className="font-[family-name:var(--font-urbanist)] text-2xl font-bold text-ark-text">Dictionary</h1>
          <p className="text-sm text-ark-text-tertiary">Crypto &amp; investing terms, explained</p>
        </div>
      </div>

      <div className="flex flex-col gap-3">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-ark-text-tertiary" />
          <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search terms…"
            className="h-10 w-full rounded-xl border border-ark-divider bg-ark-fill-secondary pl-9 pr-3 text-sm text-ark-text outline-none placeholder:text-ark-text-tertiary focus:border-ark-info" />
        </div>
        <div className="flex gap-1.5 overflow-x-auto pb-1">
          {categories.map((c) => (
            <button key={c} onClick={() => setCat(c)}
              className={cn('shrink-0 rounded-full px-3 py-1.5 text-[11px] font-semibold capitalize transition-colors', cat === c ? 'bg-ark-info text-white' : 'bg-ark-fill-secondary text-ark-text-tertiary hover:text-ark-text')}>
              {c}
            </button>
          ))}
        </div>
      </div>

      {isLoading ? (
        <div className="space-y-2">{[0, 1, 2, 3, 4].map((i) => <Skeleton key={i} className="h-12 w-full rounded-xl" />)}</div>
      ) : filtered.length === 0 ? (
        <p className="py-12 text-center text-sm text-ark-text-tertiary">No terms found.</p>
      ) : (
        <GlassCard className="px-5 py-1">
          {filtered.map((t) => <TermRow key={t.id} t={t} />)}
        </GlassCard>
      )}
    </div>
  );
}
