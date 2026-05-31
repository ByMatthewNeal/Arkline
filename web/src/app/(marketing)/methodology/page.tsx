import type { Metadata } from 'next';
import { ArrowRight } from 'lucide-react';
import { FadeIn } from '@/components/marketing/fade-in';
import { EmailCapture } from '@/components/marketing/email-capture';

export const metadata: Metadata = {
  title: 'How the Arkline Risk Model Works — Methodology',
  description:
    'Arkline scores Bitcoin risk using log regression, SMA trend analysis, macro regime detection, and additional quantitative factors. See the framework behind every signal.',
  alternates: { canonical: '/methodology' },
  openGraph: {
    title: 'How the Arkline Risk Model Works',
    description:
      'The framework behind the BTC Risk Score, Positioning Signals, and Rotation Signal. No black box.',
  },
};

/* ── Data ── */

const riskLevels = [
  { label: 'Very Low Risk', color: 'bg-emerald-500', description: 'Deep value zone. Price well below fair value. Historically the strongest accumulation windows.' },
  { label: 'Low Risk', color: 'bg-green-400', description: 'Below fair value. Favorable risk/reward for long-term positioning.' },
  { label: 'Neutral', color: 'bg-yellow-400', description: 'Near fair value. No strong directional bias from valuation alone.' },
  { label: 'Elevated Risk', color: 'bg-orange-400', description: 'Above fair value. Reduce position sizing. Tighten risk management.' },
  { label: 'High Risk', color: 'bg-red-400', description: 'Significantly overvalued. Historical distribution zone. Defensive positioning.' },
  { label: 'Extreme Risk', color: 'bg-red-600', description: 'Extreme deviation above fair value. Maximum caution. Cycle top territory.' },
];

const qpsInputs = [
  { input: 'Long-term trend position', description: 'Where price sits relative to the 200-day moving average — the single strongest signal of long-term trend health.' },
  { input: 'Medium-term structure', description: 'Intermediate moving average position confirms whether the trend supports the current bias.' },
  { input: 'Short-term momentum', description: 'Near-term moving average and crossover dynamics capture immediate strength or weakness.' },
  { input: 'Momentum oscillator', description: 'RSI-based contrarian and overbought/oversold adjustments fine-tune the score at extremes.' },
  { input: 'Cycle regime check', description: 'A weekly-timeframe support band confirms whether the broader bull or bear market structure is intact.' },
];

const rotationInputs = [
  { input: 'Relative Performance', description: 'How crypto and equities have performed against each other over the trailing period.' },
  { input: 'Trend Signal Comparison', description: 'Positioning signal state for BTC and SPY — opposing signals amplify the rotation bias.' },
  { input: 'Market Sentiment', description: 'Fear & Greed dynamics — recovery from fear favors crypto, euphoria signals rotation risk.' },
  { input: 'Dollar Trend', description: 'USD strength tends to favor equities. Weakness tends to favor crypto.' },
  { input: 'Bitcoin Dominance', description: 'Rising dominance signals an accumulation phase within crypto.' },
  { input: 'Volatility Regime', description: 'Elevated volatility triggers defensive positioning across both asset classes.' },
];

/* ── Divider ── */
function Divider() {
  return (
    <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-divider to-transparent" />
  );
}

/* ── Section wrapper ── */
function Section({ children, className = '' }: { children: React.ReactNode; className?: string }) {
  return (
    <section className={`relative py-20 sm:py-28 ${className}`}>
      <Divider />
      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">{children}</div>
    </section>
  );
}


/* ── Page ── */
export default function MethodologyPage() {
  return (
    <main>
      {/* ── Hero ── */}
      <section className="relative overflow-hidden pt-32 pb-16 sm:pt-40 sm:pb-20">
        <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8 text-center">
          <FadeIn>
            <span className="inline-block rounded-full border border-ark-primary/20 bg-ark-primary/5 px-4 py-1.5 text-xs font-semibold uppercase tracking-widest text-ark-primary">
              Methodology
            </span>
          </FadeIn>

          <FadeIn delay={0.1}>
            <h1 className="mt-6 font-[family-name:var(--font-urbanist)] text-4xl font-semibold tracking-tight text-ark-text sm:text-5xl lg:text-6xl">
              Transparent by design.{' '}
              <span className="bg-gradient-to-r from-ark-primary via-ark-purple to-ark-cyan bg-clip-text text-transparent">
                Not by accident.
              </span>
            </h1>
          </FadeIn>

          <FadeIn delay={0.2}>
            <p className="mx-auto mt-6 max-w-2xl text-lg leading-relaxed text-ark-text-secondary">
              Every signal Arkline produces is driven by quantitative models — not gut calls,
              not hype, not vibes. Here&apos;s the framework behind the intelligence.
            </p>
          </FadeIn>
        </div>
      </section>

      {/* ── 1. BTC Risk Score ── */}
      <Section>
        <FadeIn>
          <h2 className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text sm:text-3xl">
            BTC Risk Score
          </h2>

          <p className="mt-4 text-ark-text-secondary leading-relaxed">
            The BTC Risk Score measures where Bitcoin&apos;s current price sits relative to its long-term
            fair value. It uses logarithmic regression fitted to BTC&apos;s entire price history since
            the genesis block (January 3, 2009) to establish a fair value curve, then normalizes
            the deviation into a 0–1 score.
          </p>

          <div className="mt-8 rounded-2xl border border-ark-divider bg-ark-fill-secondary/50 p-6">
            <h3 className="text-sm font-semibold uppercase tracking-wider text-ark-text-secondary">
              How it works
            </h3>
            <ol className="mt-4 space-y-3 text-sm text-ark-text-secondary leading-relaxed">
              <li className="flex gap-3">
                <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-ark-primary/10 text-xs font-bold text-ark-primary">1</span>
                <span><strong className="text-ark-text">Fit a regression model</strong> to BTC&apos;s full daily price history in log space — capturing the long-term growth trajectory.</span>
              </li>
              <li className="flex gap-3">
                <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-ark-primary/10 text-xs font-bold text-ark-primary">2</span>
                <span><strong className="text-ark-text">Compute today&apos;s fair value</strong> — the model&apos;s estimate of where BTC &ldquo;should&rdquo; be based on its maturity curve.</span>
              </li>
              <li className="flex gap-3">
                <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-ark-primary/10 text-xs font-bold text-ark-primary">3</span>
                <span><strong className="text-ark-text">Measure the gap</strong> — how far the current price has deviated above or below fair value.</span>
              </li>
              <li className="flex gap-3">
                <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-ark-primary/10 text-xs font-bold text-ark-primary">4</span>
                <span><strong className="text-ark-text">Classify risk</strong> — the deviation maps to one of six risk categories, from deep value to cycle-top territory.</span>
              </li>
            </ol>
          </div>

          <h3 className="mt-8 text-sm font-semibold uppercase tracking-wider text-ark-text-secondary">
            Risk Categories
          </h3>
          <div className="mt-4 space-y-2">
            {riskLevels.map((level) => (
              <div key={level.label} className="flex items-start gap-3 rounded-lg border border-ark-divider/50 p-3">
                <div className={`mt-1 h-3 w-3 shrink-0 rounded-full ${level.color}`} />
                <div className="flex-1">
                  <span className="text-sm font-medium text-ark-text">{level.label}</span>
                  <p className="mt-0.5 text-xs text-ark-text-secondary">{level.description}</p>
                </div>
              </div>
            ))}
          </div>

          <p className="mt-6 text-sm text-ark-text-secondary leading-relaxed">
            The risk score feeds directly into portfolio allocation decisions. Lower risk levels
            unlock higher crypto exposure. Elevated and extreme risk levels trigger defensive
            positioning — shifting toward cash and gold while maintaining minimum durable asset floors.
          </p>
        </FadeIn>
      </Section>

      {/* ── 2. Positioning Signals (QPS) ── */}
      <Section>
        <FadeIn>
          <h2 className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text sm:text-3xl">
            Daily Positioning Signals
          </h2>

          <p className="mt-4 text-ark-text-secondary leading-relaxed">
            Every day, Arkline evaluates 54+ assets across crypto, equities, commodities, and macro
            indicators. Each asset receives a trend score based on multiple technical inputs, which
            determines whether the daily signal is <strong className="text-emerald-500">Bullish</strong>,{' '}
            <strong className="text-ark-text">Neutral</strong>, or{' '}
            <strong className="text-red-500">Bearish</strong>.
          </p>

          <div className="mt-8 rounded-2xl border border-ark-divider bg-ark-fill-secondary/50 p-6">
            <h3 className="text-sm font-semibold uppercase tracking-wider text-ark-text-secondary">
              What goes into the score
            </h3>
            <p className="mt-2 text-sm text-ark-text-secondary">
              The scoring model is built primarily around moving average positioning — where price
              sits relative to key trend levels — with secondary inputs for momentum, sentiment,
              and cycle structure:
            </p>
            <div className="mt-4 space-y-2">
              {qpsInputs.map((f) => (
                <div key={f.input} className="flex items-start gap-3 py-2 border-b border-ark-divider/30 last:border-0">
                  <div className="mt-1 h-1.5 w-1.5 shrink-0 rounded-full bg-emerald-500" />
                  <div className="flex-1">
                    <span className="text-sm font-medium text-ark-text">{f.input}</span>
                    <p className="mt-0.5 text-xs text-ark-text-secondary">{f.description}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <p className="mt-6 text-sm text-ark-text-secondary leading-relaxed">
            The system includes structural safeguards — an asset in a clearly broken trend can&apos;t
            be classified as Bullish regardless of other factors. This prevents the model from
            fighting obvious price structure.
          </p>
        </FadeIn>
      </Section>

      {/* ── 3. Rotation Signal ── */}
      <Section>
        <FadeIn>
          <h2 className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text sm:text-3xl">
            Crypto / Equities Rotation
          </h2>

          <p className="mt-4 text-ark-text-secondary leading-relaxed">
            The Rotation Signal answers one question: should you favor crypto or equities right now?
            It produces a daily score that leans toward crypto, equities, or stays neutral — based
            on a weighted blend of performance, sentiment, and macro inputs.
          </p>

          <div className="mt-8 rounded-2xl border border-ark-divider bg-ark-fill-secondary/50 p-6">
            <h3 className="text-sm font-semibold uppercase tracking-wider text-ark-text-secondary">
              Inputs
            </h3>
            <div className="mt-4 space-y-2">
              {rotationInputs.map((input) => (
                <div key={input.input} className="flex items-start gap-3 py-2 border-b border-ark-divider/30 last:border-0">
                  <div className="mt-1 h-1.5 w-1.5 shrink-0 rounded-full bg-violet-500" />
                  <div className="flex-1">
                    <span className="text-sm font-medium text-ark-text">{input.input}</span>
                    <p className="mt-0.5 text-xs text-ark-text-secondary">{input.description}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
            {[
              { label: 'Favor Crypto', color: 'text-orange-400 border-orange-400/20 bg-orange-400/5' },
              { label: 'Neutral', color: 'text-ark-text-secondary border-ark-divider bg-ark-fill-secondary/50' },
              { label: 'Favor Equities', color: 'text-blue-400 border-blue-400/20 bg-blue-400/5' },
              { label: 'Risk Off', color: 'text-red-400 border-red-400/20 bg-red-400/5' },
            ].map((regime) => (
              <div key={regime.label} className={`rounded-xl border p-3 text-center ${regime.color}`}>
                <p className="text-sm font-semibold">{regime.label}</p>
              </div>
            ))}
          </div>

          <p className="mt-6 text-sm text-ark-text-secondary leading-relaxed">
            Each regime comes with suggested allocation ranges and actionable guidance — visible
            directly in the app alongside the score and a daily AI-generated narrative.
          </p>
        </FadeIn>
      </Section>

      {/* ── 4. Model Portfolios ── */}
      <Section>
        <FadeIn>
          <h2 className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text sm:text-3xl">
            Model Portfolios
          </h2>

          <p className="mt-4 text-ark-text-secondary leading-relaxed">
            Three systematic portfolios rebalance daily based on positioning signals, BTC risk level,
            gold trend, and macro regime. Each one applies the same intelligence with a different
            risk tolerance — from conservative to aggressive.
          </p>

          <div className="mt-8 space-y-4">
            {[
              { name: 'Core', description: 'Conservative. Higher base allocation to BTC and ETH. Slower to rotate. Highest minimum floors on durable assets.' },
              { name: 'Edge', description: 'Moderate. Balanced exposure with gradual position sizing — positions step toward targets over multiple days rather than jumping.' },
              { name: 'Alpha', description: 'Aggressive. Largest allocation to alt rotation. Fastest position changes. Lowest durable asset floors.' },
            ].map((portfolio) => (
              <div key={portfolio.name} className="rounded-2xl border border-ark-divider p-5">
                <h3 className="text-lg font-semibold text-ark-text">Arkline {portfolio.name}</h3>
                <p className="mt-2 text-sm text-ark-text-secondary">{portfolio.description}</p>
              </div>
            ))}
          </div>

          <div className="mt-6 rounded-2xl border border-ark-divider bg-ark-fill-secondary/50 p-6">
            <h3 className="text-sm font-semibold uppercase tracking-wider text-ark-text-secondary">
              Key Principles
            </h3>
            <ul className="mt-4 space-y-2 text-sm text-ark-text-secondary">
              {[
                'Durable assets (BTC, Gold) are never fully exited — minimum floors hold regardless of signal state.',
                'Alt rotation requires dual confirmation across multiple timeframes before capital is deployed.',
                'Defensive moves (cash, gold) execute immediately. Risk-on moves blend in gradually.',
                'Every portfolio benchmarks against SPY buy-and-hold for transparent performance comparison.',
              ].map((point, i) => (
                <li key={i} className="flex gap-2">
                  <ArrowRight className="mt-0.5 h-4 w-4 shrink-0 text-amber-500" />
                  <span>{point}</span>
                </li>
              ))}
            </ul>
          </div>
        </FadeIn>
      </Section>

      {/* ── 5. Trade Signals ── */}
      <Section>
        <FadeIn>
          <h2 className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text sm:text-3xl">
            Fibonacci Trade Signals
          </h2>

          <p className="mt-4 text-ark-text-secondary leading-relaxed">
            Arkline continuously scans crypto assets for trade setups using automated Fibonacci analysis.
            The system identifies swing structure, computes retracement levels, finds confluence zones,
            and generates signals only after price confirms a reaction at the level.
          </p>

          <div className="mt-8 rounded-2xl border border-ark-divider bg-ark-fill-secondary/50 p-6">
            <h3 className="text-sm font-semibold uppercase tracking-wider text-ark-text-secondary">
              How signals are generated
            </h3>
            <ol className="mt-4 space-y-3 text-sm text-ark-text-secondary leading-relaxed">
              {[
                { title: 'Detect swing structure', detail: '— identify significant highs and lows across multiple timeframes.' },
                { title: 'Compute Fibonacci levels', detail: '— map key retracement ratios between each swing pair.' },
                { title: 'Find confluence zones', detail: '— areas where multiple Fibonacci levels from different swings cluster together, increasing significance.' },
                { title: 'Wait for confirmation', detail: '— no signal fires until price shows a measurable reaction at the zone (rejection wick, volume spike, or structural hold).' },
                { title: 'Score and publish', detail: '— each setup is scored on zone strength, volume, trend alignment, and market regime before reaching users.' },
              ].map((step, i) => (
                <li key={i} className="flex gap-3">
                  <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-cyan-500/10 text-xs font-bold text-cyan-500">{i + 1}</span>
                  <span><strong className="text-ark-text">{step.title}</strong> {step.detail}</span>
                </li>
              ))}
            </ol>
          </div>

          <p className="mt-6 text-sm text-ark-text-secondary leading-relaxed">
            Signals include entry zones, targets, stop losses, and a risk/reward assessment.
            Both swing (multi-hour) and scalp (short-duration) tiers are supported, each with
            their own confirmation requirements.
          </p>
        </FadeIn>
      </Section>

      {/* ── 6. Macro Regime Detection ── */}
      <Section>
        <FadeIn>
          <h2 className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text sm:text-3xl">
            Macro Regime Detection
          </h2>

          <p className="mt-4 text-ark-text-secondary leading-relaxed">
            Arkline classifies the current macro environment as Risk-On or Risk-Off by analyzing
            the health of major equity indices alongside volatility conditions. When the macro
            picture deteriorates, the system automatically reduces crypto exposure and increases
            defensive allocations across all model portfolios.
          </p>

          <div className="mt-6 grid grid-cols-2 gap-3">
            <div className="rounded-xl border border-emerald-500/20 bg-emerald-500/5 p-5">
              <p className="text-lg font-semibold text-emerald-500">Risk-On</p>
              <p className="mt-2 text-xs text-ark-text-secondary">Equities healthy. Full crypto allocation per signal state. Alt rotation active. Offensive positioning.</p>
            </div>
            <div className="rounded-xl border border-red-400/20 bg-red-400/5 p-5">
              <p className="text-lg font-semibold text-red-400">Risk-Off</p>
              <p className="mt-2 text-xs text-ark-text-secondary">Macro weakness detected. Crypto exposure reduced. Defensive assets prioritized. Capital preservation mode.</p>
            </div>
          </div>
        </FadeIn>
      </Section>

      {/* ── CTA ── */}
      <Section>
        <FadeIn>
          <div className="text-center">
            <h2 className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text sm:text-3xl">
              Built for clarity.{' '}
              <span className="bg-gradient-to-r from-ark-primary via-ark-purple to-ark-cyan bg-clip-text text-transparent">
                Not mystery.
              </span>
            </h2>
            <p className="mx-auto mt-4 max-w-xl text-ark-text-secondary">
              You shouldn&apos;t have to trust a black box with your money. Arkline shows you the
              framework, the inputs, and the logic — so the confidence is yours, not borrowed.
            </p>
            <div className="mt-8 flex justify-center">
              <EmailCapture size="lg" />
            </div>
          </div>
        </FadeIn>
      </Section>
    </main>
  );
}
