import type {
  CryptoAsset,
  FearGreedIndex,
  GlobalMarketData,
  NewsItem,
  EconomicEvent,
  MacroIndicator,
  RiskHistoryPoint,
  DCAReminder,
  CryptoPositioningData,
  TraditionalMarketAsset,
  MarketSentimentData,
  AltcoinScannerEntry,
  ArkLineScoreData,
  SupplyInProfitData,
  AssetRiskLevelData,
} from '@/types';

/* ── Helpers ── */

function sparkline(base: number, volatility: number, points = 168): number[] {
  const data: number[] = [base];
  for (let i = 1; i < points; i++) {
    const change = (Math.random() - 0.48) * volatility;
    data.push(data[i - 1] + change);
  }
  return data;
}

function daysAgo(n: number): string {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d.toISOString();
}

const today = new Date().toISOString().split('T')[0];

/* ── Crypto Assets ── */

export const demoCryptoAssets: CryptoAsset[] = [
  { id: 'bitcoin', symbol: 'btc', name: 'Bitcoin', current_price: 49832, price_change_24h: 1180, price_change_percentage_24h: 2.42, market_cap: 978_000_000_000, market_cap_rank: 1, total_volume: 28_500_000_000, sparkline_in_7d: { price: sparkline(47500, 300) } },
  { id: 'ethereum', symbol: 'eth', name: 'Ethereum', current_price: 2741, price_change_24h: 48.5, price_change_percentage_24h: 1.8, market_cap: 329_000_000_000, market_cap_rank: 2, total_volume: 14_200_000_000, sparkline_in_7d: { price: sparkline(2620, 20) } },
  { id: 'solana', symbol: 'sol', name: 'Solana', current_price: 124.5, price_change_24h: -0.75, price_change_percentage_24h: -0.6, market_cap: 55_000_000_000, market_cap_rank: 5, total_volume: 3_100_000_000, sparkline_in_7d: { price: sparkline(128, 3) } },
  { id: 'binancecoin', symbol: 'bnb', name: 'BNB', current_price: 412.3, price_change_24h: 5.2, price_change_percentage_24h: 1.28, market_cap: 63_000_000_000, market_cap_rank: 4, total_volume: 1_800_000_000, sparkline_in_7d: { price: sparkline(400, 5) } },
  { id: 'ripple', symbol: 'xrp', name: 'XRP', current_price: 0.632, price_change_24h: -0.008, price_change_percentage_24h: -1.25, market_cap: 34_500_000_000, market_cap_rank: 6, total_volume: 1_200_000_000, sparkline_in_7d: { price: sparkline(0.64, 0.01) } },
  { id: 'cardano', symbol: 'ada', name: 'Cardano', current_price: 0.485, price_change_24h: 0.012, price_change_percentage_24h: 2.53, market_cap: 17_000_000_000, market_cap_rank: 8, total_volume: 680_000_000, sparkline_in_7d: { price: sparkline(0.47, 0.008) } },
  { id: 'avalanche-2', symbol: 'avax', name: 'Avalanche', current_price: 38.2, price_change_24h: 0.95, price_change_percentage_24h: 2.55, market_cap: 14_200_000_000, market_cap_rank: 9, total_volume: 520_000_000, sparkline_in_7d: { price: sparkline(36.5, 0.8) } },
  { id: 'polkadot', symbol: 'dot', name: 'Polkadot', current_price: 7.82, price_change_24h: -0.12, price_change_percentage_24h: -1.51, market_cap: 10_800_000_000, market_cap_rank: 12, total_volume: 310_000_000, sparkline_in_7d: { price: sparkline(7.9, 0.15) } },
  { id: 'chainlink', symbol: 'link', name: 'Chainlink', current_price: 16.45, price_change_24h: 0.38, price_change_percentage_24h: 2.36, market_cap: 9_800_000_000, market_cap_rank: 14, total_volume: 480_000_000, sparkline_in_7d: { price: sparkline(15.8, 0.3) } },
  { id: 'dogecoin', symbol: 'doge', name: 'Dogecoin', current_price: 0.0892, price_change_24h: 0.0015, price_change_percentage_24h: 1.71, market_cap: 12_800_000_000, market_cap_rank: 10, total_volume: 890_000_000, sparkline_in_7d: { price: sparkline(0.087, 0.002) } },
];

/* ── Global Market ── */

export const demoGlobalMarket: GlobalMarketData = {
  total_market_cap: 1_820_000_000_000,
  total_volume: 78_500_000_000,
  btc_dominance: 53.7,
  eth_dominance: 18.1,
  market_cap_change_percentage_24h: 1.84,
};

/* ── Fear & Greed ── */

export const demoFearGreed: FearGreedIndex = {
  value: 68,
  value_classification: 'Greed',
  timestamp: new Date().toISOString(),
};

/* ── Macro Indicators ── */

export const demoMacroIndicators: MacroIndicator[] = [
  { name: 'VIX', value: 18.2, change: -0.56, change_percentage: -3.0, sparkline: sparkline(19.5, 0.3, 30), z_score: -0.42, regime: 'low_vol' },
  { name: 'DXY', value: 103.4, change: 0.21, change_percentage: 0.2, sparkline: sparkline(103.0, 0.2, 30), z_score: 0.15, regime: 'neutral' },
  { name: 'M2', value: 21.8, change: 0.09, change_percentage: 0.4, sparkline: sparkline(21.5, 0.05, 30), z_score: 0.85, regime: 'expanding' },
  { name: 'WTI', value: 72.1, change: -0.87, change_percentage: -1.2, sparkline: sparkline(73.5, 0.6, 30), z_score: -0.28, regime: 'neutral' },
];

/* ── Risk History ── */

export const demoRiskHistory: RiskHistoryPoint[] = Array.from({ length: 90 }, (_, i) => {
  const d = new Date();
  d.setDate(d.getDate() - (89 - i));
  const risk = 0.3 + Math.sin(i / 15) * 0.15 + (i / 300) + (Math.random() - 0.5) * 0.04;
  return {
    date: d.toISOString().split('T')[0],
    risk_level: Math.max(0, Math.min(1, risk)),
    price: 42000 + i * 85 + (Math.random() - 0.5) * 500,
    fair_value: 42000 + i * 80,
    deviation: (Math.random() - 0.5) * 0.1,
  };
});

/* ── Market Briefing ── */

export const demoBriefing = `Bitcoin is trading at $49,832, up 2.4% in the last 24 hours as bulls push above the key $49K resistance level. The broader crypto market is following suit with ETH gaining 1.8%.

Macro conditions remain favorable: the VIX has dropped to 18.2, signaling low market volatility. The DXY is flat around 103.4, while global M2 money supply continues its gradual expansion.

The Fear & Greed index sits at 68 (Greed), reflecting growing optimism. Key risk: upcoming FOMC minutes could introduce short-term volatility. DCA into strength with caution.`;

/* ── Economic Events ── */

export const demoEvents: EconomicEvent[] = [
  { id: '1', title: 'FOMC Meeting Minutes', date: `${today}T14:00:00Z`, time: '2:00 PM', impact: 'high', country: 'US' },
  { id: '2', title: 'Initial Jobless Claims', date: `${today}T08:30:00Z`, time: '8:30 AM', impact: 'medium', country: 'US' },
  { id: '3', title: 'Crude Oil Inventories', date: `${today}T10:30:00Z`, time: '10:30 AM', impact: 'medium', country: 'US' },
  { id: '4', title: 'ECB Interest Rate Decision', date: `${today}T07:45:00Z`, time: '7:45 AM', impact: 'high', country: 'EU' },
  { id: '5', title: 'US 10Y Treasury Auction', date: `${today}T13:00:00Z`, time: '1:00 PM', impact: 'low', country: 'US' },
];

/* ── DCA Reminders ── */

export const demoReminders: DCAReminder[] = [
  { id: '1', user_id: 'demo', symbol: 'btc', name: 'Bitcoin Weekly', amount: 50, frequency: 'weekly', completed_purchases: 12, notification_time: '09:00', start_date: daysAgo(90), next_reminder_date: daysAgo(-2), is_active: true, created_at: daysAgo(90) },
  { id: '2', user_id: 'demo', symbol: 'eth', name: 'Ethereum Bi-weekly', amount: 25, frequency: 'biweekly', completed_purchases: 6, notification_time: '09:00', start_date: daysAgo(90), next_reminder_date: daysAgo(-5), is_active: true, created_at: daysAgo(90) },
  { id: '3', user_id: 'demo', symbol: 'sol', name: 'Solana Monthly', amount: 100, frequency: 'monthly', completed_purchases: 3, notification_time: '09:00', start_date: daysAgo(90), next_reminder_date: daysAgo(-12), is_active: true, created_at: daysAgo(90) },
];

/* ── News ── */

export const demoNews: NewsItem[] = [
  { id: '1', title: 'Bitcoin Breaks Above $49K as Institutional Interest Surges', description: 'BTC rallied past the key resistance level amid reports of increased ETF inflows.', url: '#', source: 'CoinDesk', published_at: daysAgo(0) },
  { id: '2', title: 'Ethereum Layer 2 TVL Reaches All-Time High', description: 'Combined L2 total value locked surpasses $40 billion as adoption accelerates.', url: '#', source: 'The Block', published_at: daysAgo(0) },
  { id: '3', title: 'Fed Officials Signal Patience on Rate Cuts', description: 'Multiple FOMC members suggest data-dependent approach to monetary policy.', url: '#', source: 'Reuters', published_at: daysAgo(0) },
  { id: '4', title: 'Solana DeFi Ecosystem Sees Record Trading Volume', description: 'Decentralized exchanges on Solana processed over $2B in daily volume.', url: '#', source: 'DL News', published_at: daysAgo(1) },
];

/* ── Crypto Positioning ── */

export const demoCryptoPositioning: CryptoPositioningData = {
  regime: 'risk-off-disinflation',
  regime_label: 'Risk-Off Disinflation',
  regime_description: 'Slowing growth with easing conditions. Defensive positioning recommended until growth signals improve.',
  growth_score: 35,
  inflation_score: 40,
  signal_counts: { bullish: 0, neutral: 2, bearish: 1 },
  extreme_move: false,
  macro_inputs: [
    { id: 'gei', name: 'GEI', value: -0.21, formatted_value: '-0.21', signal: 'Neutral', icon: 'globe' },
    { id: 'vix', name: 'VIX', value: 22.58, formatted_value: '22.58', signal: 'Neutral', icon: 'trending-up' },
    { id: 'dxy', name: 'DXY', value: 99.04, formatted_value: '99.04', signal: 'Bullish', icon: 'dollar-sign' },
    { id: 'liquidity', name: 'Net Liquidity', value: 5_730_000_000_000, formatted_value: '$5.73T', signal: 'Bullish', icon: 'bar-chart-3' },
    { id: 'wti', name: 'WTI', value: 73.78, formatted_value: '$73.78', signal: 'Bullish', icon: 'droplet' },
    { id: 'gold', name: 'Gold', value: 5127, formatted_value: '$5,127', signal: 'Bullish', icon: 'diamond' },
  ],
  assets: [
    { symbol: 'BTC', name: 'Bitcoin', signal: 'neutral', regime_fit: 0.34, target_allocation: 25, is_dca_opportunity: true, risk_level: 0.34, interpretation: 'Trend is weak but risk is low (0.34). Small DCA positions may be favorable.' },
    { symbol: 'ETH', name: 'Ethereum', signal: 'neutral', regime_fit: 0.33, target_allocation: 25, is_dca_opportunity: true, risk_level: 0.33, interpretation: 'Trend is weak but risk is low (0.33). Small DCA positions may be favorable.' },
    { symbol: 'SOL', name: 'Solana', signal: 'neutral', regime_fit: 0.29, target_allocation: 25, is_dca_opportunity: true, risk_level: 0.29, interpretation: 'Trend is weak but risk is low (0.29). Small DCA positions may be favorable.' },
    { symbol: 'BNB', name: 'BNB', signal: 'bearish', regime_fit: 0.48, target_allocation: 0, is_dca_opportunity: false, risk_level: 0.48, interpretation: "Trend doesn't support new positions right now." },
    { symbol: 'SUI', name: 'Sui', signal: 'neutral', regime_fit: 0.11, target_allocation: 25, is_dca_opportunity: true, risk_level: 0.11, interpretation: 'Trend is weak but risk is low (0.11). Small DCA positions may be favorable.' },
    { symbol: 'UNI', name: 'Uniswap', signal: 'neutral', regime_fit: 0.24, target_allocation: 25, is_dca_opportunity: true, risk_level: 0.24, interpretation: 'Trend is weak but risk is low (0.24). Small DCA positions may be favorable.' },
    { symbol: 'ONDO', name: 'Ondo', signal: 'neutral', regime_fit: 0.33, target_allocation: 25, is_dca_opportunity: true, risk_level: 0.33, interpretation: 'Trend is weak but risk is low (0.33). Small DCA positions may be favorable.' },
    { symbol: 'RNDR', name: 'Render', signal: 'bearish', regime_fit: 0.37, target_allocation: 0, is_dca_opportunity: false, risk_level: 0.37, interpretation: "Trend doesn't support new positions right now." },
  ],
};

/* ── Traditional Markets ── */

export const demoTraditionalMarkets: TraditionalMarketAsset[] = [
  { id: 'sp500', symbol: 'SPX', name: 'S&P 500', current_price: 5_021.84, price_change_24h: 18.72, price_change_percentage_24h: 0.37, trend_signal: 'Bullish', sparkline: sparkline(4950, 15, 30) },
  { id: 'nasdaq', symbol: 'NDX', name: 'Nasdaq 100', current_price: 17_842.15, price_change_24h: 92.41, price_change_percentage_24h: 0.52, trend_signal: 'Bullish', sparkline: sparkline(17500, 60, 30) },
  { id: 'gold', symbol: 'XAU', name: 'Gold', current_price: 2_038.50, price_change_24h: 8.20, price_change_percentage_24h: 0.40, trend_signal: 'Bullish', sparkline: sparkline(2010, 5, 30) },
  { id: 'silver', symbol: 'XAG', name: 'Silver', current_price: 22.84, price_change_24h: -0.16, price_change_percentage_24h: -0.70, trend_signal: 'Neutral', sparkline: sparkline(23.0, 0.2, 30) },
];

/* ── Market Sentiment ── */

export const demoSentiment: MarketSentimentData = {
  risk_score: 35,
  fear_greed: 14,
  fear_greed_label: 'Extreme Fear',
  season: 'bitcoin',
  season_index: 27,
  btc_dominance: 56.75,
  btc_dominance_change: 0.0,
  total_market_cap: 2_410_000_000_000,
  market_cap_change: -1.21,
  market_cap_sparkline: sparkline(2500, 30, 30),
  sentiment_regime: 'Apathy',
  sentiment_regime_description: 'Low volume and fearful. Markets are disinterested with minimal participation — often a bottoming signal.',
  emotion_score: 40,
  engagement_score: 44,
  regime_trajectory: [
    { date: daysAgo(90).split('T')[0], emotion_score: 25, engagement_score: 72, regime: 'Panic' },
    { date: daysAgo(30).split('T')[0], emotion_score: 30, engagement_score: 65, regime: 'Panic' },
    { date: daysAgo(7).split('T')[0], emotion_score: 38, engagement_score: 48, regime: 'Apathy' },
    { date: today, emotion_score: 40, engagement_score: 44, regime: 'Apathy' },
  ],
  asset_risk_levels: [
    { symbol: 'BNB', name: 'BNB', risk_level: 0.479, risk_category: 'Neutral', days_at_level: 29 },
    { symbol: 'BTC', name: 'Bitcoin', risk_level: 0.338, risk_category: 'Low Risk', days_at_level: 32 },
    { symbol: 'ETH', name: 'Ethereum', risk_level: 0.330, risk_category: 'Low Risk', days_at_level: 31 },
    { symbol: 'ONDO', name: 'Ondo', risk_level: 0.329, risk_category: 'Low Risk', days_at_level: 34 },
    { symbol: 'RNDR', name: 'Render', risk_level: 0.374, risk_category: 'Low Risk', days_at_level: 32 },
    { symbol: 'SOL', name: 'Solana', risk_level: 0.287, risk_category: 'Low Risk', days_at_level: 32 },
    { symbol: 'SUI', name: 'Sui', risk_level: 0.110, risk_category: 'Very Low Risk', days_at_level: 28 },
    { symbol: 'UNI', name: 'Uniswap', risk_level: 0.239, risk_category: 'Low Risk', days_at_level: 7 },
  ],
  funding_rate: {
    rate: -0.0023,
    sentiment: 'Neutral',
    annualized_rate: -2.5,
    exchange: 'Binance',
  },
  retail_sentiment: {
    coinbase_rank: null,
    coinbase_rank_change: 0,
    btc_search_index: 2,
    btc_search_change: -4,
  },
};

/* ── ArkLine Score ── */

export const demoArkLineScore: ArkLineScoreData = {
  score: 42,
  level: 'Moderate',
  components: [
    { name: 'Fear & Greed', value: 68, weight: 20, icon: 'gauge' },
    { name: 'Funding Rates', value: 35, weight: 15, icon: 'bar-chart-3' },
    { name: 'RSI', value: 52, weight: 15, icon: 'activity' },
    { name: 'Log Regression', value: 38, weight: 15, icon: 'trending-up' },
    { name: 'SMA Position', value: 45, weight: 10, icon: 'git-branch' },
    { name: 'Bull Market Bands', value: 30, weight: 10, icon: 'layers' },
    { name: 'Macro Risk', value: 40, weight: 15, icon: 'globe' },
  ],
};

/* ── BTC Supply in Profit ── */

export const demoSupplyInProfit: SupplyInProfitData = {
  percentage: 78.45,
  status: 'Normal',
  date: today,
  history: Array.from({ length: 90 }, (_, i) => {
    const d = new Date();
    d.setDate(d.getDate() - (89 - i));
    return {
      date: d.toISOString().split('T')[0],
      value: 70 + Math.sin(i / 12) * 8 + (i / 45) + (Math.random() - 0.5) * 3,
    };
  }),
};

/* ── Asset Risk Levels (detailed) ── */

export const demoAssetRiskLevels: AssetRiskLevelData[] = [
  {
    symbol: 'BTC', name: 'Bitcoin', risk_value: 0.590, level: 'Moderate', days_at_level: 14, seven_day_avg: 0.565,
    factors: [
      { type: 'Log Regression', raw_value: 0.62, normalized_value: 0.62, weight: 0.25 },
      { type: 'RSI', raw_value: 58, normalized_value: 0.58, weight: 0.15 },
      { type: 'SMA Position', raw_value: 1.08, normalized_value: 0.55, weight: 0.10 },
      { type: 'Bull Market Bands', raw_value: 0.65, normalized_value: 0.65, weight: 0.10 },
      { type: 'Funding Rate', raw_value: 0.012, normalized_value: 0.45, weight: 0.15 },
      { type: 'Fear & Greed', raw_value: 68, normalized_value: 0.68, weight: 0.10 },
      { type: 'Macro Risk', raw_value: 0.40, normalized_value: 0.40, weight: 0.15 },
    ],
  },
  {
    symbol: 'ETH', name: 'Ethereum', risk_value: 0.420, level: 'Moderate', days_at_level: 8, seven_day_avg: 0.405,
    factors: [
      { type: 'Log Regression', raw_value: 0.45, normalized_value: 0.45, weight: 0.25 },
      { type: 'RSI', raw_value: 48, normalized_value: 0.48, weight: 0.15 },
      { type: 'SMA Position', raw_value: 0.95, normalized_value: 0.40, weight: 0.10 },
      { type: 'Bull Market Bands', raw_value: 0.38, normalized_value: 0.38, weight: 0.10 },
      { type: 'Funding Rate', raw_value: 0.008, normalized_value: 0.35, weight: 0.15 },
      { type: 'Fear & Greed', raw_value: 68, normalized_value: 0.68, weight: 0.10 },
      { type: 'Macro Risk', raw_value: 0.40, normalized_value: 0.40, weight: 0.15 },
    ],
  },
  {
    symbol: 'SOL', name: 'Solana', risk_value: 0.380, level: 'Low', days_at_level: 21, seven_day_avg: 0.365,
    factors: [
      { type: 'Log Regression', raw_value: 0.40, normalized_value: 0.40, weight: 0.25 },
      { type: 'RSI', raw_value: 44, normalized_value: 0.44, weight: 0.15 },
      { type: 'SMA Position', raw_value: 0.92, normalized_value: 0.35, weight: 0.10 },
      { type: 'Bull Market Bands', raw_value: 0.32, normalized_value: 0.32, weight: 0.10 },
      { type: 'Funding Rate', raw_value: 0.005, normalized_value: 0.30, weight: 0.15 },
      { type: 'Fear & Greed', raw_value: 68, normalized_value: 0.68, weight: 0.10 },
      { type: 'Macro Risk', raw_value: 0.40, normalized_value: 0.40, weight: 0.15 },
    ],
  },
  {
    symbol: 'XRP', name: 'XRP', risk_value: 0.310, level: 'Low', days_at_level: 32, seven_day_avg: 0.295,
    factors: [
      { type: 'Log Regression', raw_value: 0.35, normalized_value: 0.35, weight: 0.25 },
      { type: 'RSI', raw_value: 40, normalized_value: 0.40, weight: 0.15 },
      { type: 'SMA Position', raw_value: 0.88, normalized_value: 0.28, weight: 0.10 },
      { type: 'Bull Market Bands', raw_value: 0.25, normalized_value: 0.25, weight: 0.10 },
      { type: 'Funding Rate', raw_value: 0.003, normalized_value: 0.25, weight: 0.15 },
      { type: 'Fear & Greed', raw_value: 68, normalized_value: 0.68, weight: 0.10 },
      { type: 'Macro Risk', raw_value: 0.40, normalized_value: 0.40, weight: 0.15 },
    ],
  },
];

/* ── Market Movers (top 3 coins for Core Technical Analysis) ── */

export const demoMarketMovers: CryptoAsset[] = [
  demoCryptoAssets[0], // BTC
  demoCryptoAssets[1], // ETH
  demoCryptoAssets[2], // SOL
];

/* ── Altcoin Scanner ── */

export const demoAltcoinScanner: AltcoinScannerEntry[] = [
  { id: 'ethereum', symbol: 'ETH', name: 'Ethereum', current_price: 2741, market_cap: 329_000_000_000, return_7d: 5.2, return_30d: 12.8, return_90d: 28.4, vs_btc_7d: 2.8, vs_btc_30d: 4.1, vs_btc_90d: -3.2 },
  { id: 'solana', symbol: 'SOL', name: 'Solana', current_price: 124.5, market_cap: 55_000_000_000, return_7d: -2.1, return_30d: 18.5, return_90d: 142.3, vs_btc_7d: -4.5, vs_btc_30d: 9.8, vs_btc_90d: 110.7 },
  { id: 'binancecoin', symbol: 'BNB', name: 'BNB', current_price: 412.3, market_cap: 63_000_000_000, return_7d: 3.1, return_30d: 8.4, return_90d: 22.1, vs_btc_7d: 0.7, vs_btc_30d: -0.3, vs_btc_90d: -9.5 },
  { id: 'ripple', symbol: 'XRP', name: 'XRP', current_price: 0.632, market_cap: 34_500_000_000, return_7d: -3.8, return_30d: -5.2, return_90d: 8.4, vs_btc_7d: -6.2, vs_btc_30d: -13.9, vs_btc_90d: -23.2 },
  { id: 'cardano', symbol: 'ADA', name: 'Cardano', current_price: 0.485, market_cap: 17_000_000_000, return_7d: 6.8, return_30d: 15.2, return_90d: 35.7, vs_btc_7d: 4.4, vs_btc_30d: 6.5, vs_btc_90d: 4.1 },
  { id: 'avalanche-2', symbol: 'AVAX', name: 'Avalanche', current_price: 38.2, market_cap: 14_200_000_000, return_7d: 8.4, return_30d: 22.1, return_90d: 68.5, vs_btc_7d: 6.0, vs_btc_30d: 13.4, vs_btc_90d: 36.9 },
  { id: 'polkadot', symbol: 'DOT', name: 'Polkadot', current_price: 7.82, market_cap: 10_800_000_000, return_7d: -1.5, return_30d: 4.8, return_90d: 18.2, vs_btc_7d: -3.9, vs_btc_30d: -3.9, vs_btc_90d: -13.4 },
  { id: 'chainlink', symbol: 'LINK', name: 'Chainlink', current_price: 16.45, market_cap: 9_800_000_000, return_7d: 4.2, return_30d: 19.8, return_90d: 52.4, vs_btc_7d: 1.8, vs_btc_30d: 11.1, vs_btc_90d: 20.8 },
  { id: 'dogecoin', symbol: 'DOGE', name: 'Dogecoin', current_price: 0.0892, market_cap: 12_800_000_000, return_7d: 2.1, return_30d: -8.3, return_90d: 14.5, vs_btc_7d: -0.3, vs_btc_30d: -17.0, vs_btc_90d: -17.1 },
  { id: 'uniswap', symbol: 'UNI', name: 'Uniswap', current_price: 7.24, market_cap: 5_400_000_000, return_7d: 9.2, return_30d: 24.5, return_90d: 45.8, vs_btc_7d: 6.8, vs_btc_30d: 15.8, vs_btc_90d: 14.2 },
  { id: 'near', symbol: 'NEAR', name: 'NEAR Protocol', current_price: 3.42, market_cap: 3_800_000_000, return_7d: 11.5, return_30d: 32.1, return_90d: 78.4, vs_btc_7d: 9.1, vs_btc_30d: 23.4, vs_btc_90d: 46.8 },
  { id: 'render-token', symbol: 'RNDR', name: 'Render', current_price: 4.85, market_cap: 2_400_000_000, return_7d: 14.2, return_30d: 38.7, return_90d: 112.5, vs_btc_7d: 11.8, vs_btc_30d: 30.0, vs_btc_90d: 80.9 },
  { id: 'injective-protocol', symbol: 'INJ', name: 'Injective', current_price: 28.45, market_cap: 2_600_000_000, return_7d: 7.8, return_30d: 28.4, return_90d: 95.2, vs_btc_7d: 5.4, vs_btc_30d: 19.7, vs_btc_90d: 63.6 },
  { id: 'sui', symbol: 'SUI', name: 'Sui', current_price: 1.82, market_cap: 2_200_000_000, return_7d: 12.4, return_30d: 42.8, return_90d: 185.3, vs_btc_7d: 10.0, vs_btc_30d: 34.1, vs_btc_90d: 153.7 },
  { id: 'celestia', symbol: 'TIA', name: 'Celestia', current_price: 15.62, market_cap: 2_800_000_000, return_7d: -4.2, return_30d: 8.5, return_90d: 62.1, vs_btc_7d: -6.6, vs_btc_30d: -0.2, vs_btc_90d: 30.5 },
];
