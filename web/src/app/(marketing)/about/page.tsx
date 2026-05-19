import Image from 'next/image';
import Link from 'next/link';
import { Linkedin, Twitter, Mail } from 'lucide-react';
import { EmailCapture } from '@/components/marketing/email-capture';
import { FadeIn } from '@/components/marketing/fade-in';

export const metadata = {
  title: 'About ArkLine — Built by Matt Neal',
  description: 'Why I\'m building ArkLine, and how to reach me.',
  robots: { index: true, follow: true },
};

export default function AboutPage() {
  return (
    <>
      {/* ── Hero ── */}
      <section className="relative pt-28 pb-16 sm:pt-36 sm:pb-20">
        <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
          <FadeIn className="flex flex-col items-center text-center">
            <div className="h-28 w-28 overflow-hidden rounded-full ring-2 ring-ark-primary/30 sm:h-36 sm:w-36">
              <Image
                src="/founder.jpg"
                alt="Matt Neal, founder of ArkLine"
                width={144}
                height={144}
                priority
                className="h-full w-full object-cover"
              />
            </div>
            <h1 className="mt-6 font-[family-name:var(--font-urbanist)] text-3xl font-semibold text-ark-text sm:text-4xl">
              Matt Neal
            </h1>
            <p className="mt-3 text-lg leading-relaxed text-ark-text-secondary sm:text-xl">
              {/* FOUNDER_HERO_LINE */}
              I&apos;m building ArkLine so retail investors don&apos;t have to fly blind.
            </p>
          </FadeIn>
        </div>
      </section>

      {/* ── Why I'm building this ── */}
      <section className="relative py-16 sm:py-20">
        <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-divider to-transparent" />
        <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
          <FadeIn>
            <h2 className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text sm:text-3xl">
              Why I&apos;m building this
            </h2>
          </FadeIn>
          <FadeIn delay={0.1} className="mt-8 space-y-5 text-base leading-relaxed text-ark-text-secondary sm:text-lg">
            {/* FOUNDER_WHY_PARAGRAPHS */}
            <p>
              I&apos;ve been investing in crypto and traditional markets for years. The tools I kept coming back to were either built for institutions (Bloomberg terminal — $24k/year) or built for day traders chasing 5-minute candles. Nothing sat in the middle: serious, data-driven, but designed for people with jobs and portfolios, not full-time chart watchers.
            </p>
            <p>
              What frustrated me most was how scattered the data was. Risk models on one site, macro data on another, sentiment on a third, positioning signals on a Telegram channel. I was spending more time aggregating information than acting on it.
            </p>
            <p>
              ArkLine is the tool I wanted. One app that combines regression risk scoring, macro regime analysis, AI-generated briefings, and systematic trade signals — without the noise, the hype, or the $500/month price tag.
            </p>
            <p>
              I&apos;m building this as a solo founder because I think the best investment tools come from people who actually invest. Every feature in ArkLine exists because I needed it myself.
            </p>
          </FadeIn>
        </div>
      </section>

      {/* ── Background ── */}
      <section className="relative py-16 sm:py-20">
        <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-divider to-transparent" />
        <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
          <FadeIn>
            <h2 className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text sm:text-3xl">
              Background
            </h2>
          </FadeIn>
          <FadeIn delay={0.1} className="mt-8 text-base leading-relaxed text-ark-text-secondary sm:text-lg">
            {/* FOUNDER_BACKGROUND_INTRO */}
            <p>
              I&apos;m an investor and project leader based in New York. I&apos;ve spent my career driving complex initiatives across global teams — and investing in crypto and traditional markets since 2017.
            </p>
          </FadeIn>
          <FadeIn delay={0.15} className="mt-6">
            <ul className="space-y-3 text-base text-ark-text-secondary sm:text-lg">
              {/* FOUNDER_BACKGROUND_BULLETS */}
              <li className="flex items-start gap-3">
                <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-ark-primary/60" />
                <span>6 years as a global strategic project manager</span>
              </li>
              <li className="flex items-start gap-3">
                <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-ark-primary/60" />
                <span>Active crypto and equities investor since 2017</span>
              </li>
              <li className="flex items-start gap-3">
                <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-ark-primary/60" />
                <span>Helped sell a crypto launchpad to a hedge fund in 2023</span>
              </li>
              <li className="flex items-start gap-3">
                <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-ark-primary/60" />
                <span>Arkline Technologies LLC — Wyoming-formed, New York-operated</span>
              </li>
            </ul>
          </FadeIn>
        </div>
      </section>

      {/* ── How to reach me ── */}
      <section className="relative py-16 sm:py-20">
        <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-divider to-transparent" />
        <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
          <FadeIn>
            <h2 className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text sm:text-3xl">
              How to reach me
            </h2>
          </FadeIn>
          <FadeIn delay={0.1} className="mt-8 space-y-4">
            <a
              href="mailto:matt@arkline.io"
              className="flex items-center gap-3 text-base text-ark-text-secondary transition-colors hover:text-ark-text sm:text-lg"
            >
              <Mail className="h-5 w-5 shrink-0 text-ark-primary/60" />
              matt@arkline.io
            </a>
            <a
              href="https://www.linkedin.com/in/bymatthewneal/"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-3 text-base text-ark-text-secondary transition-colors hover:text-ark-text sm:text-lg"
            >
              <Linkedin className="h-5 w-5 shrink-0 text-ark-primary/60" />
              {/* FOUNDER_LINKEDIN_LABEL */}
              LinkedIn
            </a>
            <a
              href="https://x.com/Arklineio"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-3 text-base text-ark-text-secondary transition-colors hover:text-ark-text sm:text-lg"
            >
              <Twitter className="h-5 w-5 shrink-0 text-ark-primary/60" />
              @Arklineio
            </a>
          </FadeIn>
        </div>
      </section>

      {/* ── CTA ── */}
      <section className="relative py-20 sm:py-28">
        <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-divider to-transparent" />
        <div className="mx-auto max-w-2xl px-4 text-center sm:px-6 lg:px-8">
          <FadeIn>
            <h2 className="font-[family-name:var(--font-urbanist)] text-3xl font-semibold text-ark-text sm:text-4xl">
              Join the early access list
            </h2>
            <p className="mt-4 text-base leading-relaxed text-ark-text-secondary sm:text-lg">
              First 150 members lock in $39.99/month &mdash; forever.
            </p>
          </FadeIn>
          <FadeIn delay={0.1} className="mt-10">
            <EmailCapture size="lg" />
          </FadeIn>
          <FadeIn delay={0.15}>
            <p className="mt-4 text-sm text-ark-text-tertiary">
              150 founding spots &middot; Launching June 2026 &middot; No card required
            </p>
          </FadeIn>
        </div>
      </section>
    </>
  );
}
