'use client';

import Link from 'next/link';
import {
  Check,
  Shield,
  ChartNoAxesCombined,
  Database,
  Activity,
  Zap,
  Rocket,
  Tag,
  MessageSquare,
  Clock,
} from 'lucide-react';
import { ArklineLogo, Button } from '@/components/ui';
import { EmailCapture } from '@/components/marketing/email-capture';
import { HeroDashboard } from '@/components/marketing/hero-dashboard';
import { AnimatedBackground } from '@/components/marketing/animated-bg';
import { AnimatedCounter } from '@/components/marketing/animated-counter';
import { BentoFeatures } from '@/components/marketing/bento-features';
import { HowItWorks } from '@/components/marketing/how-it-works';
import { SocialProof } from '@/components/marketing/social-proof';
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

export default function LandingPage() {
  return (
    <div className="overflow-hidden">
      {/* ── Hero ── */}
      <section className="relative pt-32 pb-20 sm:pt-40 sm:pb-28">
        <AnimatedBackground />

        <div className="relative mx-auto max-w-7xl px-4 text-center sm:px-6 lg:px-8">
          {/* Badge */}
          <FadeIn variant="scale" onMount className="mb-10 inline-flex items-center gap-2 rounded-full border border-ark-primary/20 bg-ark-primary/5 px-4 py-1.5 transition-colors hover:border-ark-primary/30 hover:bg-ark-primary/8">
            <span className="relative flex h-1.5 w-1.5 shrink-0 self-center">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-ark-primary opacity-75" />
              <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-ark-primary" />
            </span>
            <span className="text-xs font-medium text-ark-primary">Launching Spring 2026</span>
          </FadeIn>

          <FadeIn onMount className="font-[family-name:var(--font-urbanist)] text-4xl font-semibold tracking-tight text-ark-text sm:text-5xl md:text-7xl" as="h1" delay={0.05}>
            The market rewards{' '}
            <br className="hidden sm:block" />
            the{' '}
            <span className="bg-gradient-to-r from-ark-primary via-ark-violet to-ark-cyan bg-clip-text text-transparent">
              informed.
            </span>
          </FadeIn>

          <FadeIn onMount delay={0.12} as="p" className="mx-auto mt-8 max-w-2xl text-lg leading-relaxed text-ark-text-secondary sm:text-xl">
            Be first to access institutional-grade intelligence. Join the early access list.
          </FadeIn>

          {/* CTAs */}
          <FadeIn onMount delay={0.25} className="mt-10 flex flex-col items-center gap-4 sm:flex-row sm:gap-3 sm:justify-center">
            <EmailCapture />
            <Link
              href="/features"
              className="text-sm font-medium text-ark-text-secondary underline underline-offset-4 decoration-ark-divider transition-colors hover:text-ark-text sm:no-underline sm:decoration-0"
            >
              <span className="hidden sm:inline">
                <Button variant="secondary" size="lg" className="min-w-[200px]">
                  See All Features
                </Button>
              </span>
              <span className="sm:hidden">See All Features →</span>
            </Link>
          </FadeIn>

          {/* Trust strip */}
          <FadeIn onMount delay={0.4} variant="none" className="mt-8 flex items-center justify-center gap-4 sm:gap-6">
            <div className="flex items-center gap-1.5 text-xs text-ark-text-tertiary">
              <Shield className="h-3 w-3" />
              Join free
            </div>
            <div className="h-3 w-px bg-ark-divider" />
            <div className="flex items-center gap-1.5 text-xs text-ark-text-tertiary">
              <Shield className="h-3 w-3" />
              No spam
            </div>
            <div className="hidden h-3 w-px bg-ark-divider sm:block" />
            <div className="hidden items-center gap-1.5 text-xs text-ark-text-tertiary sm:flex">
              <Clock className="h-3 w-3" />
              Founding pricing for early members
            </div>
          </FadeIn>

          {/* Dashboard preview */}
          <HeroDashboard />
        </div>
      </section>

      {/* ── What You'll Get ── */}
      <section className="relative py-20 sm:py-28">
        <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-divider to-transparent" />
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <FadeIn className="text-center">
            <h2 className="font-[family-name:var(--font-urbanist)] text-3xl font-semibold text-ark-text sm:text-4xl">
              What You&apos;ll Get
            </h2>
            <p className="mx-auto mt-3 max-w-xl text-ark-text-secondary">
              Sign up for early access and unlock these benefits.
            </p>
          </FadeIn>

          <div className="mx-auto mt-14 grid max-w-4xl gap-4 sm:grid-cols-3">
            {[
              {
                icon: Rocket,
                title: 'Priority Access',
                description: 'Be first in line when Arkline launches on the App Store.',
              },
              {
                icon: Tag,
                title: 'Founding Member Pricing',
                description: 'Early access members lock in the lowest price — forever.',
              },
              {
                icon: MessageSquare,
                title: 'Shape the Product',
                description: 'Get direct input on features and priorities before launch.',
              },
            ].map((benefit, i) => (
              <FadeIn
                key={benefit.title}
                delay={i * 0.1}
                className="group relative overflow-hidden rounded-2xl border border-white/[0.06] bg-white/[0.02] p-5 transition-all duration-300 hover:border-white/[0.12] hover:bg-white/[0.04]"
              >
                <benefit.icon className="mb-3 h-5 w-5 text-ark-primary" />
                <p className="text-sm font-semibold text-ark-text">{benefit.title}</p>
                <p className="mt-2 text-xs leading-relaxed text-ark-text-tertiary">
                  {benefit.description}
                </p>
              </FadeIn>
            ))}
          </div>

          <FadeIn delay={0.3} className="mt-10 text-center">
            <EmailCapture />
          </FadeIn>
        </div>
      </section>

      {/* ── How It Works ── */}
      <HowItWorks />

      {/* ── Bento Features ── */}
      <BentoFeatures />

      {/* ── Stats ── */}
      <section className="relative py-16 sm:py-24">
        <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-ark-primary/[0.03] via-transparent to-ark-violet/[0.03]" />
        {/* Top gradient divider */}
        <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-divider to-transparent" />
        <div className="relative mx-auto max-w-6xl px-4 sm:px-6">
          <FadeIn variant="none" className="mb-10 text-center text-xs font-medium uppercase tracking-widest text-ark-text-tertiary" as="p">
            Arkline by the numbers
          </FadeIn>
          <div className="grid grid-cols-2 gap-10 sm:grid-cols-4">
            <AnimatedCounter value="20,000+" label="Crypto & Macro Assets" icon={ChartNoAxesCombined} />
            <AnimatedCounter value="12" label="Integrated Data Feeds" icon={Database} />
            <AnimatedCounter value="8" label="BTC Risk Factors" icon={Activity} />
            <AnimatedCounter value="24/7" label="Live Market Data" icon={Zap} />
          </div>
        </div>
      </section>

      {/* ── Social Proof ── */}
      <SocialProof />

      {/* ── Why Arkline Exists ── */}
      <section className="relative py-20 sm:py-28">
        <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-divider to-transparent" />
        <div className="relative mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
          <FadeIn className="text-center">
            <h2 className="font-[family-name:var(--font-urbanist)] text-3xl font-semibold text-ark-text sm:text-4xl">
              Why Arkline Exists
            </h2>
          </FadeIn>
          <FadeIn delay={0.1} className="mt-8 space-y-5 text-center text-base leading-relaxed text-ark-text-secondary sm:text-lg">
            <p>
              Too many investors learn crypto from YouTube algorithms and Twitter noise — sources that profit from attention, not from being right. The people who actually build wealth in this market aren&apos;t following influencers. They&apos;re reading risk models, tracking macro regimes, and watching sentiment data that most retail investors don&apos;t even know exists.
            </p>
            <p>
              Arkline was built to close that gap. Institutional-grade tools — risk scoring, macro intelligence, AI briefings — designed for everyday investors who are ready to stop guessing and start positioning with real data.
            </p>
          </FadeIn>
          <FadeIn delay={0.2} as="p" className="mt-10 text-center text-sm italic text-ark-text-tertiary">
            Built by an investor who spent years looking for this tool — then built it.
          </FadeIn>
        </div>
      </section>

      {/* ── Pricing ── */}
      <section className="py-20 sm:py-28" id="pricing">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <FadeIn className="text-center">
            <h2 className="font-[family-name:var(--font-urbanist)] text-3xl font-semibold text-ark-text sm:text-4xl">
              Transparent Pricing, Real Value
            </h2>
            <p className="mx-auto mt-3 max-w-xl text-ark-text-secondary">
              Start with a 7-day free trial. Full access to everything — risk models, AI briefings, macro intelligence, and more.
            </p>
          </FadeIn>

          <FadeIn delay={0.1} className="mx-auto mt-14 max-w-2xl">
            <div className="relative overflow-hidden rounded-2xl border border-ark-primary/30 bg-gradient-to-b from-ark-primary/[0.06] to-ark-primary/[0.01] p-8 sm:p-10 shadow-xl shadow-ark-primary/10">
              {/* Corner glow */}
              <div className="pointer-events-none absolute -top-24 -right-24 h-48 w-48 rounded-full bg-ark-primary/10 blur-3xl" />
              {/* Top accent */}
              <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-primary to-transparent" />

              <div className="inline-flex items-center gap-1.5 rounded-full bg-ark-primary/10 px-2.5 py-1 text-[11px] font-semibold text-ark-primary">
                Limited — first 150 members
              </div>

              <div className="mt-3 flex flex-col gap-6 sm:flex-row sm:items-start sm:justify-between">
                <div>
                  <h3 className="text-xl font-semibold text-ark-text">Early Investor</h3>
                  <p className="mt-1 text-sm text-ark-text-tertiary">
                    Lock in the lowest price. Yours forever as long as you stay subscribed.
                  </p>
                </div>
                <div className="shrink-0 text-right">
                  <div className="flex items-baseline gap-1">
                    <span className="font-[family-name:var(--font-urbanist)] text-4xl font-bold text-ark-text">
                      $39.99
                    </span>
                    <span className="text-sm text-ark-text-tertiary">/month</span>
                  </div>
                  <p className="mt-1 text-xs text-ark-text-tertiary">
                    or <span className="font-medium text-ark-text-secondary">$400/year</span> — save over $79
                  </p>
                </div>
              </div>

              <ul className="mt-8 grid gap-x-6 gap-y-2.5 sm:grid-cols-2">
                {proFeatures.map((f) => (
                  <li key={f} className="flex items-start gap-2 text-sm text-ark-text-secondary">
                    <Check className="mt-0.5 h-4 w-4 shrink-0 text-ark-success" />
                    {f}
                  </li>
                ))}
              </ul>

              <div className="mt-8">
                <EmailCapture />
              </div>
              <p className="mt-3 text-center text-[11px] text-ark-text-tertiary">
                Early access members lock in this price forever. No spam.
              </p>
              <p className="mt-2 text-center text-[11px] text-ark-text-disabled">
                Your portfolio data is encrypted and never shared.
              </p>
            </div>
          </FadeIn>
        </div>
      </section>

      {/* ── CTA ── */}
      <section className="relative py-24 sm:py-32">
        <AnimatedBackground />
        {/* Top gradient fade */}
        <div className="pointer-events-none absolute inset-x-0 top-0 h-32 bg-gradient-to-b from-ark-bg to-transparent" />
        <div className="relative mx-auto max-w-3xl px-4 text-center sm:px-6">
          <FadeIn>
            <ArklineLogo size="xl" showText={false} className="mx-auto mb-8 justify-center" />
            <h2 className="font-[family-name:var(--font-urbanist)] text-3xl font-semibold text-ark-text sm:text-4xl md:text-5xl">
              Invest with{' '}
              <span className="bg-gradient-to-r from-ark-primary to-ark-violet bg-clip-text text-transparent">
                conviction.
              </span>
            </h2>
            <p className="mt-5 text-lg leading-relaxed text-ark-text-secondary">
              Risk scoring. Macro intelligence. AI briefings. Arkline gives you
              the data-driven edge to manage your portfolio with confidence.
            </p>
            <p className="mt-3 text-sm font-medium text-ark-primary">
              Early members lock in founding pricing — forever.
            </p>
            <div className="mt-8">
              <EmailCapture />
            </div>

            {/* Platform availability */}
            <div className="mt-10 flex items-center justify-center gap-1.5 text-xs text-ark-text-disabled">
              Launching Spring 2026 on iOS
            </div>
          </FadeIn>
        </div>
        {/* Bottom gradient fade */}
        <div className="pointer-events-none absolute inset-x-0 bottom-0 h-32 bg-gradient-to-t from-ark-bg to-transparent" />
      </section>
    </div>
  );
}
