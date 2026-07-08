import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';

/**
 * Model portfolios (Core / Edge / Alpha strategies) — mirrors the iOS
 * APIModelPortfolioService: `model_portfolios`, `model_portfolio_nav`,
 * `model_portfolio_trades`, `benchmark_nav` (SPY), and the followed
 * strategy persisted on `profiles.followed_model_portfolio`.
 */

export interface ModelPortfolio {
  id: string;
  name: string;
  strategy: string;
  description: string | null;
  universe: string[];
  starting_nav: number;
}

export interface AllocationDetail {
  pct: number;
  value?: number;
  qty?: number;
  entry_price?: number;
}

export interface ModelPortfolioNav {
  nav_date: string;
  nav: number;
  allocations: Record<string, AllocationDetail | number>;
  btc_signal: string | null;
  macro_regime: string | null;
}

export interface ModelPortfolioTrade {
  id: string;
  trade_date: string;
  trigger: string;
  from_allocation: Record<string, number>;
  to_allocation: Record<string, number>;
}

export interface BenchmarkNavPoint {
  nav_date: string;
  nav: number;
}

function getSupabase() {
  return createClient();
}

export async function fetchModelPortfolios(): Promise<ModelPortfolio[]> {
  if (!isSupabaseConfigured()) return [];
  const { data, error } = await getSupabase()
    .from('model_portfolios')
    .select('id, name, strategy, description, universe, starting_nav')
    .order('strategy', { ascending: true });
  if (error || !data) return [];
  return (data as Record<string, unknown>[]).map((p) => ({
    id: String(p.id),
    name: String(p.name ?? ''),
    strategy: String(p.strategy ?? ''),
    description: (p.description as string) ?? null,
    universe: Array.isArray(p.universe) ? (p.universe as string[]) : [],
    starting_nav: Number(p.starting_nav ?? 0),
  }));
}

export async function fetchModelPortfolioNav(portfolioId: string, limit = 365): Promise<ModelPortfolioNav[]> {
  if (!isSupabaseConfigured()) return [];
  const { data, error } = await getSupabase()
    .from('model_portfolio_nav')
    .select('nav_date, nav, allocations, btc_signal, macro_regime')
    .eq('portfolio_id', portfolioId)
    .order('nav_date', { ascending: false })
    .limit(limit);
  if (error || !data) return [];
  return (data as ModelPortfolioNav[]).slice().reverse();
}

export async function fetchBenchmarkNav(limit = 365): Promise<BenchmarkNavPoint[]> {
  if (!isSupabaseConfigured()) return [];
  const { data, error } = await getSupabase()
    .from('benchmark_nav')
    .select('nav_date, nav')
    .order('nav_date', { ascending: false })
    .limit(limit);
  if (error || !data) return [];
  return (data as BenchmarkNavPoint[]).slice().reverse();
}

export async function fetchModelPortfolioTrades(portfolioId: string, limit = 20): Promise<ModelPortfolioTrade[]> {
  if (!isSupabaseConfigured()) return [];
  const { data, error } = await getSupabase()
    .from('model_portfolio_trades')
    .select('id, trade_date, trigger, from_allocation, to_allocation')
    .eq('portfolio_id', portfolioId)
    .order('trade_date', { ascending: false })
    .limit(limit);
  if (error || !data) return [];
  return data as ModelPortfolioTrade[];
}

/** Follow (or unfollow with null) a strategy — same column iOS writes. */
export async function setFollowedModelPortfolio(profileId: string, strategy: string | null): Promise<void> {
  if (!isSupabaseConfigured()) throw new Error('Not available in demo mode.');
  const { error } = await getSupabase()
    .from('profiles')
    .update({ followed_model_portfolio: strategy })
    .eq('id', profileId);
  if (error) throw error;
}

export async function fetchFollowedModelPortfolio(profileId: string): Promise<string | null> {
  if (!isSupabaseConfigured()) return null;
  const { data } = await getSupabase()
    .from('profiles')
    .select('followed_model_portfolio')
    .eq('id', profileId)
    .single();
  return (data?.followed_model_portfolio as string) ?? null;
}
