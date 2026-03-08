import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';
import {
  demoMacroIndicators,
  demoRiskHistory,
  demoBriefing,
  demoArkLineScore,
  demoSupplyInProfit,
  demoAssetRiskLevels,
} from '@/lib/demo-data';
import type {
  MacroIndicator,
  RiskHistoryPoint,
  ArkLineScoreData,
  SupplyInProfitData,
  AssetRiskLevelData,
} from '@/types';

function getSupabase() {
  return createClient();
}

export async function fetchMacroIndicators(): Promise<MacroIndicator[]> {
  if (!isSupabaseConfigured()) return demoMacroIndicators;
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('indicatorSnapshots')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(1);

  if (error || !data?.[0]) return [];
  return data[0].indicators as MacroIndicator[];
}

export async function fetchRiskHistory(days = 365): Promise<RiskHistoryPoint[]> {
  if (!isSupabaseConfigured()) return demoRiskHistory;
  const supabase = getSupabase();
  const since = new Date();
  since.setDate(since.getDate() - days);

  const { data, error } = await supabase
    .from('riskSnapshots')
    .select('*')
    .gte('date', since.toISOString())
    .order('date', { ascending: true });

  if (error) return [];
  return data as RiskHistoryPoint[];
}

export async function fetchMarketBriefing(): Promise<string | null> {
  if (!isSupabaseConfigured()) return demoBriefing;
  const supabase = getSupabase();
  const { data, error } = await supabase.functions.invoke('market-summary', {
    body: { action: 'get' },
  });
  if (error) return null;
  return data?.summary ?? null;
}

export async function fetchSentimentData() {
  if (!isSupabaseConfigured()) return null;
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('sentimentHistory')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(1);

  if (error || !data?.[0]) return null;
  return data[0];
}

export async function fetchRegimeData() {
  if (!isSupabaseConfigured()) return null;
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('regimeSnapshots')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(1);

  if (error || !data?.[0]) return null;
  return data[0];
}

export async function fetchArkLineScore(): Promise<ArkLineScoreData> {
  if (!isSupabaseConfigured()) return demoArkLineScore;
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('riskScoreComponents')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(1);

  if (error || !data?.[0]) return demoArkLineScore;
  return data[0] as ArkLineScoreData;
}

export async function fetchSupplyInProfit(): Promise<SupplyInProfitData> {
  if (!isSupabaseConfigured()) return demoSupplyInProfit;
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('supplyInProfit')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(1);

  if (error || !data?.[0]) return demoSupplyInProfit;
  return data[0] as SupplyInProfitData;
}

export async function fetchAssetRiskLevels(): Promise<AssetRiskLevelData[]> {
  if (!isSupabaseConfigured()) return demoAssetRiskLevels;
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('assetRiskLevels')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(10);

  if (error || !data?.length) return demoAssetRiskLevels;
  return data as AssetRiskLevelData[];
}
