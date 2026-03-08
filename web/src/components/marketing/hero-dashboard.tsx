'use client';

import { FadeIn } from '@/components/marketing/fade-in';

const phones = [
  { src: '/screenshot-portfolio.webp', alt: 'Portfolio tracking', label: 'Portfolio' },
  { src: '/screenshot-home.webp', alt: 'Home dashboard', label: 'Dashboard' },
  { src: '/screenshot-market.webp', alt: 'Market sentiment', label: 'Market Intelligence' },
];

export function HeroDashboard() {
  return (
    <FadeIn onMount delay={0.5} className="mx-auto mt-16 max-w-4xl px-4">
      <div className="relative flex items-start justify-center gap-4 sm:gap-6 md:gap-8">
        {/* Glow behind center phone */}
        <div className="pointer-events-none absolute left-1/2 top-1/3 h-[60%] w-[40%] -translate-x-1/2 -translate-y-1/2 rounded-full bg-ark-primary/10 blur-[80px]" />
        <div className="pointer-events-none absolute left-1/2 top-1/3 h-[40%] w-[30%] -translate-x-1/2 -translate-y-1/2 rounded-full bg-ark-violet/8 blur-[60px]" />

        {phones.map((phone, i) => {
          const isCenter = i === 1;
          return (
            <FadeIn
              key={phone.src}
              onMount
              delay={0.6 + i * 0.15}
              variant={isCenter ? 'up' : 'up'}
              className={`relative shrink-0 ${
                isCenter
                  ? 'z-20 w-[220px] sm:w-[270px] md:w-[320px]'
                  : 'z-10 hidden w-[200px] sm:block sm:w-[235px] md:w-[275px]'
              }`}
              style={!isCenter ? { marginTop: 24 } : undefined}
            >
              {/* Phone frame with bottom fade mask */}
              <div
                className={`overflow-hidden rounded-t-[28px] rounded-b-[8px] border-x-[3px] border-t-[3px] shadow-2xl ${
                  isCenter
                    ? 'border-white/[0.15] shadow-ark-primary/10'
                    : 'border-white/[0.08] shadow-black/10'
                }`}
                style={{
                  maxHeight: isCenter ? 680 : 600,
                  WebkitMaskImage: 'linear-gradient(to bottom, black 85%, transparent 100%)',
                  maskImage: 'linear-gradient(to bottom, black 85%, transparent 100%)',
                }}
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={phone.src}
                  alt={phone.alt}
                  className="block w-full"
                  loading="eager"
                />
              </div>

              {/* Label */}
              <p className={`mt-4 text-center font-[family-name:var(--font-urbanist)] text-sm font-semibold tracking-wide ${
                isCenter ? 'text-ark-text' : 'text-ark-text-secondary'
              }`}>
                {phone.label}
              </p>
            </FadeIn>
          );
        })}
      </div>
    </FadeIn>
  );
}
