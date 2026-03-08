import type { Metadata } from 'next';
import { Inter, Urbanist } from 'next/font/google';
import { Providers } from './providers';
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
  title: 'Arkline — Market Intelligence, Simplified',
  description:
    'Arkline combines multi-factor risk scoring, macro intelligence, and AI-generated briefings into one platform. Track crypto & stocks, quantify risk, and invest with clarity.',
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
    images: [{ url: '/og-image.png', width: 1200, height: 630 }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Arkline — Your Portfolio. Your Edge.',
    description:
      'Multi-factor risk scoring, macro dashboard, and AI briefings — all in one platform. Start free.',
    images: ['/og-image.png'],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${inter.variable} ${urbanist.variable}`} suppressHydrationWarning>
      <body className="antialiased">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
