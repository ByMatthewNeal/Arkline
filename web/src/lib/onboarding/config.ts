// Web onboarding — mirrors the iOS OnboardingViewModel flow, adapted for the
// desktop/web experience (email + password auth instead of passcode/Face ID,
// and an account-linked Stripe payment step that iOS doesn't have).

export type OnboardingStepId =
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

// Stripe price IDs (founding tier — live mode, from create-checkout-session).
export const PRICE_IDS = {
  foundingMonthly: 'price_1TXCJyPHuageZ7zbIGTJCHPl', // $39.99/mo
  foundingAnnual: 'price_1TXCOPPHuageZ7zb7d2HyeHc',  // $400/yr
} as const;

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
