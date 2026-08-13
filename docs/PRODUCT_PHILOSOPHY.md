# Arkline — Product Philosophy & North Star

> This is the "why" behind Arkline. It's meant to be a decision lens: when we're
> unsure whether to build something, or how, we run it through this. If a feature
> works against what's written here, that's a strong signal to change it — no
> matter how clever it is.

## The North Star

**Arkline is a calm, accessible place where everyday people can understand
markets and learn to invest — at their own pace, without needing to already
speak the language.**

The app is the cockpit. We're the copilot. Our job is to quietly hand people the
instruments, take away the noise, and guide them toward understanding — never to
overwhelm them, talk down to them, or make them feel like they don't belong.

So many people have said the same thing: *"I don't know investing terms,"* or
*"can you say this in plain English?"* That sentence is the problem we exist to
solve. Removing that barrier — making markets legible to the everyday person — is
the whole point.

## Who we're building for

A deliberately mixed audience, at the same time:

- **The complete beginner** who wants to learn but is intimidated by jargon and
  noise. They need plain language, gentle on-ramps, and permission to not know
  things yet.
- **The experienced investor** who wants signal, speed, and depth. They shouldn't
  be slowed down or patronized.

The tension between those two is real, and the way we resolve it is the core of
our design philosophy below. We don't pick one audience. We build so the surface
is simple for the beginner and the depth is one tap away for the pro.

## The design principles (the decision lens)

### 1. Plain English by default
Say it the way you'd say it to a smart friend who doesn't work in finance. The
plain-language version is the default; the technical term is the annotation, not
the headline.

- "Markets are closing — here's your evening recap," not "US equity session close."
- "Consider taking some profit," not "scale out at the 0.618 extension."
- Lead with what it *means for the user*, then let them dig into the mechanism.

### 2. Progressive disclosure — simple by default, depth on tap
Everyone sees a clean number or a plain verdict. Anyone who wants the mechanics
taps once and gets them. Nobody is forced to wade through complexity to get the
takeaway, and nobody who wants detail is denied it.

- A scary-looking metric shows a one-line "what this means" first; the chart,
  formula, and history live behind a tap.
- The glossary term is underlined inline; the definition appears only if they ask.

### 3. Ambient education — invited, never forced
Teaching should feel like something the user chose to notice, not a pop quiz.
Education is offered in the flow, in small doses, and it gets out of the way.

- Definitions appear right where the term shows up.
- A "did you know?" surfaces gently at the edge of the screen, not in a modal.
- Teach the first time someone meets a feature; then step back.

### 4. Remove noise and reduce barriers
Every element should earn its place. If it doesn't help someone understand or
act, it's noise — and noise is the thing we're here to remove. Fewer, clearer
things beat more, cleverer things.

- Curate, don't dump. (The Home "Stock Risk" widget shows the Mag 7, not 50
  tickers. The Learn card features real lessons, not the Disclaimer page.)
- Sensible, tight defaults; power and breadth available for those who go looking.

### 5. Calm, not urgent — a copilot, not a casino
The tone is steady and reassuring. We do not manufacture urgency, hype, or fear
to drive engagement. We help people make calmer, better-informed decisions.

- No countdown-timer pressure, no red-alert dark patterns.
- Notifications inform; they don't nag or panic.
- We surface risk plainly so people feel *more* in control, not less.

## The test

Before shipping a feature, screen, or piece of copy, ask:

1. **Would my non-finance friend understand this on the first read?** If not,
   rewrite it or add a one-tap explanation.
2. **Is the takeaway visible without any work, with depth available on tap?**
3. **Does this reduce noise, or add something new to already understand?**
4. **Is the education invited, or is it forced/naggy?**
5. **Does this make someone feel more capable and calm — or more lost and anxious?**

If a feature can't pass these, it's probably fighting the North Star.

## Voice & language guide

- Write like a knowledgeable friend, not a terminal or a textbook.
- Prefer short, concrete sentences. Cut hedging and jargon.
- When a technical term is unavoidable, make it tappable to a plain definition.
- Explain the "so what" before (or instead of) the "how."
- Never assume prior knowledge; never make the reader feel dumb for not having it.

Quick before/after:

| Instead of… | Say… |
|---|---|
| "RSI is overbought at 78." | "Bitcoin has run up fast and may be due for a breather." (tap for the RSI detail) |
| "DXY strengthening, risk-off regime." | "The dollar is getting stronger, which often pressures risk assets like crypto." |
| "T1 hit, moving stop to breakeven." | "First target reached — the trade is now risk-free." |

## Patterns already living this

These are our proof points — extend them, don't reinvent them:

- **Inline glossary terms** — tappable definitions wherever a term appears
  (briefings, macro dashboard, risk breakdowns, technical cards).
- **The Home "Learn" card** — a daily, rotating teaching moment: mostly bite-sized
  glossary "did you know?" definitions, with a deeper article every few days.
  Invited, low-friction, at the tail of Home.
- **The Daily Briefing voice** — plain-English market recaps with a TLDR up top.
- **Signal language** — "consider taking profit," "entry confirmed," "now
  risk-free" instead of raw trading jargon.
- **Tight, curated defaults** — Home shows a focused set; everything else is
  discoverable in Customize.

## Ideas backlog (aligned to the North Star)

A living list — some may be great, some may not, all are optional. The point is to
keep generating gentle, subtle ways to educate and remove barriers.

- **"What this means for you" one-liners** under intimidating metrics (risk score,
  VIX, DXY, funding) — plain-English interpretation, always visible, depth on tap.
- **A "New to this? Start here" thread** for first-time users — a soft, skippable
  on-ramp that threads through the get-started articles.
- **Contextual tips that teach once** — the first time someone opens a feature,
  a small, dismissible note explains it; then it never shows again.
- **Definitions tied to what they're actually looking at** — e.g., feature a
  glossary term that appears in *today's* briefing, so the lesson is relevant.
- **A gentle "learn as you go" trail** — optional micro-lessons that build on each
  other for people who want a path, not just a reference.
- **Plain-English mode everywhere by default**, with an optional "show the
  technicals" toggle for power users who want the raw terms surfaced.

## Anti-patterns to avoid

- Jargon as the headline, with no plain-English fallback.
- Walls of text or data with no takeaway.
- Forced modals, quizzes, or tutorials the user didn't ask for.
- Manufactured urgency, hype, FOMO, or fear to drive engagement.
- Talking down to beginners, or slowing down experts.
- Adding features because they're clever, not because they help someone
  understand or act.

---

*This is a living document. As Arkline grows, keep asking the same question of
every new thing: does it make markets calmer, clearer, and more accessible for the
everyday person? If yes, we're on course.*
