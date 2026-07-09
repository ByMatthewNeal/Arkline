import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';

/**
 * Trade signals (Fibonacci setups) — full detail shape matching the iOS
 * `TradeSignal` model / `trade_signals` table.
 */

export type SignalType = 'strong_buy' | 'buy' | 'strong_sell' | 'sell';
export type SignalStatus = 'active' | 'triggered' | 'invalidated' | 'target_hit' | 'expired';
export type SignalOutcome = 'win' | 'partial' | 'loss';

export interface TradeSignal {
  id: string;
  asset: string;
  signal_type: SignalType;
  status: SignalStatus;
  timeframe: string | null;
  entry_zone_low: number;
  entry_zone_high: number;
  entry_price_mid: number;
  target_1: number | null;
  target_2: number | null;
  stop_loss: number;
  risk_reward_ratio: number;
  invalidation_note: string | null;
  btc_risk_score: number | null;
  fear_greed_index: number | null;
  macro_regime: string | null;
  arkline_score: number | null;
  composite_score: number | null;
  suggested_risk_pct: number | null;
  outcome: SignalOutcome | null;
  outcome_pct: number | null;
  t1_pnl_pct: number | null;
  runner_pnl_pct: number | null;
  duration_hours: number | null;
  volatility_regime: string | null;
  low_conviction: boolean | null;
  counter_trend: boolean | null;
  ema_trend_aligned: boolean | null;
  short_rationale: string | null;
  briefing_text: string | null;
  generated_at: string;
  triggered_at: string | null;
  t1_hit_at: string | null;
  closed_at: string | null;
  expires_at: string | null;
}

const COLUMNS =
  'id, asset, signal_type, status, timeframe, entry_zone_low, entry_zone_high, entry_price_mid, ' +
  'target_1, target_2, stop_loss, risk_reward_ratio, invalidation_note, btc_risk_score, ' +
  'fear_greed_index, macro_regime, arkline_score, composite_score, suggested_risk_pct, ' +
  'outcome, outcome_pct, t1_pnl_pct, runner_pnl_pct, duration_hours, volatility_regime, ' +
  'low_conviction, counter_trend, ema_trend_aligned, ' +
  'short_rationale, briefing_text, generated_at, triggered_at, t1_hit_at, closed_at, expires_at';

export async function fetchTradeSignalsFull(limit = 12): Promise<TradeSignal[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = createClient();
  const { data, error } = await supabase
    .from('trade_signals')
    .select(COLUMNS)
    .order('generated_at', { ascending: false })
    .limit(limit);
  if (error || !data) return [];
  return data as unknown as TradeSignal[];
}

/**
 * Closed signals (win / partial / loss) for the History and Performance tabs.
 * Optionally windowed to the last `days`; ordered newest first.
 */
export async function fetchSignalHistory(days?: number, limit = 400): Promise<TradeSignal[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = createClient();
  let q = supabase
    .from('trade_signals')
    .select(COLUMNS)
    .not('outcome', 'is', null)
    .order('closed_at', { ascending: false })
    .limit(limit);
  if (days) {
    const since = new Date(Date.now() - days * 86_400_000).toISOString();
    q = q.gte('closed_at', since);
  }
  const { data, error } = await q;
  if (error || !data) return [];
  return data as unknown as TradeSignal[];
}

export const isLong = (t: SignalType) => t === 'buy' || t === 'strong_buy';

export const SIGNAL_TYPE_LABEL: Record<SignalType, string> = {
  strong_buy: 'Strong Long',
  buy: 'Long',
  strong_sell: 'Strong Short',
  sell: 'Short',
};

export const SIGNAL_STATUS_META: Record<SignalStatus, { label: string; tone: 'info' | 'warning' | 'success' | 'error' | 'default' }> = {
  active: { label: 'Active', tone: 'info' },
  triggered: { label: 'Live', tone: 'warning' },
  target_hit: { label: 'Target Hit', tone: 'success' },
  invalidated: { label: 'Stopped', tone: 'error' },
  expired: { label: 'Expired', tone: 'default' },
};
