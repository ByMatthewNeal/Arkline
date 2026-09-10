import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';

/**
 * Model portfolios (crypto Core/Edge, curated Equity, and the systematic Metals
 * book) — mirrors the iOS APIModelPortfolioService: `model_portfolios`
 * (active only), `model_portfolio_nav`, `model_portfolio_trades`,
 * `benchmark_nav` (SPY), and the followed strategy on
 * `profiles.followed_model_portfolio`. The retired Alpha book is is_active=false
 * and filtered out.
 */

export interface ModelPortfolio {
  id: string;
  name: string;
  strategy: string;
  description: string | null;
  universe: string[];
  starting_nav: number;
  asset_class: string; // 'crypto' | 'stock' | 'metal'
}

export interface AllocationDetail {
  pct: number;
  value?: number;
  qty?: number;
  entry_price?: number;
}

export interface MetalSignalContext {
  zone?: string | null;      // e.g. "cheap" | "fair" | "rich"
  rsi?: number | null;
  target_gold?: number | null;
}

export interface ModelPortfolioNav {
  nav_date: string;
  nav: number;
  allocations: Record<string, AllocationDetail | number>;
  btc_signal: string | null;
  btc_risk_category: string | null;
  gold_signal: string | null;
  macro_regime: string | null;
  signal_context: MetalSignalContext | null;
}

export interface ModelPortfolioTrade {
  id: string;
  trade_date: string;
  trigger: string;
  from_allocation: Record<string, number>;
  to_allocation: Record<string, number>;
  market_context: { headlines?: string[]; events?: string[] } | null;
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
    .select('id, name, strategy, description, universe, starting_nav, asset_class, display_order, is_active')
    .eq('is_active', true) // drops the retired Alpha book (is_active=false)
    .order('display_order', { ascending: true, nullsFirst: false });
  if (error || !data) return [];
  return (data as Record<string, unknown>[]).map((p) => ({
    id: String(p.id),
    name: String(p.name ?? ''),
    strategy: String(p.strategy ?? ''),
    description: (p.description as string) ?? null,
    universe: Array.isArray(p.universe) ? (p.universe as string[]) : [],
    starting_nav: Number(p.starting_nav ?? 0),
    asset_class: String(p.asset_class ?? 'crypto'),
  }));
}

export async function fetchModelPortfolioNav(portfolioId: string, limit = 3000): Promise<ModelPortfolioNav[]> {
  if (!isSupabaseConfigured()) return [];
  const { data, error } = await getSupabase()
    .from('model_portfolio_nav')
    .select('nav_date, nav, allocations, btc_signal, btc_risk_category, gold_signal, macro_regime, signal_context')
    .eq('portfolio_id', portfolioId)
    .order('nav_date', { ascending: false })
    .limit(limit);
  if (error || !data) return [];
  return (data as ModelPortfolioNav[]).slice().reverse();
}

export async function fetchBenchmarkNav(limit = 3000): Promise<BenchmarkNavPoint[]> {
  if (!isSupabaseConfigured()) return [];
  const { data, error } = await getSupabase()
    .from('benchmark_nav')
    .select('nav_date, nav')
    .order('nav_date', { ascending: false })
    .limit(limit);
  if (error || !data) return [];
  return (data as BenchmarkNavPoint[]).slice().reverse();
}

export async function fetchModelPortfolioTrades(portfolioId: string, limit = 1000): Promise<ModelPortfolioTrade[]> {
  if (!isSupabaseConfigured()) return [];
  const { data, error } = await getSupabase()
    .from('model_portfolio_trades')
    .select('id, trade_date, trigger, from_allocation, to_allocation, market_context')
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

// ─────────────────────────────────────────────────────────────────────────────
// Position History (TS port of the iOS PositionHistoryBuilder)
//
// Derives a per-ticker "position call" timeline from the rebalance trade log
// plus the NAV series: when each name was entered, when (if ever) it was exited,
// the trigger that closed it, and realized/unrealized P&L. CASH is not a position.
// ─────────────────────────────────────────────────────────────────────────────

export interface PositionCall {
  ticker: string;
  enteredDate: string;
  exitedDate: string | null;   // null → still open
  exitRationale: string | null;
  pnlPct: number | null;       // realized if closed, unrealized if open, null if unknown
}

/** Read an allocation weight regardless of the object/number encoding. */
export function allocPct(v: AllocationDetail | number | undefined): number {
  if (v == null) return 0;
  return typeof v === 'number' ? v : Number(v.pct ?? 0);
}

function allocOf(navRow: ModelPortfolioNav | undefined, ticker: string): AllocationDetail | null {
  if (!navRow) return null;
  const v = navRow.allocations?.[ticker];
  if (v == null) return null;
  return typeof v === 'number' ? { pct: v } : v;
}

/** Names held (weight > 0), excluding CASH. */
function heldSet(alloc: Record<string, AllocationDetail | number> | Record<string, number> | undefined): Set<string> {
  const s = new Set<string>();
  for (const [k, v] of Object.entries(alloc ?? {})) {
    if (k !== 'CASH' && allocPct(v as AllocationDetail | number) > 0) s.add(k);
  }
  return s;
}

/** Current-price ((value / qty)) vs. entry_price → % return, or null if unpriced. */
function pnlFromDetail(a: AllocationDetail | null): number | null {
  if (!a || !a.entry_price || a.entry_price <= 0 || !a.value || !a.qty || a.qty <= 0) return null;
  return (((a.value / a.qty) - a.entry_price) / a.entry_price) * 100;
}

function realizedPnl(
  ticker: string,
  entered: string,
  exited: string,
  navAsc: ModelPortfolioNav[],
): number | null {
  const entryRow = navAsc.find((r) => r.nav_date >= entered && (allocOf(r, ticker)?.entry_price ?? 0) > 0);
  const entryPrice = entryRow ? allocOf(entryRow, ticker)!.entry_price! : null;
  const exitRow = [...navAsc].reverse().find((r) => r.nav_date < exited && (allocOf(r, ticker)?.qty ?? 0) > 0);
  if (!entryPrice || entryPrice <= 0 || !exitRow) return null;
  const a = allocOf(exitRow, ticker)!;
  if (!a.value || !a.qty || a.qty <= 0) return null;
  return (((a.value / a.qty) - entryPrice) / entryPrice) * 100;
}

export function buildPositionHistory(
  trades: ModelPortfolioTrade[],
  nav: ModelPortfolioNav[],
): PositionCall[] {
  const sortedTrades = [...trades].sort((a, b) => a.trade_date.localeCompare(b.trade_date));
  const navAsc = [...nav].sort((a, b) => a.nav_date.localeCompare(b.nav_date));
  const inception = navAsc[0]?.nav_date ?? sortedTrades[0]?.trade_date ?? '';

  const openedAt: Record<string, string> = {};
  const closed: PositionCall[] = [];

  // Seed positions held at inception (before the first recorded trade).
  if (sortedTrades.length > 0) {
    for (const t of heldSet(sortedTrades[0].from_allocation)) openedAt[t] = inception;
  }

  for (const trade of sortedTrades) {
    const before = heldSet(trade.from_allocation);
    const after = heldSet(trade.to_allocation);
    // Exits: held before, gone after.
    for (const t of before) {
      if (!after.has(t)) {
        const entered = openedAt[t] ?? trade.trade_date;
        closed.push({
          ticker: t,
          enteredDate: entered,
          exitedDate: trade.trade_date,
          exitRationale: trade.trigger || null,
          pnlPct: realizedPnl(t, entered, trade.trade_date, navAsc),
        });
        delete openedAt[t];
      }
    }
    // Entries: new after, absent before.
    for (const t of after) {
      if (!before.has(t) && !(t in openedAt)) openedAt[t] = trade.trade_date;
    }
  }

  // Anything still held per the latest NAV counts as an open position.
  const latest = navAsc[navAsc.length - 1];
  for (const t of heldSet(latest?.allocations)) {
    if (!(t in openedAt)) openedAt[t] = inception;
  }

  const open: PositionCall[] = Object.entries(openedAt).map(([ticker, entered]) => ({
    ticker,
    enteredDate: entered,
    exitedDate: null,
    exitRationale: null,
    pnlPct: pnlFromDetail(allocOf(latest, ticker)),
  }));

  open.sort((a, b) => b.enteredDate.localeCompare(a.enteredDate));
  closed.sort((a, b) => (b.exitedDate ?? '').localeCompare(a.exitedDate ?? ''));
  return [...open, ...closed];
}
