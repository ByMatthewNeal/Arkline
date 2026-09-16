import type { Metadata } from 'next';

/**
 * features/page.tsx is a client component and cannot export metadata itself.
 *
 * As with /pricing, the canonical is the load-bearing part: inheriting the root
 * "/" canonical marked this page as a duplicate of the homepage, so it could
 * not be indexed or ranked in its own right.
 */
export const metadata: Metadata = {
  title: 'Features — Risk Scoring, Macro Dashboard & AI Briefings | Arkline',
  description:
    'Multi-factor risk scoring for crypto and stocks, a macro dashboard with regime detection, twice-daily AI market briefings, model portfolios, and smart DCA reminders. Every feature included, free on iOS and the web.',
  alternates: { canonical: '/features' },
  openGraph: {
    title: 'Every Arkline Feature, Free',
    description:
      'Risk scoring, macro regime detection, AI briefings, model portfolios, and DCA reminders across crypto and traditional markets. Free to use.',
    url: 'https://arkline.io/features',
  },
  twitter: {
    title: 'Every Arkline Feature, Free',
    description:
      'Risk scoring, macro regime detection, AI briefings, and model portfolios across crypto and traditional markets. Free to use.',
  },
};

export default function FeaturesLayout({ children }: { children: React.ReactNode }) {
  return children;
}
