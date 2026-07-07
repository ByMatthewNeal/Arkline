import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';
import type { PortfolioHolding } from '@/types';

function getSupabase() {
  return createClient();
}

export interface RecordTxInput {
  portfolioId: string;
  type: 'buy' | 'sell';
  asset_type: string;
  symbol: string;
  name: string;
  quantity: number;
  price_per_unit: number;
  fee?: number;
  date?: string; // ISO
  notes?: string;
}

/**
 * Records a buy/sell transaction and reconciles the holding for that symbol.
 * If multiple holding rows exist for the symbol (legacy duplicates), they are
 * consolidated into a single row with a quantity-weighted average cost.
 */
export async function recordTransaction(input: RecordTxInput): Promise<void> {
  if (!isSupabaseConfigured()) throw new Error('Not available in demo mode.');
  const supabase = getSupabase();
  const q = Math.abs(input.quantity);
  const price = Math.abs(input.price_per_unit);
  const fee = Math.abs(input.fee ?? 0);
  if (q <= 0) throw new Error('Quantity must be greater than 0.');

  // Gather existing rows for this symbol (case-insensitive) in this portfolio.
  const { data: rows, error: fetchErr } = await supabase
    .from('holdings')
    .select('*')
    .eq('portfolio_id', input.portfolioId)
    .ilike('symbol', input.symbol);
  if (fetchErr) throw fetchErr;
  const existing = (rows ?? []) as PortfolioHolding[];

  const oldQty = existing.reduce((s, h) => s + Number(h.quantity), 0);
  const oldAvg = oldQty > 0
    ? existing.reduce((s, h) => s + (Number(h.average_buy_price ?? 0) * Number(h.quantity)), 0) / oldQty
    : 0;

  let newQty = oldQty;
  let newAvg = oldAvg;
  let realized: number | null = null;
  let costBasis: number | null = null;

  if (input.type === 'buy') {
    newQty = oldQty + q;
    newAvg = newQty > 0 ? (oldAvg * oldQty + price * q) / newQty : price;
  } else {
    if (q > oldQty + 1e-9) throw new Error(`You only hold ${oldQty} ${input.symbol.toUpperCase()}.`);
    realized = (price - oldAvg) * q;
    costBasis = oldAvg;
    newQty = oldQty - q;
    newAvg = oldAvg; // avg cost unchanged on sells
  }

  // Consolidate holding rows.
  const keep = existing[0];
  const extras = existing.slice(1);
  if (extras.length) {
    await supabase.from('holdings').delete().in('id', extras.map((h) => h.id));
  }

  let holdingId: string | undefined = keep?.id;
  if (newQty <= 1e-9) {
    // Fully sold out — remove the position.
    if (keep) await supabase.from('holdings').delete().eq('id', keep.id);
    holdingId = undefined;
  } else if (keep) {
    const { error } = await supabase
      .from('holdings')
      .update({ quantity: newQty, average_buy_price: newAvg, name: input.name, asset_type: input.asset_type, updated_at: new Date().toISOString() })
      .eq('id', keep.id);
    if (error) throw error;
  } else {
    const { data: inserted, error } = await supabase
      .from('holdings')
      .insert({ portfolio_id: input.portfolioId, asset_type: input.asset_type, symbol: input.symbol.toUpperCase(), name: input.name, quantity: newQty, average_buy_price: newAvg })
      .select('id')
      .single();
    if (error) throw error;
    holdingId = inserted?.id;
  }

  // Insert the transaction record.
  const { error: txErr } = await supabase.from('transactions').insert({
    portfolio_id: input.portfolioId,
    holding_id: holdingId ?? null,
    type: input.type,
    asset_type: input.asset_type,
    symbol: input.symbol.toUpperCase(),
    quantity: q,
    price_per_unit: price,
    gas_fee: fee,
    total_value: q * price + (input.type === 'buy' ? fee : -fee),
    transaction_date: input.date ?? new Date().toISOString(),
    notes: input.notes ?? null,
    cost_basis_per_unit: costBasis,
    realized_profit_loss: realized,
  });
  if (txErr) throw txErr;
}

export async function deleteHolding(holdingId: string): Promise<void> {
  if (!isSupabaseConfigured()) throw new Error('Not available in demo mode.');
  const supabase = getSupabase();
  const { error } = await supabase.from('holdings').delete().eq('id', holdingId);
  if (error) throw error;
}

export async function deleteHoldingsBySymbol(portfolioId: string, symbol: string): Promise<void> {
  if (!isSupabaseConfigured()) throw new Error('Not available in demo mode.');
  const supabase = getSupabase();
  const { error } = await supabase.from('holdings').delete().eq('portfolio_id', portfolioId).ilike('symbol', symbol);
  if (error) throw error;
}

export async function updateHoldingTarget(holdingId: string, targetPct: number | null): Promise<void> {
  if (!isSupabaseConfigured()) throw new Error('Not available in demo mode.');
  const supabase = getSupabase();
  const { error } = await supabase.from('holdings').update({ target_percentage: targetPct }).eq('id', holdingId);
  if (error) throw error;
}

export async function createPortfolio(userId: string, name: string): Promise<void> {
  if (!isSupabaseConfigured()) throw new Error('Not available in demo mode.');
  const supabase = getSupabase();
  const { error } = await supabase.from('portfolios').insert({ user_id: userId, name, is_public: false });
  if (error) throw error;
}
