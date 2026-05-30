import type { Metadata } from 'next';
import { Inter, Urbanist } from 'next/font/google';
import { Providers } from './providers';
import { ContentProtection } from '@/components/ui/content-protection';
import { MetaPixel } from '@/components/analytics/MetaPixel';
import { PixelPageViewTracker } from '@/components/analytics/PixelPageViewTracker';
import './globals.css';

const inter = Inter({
  variable: '--font-inter',
  subsets: ['latin'],
  display: 'swap',
});

const urbanist = Urbanist({
  variable: '--font-urbanist',
  subsets: ['latin'],
  display: 'swap',
});

export const metadata: Metadata = {
  metadataBase: new URL('https://arkline.io'),
  title: 'Arkline — Market Intelligence, Simplified',
  description:
    'Arkline combines multi-factor risk scoring, macro intelligence, and AI-generated briefings into one platform. Track crypto & stocks, quantify risk, and invest with clarity.',
  alternates: {
    canonical: '/',
  },
  icons: {
    icon: [
      { url: '/icon-192.png', sizes: '192x192', type: 'image/png' },
      { url: '/icon-512.png', sizes: '512x512', type: 'image/png' },
    ],
    apple: '/apple-touch-icon.png',
  },
  openGraph: {
    title: 'Arkline — Your Portfolio. Your Edge.',
    description:
      'Multi-factor risk scoring, macro dashboard, and AI briefings — all in one platform. Start free.',
    type: 'website',
    siteName: 'Arkline',
    url: 'https://arkline.io',
    images: [{ url: '/og-image.png', width: 1200, height: 630 }],
  },
  twitter: {
    card: 'summary_large_image',
    site: '@Arklineio',
    creator: '@Arklineio',
    title: 'Arkline — Your Portfolio. Your Edge.',
    description:
      'Multi-factor risk scoring, macro dashboard, and AI briefings — all in one platform. Start free.',
    images: ['/og-image.png'],
  },
};

const jsonLd = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'Organization',
      '@id': 'https://arkline.io/#organization',
      name: 'Arkline Technologies LLC',
      url: 'https://arkline.io',
      logo: {
        '@type': 'ImageObject',
        url: 'https://arkline.io/icon-512.png',
      },
      sameAs: [
        'https://x.com/Arklineio',
        'https://www.instagram.com/arklineio/',
      ],
      contactPoint: {
        '@type': 'ContactPoint',
        email: 'support@arkline.io',
        contactType: 'customer support',
      },
    },
    {
      '@type': 'WebSite',
      '@id': 'https://arkline.io/#website',
      url: 'https://arkline.io',
      name: 'Arkline',
      publisher: { '@id': 'https://arkline.io/#organization' },
    },
    {
      '@type': 'SoftwareApplication',
      '@id': 'https://arkline.io/#app',
      name: 'Arkline',
      operatingSystem: 'iOS',
      applicationCategory: 'FinanceApplication',
      description:
        'Market intelligence platform combining multi-factor risk scoring, macro dashboard, AI briefings, and positioning signals for crypto and traditional markets.',
      offers: {
        '@type': 'Offer',
        price: '39.99',
        priceCurrency: 'USD',
        priceValidUntil: '2027-12-31',
      },
      publisher: { '@id': 'https://arkline.io/#organization' },
    },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${inter.variable} ${urbanist.variable}`} suppressHydrationWarning>
      <body className="antialiased">
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
        <MetaPixel />
        <PixelPageViewTracker />
        <ContentProtection />
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
