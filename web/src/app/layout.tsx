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
  title: 'Arkline: Market Intelligence, Simplified',
  description:
    'Institutional-grade market intelligence across crypto and traditional markets. Multi-factor risk scoring, macro dashboard, AI briefings, and portfolio tracking in one app.',
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
    title: 'Arkline: Your Portfolio. Your Edge.',
    description:
      'Multi-factor risk scoring, macro dashboard, and AI briefings across crypto and traditional markets. All in one app.',
    type: 'website',
    siteName: 'Arkline',
    url: 'https://arkline.io',
    images: [{ url: '/og-image.png', width: 1200, height: 630 }],
  },
  twitter: {
    card: 'summary_large_image',
    site: '@Arklineio',
    creator: '@Arklineio',
    title: 'Arkline: Your Portfolio. Your Edge.',
    description:
      'Multi-factor risk scoring, macro dashboard, and AI briefings across crypto and traditional markets. All in one app.',
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
        // Surfaces the free trial in rich results alongside the price.
        eligibleCustomerType: 'https://schema.org/NewCondition',
        description: '7-day free trial, then $39.99/month. Cancel anytime.',
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
      <head>
        {/* Apply the theme class before first paint to avoid a light/dark flash.
            Mirrors ThemeProvider's resolution: stored preference, else system. */}
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){try{var t=localStorage.getItem('ark-theme')||'system';var d=t==='dark'||(t==='system'&&window.matchMedia('(prefers-color-scheme: dark)').matches);document.documentElement.classList.toggle('dark',d);}catch(e){}})();`,
          }}
        />
      </head>
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
