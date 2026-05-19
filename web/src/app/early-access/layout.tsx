import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Arkline — Early Access',
  description: 'Multi-factor risk scoring, macro intelligence, and AI briefings for retail investors. 150 founding spots. June 2026.',
  robots: { index: false, follow: false },
  openGraph: {
    title: 'Arkline — Early Access',
    description: 'Institutional intelligence for retail investors. 150 founding spots locked in.',
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
