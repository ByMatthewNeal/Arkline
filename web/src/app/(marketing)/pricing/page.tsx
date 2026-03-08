'use client';

import Link from 'next/link';
import { Check, HelpCircle, Shield } from 'lucide-react';
import { ArklineLogo, Button } from '@/components/ui';
import { EmailCapture } from '@/components/marketing/email-capture';
import { AnimatedBackground } from '@/components/marketing/animated-bg';
import { FadeIn } from '@/components/marketing/fade-in';

const proFeatures = [
  'Full portfolio tracking across 20,000+ assets',
  '8-factor BTC risk scoring with historical trends',
  'Morning & evening AI briefings',
  'Macro dashboard with regime detection',
  'Smart DCA with risk-adjusted reminders',
  'Market sentiment analysis',
  'Coinbase App Store ranking tracker',
  'Real-time news feed',
  'FedWatch integration',
  'Push notifications & alerts',
];

const faqs = [
  {
    q: 'Can I cancel anytime?',
    a: 'Yes. Cancel from Settings at any time. You keep full access until the end of your billing period.',
  },
  {
    q: 'Is there a free trial?',
    a: 'Arkline Pro comes with a 7-day free trial. Add a card to start — you won\'t be charged until the trial ends.',
  },
  {
    q: 'What payment methods do you accept?',
    a: 'All major credit cards, Apple Pay, and Google Pay through a secure payment processor.',
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
              Join the early access list. Be first when we launch.
            </p>
            <div className="mt-5 flex items-center justify-center gap-4 text-xs text-ark-text-tertiary">
              <div className="flex items-center gap-1">
                <Shield className="h-3 w-3" />
                Join free
              </div>
              <div className="h-3 w-px bg-ark-divider" />
              <div className="flex items-center gap-1">
                <Shield className="h-3 w-3" />
                No spam
              </div>
            </div>
          </FadeIn>
        </div>
      </section>

      {/* Pricing cards */}
      <section className="pt-8 pb-20 sm:pt-12 sm:pb-28">
        <div className="mx-auto grid max-w-5xl gap-8 px-4 sm:px-6 lg:grid-cols-2 lg:px-8">
          {/* Early Investor */}
          <FadeIn onMount delay={0.1}>
            <div className="relative h-full overflow-hidden rounded-2xl border border-ark-primary/30 bg-gradient-to-b from-ark-primary/[0.06] to-ark-primary/[0.01] p-8 shadow-xl shadow-ark-primary/10">
              {/* Corner glow */}
              <div className="pointer-events-none absolute -top-24 -right-24 h-48 w-48 rounded-full bg-ark-primary/10 blur-3xl" />
              {/* Top accent */}
              <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-primary to-transparent" />

              <div className="inline-flex items-center gap-1.5 rounded-full bg-ark-primary/10 px-2.5 py-1 text-[11px] font-semibold text-ark-primary">
                Limited — first 150 members
              </div>

              <h3 className="mt-3 text-lg font-semibold text-ark-text">Early Investor</h3>
              <p className="mt-1 text-sm text-ark-text-secondary">
                Lock in the lowest price. Yours forever as long as you stay subscribed.
              </p>

              <div className="mt-5 flex items-baseline gap-1">
                <span className="font-[family-name:var(--font-urbanist)] text-4xl font-bold text-ark-text">
                  $39.99
                </span>
                <span className="text-sm text-ark-text-tertiary">/month</span>
              </div>
              <p className="mt-1 text-xs text-ark-text-tertiary">
                or <span className="font-medium text-ark-text-secondary">$400/year</span> — save over $79
              </p>

              <ul className="mt-6 space-y-2.5">
                {proFeatures.map((f) => (
                  <li key={f} className="flex items-start gap-2.5 text-sm text-ark-text-secondary">
                    <Check className="mt-0.5 h-4 w-4 shrink-0 text-ark-success" />
                    {f}
                  </li>
                ))}
              </ul>

              <div className="mt-8 [&_form]:flex-col [&_form]:items-stretch [&_input]:w-full [&_button]:w-full">
                <EmailCapture />
              </div>
              <p className="mt-3 text-center text-[11px] text-ark-text-tertiary">
                Join the early access list to claim your spot.
              </p>
            </div>
          </FadeIn>

          {/* Standard */}
          <FadeIn onMount delay={0.2}>
            <div className="relative h-full overflow-hidden rounded-2xl border border-white/[0.06] bg-white/[0.02] p-8">
              <h3 className="mt-8 text-lg font-semibold text-ark-text">Standard</h3>
              <p className="mt-1 text-sm text-ark-text-secondary">
                Full access to Arkline Pro after the early investor window closes.
              </p>

              <div className="mt-5 flex items-baseline gap-1">
                <span className="font-[family-name:var(--font-urbanist)] text-4xl font-bold text-ark-text">
                  $59.99
                </span>
                <span className="text-sm text-ark-text-tertiary">/month</span>
              </div>

              <ul className="mt-6 space-y-2.5">
                {proFeatures.map((f) => (
                  <li key={f} className="flex items-start gap-2.5 text-sm text-ark-text-secondary">
                    <Check className="mt-0.5 h-4 w-4 shrink-0 text-ark-success" />
                    {f}
                  </li>
                ))}
              </ul>

              <div className="mt-8 [&_form]:flex-col [&_form]:items-stretch [&_input]:w-full [&_button]:w-full">
                <EmailCapture />
              </div>
              <p className="mt-3 text-center text-[11px] text-ark-text-tertiary">
                We&apos;ll notify you when Arkline launches. No spam.
              </p>
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
              Risk scoring. Macro intelligence. AI briefings. See why investors choose Arkline.
            </p>
            <div className="mt-8">
              <EmailCapture />
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
