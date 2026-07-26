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
  title: 'Pricing — 7-Day Free Trial, Then $39.99/Month | Arkline',
  description:
    'Try Arkline Pro free for 7 days. One tier, everything included: multi-factor risk scoring, macro dashboard, AI briefings, and portfolio tracking across crypto and traditional markets. $39.99/month or $400/year. Cancel anytime.',
  alternates: { canonical: '/pricing' },
  openGraph: {
    title: 'Arkline Pricing — 7 Days Free, Then $39.99/Month',
    description:
      'One tier. Everything included. Start with a 7-day free trial on iPhone or on the web. Founding members lock in $39.99/month forever.',
    url: 'https://arkline.io/pricing',
  },
  twitter: {
    title: 'Arkline Pricing — 7 Days Free, Then $39.99/Month',
    description:
      'One tier. Everything included. Start with a 7-day free trial on iPhone or on the web.',
  },
};

export default function PricingLayout({ children }: { children: React.ReactNode }) {
  return children;
}
