'use client';

import Image from 'next/image';
import {
  BarChart3,
  Shield,
  TrendingUp,
  Brain,
  Bell,
  Globe,
} from 'lucide-react';
import { FadeIn } from '@/components/marketing/fade-in';

const iconColors: Record<string, string> = {
  'Portfolio Tracking': 'var(--ark-primary)',
  'Risk Scoring': 'var(--ark-warning)',
  'Market Analysis': 'var(--ark-success)',
  'AI Briefings': 'var(--ark-purple)',
  'Smart DCA': 'var(--ark-cyan)',
  'Macro Dashboard': 'var(--ark-error)',
};

const bentoItems = [
  {
    icon: BarChart3,
    title: 'Portfolio Tracking',
    description: 'Track crypto, stocks, and custom assets with live pricing, P&L breakdown, and allocation charts — all in one view.',
    span: 'sm:col-span-2',
    screenshot: '/bento-portfolio.webp',
  },
  {
    icon: Shield,
    title: 'Risk Scoring',
    description: 'Arkline\'s proprietary risk model combines on-chain, technical, sentiment, and macro data into a single 0–1 score. Know exactly where you are in the cycle — at a glance.',
    span: '',
    screenshot: '/bento-risk.webp',
  },
  {
    icon: TrendingUp,
    title: 'Market Analysis',
    description: 'Live sentiment gauges, altcoin season index, ETF flows, derivatives data, and liquidation tracking. The full picture, not just prices.',
    span: '',
    screenshot: '/bento-market.webp',
  },
  {
    icon: Brain,
    title: 'AI Briefings',
    description: 'Morning and evening market summaries powered by AI — distilling prices, sentiment, macro shifts, and portfolio impact into actionable insights. One read. Full clarity.',
    span: 'sm:col-span-2',
    screenshot: '/bento-briefings.webp',
  },
  {
    icon: Bell,
    title: 'Smart DCA',
    description: 'Time-based or risk-adjusted DCA reminders. Buy more when Arkline\'s risk score drops, less when it spikes. Remove the emotion from your strategy.',
    span: '',
    screenshot: '/bento-dca.webp',
  },
  {
    icon: Globe,
    title: 'Macro Dashboard',
    description: 'VIX, DXY, WTI Crude, and US Net Liquidity — with sparklines, z-scores, and regime detection to spot macro shifts early. See the backdrop before it hits crypto.',
    span: '',
    screenshot: '/bento-macro.webp',
  },
];

export function BentoFeatures() {
  return (
    <section className="py-20 sm:py-28" id="features">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <FadeIn className="text-center">
          <p className="mb-3 text-xs font-medium uppercase tracking-widest text-ark-primary">What Arkline Does</p>
          <h2 className="font-[family-name:var(--font-urbanist)] text-3xl font-semibold text-ark-text sm:text-4xl">
            One Platform. Complete Market Intelligence.
          </h2>
          <p className="mx-auto mt-3 max-w-xl text-ark-text-secondary">
            From risk scoring to AI briefings, Arkline puts institutional-level tools in your hands.
          </p>
        </FadeIn>

        <div className="mt-14 grid gap-6 sm:grid-cols-2 lg:grid-cols-3 lg:gap-8">
          {bentoItems.map((item, i) => {
            const accentColor = iconColors[item.title] ?? '#3B82F6';
            return (
              <FadeIn
                key={item.title}
                delay={i * 0.08}
                className={`group relative overflow-hidden rounded-2xl border border-white/[0.06] bg-white/[0.02] transition-all duration-300 hover:border-white/[0.12] hover:bg-white/[0.04] ${item.span}`}
              >
                {/* Hover glow */}
                <div
                  className="pointer-events-none absolute -inset-px rounded-2xl opacity-0 transition-opacity duration-300 group-hover:opacity-100"
                  style={{
                    background: `radial-gradient(400px circle at 50% 0%, ${accentColor}10, transparent 60%)`,
                  }}
                />

                {/* Top accent line on hover */}
                <div
                  className="pointer-events-none absolute inset-x-0 top-0 h-px opacity-0 transition-opacity duration-300 group-hover:opacity-100"
                  style={{
                    background: `linear-gradient(to right, transparent, ${accentColor}40, transparent)`,
                  }}
                />

                {/* Text content */}
                <div className="relative p-6 pb-0">
                  <div className="mb-3 flex items-center gap-3">
                    <div
                      className="flex h-9 w-9 items-center justify-center rounded-xl"
                      style={{ background: `${accentColor}15` }}
                    >
                      <item.icon className="h-4.5 w-4.5" style={{ color: accentColor }} />
                    </div>
                    <h3 className="text-sm font-semibold text-ark-text">{item.title}</h3>
                  </div>
                  <p className="text-sm text-ark-text-secondary leading-relaxed">{item.description}</p>
                </div>

                {/* Phone screenshot */}
                <div className="relative mt-5 flex justify-center">
                  <div
                    className="relative w-[85%] max-w-[380px] overflow-hidden rounded-t-[24px] border-x-[3px] border-t-[3px] border-white/[0.08] shadow-2xl shadow-black/40"
                    style={{
                      maxHeight: 520,
                      WebkitMaskImage: 'linear-gradient(to bottom, black 75%, transparent 100%)',
                      maskImage: 'linear-gradient(to bottom, black 75%, transparent 100%)',
                    }}
                  >
                    <Image
                      src={item.screenshot}
                      alt={item.title}
                      width={390}
                      height={844}
                      className="w-full"
                    />
                  </div>
                </div>
              </FadeIn>
            );
          })}
        </div>
      </div>
    </section>
  );
}
