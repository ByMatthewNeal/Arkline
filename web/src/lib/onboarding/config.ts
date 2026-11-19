// Web onboarding — mirrors the iOS OnboardingViewModel flow, adapted for the
// desktop/web experience (email + password auth instead of passcode/Face ID,
// and an account-linked Stripe payment step that iOS doesn't have).

export type OnboardingStepId =
  | 'payment'
  | 'name'
  | 'interests'
  | 'experience'
  | 'approach'
  | 'goals'
  | 'notifications'
  | 'complete';

// Steps shown inside the /onboarding wizard. Invite validation + account
// creation happen on /signup; payment happens upstream via the paid invite
// code (Stripe), mirroring the iOS flow, so the wizard is profile-only.
export const ONBOARDING_STEPS: OnboardingStepId[] = [
  'name',
  'interests',
  'experience',
  'approach',
  'goals',
  'notifications',
  'complete',
];

export const SKIPPABLE_STEPS: Set<OnboardingStepId> = new Set([
  'interests', 'experience', 'approach', 'goals', 'notifications',
]);

// ── Option sets (mirrored from iOS OnboardingViewModel) ──────────────────────

export const INVESTMENT_INTERESTS = [
  { id: 'crypto', label: 'Crypto', icon: 'bitcoin' },
  { id: 'stocks', label: 'Stocks & ETFs', icon: 'line-chart' },
  { id: 'commodities', label: 'Commodities', icon: 'leaf' },
] as const;

export const EXPERIENCE_LEVELS = [
  { id: 'beginner', label: 'Beginner', description: 'New to investing' },
  { id: 'intermediate', label: 'Intermediate', description: 'A few years in' },
  { id: 'advanced', label: 'Advanced', description: 'Seasoned investor' },
  { id: 'professional', label: 'Professional', description: 'I do this for a living' },
] as const;

export const PORTFOLIO_SIZES = [
  { id: 'under1k', label: 'Under $1K' },
  { id: '1k_10k', label: '$1K – $10K' },
  { id: '10k_50k', label: '$10K – $50K' },
  { id: '50k_250k', label: '$50K – $250K' },
  { id: 'over250k', label: '$250K+' },
] as const;

export const CRYPTO_APPROACHES = [
  { id: 'long_term', label: 'Long-term holder', description: 'Spot positions, multi-year horizon', icon: 'hourglass' },
  { id: 'active_trader', label: 'Active trader', description: 'Swing setups and short-term moves', icon: 'zap' },
  { id: 'systematic_dca', label: 'Systematic DCA', description: 'Scheduled or risk-adjusted accumulation', icon: 'calendar-clock' },
  { id: 'building_conviction', label: 'Building conviction', description: 'Getting started, learning the signals', icon: 'lightbulb' },
] as const;

export const PORTFOLIO_GOALS = [
  { id: 'risk_management', label: 'Risk Management', description: 'Know when to size up or de-risk', icon: 'shield-check' },
  { id: 'entry_signals', label: 'Finding Entries', description: 'Fibonacci-based trade signals', icon: 'crosshair' },
  { id: 'portfolio_tracking', label: 'Portfolio Tracking', description: 'Track holdings and performance', icon: 'pie-chart' },
  { id: 'market_intelligence', label: 'Market Intelligence', description: 'Daily briefings and sentiment', icon: 'sparkles' },
  { id: 'dca_strategy', label: 'DCA Strategy', description: 'Systematic accumulation plans', icon: 'calendar-clock' },
  { id: 'macro_analysis', label: 'Macro Analysis', description: 'VIX, DXY, liquidity cycles', icon: 'globe' },
] as const;

// Stripe price IDs (live mode). New web signups get Standard; Founding is
// reserved for existing users (not shown in the new-user onboarding flow).
export const PRICE_IDS = {
  standardMonthly: 'price_1TXCPTPHuageZ7zbCrDoFlRO', // $69.99/mo
  standardAnnual: 'price_1UdUlxPHuageZ7zbkgyVJ7f5',  // $699/yr
  foundingMonthly: 'price_1TXCJyPHuageZ7zbIGTJCHPl', // $39.99/mo (existing users only)
  foundingAnnual: 'price_1UdUnGPHuageZ7zbdLqwrlkW',  // $399.99/yr (existing users only)
} as const;

// Self-serve payment plans shown in the onboarding payment step (when the user
// did not arrive with a pre-paid invite code). New signups see Standard pricing;
// founding is grandfathered to existing users and intentionally not listed here.
export const PAYMENT_PLANS = [
  { id: PRICE_IDS.standardAnnual, label: 'Annual', price: '$699', cadence: 'per year', note: 'Save ~17% · 14-day free trial', highlight: true },
  { id: PRICE_IDS.standardMonthly, label: 'Monthly', price: '$69.99', cadence: 'per month', note: '14-day free trial', highlight: false },
] as const;

// ── Collected onboarding data ────────────────────────────────────────────────

export interface OnboardingData {
  firstName: string;
  lastName: string;
  interests: string[];
  experienceLevel: string | null;
  portfolioSize: string | null;
  cryptoApproach: string | null;
  goals: string[];
  notificationsEnabled: boolean;
}

export const EMPTY_ONBOARDING_DATA: OnboardingData = {
  firstName: '',
  lastName: '',
  interests: [],
  experienceLevel: null,
  portfolioSize: null,
  cryptoApproach: null,
  goals: [],
  notificationsEnabled: true,
};
