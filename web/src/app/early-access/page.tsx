'use client';

import { useEffect } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import {
  LayoutDashboard,
  Target,
  BarChart3,
  Sparkles,
  CalendarClock,
  Globe,
} from 'lucide-react';
import { EmailCapture } from '@/components/marketing/email-capture';
import { AnimatedBackground } from '@/components/marketing/animated-bg';
import { FadeIn } from '@/components/marketing/fade-in';

// Meta Pixel ViewContent event
function useViewContent() {
  useEffect(() => {
    if (typeof window !== 'undefined' && typeof window.fbq === 'function') {
      window.fbq('track', 'ViewContent', { content_name: 'early_access_landing' });
    }
  }, []);
}

const pillars = [
  {
    icon: LayoutDashboard,
    title: 'Portfolio Tracking',
    description: 'Crypto, stocks, and custom assets in one view. Live P&L. 20,000+ instruments.',
  },
  {
    icon: Target,
    title: 'Risk Scoring',
    description: '8-factor BTC risk model. 0-1 score, updates in real time.',
  },
  {
    icon: BarChart3,
    title: 'Market Analysis',
    description: 'Sentiment, altcoin season, ETF flows, derivatives. The picture behind the price.',
  },
  {
    icon: Sparkles,
    title: 'AI Briefings',
    description: 'Morning and evening summaries. Personalized to your holdings.',
  },
  {
    icon: CalendarClock,
    title: 'Smart DCA',
    description: 'Risk-adjusted dollar-cost averaging. Buy more when conditions favor it.',
  },
  {
    icon: Globe,
    title: 'Macro Dashboard',
    description: 'VIX, DXY, WTI, US Net Liquidity. Z-scores. Regime detection.',
  },
];

const steps = [
  {
    number: '1',
    title: 'Join the early access list',
    description: 'Email gets you the launch invite. No card required.',
  },
  {
    number: '2',
    title: 'Build your portfolio at launch',
    description: 'Add what you hold. We track the rest.',
  },
  {
    number: '3',
    title: 'Invest with conviction',
    description: 'Daily briefings, real-time risk scores, macro context.',
  },
];

export default function EarlyAccessPage() {
  useViewContent();

  return (
    <div className="min-h-screen bg-ark-bg text-ark-text">
      {/* Minimal header — logo only */}
      <header className="relative z-10 mx-auto flex max-w-7xl items-center px-4 pt-6 sm:px-6 lg:px-8">
        <Link href="/" className="flex items-center gap-2">
          <Image src="/appicon.png" alt="Arkline" width={32} height={32} className="rounded-lg" />
          <span className="font-[family-name:var(--font-urbanist)] text-lg font-semibold text-ark-text">
            Arkline
          </span>
        </Link>
      </header>

      {/* Section 1 — Hero */}
      <section className="relative overflow-hidden pt-20 pb-16 sm:pt-28 sm:pb-24">
        <AnimatedBackground />
        <div className="relative mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="grid items-center gap-12 lg:grid-cols-2 lg:gap-16">
            {/* Left — copy + form */}
            <div className="text-center lg:text-left">
              <FadeIn onMount variant="up">
                <h1 className="font-[family-name:var(--font-urbanist)] text-4xl font-bold leading-tight tracking-tight sm:text-5xl lg:text-6xl">
                  The market rewards the informed.
                </h1>
              </FadeIn>

              <FadeIn onMount variant="up" delay={0.1}>
                <p className="mt-5 text-lg leading-relaxed text-ark-text-secondary sm:text-xl">
                  Multi-factor risk scoring, macro intelligence, and AI briefings — for retail investors who want signal, not screaming.
                </p>
              </FadeIn>

              <FadeIn onMount variant="up" delay={0.2}>
                <div className="mt-8">
                  <EmailCapture size="lg" />
                </div>
              </FadeIn>

              <FadeIn onMount variant="up" delay={0.3}>
                <p className="mt-4 text-sm text-ark-text-tertiary">
                  150 founding spots · Launching June 2026 · No card required
                </p>
              </FadeIn>
            </div>

            {/* Right — product screenshot */}
            <FadeIn onMount variant="up" delay={0.3}>
              <div className="relative mx-auto max-w-sm lg:max-w-none">
                <div className="absolute -inset-4 rounded-3xl bg-ark-primary/10 blur-3xl" />
                <Image
                  src="/screenshot-risk.webp"
                  alt="Arkline Risk Dashboard"
                  width={400}
                  height={800}
                  className="relative rounded-2xl shadow-2xl"
                  priority
                />
              </div>
            </FadeIn>
          </div>
        </div>
      </section>

      {/* Section 2 — Problem statement */}
      <section className="py-20 sm:py-28">
        <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
          <FadeIn>
            <h2 className="font-[family-name:var(--font-urbanist)] text-3xl font-bold tracking-tight sm:text-4xl">
              Most retail investors are guessing.
            </h2>
          </FadeIn>

          <FadeIn delay={0.1}>
            <div className="mt-8 space-y-6 text-lg leading-relaxed text-ark-text-secondary">
              <p>
                Crypto Twitter at 3am. YouTube thumbnails. Discord pumps. Influencers who profit from your attention, not your performance.
              </p>
              <p>
                The people who actually build wealth in this market aren&apos;t watching that. They&apos;re reading risk models, tracking macro regimes, watching sentiment data that most retail investors don&apos;t even know exists.
              </p>
              <p className="text-ark-text font-medium">
                Arkline closes the gap.
              </p>
            </div>
          </FadeIn>
        </div>
      </section>

      {/* Section 3 — Six pillars */}
      <section className="py-20 sm:py-28">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <FadeIn>
            <h2 className="text-center font-[family-name:var(--font-urbanist)] text-3xl font-bold tracking-tight sm:text-4xl">
              Six tools. One platform. No noise.
            </h2>
          </FadeIn>

          <div className="mt-14 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {pillars.map((pillar, i) => (
              <FadeIn key={pillar.title} delay={i * 0.08}>
                <div className="glass rounded-2xl p-6">
                  <pillar.icon className="h-6 w-6 text-ark-primary" />
                  <h3 className="mt-3 font-[family-name:var(--font-urbanist)] text-lg font-semibold">
                    {pillar.title}
                  </h3>
                  <p className="mt-1.5 text-sm leading-relaxed text-ark-text-secondary">
                    {pillar.description}
                  </p>
                </div>
              </FadeIn>
            ))}
          </div>
        </div>
      </section>

      {/* Section 4 — How it works */}
      <section className="py-20 sm:py-28">
        <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
          <FadeIn>
            <h2 className="text-center font-[family-name:var(--font-urbanist)] text-3xl font-bold tracking-tight sm:text-4xl">
              How it works
            </h2>
          </FadeIn>

          <div className="mt-14 grid gap-8 sm:grid-cols-3">
            {steps.map((step, i) => (
              <FadeIn key={step.number} delay={i * 0.1}>
                <div className="text-center sm:text-left">
                  <div className="mx-auto flex h-10 w-10 items-center justify-center rounded-full bg-ark-primary/10 text-lg font-bold text-ark-primary sm:mx-0">
                    {step.number}
                  </div>
                  <h3 className="mt-4 font-[family-name:var(--font-urbanist)] text-lg font-semibold">
                    {step.title}
                  </h3>
                  <p className="mt-2 text-sm leading-relaxed text-ark-text-secondary">
                    {step.description}
                  </p>
                </div>
              </FadeIn>
            ))}
          </div>
        </div>
      </section>

      {/* Section 5 — Founder note */}
      <section className="py-20 sm:py-28">
        <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
          <FadeIn>
            <h2 className="font-[family-name:var(--font-urbanist)] text-3xl font-bold tracking-tight sm:text-4xl">
              Why I built this
            </h2>
          </FadeIn>

          <FadeIn delay={0.1}>
            <div className="mt-8 space-y-6 text-lg leading-relaxed text-ark-text-secondary">
              <p>
                I spent two years looking for a tool that gave retail investors the same kind of intelligence institutions have. Risk models. Macro context. AI briefings.
              </p>
              <p>
                I couldn&apos;t find one. So I built it.
              </p>
              <p>
                Arkline launches in June 2026 with 150 founding members. They lock in $39.99/month — forever — as long as they stay subscribed. After that, standard pricing applies.
              </p>
              <p>
                If you&apos;re tired of investing on takes, get on the list.
              </p>
              <p className="text-ark-text">
                — Matt<br />
                <span className="text-sm text-ark-text-tertiary">Founder, Arkline</span>
              </p>
            </div>
          </FadeIn>

          <FadeIn delay={0.2}>
            <div className="mt-8 rounded-xl border border-ark-primary/20 bg-ark-primary/5 px-5 py-3">
              <p className="text-sm font-medium text-ark-primary">
                150 founding spots · $39.99/month locked forever · June 2026 launch
              </p>
            </div>
          </FadeIn>
        </div>
      </section>

      {/* Section 6 — Final CTA */}
      <section className="relative overflow-hidden py-20 sm:py-28">
        <AnimatedBackground />
        <div className="relative mx-auto max-w-2xl px-4 text-center sm:px-6 lg:px-8">
          <FadeIn>
            <h2 className="font-[family-name:var(--font-urbanist)] text-3xl font-bold tracking-tight sm:text-4xl">
              Get the institutional toolkit.
            </h2>
          </FadeIn>

          <FadeIn delay={0.1}>
            <p className="mt-4 text-lg text-ark-text-secondary">
              150 founding members. Founding pricing locked forever. June 2026.
            </p>
          </FadeIn>

          <FadeIn delay={0.2}>
            <div className="mt-8">
              <EmailCapture size="lg" />
            </div>
          </FadeIn>

          <FadeIn delay={0.3}>
            <p className="mt-4 text-sm text-ark-text-tertiary">
              Free to join · No spam · You&apos;ll be the first to know
            </p>
          </FadeIn>
        </div>
      </section>

      {/* Minimal footer */}
      <footer className="border-t border-ark-divider py-8">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
          <p className="text-xs text-ark-text-tertiary">
            &copy; 2026 Arkline Technologies LLC
          </p>
          <div className="flex gap-6">
            <Link href="/privacy" className="text-xs text-ark-text-tertiary hover:text-ark-text-secondary transition-colors">
              Privacy
            </Link>
            <Link href="/terms" className="text-xs text-ark-text-tertiary hover:text-ark-text-secondary transition-colors">
              Terms
            </Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
