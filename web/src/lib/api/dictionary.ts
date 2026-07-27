import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';

export interface DictionaryTerm {
  id: string;
  term: string;
  definition: string;
  category: string | null;
  example: string | null;
  related_terms: string[];
  slug: string;
  aliases: string[];
}

/** Mirrors the DB slug rule: strip parens, non-alphanumerics -> '-', trim '-'. */
export function slugifyTerm(term: string): string {
  return term
    .replace(/[()]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

export async function fetchDictionary(): Promise<DictionaryTerm[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = createClient();
  const { data, error } = await supabase
    .from('dictionary')
    .select('id, term, definition, category, example, related_terms, slug, aliases')
    .order('term', { ascending: true })
    .limit(1000);
  if (error || !data) return [];
  return (data as Array<Record<string, unknown>>).map((r) => {
    const term = String(r.term);
    return {
      id: String(r.id),
      term,
      definition: String(r.definition ?? ''),
      category: (r.category as string | null) ?? null,
      example: (r.example as string | null) ?? null,
      related_terms: Array.isArray(r.related_terms) ? (r.related_terms as string[]) : [],
      slug: r.slug ? String(r.slug) : slugifyTerm(term),
      aliases: Array.isArray(r.aliases) ? (r.aliases as string[]) : [],
    };
  });
}
