# Learning Trails — Seed Notes

> **Status: seed / pre-deep-dive.** This captures the vision as of the first
> conversation so we start from something written. It is NOT a spec yet — we're
> deep-diving to shape it. Extends the ideas in `PRODUCT_PHILOSOPHY.md`
> (the "learn as you go" trail).

## The vision (in Matt's words, paraphrased)

A self-paced learning offering inside Arkline where someone can walk in knowing
nothing and educate themselves about investing — **at their own pace, without
relying on Matt.** Clear, truthful, honest information, all under one platform, so
people don't have to look elsewhere and get lost, distracted, or misled.

This is meant to be a **major offering** of the app, not a side feature. The edge:
most people cobble investing knowledge together from YouTube, Reddit, and finance
influencers with something to sell. Arkline can be the calm, honest, single source.

## Core intent

- **Self-paced.** Start, stop, resume anytime. No pressure, no deadlines.
- **Choose your path.** Learners pick what they want to learn:
  - Investing in **crypto**
  - Investing in **traditional markets** (stocks / equities)
  - **Hedging** in / across those markets
  - (Likely a shared **foundations** track underneath all of them.)
- **Reduce reliance on the founder.** People educate themselves; Matt doesn't have
  to hand-hold each person.
- **One honest platform.** Truthful, unbiased, plain-English — the antidote to the
  noise and hype elsewhere.

## Guiding principles (inherited from the North Star)

- Optional, never forced. An invitation, not a gate.
- Micro-lessons: ~1–2 minutes each, resumable.
- Sequential and building — a *path*, not a random-access reference (that's what
  the glossary/Resources already are).
- Calm progress — a gentle sense of forward motion; **no streaks, badges, or
  dopamine loops.** The moment it nags, it's become the casino we avoid.
- Plain English. Teach how to *think*, not jargon to memorize.
- Ties into Arkline's own live data where possible, so learning and doing are one
  motion (e.g., after the risk lesson, point at the actual risk widget).

## Strawman structure (to react to, not commit to)

A shared foundation that then branches by market:

```
Foundations (shared)
  • What "risk" really means
  • Why nobody can time the top
  • Cycles, volatility, and patience
  • Dollar-cost averaging in plain English
        │
        ├── Crypto track
        │     • What crypto actually is / how it trades 24/7
        │     • On-chain & sentiment basics
        │     • Reading Arkline's crypto risk levels
        │
        ├── Traditional markets track
        │     • Stocks, indices, what moves them
        │     • Valuation basics
        │     • Macro: the dollar, rates, liquidity
        │
        └── Hedging track (more advanced)
              • What hedging is and why
              • Simple ways to reduce exposure
              • Thinking about position sizing
```

## Open questions for the deep-dive

1. **Track structure & overlap.** How much is shared foundations vs. per-market?
   Where do crypto and traditional genuinely diverge vs. share concepts?
2. **Sequencing.** What's the right order within a track so each lesson truly
   builds on the last? What are the prerequisites?
3. **Depth tiers.** Beginner → intermediate → advanced within a track? Or keep it
   flat and gentle?
4. **Lesson format.** Text? Short cards? Illustrations? Interactive? How long is a
   "micro" lesson, really?
5. **Integration with the app.** How do lessons connect to live widgets, briefings,
   signals, the glossary? Can a lesson "point at" a real thing on screen?
6. **Progress model.** How do we show progress in a *calm* way — resume points,
   a quiet map — without turning it into a streak/gamification machine?
7. **Content pipeline.** Server-driven (like Resources) so it's editable without an
   app release? Who writes/reviews it? How do we keep it truthful and current?
8. **Education vs. advice — important.** Keep it firmly *educational* (concepts, how
   to think) and clear of anything that reads as personalized "buy/sell this"
   advice. This protects users AND reinforces the truthful/honest value. Worth
   getting the framing and disclaimers right early.
9. **Entry points.** Where does a learner discover this? A soft "New here? Start
   with the basics," a dedicated tab/section, a tie-in from the Learn card?
10. **Measuring "did it help?"** How do we know it's working — without vanity
    metrics that push us toward engagement-bait?

## Relationship to what already exists

- **Glossary** = reference (random-access definitions). Already built.
- **Resources hub** = a small library of standalone articles. Already built.
- **Home "Learn" card** = ambient, serendipitous daily lesson/definition. Just built.
- **Learning Trails (this)** = the intentional, sequential *path* for people who
  want to be taken by the hand from "I know nothing" to "I get this now."

These are complementary: browse (glossary/Resources), stumble into (Learn card),
or follow a path (Trails).

---

*Next: deep-dive with Matt to shape tracks, sequencing, format, and the
education-not-advice framing. Update this doc into a real spec as decisions land.*
