'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useAuth } from './use-auth';
import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';

// Watchlist is stored on profiles.risk_coins as an array of UPPERCASE symbols (e.g. ["BTC","ETH"]).
async function fetchWatchlist(userId: string): Promise<string[]> {
  if (!isSupabaseConfigured()) return [];
  const { data } = await createClient().from('profiles').select('risk_coins').eq('id', userId).single();
  return ((data?.risk_coins as string[] | null) ?? []).map((s) => s.toUpperCase());
}

export function useWatchlist() {
  const { authUser } = useAuth();
  const qc = useQueryClient();
  const uid = authUser?.id;
  const key = ['watchlist', uid];

  const q = useQuery({ queryKey: key, queryFn: () => fetchWatchlist(uid!), enabled: !!uid, staleTime: 60_000 });
  const coins = q.data ?? [];
  const has = (symbol: string) => coins.some((c) => c.toLowerCase() === symbol.toLowerCase());

  const toggle = useMutation({
    mutationFn: async (symbol: string) => {
      if (!uid) return coins;
      const map = new Map(coins.map((c) => [c.toLowerCase(), c]));
      const k = symbol.toLowerCase();
      if (map.has(k)) map.delete(k); else map.set(k, symbol.toUpperCase());
      const next = [...map.values()];
      const { error } = await createClient().from('profiles').update({ risk_coins: next }).eq('id', uid);
      if (error) throw error;
      return next;
    },
    onMutate: async (symbol: string) => {
      await qc.cancelQueries({ queryKey: key });
      const prev = qc.getQueryData<string[]>(key) ?? [];
      const map = new Map(prev.map((c) => [c.toLowerCase(), c]));
      const k = symbol.toLowerCase();
      if (map.has(k)) map.delete(k); else map.set(k, symbol.toUpperCase());
      qc.setQueryData(key, [...map.values()]);
      return { prev };
    },
    onError: (_e, _v, ctx) => { if (ctx?.prev) qc.setQueryData(key, ctx.prev); },
    onSettled: () => qc.invalidateQueries({ queryKey: key }),
  });

  return { coins, has, toggle: (symbol: string) => toggle.mutate(symbol), isLoading: q.isLoading };
}
