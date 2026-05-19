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
            <p>
              I&apos;ve been investing for years, through more cycles than I want to count. I&apos;ve had mentors. I&apos;ve tried day trading in 2019&ndash;2021 and I&apos;ve done both ends of it. I&apos;ve had years where the strategy worked and years where it didn&apos;t, and what stays with me from that period isn&apos;t the P&amp;L. It&apos;s the emotional roller coaster. Being tied to a screen. Checking charts on my phone at dinner. Trading through stretches of my life I should have been spending on something else.
            </p>
            <p>
              The thing that actually changed my life wasn&apos;t a winning trade, it was switching to spot. Holding longer. Trading less. The moment I stopped trying to catch every move, my lifestyle came back. Less worry. More time. Less of my mood held hostage to a candle. And the strange thing is: my results got better, not worse.
            </p>
            <p>
              But the noise didn&apos;t stop. Crypto Twitter is a casino with a megaphone. YouTube is worse &mdash; algorithmic incentives that reward confidence, not accuracy. If you&apos;re a retail investor trying to figure out who to actually listen to, the honest answer is that most days, you can&apos;t. I&apos;ve been in this long enough to know which voices are signal and which ones are selling something.
            </p>
            <p>
              I went looking for help the same way most people do. I joined the Telegram groups. I joined the Discord servers. I paid tens of thousands of dollars to learn from people who said they knew. Some of it worked. A lot of it didn&apos;t. I got scammed more than once. I sat in rooms I&apos;d paid five figures to be in and walked out knowing less than when I arrived. I&apos;m not bitter about any of it &mdash; those were the lessons that taught me what to actually look for &mdash; but they were expensive lessons, and most retail investors can&apos;t afford to pay them twice.
            </p>
            <p>
              What I figured out along the way is that the people who don&apos;t get caught in the noise aren&apos;t smarter. They have different tools. Institutions have risk models. Sentiment data. Macro regime detection. Positioning data. They invest systematically because they have the inputs to invest systematically. Retail has CoinGecko and a group chat. The tools that would let you make decisions the way professionals do exist, but they sit behind paywalls that start at hundreds of dollars a month and go up from there. Most people don&apos;t even know what to ask for, let alone how to pay for it.
            </p>
            <p>
              ArkLine is my answer to that. The same systematic approach I had to learn the hard way &mdash; multi-factor risk scoring, macro regime detection, sentiment signals, AI briefings that pull it together &mdash; built for people with jobs and portfolios. Not for day traders. Not for institutions. For the version of me that spent years and tens of thousands of dollars figuring this out without a guide.
            </p>
            <p>
              You don&apos;t have to be that person. You don&apos;t have to take the risk, because I&apos;ve taken it for you. I&apos;ve paid the tuition to the market for you. ArkLine is me giving that back &mdash; institutional-level data, in your pocket, for the price of a couple of takeout meals a month &mdash; so you can actually compete, and stop being driven by emotion and fear.
            </p>
            <p>
              I&apos;m a solo founder, in New York. No outside funding. I read every email at matt@arkline.io. If any of this sounded like you, I&apos;d like to hear from you. &mdash; Matt
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
