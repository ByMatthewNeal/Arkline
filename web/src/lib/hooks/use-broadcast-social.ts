'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useAuth } from './use-auth';
import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';

interface SocialState { reacted: string[]; bookmarked: string[] }

async function fetchState(userId: string): Promise<SocialState> {
  if (!isSupabaseConfigured()) return { reacted: [], bookmarked: [] };
  const supabase = createClient();
  const [r, b] = await Promise.all([
    supabase.from('broadcast_reactions').select('broadcast_id').eq('user_id', userId),
    supabase.from('broadcast_bookmarks').select('broadcast_id').eq('user_id', userId),
  ]);
  return {
    reacted: (r.data ?? []).map((x: { broadcast_id: string }) => x.broadcast_id),
    bookmarked: (b.data ?? []).map((x: { broadcast_id: string }) => x.broadcast_id),
  };
}

export function useBroadcastSocial() {
  const { authUser } = useAuth();
  const qc = useQueryClient();
  const uid = authUser?.id;
  const key = ['broadcast-social', uid];
  const q = useQuery({ queryKey: key, queryFn: () => fetchState(uid!), enabled: !!uid, staleTime: 120_000 });
  const reacted = new Set(q.data?.reacted ?? []);
  const bookmarked = new Set(q.data?.bookmarked ?? []);

  const optimistic = (field: 'reacted' | 'bookmarked', id: string) => {
    qc.setQueryData<SocialState>(key, (prev) => {
      const cur = prev ?? { reacted: [], bookmarked: [] };
      const set = new Set(cur[field]);
      if (set.has(id)) set.delete(id); else set.add(id);
      return { ...cur, [field]: [...set] };
    });
  };

  const react = useMutation({
    mutationFn: async (id: string) => {
      if (!uid) return;
      const supabase = createClient();
      if (reacted.has(id)) await supabase.from('broadcast_reactions').delete().eq('user_id', uid).eq('broadcast_id', id);
      else await supabase.from('broadcast_reactions').insert({ user_id: uid, broadcast_id: id, emoji: '❤️' });
    },
    onMutate: (id: string) => optimistic('reacted', id),
    onSettled: () => qc.invalidateQueries({ queryKey: key }),
  });

  const bookmark = useMutation({
    mutationFn: async (id: string) => {
      if (!uid) return;
      const supabase = createClient();
      if (bookmarked.has(id)) await supabase.from('broadcast_bookmarks').delete().eq('user_id', uid).eq('broadcast_id', id);
      else await supabase.from('broadcast_bookmarks').insert({ user_id: uid, broadcast_id: id });
    },
    onMutate: (id: string) => optimistic('bookmarked', id),
    onSettled: () => qc.invalidateQueries({ queryKey: key }),
  });

  return {
    isReacted: (id: string) => reacted.has(id),
    isBookmarked: (id: string) => bookmarked.has(id),
    toggleReact: (id: string) => react.mutate(id),
    toggleBookmark: (id: string) => bookmark.mutate(id),
  };
}
