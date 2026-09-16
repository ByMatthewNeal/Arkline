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
  title: 'Pricing — Free to Use | Arkline',
  description:
    'Arkline is free. Everything included: multi-factor risk scoring, macro dashboard, AI briefings, and portfolio tracking across crypto and traditional markets. No tiers, no trial clock, no card — on iOS and the web.',
  alternates: { canonical: '/pricing' },
  openGraph: {
    title: 'Arkline — Free to Use',
    description:
      'Every tool included, free while we grow Arkline. Multi-factor risk scoring, macro dashboard, and AI briefings on iPhone and the web. No card required.',
    url: 'https://arkline.io/pricing',
  },
  twitter: {
    title: 'Arkline — Free to Use',
    description:
      'Every tool included, free. Risk scoring, macro dashboard, and AI briefings on iPhone and the web. No card required.',
  },
};

export default function PricingLayout({ children }: { children: React.ReactNode }) {
  return children;
}
