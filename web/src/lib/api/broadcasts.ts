import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';

/** A published market-insight broadcast (read-only feed for subscribers). */
export interface Broadcast {
  id: string;
  title: string;
  content: string;
  tags: string[];
  published_at: string | null;
  created_at: string;
  is_pinned: boolean;
  reaction_count: number;
  view_count: number;
  images: string[];
  video_url: string | null;
}

function toArray(v: unknown): string[] {
  if (Array.isArray(v)) return v as string[];
  if (typeof v === 'string') {
    try {
      const p = JSON.parse(v);
      return Array.isArray(p) ? p : [];
    } catch {
      return [];
    }
  }
  return [];
}

/** Published broadcasts, pinned first then newest. */
export async function fetchBroadcasts(): Promise<Broadcast[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = createClient();
  const { data, error } = await supabase
    .from('broadcasts')
    .select('id, title, content, tags, published_at, created_at, is_pinned, reaction_count, view_count, images, video_url')
    .eq('status', 'published')
    .order('is_pinned', { ascending: false })
    .order('published_at', { ascending: false })
    .limit(100);
  if (error || !data) return [];
  return (data as Record<string, unknown>[]).map((b) => ({
    id: String(b.id),
    title: String(b.title ?? ''),
    content: String(b.content ?? ''),
    tags: toArray(b.tags),
    published_at: (b.published_at as string) ?? null,
    created_at: String(b.created_at ?? ''),
    is_pinned: Boolean(b.is_pinned),
    reaction_count: Number(b.reaction_count ?? 0),
    view_count: Number(b.view_count ?? 0),
    images: toArray(b.images),
    video_url: (b.video_url as string) ?? null,
  }));
}
