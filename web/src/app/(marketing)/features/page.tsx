'use client';

import Link from 'next/link';
import {
  BarChart3,
  Shield,
  TrendingUp,
  Brain,
  Bell,
  Globe,
  PieChart,
  Activity,
  Newspaper,
  Calculator,
  LineChart,
  Gauge,
} from 'lucide-react';
import { ArklineLogo } from '@/components/ui';
import { EmailCapture } from '@/components/marketing/email-capture';
import { AnimatedBackground } from '@/components/marketing/animated-bg';
import { FadeIn } from '@/components/marketing/fade-in';

/* ── Small features grid ── */
const gridFeatures = [
  { icon: BarChart3, title: 'Multi-Asset Portfolios', description: 'Crypto, stocks, and custom assets with live pricing.' },
  { icon: PieChart, title: 'Allocation Analysis', description: 'Visualize allocation and track target drift.' },
  { icon: Calculator, title: 'Performance Metrics', description: 'Sharpe ratio, drawdown, volatility — in real time.' },
  { icon: Bell, title: 'Smart DCA', description: 'Risk-adjusted reminders. Buy more when risk is low.' },
  { icon: Newspaper, title: 'News Aggregation', description: 'AI-summarized headlines. Signal without the noise.' },
  { icon: Activity, title: 'Economic Calendar', description: 'FOMC, CPI, jobs reports — never miss a catalyst.' },
  { icon: TrendingUp, title: 'Derivatives Data', description: 'OI, funding rates, liquidations from Coinglass.' },
  { icon: Globe, title: 'FedWatch', description: 'CME rate probabilities — directly in the app.' },
  { icon: LineChart, title: 'Coinbase Ranking', description: 'Track the Coinbase App Store rank daily.' },
  { icon: Shield, title: 'Regime Detection', description: 'Auto-classified macro regimes with shift alerts.' },
  { icon: Gauge, title: 'Sentiment Gauges', description: 'Fear & Greed, BTC dominance, altcoin season.' },
  { icon: Brain, title: 'AI Briefings', description: 'Morning and evening summaries. One read. Full clarity.' },
];

function PhoneFrame({ src, alt, className = '' }: { src: string; alt: string; className?: string }) {
  return (
    <div
      className={`overflow-hidden rounded-[24px] border-[2px] border-white/[0.1] shadow-2xl shadow-black/20 ${className}`}
      style={{
        WebkitMaskImage: 'linear-gradient(to bottom, black 88%, transparent 100%)',
        maskImage: 'linear-gradient(to bottom, black 88%, transparent 100%)',
      }}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={src} alt={alt} className="block w-full" loading="lazy" />
    </div>
  );
}

export default function FeaturesPage() {
  return (
    <div className="overflow-hidden">
      {/* Hero */}
      <section className="relative pt-32 pb-16 sm:pt-40 sm:pb-20">
        <AnimatedBackground />
        <div className="relative mx-auto max-w-7xl px-4 text-center sm:px-6 lg:px-8">
          <FadeIn onMount>
            <p className="mb-3 text-xs font-medium uppercase tracking-widest text-ark-primary">Arkline Platform</p>
            <h1 className="font-[family-name:var(--font-urbanist)] text-4xl font-semibold tracking-tight text-ark-text sm:text-5xl md:text-6xl">
              Every Tool.{' '}
              <span className="bg-gradient-to-r from-ark-primary via-ark-purple to-ark-cyan bg-clip-text text-transparent">
                One Platform.
              </span>
            </h1>
            <p className="mx-auto mt-5 max-w-2xl text-lg text-ark-text-secondary">
              Risk scoring, macro intelligence, AI briefings, and portfolio tracking — Arkline puts the full picture at your fingertips.
            </p>
          </FadeIn>
        </div>
      </section>

      {/* ── Bento Feature Cards ── */}
      <section className="mx-auto max-w-7xl px-4 pb-20 sm:px-6 lg:px-8">
        <div className="flex flex-col gap-4">

          {/* Card 1: Risk Scoring — full width */}
          <FadeIn
            className="group relative overflow-hidden rounded-3xl border border-white/[0.06] bg-gradient-to-br from-ark-warning/[0.06] via-white/[0.02] to-transparent p-8 sm:p-10"
          >
            <div className="pointer-events-none absolute -top-32 -right-32 h-64 w-64 rounded-full bg-ark-warning/8 blur-[80px]" />
            <div className="relative flex flex-col items-center gap-8 lg:flex-row lg:gap-12">
              <div className="flex-1">
                <span className="inline-block rounded-full bg-ark-warning/15 px-3 py-1 text-xs font-medium text-ark-warning">
                  Risk Scoring
                </span>
                <h2 className="mt-4 font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text sm:text-3xl lg:text-4xl">
                  Know where you are in the cycle.
                </h2>
                <p className="mt-4 max-w-lg text-base leading-relaxed text-ark-text-secondary">
                  Arkline&apos;s proprietary risk model combines on-chain, technical, sentiment, and macro data into a single 0–1 score — with adaptive confidence levels that grow with data.
                </p>
              </div>
              <PhoneFrame
                src="/screenshot-risk.webp"
                alt="BTC Risk Level"
                className="w-[255px] shrink-0 sm:w-[290px]"
              />
            </div>
          </FadeIn>

          {/* Card 2 + 3: Macro + Market Intelligence — two columns */}
          <div className="grid gap-4 md:grid-cols-2">
            <FadeIn
              className="group relative overflow-hidden rounded-3xl border border-white/[0.06] bg-gradient-to-br from-ark-primary/[0.06] via-white/[0.02] to-transparent p-8"
            >
              <div className="pointer-events-none absolute -top-24 -left-24 h-48 w-48 rounded-full bg-ark-primary/8 blur-[60px]" />
              <div className="relative">
                <span className="inline-block rounded-full bg-ark-primary/15 px-3 py-1 text-xs font-medium text-ark-primary">
                  Macro Dashboard
                </span>
                <h3 className="mt-4 font-[family-name:var(--font-urbanist)] text-xl font-semibold text-ark-text sm:text-2xl">
                  See the backdrop before it hits crypto.
                </h3>
                <p className="mt-3 text-sm leading-relaxed text-ark-text-secondary">
                  VIX, DXY, WTI Crude, and US Net Liquidity with sparklines, z-scores, and regime detection — updated in real time.
                </p>
                <div className="mt-6 flex justify-center">
                  <PhoneFrame
                    src="/screenshot-macro.webp"
                    alt="Macro Dashboard"
                    className="w-[230px] sm:w-[255px]"
                  />
                </div>
              </div>
            </FadeIn>

            <FadeIn
              delay={0.1}
              className="group relative overflow-hidden rounded-3xl border border-white/[0.06] bg-gradient-to-br from-ark-success/[0.06] via-white/[0.02] to-transparent p-8"
            >
              <div className="pointer-events-none absolute -top-24 -right-24 h-48 w-48 rounded-full bg-ark-success/8 blur-[60px]" />
              <div className="relative">
                <span className="inline-block rounded-full bg-ark-success/15 px-3 py-1 text-xs font-medium text-ark-success">
                  Market Intelligence
                </span>
                <h3 className="mt-4 font-[family-name:var(--font-urbanist)] text-xl font-semibold text-ark-text sm:text-2xl">
                  The full picture, not just prices.
                </h3>
                <p className="mt-3 text-sm leading-relaxed text-ark-text-secondary">
                  Sentiment gauges, altcoin season detection, BTC dominance, ETF flows, derivatives data, and Coinbase ranking — in one view.
                </p>
                <div className="mt-6 flex justify-center">
                  <PhoneFrame
                    src="/screenshot-overview.webp"
                    alt="Market Overview"
                    className="w-[230px] sm:w-[255px]"
                  />
                </div>
              </div>
            </FadeIn>
          </div>

          {/* Card 4: Technical Analysis — full width, reversed */}
          <FadeIn
            className="group relative overflow-hidden rounded-3xl border border-white/[0.06] bg-gradient-to-br from-ark-purple/[0.06] via-white/[0.02] to-transparent p-8 sm:p-10"
          >
            <div className="pointer-events-none absolute -bottom-32 -left-32 h-64 w-64 rounded-full bg-ark-purple/8 blur-[80px]" />
            <div className="relative flex flex-col items-center gap-8 lg:flex-row-reverse lg:gap-12">
              <div className="flex-1">
                <span className="inline-block rounded-full bg-ark-purple/15 px-3 py-1 text-xs font-medium text-ark-purple">
                  Technical Analysis
                </span>
                <h2 className="mt-4 font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text sm:text-3xl lg:text-4xl">
                  Identify key levels and momentum shifts.
                </h2>
                <p className="mt-4 max-w-lg text-base leading-relaxed text-ark-text-secondary">
                  Trend and valuation scores, RSI, MACD, moving averages, and Bull Market Support Bands — with investment insights generated for every asset.
                </p>
              </div>
              <PhoneFrame
                src="/screenshot-analysis.webp"
                alt="ETH Technical Analysis"
                className="w-[255px] shrink-0 sm:w-[290px]"
              />
            </div>
          </FadeIn>

          {/* Card 5 + 6: Portfolio + AI — two columns */}
          <div className="grid gap-4 md:grid-cols-2">
            <FadeIn
              className="group relative overflow-hidden rounded-3xl border border-white/[0.06] bg-gradient-to-br from-ark-cyan/[0.06] via-white/[0.02] to-transparent p-8"
            >
              <div className="pointer-events-none absolute -bottom-24 -right-24 h-48 w-48 rounded-full bg-ark-cyan/8 blur-[60px]" />
              <div className="relative">
                <span className="inline-block rounded-full bg-ark-cyan/15 px-3 py-1 text-xs font-medium text-ark-cyan">
                  Portfolio Tracking
                </span>
                <h3 className="mt-4 font-[family-name:var(--font-urbanist)] text-xl font-semibold text-ark-text sm:text-2xl">
                  Your portfolio. Complete clarity.
                </h3>
                <p className="mt-3 text-sm leading-relaxed text-ark-text-secondary">
                  Track crypto, stocks, and custom assets with live pricing, P&amp;L breakdown, performance metrics, and allocation charts — all in one view.
                </p>
                <div className="mt-6 flex justify-center">
                  <PhoneFrame
                    src="/screenshot-portfolio.webp"
                    alt="Portfolio tracking"
                    className="w-[230px] sm:w-[255px]"
                  />
                </div>
              </div>
            </FadeIn>

            <FadeIn
              delay={0.1}
              className="group relative overflow-hidden rounded-3xl border border-white/[0.06] bg-gradient-to-br from-ark-violet/[0.06] via-white/[0.02] to-transparent p-8"
            >
              <div className="pointer-events-none absolute -bottom-24 -left-24 h-48 w-48 rounded-full bg-ark-violet/8 blur-[60px]" />
              <div className="relative">
                <span className="inline-block rounded-full bg-ark-violet/15 px-3 py-1 text-xs font-medium text-ark-violet">
                  Dashboard
                </span>
                <h3 className="mt-4 font-[family-name:var(--font-urbanist)] text-xl font-semibold text-ark-text sm:text-2xl">
                  Everything at a glance.
                </h3>
                <p className="mt-3 text-sm leading-relaxed text-ark-text-secondary">
                  Prices, risk scores, macro indicators, DCA reminders, and AI briefings — your complete daily command center.
                </p>
                <div className="mt-6 flex justify-center">
                  <PhoneFrame
                    src="/screenshot-home.webp"
                    alt="Home dashboard"
                    className="w-[230px] sm:w-[255px]"
                  />
                </div>
              </div>
            </FadeIn>
          </div>
        </div>
      </section>

      {/* ── All Features Grid ── */}
      <section className="relative py-20 sm:py-28">
        <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-divider to-transparent" />

        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <FadeIn className="text-center">
            <p className="mb-3 text-xs font-medium uppercase tracking-widest text-ark-primary">Everything Included</p>
            <h2 className="font-[family-name:var(--font-urbanist)] text-3xl font-semibold text-ark-text sm:text-4xl">
              Built for Serious Investors
            </h2>
            <p className="mx-auto mt-3 max-w-xl text-ark-text-secondary">
              Every feature in Arkline Pro. No add-ons. No tiers. One price.
            </p>
          </FadeIn>

          <div className="mt-14 grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            {gridFeatures.map((f, i) => (
              <FadeIn
                key={f.title}
                delay={(i % 4) * 0.04}
                className="group rounded-2xl border border-white/[0.06] bg-white/[0.02] p-4 transition-all duration-300 hover:border-ark-primary/20 hover:bg-white/[0.04]"
              >
                <div className="mb-2.5 flex h-8 w-8 items-center justify-center rounded-lg bg-ark-primary/10 transition-colors group-hover:bg-ark-primary/15">
                  <f.icon className="h-4 w-4 text-ark-primary" />
                </div>
                <h3 className="text-sm font-semibold text-ark-text">{f.title}</h3>
                <p className="mt-1 text-xs leading-relaxed text-ark-text-secondary">{f.description}</p>
              </FadeIn>
            ))}
          </div>
        </div>
      </section>

      {/* ── CTA ── */}
      <section className="relative py-24">
        <AnimatedBackground />
        <div className="pointer-events-none absolute inset-x-0 top-0 h-32 bg-gradient-to-b from-ark-bg to-transparent" />
        <div className="relative mx-auto max-w-2xl px-4 text-center sm:px-6">
          <FadeIn>
            <ArklineLogo size="xl" showText={false} className="mx-auto mb-6 justify-center" />
            <h2 className="font-[family-name:var(--font-urbanist)] text-3xl font-semibold text-ark-text sm:text-4xl">
              See Arkline in action.
            </h2>
            <p className="mt-4 text-ark-text-secondary">
              Start your free trial — full access to every feature for 7 days.
            </p>
            <div className="mt-8">
              <EmailCapture />
            </div>
            <div className="mt-6 text-xs text-ark-text-disabled">
              Coming Soon to iOS
            </div>
          </FadeIn>
        </div>
      </section>
    </div>
  );
}
