'use client';

import Link from 'next/link';
import { ViewContentEvent } from '@/components/analytics/ViewContentEvent';
import { Check, HelpCircle, Shield } from 'lucide-react';
import { ArklineLogo } from '@/components/ui';
import { AppStoreCTA } from '@/components/marketing/app-store-cta';
import { AnimatedBackground } from '@/components/marketing/animated-bg';
import { FadeIn } from '@/components/marketing/fade-in';

import { PRO_FEATURES, PRICING, TRIAL_DAYS } from '@/lib/pricing';

const proFeatures = PRO_FEATURES;

const faqs = [
  {
    q: 'How much does Arkline cost?',
    a: `${PRICING.standard.monthly}/month, or ${PRICING.standard.annual}/year if you pay annually (about 17% off). One subscription unlocks every tool. No tiers, no add-ons, nothing held back.`,
  },
  {
    q: 'Is there a free trial?',
    a: `Yes. Every new member gets a ${TRIAL_DAYS}-day free trial. You add a card to start it, get the full app, and can cancel anytime during the trial. If you cancel before it ends, you won't be charged.`,
  },
  {
    q: 'What happens after the free trial?',
    a: `When your ${TRIAL_DAYS}-day trial ends, your subscription begins automatically at ${PRICING.standard.monthly}/month (or ${PRICING.standard.annual}/year if you chose annual). You can cancel anytime from your account settings or the App Store.`,
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
    a: 'Arkline is on iOS and the web today. You can use the full web app on any device, including Android, right now. A native Android app is on the roadmap.',
  },
  {
    q: 'What makes Arkline different from other portfolio trackers?',
    a: 'Arkline isn\'t just a portfolio tracker. It spans crypto and traditional markets (stocks, ETFs, commodities) in one place, combined with a proprietary risk model, macro regime detection, AI-generated briefings, and sentiment tracking to help you understand where markets are heading, not just where they\'ve been.',
  },
  {
    q: 'Is Arkline a trading app?',
    a: 'No. Arkline is built for investors who think long-term. It helps you understand market cycles, macro conditions, and risk levels so you can make informed decisions. You execute trades on your own exchange. Arkline gives you the intelligence behind those decisions.',
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
              One plan.{' '}
              <span className="bg-gradient-to-r from-ark-primary via-ark-purple to-ark-cyan bg-clip-text text-transparent">
                Everything.
              </span>
            </h1>
            <p className="mx-auto mt-5 max-w-xl text-lg text-ark-text-secondary">
              One app, every tool included. No tiers, no add-ons. Try it free for {TRIAL_DAYS} days, then {PRICING.standard.monthly}/month. On iOS and the web.
            </p>
            <div className="mt-5 flex items-center justify-center gap-4 text-xs text-ark-text-tertiary">
              <div className="flex items-center gap-1">
                <Shield className="h-3 w-3" />
                {TRIAL_DAYS}-day free trial
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

      {/* Pricing card */}
      <section className="pt-8 pb-20 sm:pt-12 sm:pb-28">
        <div className="mx-auto max-w-2xl px-4 sm:px-6 lg:px-8">
          <FadeIn onMount delay={0.1}>
            <div className="relative h-full overflow-hidden rounded-2xl border border-ark-primary/30 bg-gradient-to-b from-ark-primary/[0.06] to-ark-primary/[0.01] p-8 shadow-xl shadow-ark-primary/10">
              {/* Corner glow */}
              <div className="pointer-events-none absolute -top-24 -right-24 h-48 w-48 rounded-full bg-ark-primary/10 blur-3xl" />
              {/* Top accent */}
              <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-primary to-transparent" />

              <div className="inline-flex items-center gap-1.5 rounded-full bg-ark-primary/10 px-2.5 py-1 text-[11px] font-semibold text-ark-primary">
                {TRIAL_DAYS}-day free trial
              </div>

              <h3 className="mt-3 text-lg font-semibold text-ark-text">Arkline Pro</h3>
              <p className="mt-1 text-sm text-ark-text-secondary">
                The same tools I paid to learn, curated into one app. No tiers, no add-ons, just the full toolkit in one subscription.
              </p>

              <div className="mt-5 flex items-baseline gap-1">
                <span className="font-[family-name:var(--font-urbanist)] text-4xl font-bold text-ark-text">
                  {PRICING.standard.monthly}
                </span>
                <span className="text-sm text-ark-text-tertiary">/month</span>
              </div>
              <p className="mt-1 text-xs font-semibold text-ark-success">
                {TRIAL_DAYS} days free, then {PRICING.standard.monthly}/mo · or {PRICING.standard.annual}/year (save ~17%)
              </p>

              <ul className="mt-6 space-y-2.5">
                {proFeatures.map((f) => (
                  <li key={f} className="flex items-start gap-2.5 text-sm text-ark-text-secondary">
                    <Check className="mt-0.5 h-4 w-4 shrink-0 text-ark-success" />
                    {f}
                  </li>
                ))}
              </ul>

              <div className="mt-8 flex flex-col items-center gap-3">
                <AppStoreCTA className="w-full justify-center" />
                <div className="flex w-full items-center gap-3">
                  <div className="h-px flex-1 bg-ark-divider" />
                  <span className="text-[10px] font-medium uppercase tracking-wider text-ark-text-tertiary">or</span>
                  <div className="h-px flex-1 bg-ark-divider" />
                </div>
                <Link
                  href="/signup"
                  className="inline-flex h-[52px] w-full items-center justify-center gap-2 rounded-xl border border-white/[0.14] bg-white/[0.04] px-5 text-sm font-semibold text-ark-text transition-all hover:scale-[1.02] hover:border-white/[0.24] hover:bg-white/[0.08]"
                >
                  Start your free trial →
                </Link>
              </div>
              <p className="mt-3 text-center text-[11px] text-ark-text-tertiary">
                iPhone or web. Same tools, same access. Cancel anytime during your trial.
              </p>
            </div>
          </FadeIn>
          <p className="mt-4 text-center text-[11px] text-ark-text-disabled">
            Your portfolio data is encrypted and never shared.
          </p>
        </div>
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
              Risk scoring. Macro intelligence. AI briefings. Start with a {TRIAL_DAYS}-day free trial and see why investors choose ArkLine.
            </p>
            <div className="mt-8 flex justify-center">
              <AppStoreCTA />
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
