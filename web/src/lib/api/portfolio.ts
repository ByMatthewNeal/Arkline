import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';
import type { Portfolio, PortfolioHolding, PortfolioHistoryPoint } from '@/types';
import type { Transaction } from '@/types/transaction';

function getSupabase() {
  return createClient();
}

export async function fetchPortfolios(userId: string): Promise<Portfolio[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('portfolios')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: true });
  if (error) throw error;
  return data ?? [];
}

export async function fetchHoldings(portfolioId: string): Promise<PortfolioHolding[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('holdings')
    .select('*')
    .eq('portfolio_id', portfolioId)
    .order('created_at', { ascending: true });
  if (error) throw error;
  return data ?? [];
}

export async function fetchTransactions(portfolioId: string): Promise<Transaction[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('transactions')
    .select('*')
    .eq('portfolio_id', portfolioId)
    .order('transaction_date', { ascending: false });
  if (error) throw error;
  return data ?? [];
}

export async function fetchPortfolioHistory(
  portfolioId: string,
  days = 30,
): Promise<PortfolioHistoryPoint[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = getSupabase();
  const since = new Date();
  since.setDate(since.getDate() - days);

  const { data, error } = await supabase
    .from('portfolioHistory')
    .select('*')
    .eq('portfolio_id', portfolioId)
    .gte('date', since.toISOString())
    .order('date', { ascending: true });
  if (error) throw error;
  return data ?? [];
}

export async function refreshHoldingPrices(
  holdings: PortfolioHolding[],
): Promise<PortfolioHolding[]> {
  if (!isSupabaseConfigured()) return holdings;
  const supabase = getSupabase();
  const cryptoSymbols = holdings
    .filter((h) => h.asset_type === 'crypto')
    .map((h) => h.symbol.toLowerCase());

  if (cryptoSymbols.length === 0) return holdings;

  const { data, error } = await supabase.functions.invoke('api-proxy', {
    body: {
      service: 'coingecko',
      path: '/simple/price',
      params: {
        ids: cryptoSymbols.join(','),
        vs_currencies: 'usd',
        include_24hr_change: 'true',
      },
    },
  });

  if (error) return holdings;

  return holdings.map((h) => {
    const priceData = data?.[h.symbol.toLowerCase()];
    if (!priceData) return h;
    return {
      ...h,
      current_price: priceData.usd,
      price_change_percentage_24h: priceData.usd_24h_change,
    };
  });
}
