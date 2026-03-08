'use client';

import { EmailCapture } from '@/components/marketing/email-capture';
import { FadeIn } from '@/components/marketing/fade-in';

const featureProofs = [
  {
    quote: 'BTC risk at 0.35 — historically favorable accumulation.',
    detail: 'Arkline\'s risk model identified low-risk conditions 34 days ago.',
    color: 'var(--ark-success)',
  },
  {
    quote: 'Coinbase outside the Top 200.',
    detail: 'Retail hasn\'t arrived yet. Smart money moves first.',
    color: 'var(--ark-warning)',
  },
  {
    quote: 'Risk-Off Disinflation regime detected.',
    detail: 'Arkline\'s macro dashboard flagged defensive positioning before markets shifted.',
    color: 'var(--ark-primary)',
  },
];

export function SocialProof() {
  return (
    <section className="relative py-20 sm:py-28">
      {/* Top gradient divider */}
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-divider to-transparent" />

      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        {/* Early access heading */}
        <FadeIn className="text-center">
          <h2 className="font-[family-name:var(--font-urbanist)] text-3xl font-semibold text-ark-text sm:text-4xl">
            Built for Investors Who Want an Edge
          </h2>
          <p className="mx-auto mt-3 max-w-xl text-ark-text-secondary">
            Arkline is coming soon. Be the first to get access.
          </p>
        </FadeIn>

        {/* Feature proof cards */}
        <div className="mx-auto mt-14 grid max-w-4xl gap-4 sm:grid-cols-3">
          {featureProofs.map((proof, i) => (
            <FadeIn
              key={i}
              delay={i * 0.1}
              className="group relative overflow-hidden rounded-2xl border border-white/[0.06] bg-white/[0.02] p-5 transition-all duration-300 hover:border-white/[0.12] hover:bg-white/[0.04]"
            >
              {/* Top accent line */}
              <div
                className="pointer-events-none absolute inset-x-0 top-0 h-px opacity-0 transition-opacity duration-300 group-hover:opacity-100"
                style={{
                  background: `linear-gradient(to right, transparent, ${proof.color}40, transparent)`,
                }}
              />
              <p className="text-sm font-semibold text-ark-text">
                &ldquo;{proof.quote}&rdquo;
              </p>
              <p className="mt-2 text-xs leading-relaxed text-ark-text-tertiary">
                {proof.detail}
              </p>
            </FadeIn>
          ))}
        </div>

        {/* CTA */}
        <FadeIn delay={0.3} className="mt-10 text-center">
          <EmailCapture />
        </FadeIn>

      </div>
    </section>
  );
}
