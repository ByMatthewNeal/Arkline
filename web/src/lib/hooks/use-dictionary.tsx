'use client';

import { createContext, useContext, useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { fetchDictionary, type DictionaryTerm } from '@/lib/api/dictionary';

interface DictionaryContextValue {
  terms: DictionaryTerm[];
  /** Resolution order: slug -> exact term (ci) -> alias (ci). Null on miss. */
  lookup: (key: string) => DictionaryTerm | null;
  isLoading: boolean;
}

const DictionaryContext = createContext<DictionaryContextValue>({
  terms: [],
  lookup: () => null,
  isLoading: false,
});

/**
 * Loads the whole `dictionary` table once and keeps it in memory so inline
 * DefineTerm popovers open instantly and related-term chaining needs no
 * round-trips. Shares the ['dictionary'] query key with the glossary page.
 *
 * Note: `dictionary` RLS is `TO authenticated`, so this resolves to an empty
 * map for logged-out visitors and every DefineTerm trigger renders nothing.
 */
export function DictionaryProvider({ children }: { children: React.ReactNode }) {
  const { data, isLoading } = useQuery({
    queryKey: ['dictionary'],
    queryFn: fetchDictionary,
    staleTime: 24 * 60 * 60 * 1000,
    refetchInterval: false,
    refetchOnWindowFocus: false,
  });

  const value = useMemo<DictionaryContextValue>(() => {
    const terms = data ?? [];
    const bySlug = new Map<string, DictionaryTerm>();
    const labelToSlug = new Map<string, string>();

    for (const entry of terms) {
      bySlug.set(entry.slug, entry);
      labelToSlug.set(entry.term.toLowerCase(), entry.slug);
      for (const alias of entry.aliases) {
        labelToSlug.set(alias.toLowerCase(), entry.slug);
      }
    }

    const lookup = (key: string): DictionaryTerm | null => {
      if (!key) return null;
      const lowered = key.toLowerCase();
      const direct = bySlug.get(lowered);
      if (direct) return direct;
      const slug = labelToSlug.get(lowered);
      return slug ? (bySlug.get(slug) ?? null) : null;
    };

    return { terms, lookup, isLoading };
  }, [data, isLoading]);

  return <DictionaryContext.Provider value={value}>{children}</DictionaryContext.Provider>;
}

export function useDictionary() {
  return useContext(DictionaryContext);
}
