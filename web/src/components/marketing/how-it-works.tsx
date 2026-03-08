'use client';

import { UserPlus, BarChart3, Brain, TrendingUp } from 'lucide-react';
import { FadeIn } from '@/components/marketing/fade-in';

const steps = [
  {
    icon: UserPlus,
    title: 'Start Your Free Trial',
    description: 'Sign up in seconds. Add a card to start your 7-day free trial. Available on iOS.',
    color: 'var(--ark-primary)',
  },
  {
    icon: BarChart3,
    title: 'Build Your Portfolio',
    description: 'Add crypto, stocks, and custom assets. Arkline tracks live prices across 20,000+ instruments.',
    color: 'var(--ark-purple)',
  },
  {
    icon: Brain,
    title: 'Unlock AI + Risk Intelligence',
    description: 'Arkline generates daily briefings, computes your BTC risk score, and surfaces macro shifts — automatically.',
    color: 'var(--ark-cyan)',
  },
  {
    icon: TrendingUp,
    title: 'Invest with Confidence',
    description: 'Use risk-adjusted DCA, sentiment gauges, and macro z-scores to time your moves with data — not emotion.',
    color: 'var(--ark-success)',
  },
];

export function HowItWorks() {
  return (
    <section className="relative py-20 sm:py-28 border-y border-ark-divider">
      <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-white/[0.01] via-white/[0.02] to-white/[0.01]" />
      <div className="relative mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <FadeIn className="text-center">
          <p className="mb-3 text-xs font-medium uppercase tracking-widest text-ark-primary">Get Started with Arkline</p>
          <h2 className="font-[family-name:var(--font-urbanist)] text-3xl font-semibold text-ark-text sm:text-4xl">
            Built to Be Simple. Designed to Be Powerful.
          </h2>
          <p className="mx-auto mt-3 max-w-xl text-ark-text-secondary">
            Tell Arkline what you hold. It tells you what&apos;s coming.
          </p>
        </FadeIn>

        <div className="mt-16 grid gap-10 sm:grid-cols-2 lg:grid-cols-4">
          {steps.map((step, i) => (
            <FadeIn
              key={step.title}
              delay={i * 0.12}
              className="group flex flex-col items-center text-center"
            >
              {/* Number circle */}
              <div
                className="flex h-10 w-10 items-center justify-center rounded-full text-sm font-bold text-white shadow-lg"
                style={{ background: step.color, boxShadow: `0 4px 16px ${step.color}30` }}
              >
                {i + 1}
              </div>

              {/* Connector dash (desktop) */}
              <div className="my-3 h-6 w-px bg-ark-divider" />

              {/* Icon */}
              <div
                className="flex h-14 w-14 items-center justify-center rounded-2xl border border-white/[0.08] transition-transform duration-300 group-hover:scale-105"
                style={{ background: `${step.color}10` }}
              >
                <step.icon className="h-6 w-6" style={{ color: step.color }} />
              </div>

              {/* Text */}
              <h3 className="mt-4 text-sm font-semibold text-ark-text">{step.title}</h3>
              <p className="mt-1.5 text-sm leading-relaxed text-ark-text-secondary">
                {step.description}
              </p>
            </FadeIn>
          ))}
        </div>
      </div>
    </section>
  );
}
