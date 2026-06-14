# Arkline — Pre-Launch Email Sequence (Drafts)

> **Purpose:** Stop the leaky bucket. Every early access signup needs a welcome immediately, then nurture every 7–10 days until launch.
> **Voice:** Anti-influencer, data-driven, founder-to-reader, plain-text feel. No emojis. No designed templates. Adults talking to adults.
> **Status:** First two emails drafted below. More to be added once you're set up in Loops (or chosen ESP).

---

## Sequence overview

| # | Type | Trigger | Topic |
|---|---|---|---|
| 1 | Welcome | Instant on signup | "You're in." Sets expectation, asks for reply, plants founder voice. |
| 2 | Nurture #1 | +7 days | How the BTC risk score works. |
| 3 | Nurture #2 | +14 days | The macro dashboard — VIX/DXY/WTI/US Net Liquidity. |
| 4 | Nurture #3 | +21 days | Sample AI morning briefing. |
| 5 | Nurture #4 | +28 days | Founder's note — why Matt built Arkline. |
| 6 | Launch | Day iOS goes live | "It's here. 150 founding spots. Locked-in pricing." |
| 7 | Trial close #1 | +2 days post-launch | Scarcity nudge with current cap status. |
| 8 | Trial close #2 | +5 days post-launch | Final reminder; founder pricing reminder. |

Below: full drafts of #1 and #2. The rest will be drafted as we get closer to launch.

---

## Email 1 — Welcome

**Trigger:** Fires instantly when an email is captured via Supabase (or via Loops trigger if you sync the list).

**Subject line options (test):**
- A: `You're on the early access list`
- B: `Confirmed — you're in for Arkline`
- C: `Welcome to Arkline early access`

**From:** Matt Neal <matt@arkline.io> (or whichever sender you set up)

**Body:**

```
Hey,

You're in.

I wanted to send this myself rather than have it auto-fire
from a marketing tool, because the people on this list are
going to be the first 150 founding members of Arkline — and
I think that matters.

Here's what to expect:

- Arkline launches on iOS this spring — invite-only, capped
  at 150 founding members
- You'll get the invite the moment we go live, before
  anyone else
- Founding pricing ($39.99/mo or $400/yr) locks forever as
  long as you stay subscribed
- Between now and launch, I'll send a few notes on how the
  product actually works — the BTC risk model, the macro
  dashboard, sample AI briefings — so you know exactly what
  you're getting

One ask: hit reply and tell me what you're hoping a tool
like this would solve for you. I read every response. The
product is still flexible enough that good feedback shapes
what ships at launch.

Talk soon,
Matt
Founder, Arkline

P.S. If you want market takes between now and launch, I
post on X: @Arklineio
```

**Why this works:**
- Plain-text format signals "from a person, not a marketing automation"
- "I read every response" generates engagement signals (good for inbox placement) and gives you actual feedback
- Reinforces scarcity (150 cap) and value (locked pricing) without being pushy
- The P.S. softly drives X followers — a side-channel for retargeting later

---

## Email 2 — How Arkline scores BTC risk

**Trigger:** +7 days after signup, only if the user opened email #1 (optional gate).

**Subject line options (test):**
- A: `How Arkline scores BTC risk`
- B: `The 8-factor model behind your risk score`
- C: `Why most retail investors get cycle timing wrong`

**Body:**

```
Most people in crypto try to time the market by gut feel,
Twitter sentiment, or whatever the loudest YouTuber said
this week.

Institutions don't.

Institutions build risk models — multi-factor frameworks
that weigh dozens of inputs to produce a single, actionable
score. They use them to size positions, time entries, and
stay disciplined through volatile cycles.

Arkline brings that approach to retail.

Here's how the BTC risk score works:

It's an 8-factor model that outputs a single number from 0
to 1. Lower readings signal historically favorable
accumulation. Higher readings flag elevated risk.

The eight factors fall into four buckets:

  On-chain behavior — what wallets are actually doing
  Technical regime — momentum and trend across timeframes
  Sentiment — how the market feels (often diverges from
  fundamentals)
  Macro context — liquidity, dollar strength, risk-asset
  backdrop

Each factor is normalized, weighted, and combined. The
output updates in real time.

Why this matters: gut feel is unreliable. Sentiment is
loudest at exactly the wrong moments — euphoria at tops,
despair at bottoms. A risk score doesn't lie to you when
you're emotional.

When Arkline launches, you'll see today's score, the
historical chart, and the contributing factors broken out
— so you understand exactly *why* the score is what it is.
No black box.

Next week: the macro dashboard. Four indicators every
retail investor should be watching. Most aren't.

— Matt
```

**Important annotation for Matt:** Before sending, decide if you want to add a specific historical example (e.g., "the model flagged elevated risk in [month/year], 60 days before [event]"). If you have backtested or even directionally-true examples, those concrete moments make the email much sharper. I left it out of the draft because I don't want to put numbers in your mouth that aren't yours.

**Why this works:**
- Demonstrates expertise without bragging
- Anti-influencer positioning is explicit (line 1 — "loudest YouTuber")
- Teaches them something useful even if they never sign up — builds goodwill
- Plants the next email (continuity hook)
- Specifics (the 8-factor breakdown) make the product feel real, not vaporware
- Plain prose, no marketing fluff

---

## Production notes

### Format
- **Plain text emails only.** Designed HTML emails feel like marketing; plain text feels like a founder note. Plain text also lands in primary inbox more often than designed templates.
- **No images** in emails 1–4. Save imagery for the launch announcement.
- **Sender name should be "Matt Neal" or "Matt at Arkline"**, not "Arkline" — personal sender = better open rates pre-launch.

### Sender authentication
Before sending any volume, set up:
- SPF record on arkline.io
- DKIM keys
- DMARC policy (start with `p=none` to monitor)

Loops handles most of this automatically; if you go with Resend, it's slightly more manual.

### Send timing
- Welcome: instant on trigger
- Nurture cadence: every 7 days, send time around 9–10 AM ET (when finance audience is checking email pre-market)

### Subject line A/B testing
For each email, test 2 subject lines (50/50 split). Track open rate, click rate, reply rate. Reply rate is the most underrated signal — replies tell Gmail/Apple Mail you're a wanted sender, dramatically improving deliverability for the rest of the sequence.

### Personalization
For now, no personalization tokens (don't use `{{first_name}}` because you didn't capture names — fake-personalization is worse than none). When you launch trial flow, capture first name on the credit card form so post-launch emails can include it.

---

## What I need from you to finalize

1. Confirm sender email (`matt@arkline.io`? `hi@arkline.io`?) so we can set up DNS records when Loops is connected.
2. Confirm Twitter handle is `@Arklineio` — this is referenced in email 1's P.S.
3. If you have any backtested risk-score moments you'd like me to weave into email 2, share them and I'll update the draft.
