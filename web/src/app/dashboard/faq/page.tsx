'use client';

import { useState } from 'react';
import { HelpCircle, ChevronDown } from 'lucide-react';
import { GlassCard } from '@/components/ui';
import { cn } from '@/lib/utils/format';

const FAQS: { q: string; a: string }[] = [
  { q: 'What is the ArkLine Score?', a: 'A proprietary composite indicator (0–100) that blends ~10 market signals across sentiment, macro conditions, and market structure. Each component is normalized and weighted by predictive relevance. Lower scores reflect fear/opportunity; higher scores reflect greed/elevated risk.' },
  { q: 'How are Crypto & Stock Risk Levels calculated?', a: 'Crypto risk uses each asset’s position within its long-term logarithmic regression channel (0 = deeply undervalued, 1 = historically overextended). Stock risk uses a trend & momentum model. Both refresh at 7 AM and 5 PM ET.' },
  { q: 'What does the Macro regime mean?', a: 'It combines volatility (VIX), the dollar (DXY), and liquidity into one read on the backdrop. Risk-On means favorable conditions across the board; Risk-Off means multiple headwinds; the Disinflation/Inflation tag reflects whether monetary conditions are easing or tightening.' },
  { q: 'How do I track my portfolio?', a: 'On the Portfolio page, use “Add Transaction” to record buys and sells (search a coin, enter quantity and price). Holdings, allocation, and performance metrics update automatically. You can also set target allocations and export your transactions to CSV.' },
  { q: 'What are DCA reminders?', a: 'Dollar-cost-averaging reminders nudge you to invest a fixed amount on a schedule (daily → monthly). Create one from the DCA page; tap “Invest” each time you buy to log the purchase and roll the next date forward.' },
  { q: 'How does the watchlist work?', a: 'Tap the ⭐ on any coin’s detail page or in the Top Coins list to add it to your watchlist. Your watchlist appears on the Home dashboard and syncs across the app.' },
  { q: 'Is any of this financial advice?', a: 'No. Arkline provides data, analytics, and educational content only. Nothing here is investment advice — always do your own research.' },
  { q: 'Where does the data come from?', a: 'Market data is aggregated from 12+ sources (price feeds, on-chain metrics, macro indicators, and news). Some figures update intraday; risk models refresh twice daily.' },
  { q: 'How do I change appearance or currency?', a: 'Go to Settings to switch between light/dark/system themes, choose your preferred display currency, and manage notification preferences.' },
  { q: 'How is my subscription managed?', a: 'Subscriptions are handled on the web via Stripe. You can review your plan status in Settings.' },
];

function Item({ q, a }: { q: string; a: string }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="border-b border-ark-divider/60 last:border-0">
      <button onClick={() => setOpen((v) => !v)} className="flex w-full items-center justify-between gap-3 py-4 text-left">
        <span className="text-sm font-semibold text-ark-text">{q}</span>
        <ChevronDown className={cn('h-4 w-4 shrink-0 text-ark-text-tertiary transition-transform', open && 'rotate-180')} />
      </button>
      {open && <p className="pb-4 text-[13px] leading-relaxed text-ark-text-secondary">{a}</p>}
    </div>
  );
}

export default function FAQPage() {
  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <div className="flex items-center gap-3">
        <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-ark-primary/10"><HelpCircle className="h-5 w-5 text-ark-primary" /></div>
        <div>
          <h1 className="font-[family-name:var(--font-urbanist)] text-2xl font-bold text-ark-text">FAQ</h1>
          <p className="text-sm text-ark-text-tertiary">Answers to common questions</p>
        </div>
      </div>
      <GlassCard className="px-5 py-1">
        {FAQS.map((f) => <Item key={f.q} {...f} />)}
      </GlassCard>
    </div>
  );
}
