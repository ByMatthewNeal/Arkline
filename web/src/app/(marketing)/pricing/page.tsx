'use client';

import Link from 'next/link';
import { ViewContentEvent } from '@/components/analytics/ViewContentEvent';
import { Check, HelpCircle, Shield } from 'lucide-react';
import { ArklineLogo } from '@/components/ui';
import { AppStoreCTA } from '@/components/marketing/app-store-cta';
import { AnimatedBackground } from '@/components/marketing/animated-bg';
import { FadeIn } from '@/components/marketing/fade-in';
import { SpotsCounter } from '@/components/marketing/spots-counter';

const proFeatures = [
  'Portfolio tracking — crypto, stocks, and custom assets (20,000+)',
  'Performance metrics — Sharpe ratio, drawdown, volatility, allocation',
  '8-factor BTC risk scoring with historical trends',
  'Morning & evening AI briefings',
  'Macro dashboard with regime detection (VIX, DXY, US Net Liquidity)',
  'Smart DCA with risk-adjusted reminders',
  'Technical analysis — RSI, MACD, moving averages, BMSB',
  'Sentiment gauges — Fear & Greed, altcoin season, BTC dominance',
  'Derivatives data — open interest, funding rates, liquidations',
  'Economic calendar + FedWatch rate probabilities',
  'Real-time news, Coinbase ranking, and push alerts',
];

const faqs = [
  {
    q: 'Can I cancel anytime?',
    a: 'Yes. Cancel from Settings at any time. You keep full access until the end of your billing period.',
  },
  {
    q: 'How do I subscribe?',
    a: 'Download ArkLine from the App Store and subscribe in-app through Apple, or subscribe on this page through our secure web checkout (Stripe). Both give you the same full access to ArkLine Pro.',
  },
  {
    q: 'What payment methods do you accept?',
    a: 'In-app: Apple ID (any payment method attached — credit/debit, Apple Pay, Apple ID balance). On the web: all major credit cards via Stripe.',
  },
  {
    q: 'What data sources does Arkline use?',
    a: 'Arkline aggregates real-time and historical data from 12+ institutional-grade sources covering on-chain metrics, macro indicators, sentiment, and technical analysis.',
  },
  {
    q: 'How is the risk score calculated?',
    a: 'Arkline\'s proprietary model combines on-chain, technical, sentiment, and macro data into a single 0-1 score with adaptive confidence levels that grow with data.',
  },
  {
    q: 'Is my portfolio data private?',
    a: 'Your data is encrypted in transit and at rest. Portfolio data is never shared with third parties or used for advertising.',
  },
  {
    q: 'Can I import my existing portfolio?',
    a: 'You can manually add any crypto, stock, or custom asset. Arkline tracks live prices across 20,000+ instruments.',
  },
  {
    q: 'Do you support Android?',
    a: 'Arkline is currently iOS only. Android and web app support are on the roadmap.',
  },
  {
    q: 'What makes Arkline different from CoinGecko or CoinStats?',
    a: 'Arkline isn\'t just a portfolio tracker. It combines a proprietary risk model, macro regime detection, AI-generated briefings, and retail sentiment tracking to help you understand where the market is heading — not just where it\'s been.',
  },
  {
    q: 'Is Arkline a trading app?',
    a: 'No. Arkline is built for investors who think long-term. It helps you understand market cycles, macro conditions, and risk levels so you can make informed decisions. You execute trades on your own exchange — Arkline gives you the intelligence behind those decisions.',
  },
  {
    q: 'Can I connect my wallet or exchange?',
    a: 'Portfolios are currently built through manual entry. Add your holdings and Arkline tracks live prices across 20,000+ assets automatically. Wallet and exchange integrations are on the roadmap.',
  },
];

export default function PricingPage() {
  return (
    <div className="overflow-hidden">
      <ViewContentEvent contentName="pricing" />
      {/* Hero */}
      <section className="relative pt-32 pb-16 sm:pt-40 sm:pb-20">
        <AnimatedBackground />
        <div className="relative mx-auto max-w-7xl px-4 text-center sm:px-6 lg:px-8">
          <FadeIn onMount>
            <h1 className="font-[family-name:var(--font-urbanist)] text-3xl font-semibold tracking-tight text-ark-text sm:text-5xl md:text-6xl">
              Transparent Pricing.{' '}
              <span className="bg-gradient-to-r from-ark-primary via-ark-purple to-ark-cyan bg-clip-text text-transparent">
                Real Value.
              </span>
            </h1>
            <p className="mx-auto mt-5 max-w-xl text-lg text-ark-text-secondary">
              One tier. Everything included. Subscribe on iOS or on the web.
            </p>
            <div className="mt-5 flex items-center justify-center gap-4 text-xs text-ark-text-tertiary">
              <div className="flex items-center gap-1">
                <Shield className="h-3 w-3" />
                Cancel anytime
              </div>
              <div className="h-3 w-px bg-ark-divider" />
              <div className="flex items-center gap-1">
                <Shield className="h-3 w-3" />
                Encrypted &amp; private
              </div>
            </div>
          </FadeIn>
        </div>
      </section>

      {/* Pricing cards */}
      <section className="pt-8 pb-20 sm:pt-12 sm:pb-28">
        <div className="mx-auto grid max-w-5xl gap-8 px-4 sm:px-6 lg:grid-cols-2 lg:px-8">
          {/* Founding Member — active tier */}
          <FadeIn onMount delay={0.1}>
            <div className="relative h-full overflow-hidden rounded-2xl border border-ark-primary/30 bg-gradient-to-b from-ark-primary/[0.06] to-ark-primary/[0.01] p-8 shadow-xl shadow-ark-primary/10">
              {/* Corner glow */}
              <div className="pointer-events-none absolute -top-24 -right-24 h-48 w-48 rounded-full bg-ark-primary/10 blur-3xl" />
              {/* Top accent */}
              <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-primary to-transparent" />

              <div className="inline-flex items-center gap-1.5 rounded-full bg-ark-primary/10 px-2.5 py-1 text-[11px] font-semibold text-ark-primary">
                Limited — first 150 members
              </div>

              <h3 className="mt-3 text-lg font-semibold text-ark-text">Founding Member</h3>
              <p className="mt-1 text-sm text-ark-text-secondary">
                Lock in the lowest price ArkLine will ever charge. Yours forever as long as you stay subscribed.
              </p>

              <div className="mt-5 flex items-baseline gap-1">
                <span className="font-[family-name:var(--font-urbanist)] text-4xl font-bold text-ark-text">
                  $39.99
                </span>
                <span className="text-sm text-ark-text-tertiary">/month</span>
              </div>
              <p className="mt-1 text-xs text-ark-text-tertiary">
                or <span className="font-medium text-ark-text-secondary">$399.99/year</span> — save ~17%
              </p>
              <SpotsCounter className="mt-2" />

              <ul className="mt-6 space-y-2.5">
                {proFeatures.map((f) => (
                  <li key={f} className="flex items-start gap-2.5 text-sm text-ark-text-secondary">
                    <Check className="mt-0.5 h-4 w-4 shrink-0 text-ark-success" />
                    {f}
                  </li>
                ))}
              </ul>

              <div className="mt-8 flex justify-center">
                <AppStoreCTA className="w-full justify-center" />
              </div>
              <p className="mt-3 text-center text-[11px] text-ark-text-tertiary">
                Prefer web checkout?{' '}
                <a
                  href="https://buy.stripe.com/14A3cxeeE3O63rP5341Fe03"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="underline decoration-ark-divider hover:text-ark-text"
                >
                  Subscribe via Stripe
                </a>
                .
              </p>
              <p className="mt-1 text-center text-[11px] text-ark-text-disabled">
                Secure. Cancel anytime.
              </p>
            </div>
          </FadeIn>

          {/* Standard — future pricing after founding spots fill */}
          <FadeIn onMount delay={0.2}>
            <div className="relative h-full overflow-hidden rounded-2xl border border-white/[0.06] bg-white/[0.02] p-8">
              <div className="inline-flex items-center gap-1.5 rounded-full bg-white/[0.04] px-2.5 py-1 text-[11px] font-semibold text-ark-text-tertiary">
                After founding spots fill
              </div>

              <h3 className="mt-3 text-lg font-semibold text-ark-text">Standard</h3>
              <p className="mt-1 text-sm text-ark-text-secondary">
                Once the 150 founding spots are gone, ArkLine Pro moves to standard pricing.
              </p>

              <div className="mt-5 flex items-baseline gap-1">
                <span className="font-[family-name:var(--font-urbanist)] text-4xl font-bold text-ark-text">
                  $69.99
                </span>
                <span className="text-sm text-ark-text-tertiary">/month</span>
              </div>
              <p className="mt-1 text-xs text-ark-text-tertiary">
                Same features, no founding discount. Subscribe now to lock in $39.99 for life.
              </p>

              <ul className="mt-6 space-y-2.5">
                {proFeatures.map((f) => (
                  <li key={f} className="flex items-start gap-2.5 text-sm text-ark-text-secondary">
                    <Check className="mt-0.5 h-4 w-4 shrink-0 text-ark-success" />
                    {f}
                  </li>
                ))}
              </ul>

              <div className="mt-8 rounded-xl border border-white/[0.06] bg-white/[0.02] p-4 text-center">
                <p className="text-xs text-ark-text-tertiary">
                  Don&apos;t wait. Founding pricing is grandfathered forever.
                </p>
              </div>
            </div>
          </FadeIn>
        </div>
        <p className="mt-4 text-center text-[11px] text-ark-text-disabled">
          Your portfolio data is encrypted and never shared.
        </p>
      </section>

      {/* FAQ */}
      <section className="relative py-20 sm:py-28">
        <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-divider to-transparent" />
        <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
          <FadeIn className="text-center">
            <h2 className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text sm:text-3xl">
              Frequently Asked Questions
            </h2>
          </FadeIn>

          <div className="mt-12 space-y-4">
            {faqs.map((faq, i) => (
              <FadeIn
                key={i}
                delay={i * 0.05}
                className="rounded-2xl border border-white/[0.06] bg-white/[0.02] p-5"
              >
                <div className="flex items-start gap-3">
                  <HelpCircle className="mt-0.5 h-4 w-4 shrink-0 text-ark-primary" />
                  <div>
                    <h3 className="text-sm font-semibold text-ark-text">{faq.q}</h3>
                    <p className="mt-1.5 text-sm leading-relaxed text-ark-text-secondary">{faq.a}</p>
                  </div>
                </div>
              </FadeIn>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="relative py-20">
        <AnimatedBackground />
        <div className="relative mx-auto max-w-2xl px-4 text-center sm:px-6">
          <FadeIn>
            <ArklineLogo size="lg" showText={false} className="mx-auto mb-6 justify-center" />
            <h2 className="font-[family-name:var(--font-urbanist)] text-3xl font-semibold text-ark-text sm:text-4xl">
              Your edge starts here.
            </h2>
            <p className="mt-4 text-ark-text-secondary">
              Risk scoring. Macro intelligence. AI briefings. See why investors choose ArkLine.
            </p>
            <div className="mt-8 flex justify-center">
              <AppStoreCTA />
            </div>
            <div className="mt-4 flex justify-center">
              <SpotsCounter />
            </div>
          </FadeIn>
        </div>
      </section>

      {/* Disclaimer */}
      <div className="pb-8 text-center text-[11px] text-ark-text-disabled">
        This is not financial advice. Always do your own research.
      </div>
    </div>
  );
}
