'use client';

import Link from 'next/link';
import Image from 'next/image';
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
  Linkedin,
  Twitter,
  Mail,
} from 'lucide-react';
import { ArklineLogo, Button } from '@/components/ui';
import { AppStoreCTA } from '@/components/marketing/app-store-cta';
import { SpotsCounter } from '@/components/marketing/spots-counter';
import { HeroDashboard } from '@/components/marketing/hero-dashboard';
import { AnimatedBackground } from '@/components/marketing/animated-bg';
import { AnimatedCounter } from '@/components/marketing/animated-counter';
import { BentoFeatures } from '@/components/marketing/bento-features';
import { HowItWorks } from '@/components/marketing/how-it-works';
import { SocialProof } from '@/components/marketing/social-proof';
import { FadeIn } from '@/components/marketing/fade-in';

import { PRICING, PRO_FEATURES, TRIAL_COPY, TRIAL_DAYS } from '@/lib/pricing';

const proFeatures = PRO_FEATURES;

export default function LandingPage() {
  return (
    <div className="overflow-hidden">
      {/* ── Hero ── */}
      <section className="relative pt-32 pb-20 sm:pt-40 sm:pb-28">
        <AnimatedBackground />

        <div className="relative mx-auto max-w-7xl px-4 text-center sm:px-6 lg:px-8">
          {/* Badge — now-live + founding spots urgency */}
          <FadeIn variant="scale" onMount className="mb-10 inline-flex items-center gap-2.5 rounded-full border border-ark-primary/20 bg-ark-primary/5 px-4 py-1.5 transition-colors hover:border-ark-primary/30 hover:bg-ark-primary/8">
            <span className="relative flex h-2 w-2">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-ark-primary opacity-60" />
              <span className="relative inline-flex h-2 w-2 rounded-full bg-ark-primary" />
            </span>
            <span className="text-xs font-medium text-ark-primary">Now live on iOS</span>
            <span className="h-3 w-px bg-ark-primary/30" />
            <SpotsCounter />
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
            Institutional-grade intelligence across crypto and traditional markets. Risk scoring, macro regime detection, and AI briefings. All in one app.
          </FadeIn>

          {/* CTAs */}
          <FadeIn onMount delay={0.25} className="mt-10 flex flex-col items-center gap-4 sm:flex-row sm:gap-3 sm:justify-center">
            <AppStoreCTA />
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

          {/* Secondary web CTA — for non-iOS users */}
          <FadeIn onMount delay={0.32} className="mt-4 text-center">
            <Link
              href="/signup"
              className="text-sm text-ark-text-tertiary underline decoration-ark-divider underline-offset-4 transition-colors hover:text-ark-text"
            >
              No iPhone? Use ArkLine on the web →
            </Link>
          </FadeIn>

          {/* Trust strip */}
          <FadeIn onMount delay={0.4} variant="none" className="mt-8 flex flex-col items-center gap-3">
            <div className="flex items-center gap-4 sm:gap-6">
              <div className="flex items-center gap-1.5 text-xs text-ark-text-tertiary">
                <Shield className="h-3 w-3" />
                iOS 17+
              </div>
              <div className="h-3 w-px bg-ark-divider" />
              <div className="flex items-center gap-1.5 text-xs text-ark-text-tertiary">
                <Shield className="h-3 w-3" />
                {TRIAL_DAYS} days free, cancel anytime
              </div>
              <div className="hidden h-3 w-px bg-ark-divider sm:block" />
              <div className="hidden items-center gap-1.5 text-xs text-ark-text-tertiary sm:flex">
                <Clock className="h-3 w-3" />
                Also available on the web
              </div>
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
              What You Get
            </h2>
            <p className="mx-auto mt-3 max-w-xl text-ark-text-secondary">
              One subscription. Every tool ArkLine has to offer.
            </p>
          </FadeIn>

          <div className="mx-auto mt-14 grid max-w-4xl gap-4 sm:grid-cols-3">
            {[
              {
                icon: Rocket,
                title: 'Instant Access',
                description: 'Download from the App Store and start tracking your portfolio in under a minute.',
              },
              {
                icon: Tag,
                title: 'One Simple Price',
                description: `No tiers, no upsells. ${PRICING.founding.monthly}/month or ${PRICING.founding.annual}/year, after a ${TRIAL_DAYS}-day free trial. Everything included.`,
              },
              {
                icon: MessageSquare,
                title: 'Built by an Investor',
                description: 'Direct line to the founder. Reply to any email and it goes straight to Matt.',
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

          <FadeIn delay={0.3} className="mt-10 flex justify-center">
            <AppStoreCTA />
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
            <AnimatedCounter value="20,000+" label="Assets Tracked" icon={ChartNoAxesCombined} />
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
              Most investors learn about markets from YouTube algorithms and Twitter noise. Sources that profit from attention, not from being right. The people who actually build wealth aren&apos;t following influencers. They&apos;re reading risk models across every asset they hold, tracking macro regimes, and watching sentiment data that most retail investors don&apos;t even know exists.
            </p>
            <p>
              Arkline was built to close that gap. Institutional-grade tools that span crypto, equities, commodities, and macro. Designed for everyday investors who take both sides of the market seriously and are ready to stop guessing.
            </p>
          </FadeIn>
          {/* Founder card */}
          <FadeIn delay={0.2} className="mt-14">
            <div className="mx-auto max-w-xl rounded-2xl border border-white/[0.06] bg-white/[0.02] p-6 sm:p-8">
              <div className="flex flex-col items-center gap-5 sm:flex-row sm:items-start">
                {/* Headshot */}
                <div className="shrink-0">
                  <div className="h-[72px] w-[72px] overflow-hidden rounded-full ring-2 ring-ark-primary/30 sm:h-24 sm:w-24">
                    <Image
                      src="/founder.jpg"
                      alt="Matt Neal, founder of ArkLine"
                      width={96}
                      height={96}
                      className="h-full w-full object-cover"
                    />
                  </div>
                </div>

                {/* Bio */}
                <div className="text-center sm:text-left">
                  <p className="text-sm font-semibold text-ark-text">Matt Neal</p>
                  <p className="mt-0.5 text-xs text-ark-text-tertiary">
                    {/* FOUNDER_CREDIBILITY_LINE */}
                    Investor &amp; project leader. Building ArkLine since 2025.
                  </p>
                  <p className="mt-3 text-sm leading-relaxed text-ark-text-secondary">
                    {/* FOUNDER_BIO */}
                    I spent years looking for a tool that combined risk models, macro data, and positioning signals in one place, without the noise. It didn&apos;t exist, so I built it. ArkLine is the app I wanted as an investor.
                    <span className="ml-1 text-ark-text-tertiary">&mdash; Matt</span>
                  </p>

                  {/* Social links */}
                  <div className="mt-4 flex items-center justify-center gap-3 sm:justify-start">
                    <a
                      href="https://www.linkedin.com/in/bymatthewneal/"
                      target="_blank"
                      rel="noopener noreferrer"
                      aria-label="Matt Neal on LinkedIn"
                      className="flex h-7 w-7 items-center justify-center rounded-md bg-white/[0.04] text-ark-text-tertiary transition-colors hover:bg-white/[0.08] hover:text-ark-text"
                    >
                      <Linkedin className="h-3.5 w-3.5" />
                    </a>
                    <a
                      href="https://x.com/Arklineio"
                      target="_blank"
                      rel="noopener noreferrer"
                      aria-label="ArkLine on X"
                      className="flex h-7 w-7 items-center justify-center rounded-md bg-white/[0.04] text-ark-text-tertiary transition-colors hover:bg-white/[0.08] hover:text-ark-text"
                    >
                      <Twitter className="h-3.5 w-3.5" />
                    </a>
                    <a
                      href="mailto:matt@arkline.io"
                      aria-label="Email Matt"
                      className="flex h-7 w-7 items-center justify-center rounded-md bg-white/[0.04] text-ark-text-tertiary transition-colors hover:bg-white/[0.08] hover:text-ark-text"
                    >
                      <Mail className="h-3.5 w-3.5" />
                    </a>
                  </div>
                </div>
              </div>
            </div>
          </FadeIn>
        </div>
      </section>

      {/* ── Pricing ── */}
      <section className="py-20 sm:py-28" id="pricing">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <FadeIn className="text-center">
            <h2 className="font-[family-name:var(--font-urbanist)] text-3xl font-semibold text-ark-text sm:text-4xl">
              Founding Pricing, Locked In.
            </h2>
            <p className="mx-auto mt-3 max-w-xl text-ark-text-secondary">
              Try it free for {TRIAL_DAYS} days. The first {PRICING.foundingSpots} members then get founding pricing, locked forever as long as they stay subscribed. After that, standard pricing kicks in.
            </p>
          </FadeIn>

          <FadeIn delay={0.1} className="mx-auto mt-14 max-w-2xl">
            <div className="relative overflow-hidden rounded-2xl border border-ark-primary/30 bg-gradient-to-b from-ark-primary/[0.06] to-ark-primary/[0.01] p-8 sm:p-10 shadow-xl shadow-ark-primary/10">
              {/* Corner glow */}
              <div className="pointer-events-none absolute -top-24 -right-24 h-48 w-48 rounded-full bg-ark-primary/10 blur-3xl" />
              {/* Top accent */}
              <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-primary to-transparent" />

              <div className="inline-flex items-center gap-1.5 rounded-full bg-ark-primary/10 px-2.5 py-1 text-[11px] font-semibold text-ark-primary">
                Limited to the first {PRICING.foundingSpots} members
              </div>

              <div className="mt-3 flex flex-col gap-6 sm:flex-row sm:items-start sm:justify-between">
                <div>
                  <h3 className="text-xl font-semibold text-ark-text">Founding Member</h3>
                  <p className="mt-1 text-sm text-ark-text-tertiary">
                    Lock in the lowest price ArkLine will ever charge. Yours forever as long as you stay subscribed.
                  </p>
                </div>
                <div className="shrink-0 text-right">
                  <div className="flex items-baseline gap-1">
                    <span className="font-[family-name:var(--font-urbanist)] text-4xl font-bold text-ark-text">
                      {PRICING.founding.monthly}
                    </span>
                    <span className="text-sm text-ark-text-tertiary">/month</span>
                  </div>
                  <p className="mt-1 text-xs text-ark-text-tertiary">
                    or <span className="font-medium text-ark-text-secondary">{PRICING.founding.annual}/year</span>, save {PRICING.founding.annualSavings}
                  </p>
                  <p className="mt-1 text-xs font-semibold text-ark-success">
                    {TRIAL_COPY.short}
                  </p>
                  <SpotsCounter className="mt-2" />
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

              <div className="mt-8 flex flex-col items-center gap-3 sm:flex-row sm:justify-center">
                <AppStoreCTA />
                <Link
                  href="/signup"
                  className="inline-flex h-[52px] items-center justify-center gap-2 rounded-xl border border-white/[0.14] bg-white/[0.04] px-5 text-sm font-semibold text-ark-text transition-all hover:scale-[1.02] hover:border-white/[0.24] hover:bg-white/[0.08]"
                >
                  Subscribe on the web →
                </Link>
              </div>
              <p className="mt-3 text-center text-[11px] text-ark-text-tertiary">
                {TRIAL_COPY.withPrice}. {TRIAL_COPY.reassurance}
              </p>
              <p className="mt-1 text-center text-[11px] text-ark-text-tertiary">
                iPhone or web. Same features, same price, same free trial.
              </p>
              <p className="mt-4 border-t border-ark-divider pt-4 text-center text-[11px] text-ark-text-tertiary">
                After {PRICING.foundingSpots} founding spots fill, standard pricing rises to <span className="font-semibold text-ark-text-secondary">{PRICING.standard.monthly}/mo</span>.
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
              Risk scoring. Macro intelligence. AI briefings. ArkLine gives you
              the data-driven edge to manage your portfolio with confidence.
            </p>
            <p className="mt-3 text-sm font-medium text-ark-primary">
              Start free for {TRIAL_DAYS} days. Founding members lock in {PRICING.founding.monthly}/mo forever.
            </p>
            <div className="mt-8 flex flex-col items-center gap-3 sm:flex-row sm:justify-center">
              <AppStoreCTA />
              <Link
                href="/signup"
                className="inline-flex h-[52px] items-center justify-center gap-2 rounded-xl border border-white/[0.14] bg-white/[0.04] px-5 text-sm font-semibold text-ark-text transition-all hover:scale-[1.02] hover:border-white/[0.24] hover:bg-white/[0.08]"
              >
                Subscribe on the web →
              </Link>
            </div>

            <div className="mt-6 flex justify-center">
              <SpotsCounter />
            </div>
          </FadeIn>
        </div>
        {/* Bottom gradient fade */}
        <div className="pointer-events-none absolute inset-x-0 bottom-0 h-32 bg-gradient-to-t from-ark-bg to-transparent" />
      </section>
    </div>
  );
}
