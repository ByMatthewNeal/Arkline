import type { Metadata } from 'next';

/**
 * pricing/page.tsx is a client component, so it cannot export metadata itself.
 * This layout supplies it.
 *
 * The important field is `alternates.canonical`. Without it the page inherited
 * the root canonical of "/", which told Google that /pricing was a duplicate of
 * the homepage and should not be indexed on its own — so the page could never
 * rank for pricing or free-trial queries.
 */
export const metadata: Metadata = {
  title: 'Pricing · $69.99/mo, 14-Day Free Trial | Arkline',
  description:
    'Arkline Pro is $69.99/month or $699/year, with a 14-day free trial. Everything included: multi-factor risk scoring, macro dashboard, AI briefings, and portfolio tracking across crypto and traditional markets. No tiers, no add-ons, on iOS and the web.',
  alternates: { canonical: '/pricing' },
  openGraph: {
    title: 'Arkline Pro · 14-Day Free Trial',
    description:
      'Every tool in one subscription: multi-factor risk scoring, macro dashboard, and AI briefings on iPhone and the web. $69.99/month, start with a 14-day free trial.',
    url: 'https://arkline.io/pricing',
  },
  twitter: {
    title: 'Arkline Pro · 14-Day Free Trial',
    description:
      'Every tool in one subscription. Risk scoring, macro dashboard, and AI briefings on iPhone and the web. $69.99/month, 14-day free trial.',
  },
};

export default function PricingLayout({ children }: { children: React.ReactNode }) {
  return children;
}
