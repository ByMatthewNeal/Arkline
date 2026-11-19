/**
 * Single source of truth for pricing, trial, and the Pro feature list.
 *
 * These numbers previously lived as hardcoded strings on both the homepage and
 * the pricing page, which is how the annual price drifted: marketing said
 * "$399.99/year" while the checkout selector said "$400". Anything a visitor
 * reads about price or the trial should come from here.
 *
 * Keep in sync with:
 *   - Stripe price IDs in src/lib/onboarding/config.ts (PRICE_IDS)
 *   - TRIAL_DAYS in supabase/functions/create-self-checkout/index.ts
 *   - The Apple introductory offer on com.arkline.app.founding.monthly
 */

/** Free-trial length, identical on Apple and Stripe. */
export const TRIAL_DAYS = 14;

export const PRICING = {
  // Standard is the public offer for all new users (iOS + web).
  standard: {
    monthly: '$69.99',
    annual: '$699',
    annualSavings: '~17%',
  },
  // Founding is a grandfathered rate for users from before the paid relaunch.
  // It is NOT offered to new users — kept here only for internal reference and
  // any existing-member copy.
  founding: {
    monthly: '$39.99',
    annual: '$399.99',
    annualSavings: '~17%',
  },
} as const;

/**
 * Short trial phrases. Both storefronts offer the same 14 days, so no copy
 * needs to qualify by platform.
 */
export const TRIAL_COPY = {
  /** Headline / badge use. */
  short: `${TRIAL_DAYS}-day free trial`,
  /** Under a CTA, where the price must also appear. */
  withPrice: `Free for ${TRIAL_DAYS} days, then ${PRICING.standard.monthly}/month`,
  /** Reassurance line — the two questions people actually have. */
  reassurance: 'Cancel anytime during the trial and you will not be charged.',
} as const;

/** Everything included in Arkline Pro. One list, rendered in both places. */
export const PRO_FEATURES = [
  'Portfolio tracking across crypto, stocks, and custom assets (20,000+)',
  'Performance metrics: Sharpe ratio, drawdown, volatility, allocation',
  '8-factor BTC risk scoring with historical trends',
  'Morning & evening AI briefings',
  'Macro dashboard with regime detection (VIX, DXY, US Net Liquidity)',
  'Smart DCA with risk-adjusted reminders',
  'Technical analysis: RSI, MACD, moving averages, BMSB',
  'Sentiment gauges: Fear & Greed, altcoin season, BTC dominance',
  'Derivatives data: open interest, funding rates, liquidations',
  'Economic calendar + FedWatch rate probabilities',
  'Real-time news, Coinbase ranking, and push alerts',
] as const;
