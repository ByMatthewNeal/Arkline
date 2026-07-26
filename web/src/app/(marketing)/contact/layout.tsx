import type { Metadata } from 'next';

/**
 * contact/page.tsx is a client component (it owns a form) and cannot export
 * metadata itself. Same canonical fix as /pricing and /features.
 *
 * No trial or price copy here on purpose — this page serves people who already
 * have a question, not people deciding whether to buy.
 */
export const metadata: Metadata = {
  title: 'Contact Arkline — Support & Questions',
  description:
    'Questions about Arkline, your subscription, or the risk model? Get in touch and reach the founder directly.',
  alternates: { canonical: '/contact' },
  openGraph: {
    title: 'Contact Arkline',
    description:
      'Questions about Arkline, your subscription, or the risk model? Reach the founder directly.',
    url: 'https://arkline.io/contact',
  },
  twitter: {
    title: 'Contact Arkline',
    description: 'Questions about Arkline, your subscription, or the risk model?',
  },
};

export default function ContactLayout({ children }: { children: React.ReactNode }) {
  return children;
}
