import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Arkline — Early Access',
  description: 'Multi-factor risk scoring, macro intelligence, and AI briefings across crypto and traditional markets. 150 founding spots.',
  robots: { index: false, follow: false },
  openGraph: {
    title: 'Arkline — Early Access',
    description: 'Institutional intelligence across crypto and traditional markets. 150 founding spots locked in.',
    images: [{ url: '/og-image.png' }],
  },
};

export default function EarlyAccessLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <>{children}</>;
}
