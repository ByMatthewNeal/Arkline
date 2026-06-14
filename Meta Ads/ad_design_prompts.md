# Arkline — Ad Design Prompts

> **How to use:** Each prompt below is self-contained. Copy the full prompt block into Claude (or any design tool) — it includes all brand context, colors, fonts, copy, and dimensions needed to produce the ad without prior conversation context.
>
> **Best output format:** Ask the tool to generate HTML files (with Google Fonts via CDN link tags). Open in Chrome → DevTools → "Capture node screenshot" for pixel-perfect PNGs at exact dimensions. Avoid asking for SVG output — font rendering breaks during rasterization.

---

## SHARED BRAND CONTEXT (referenced by all prompts below)

```
BRAND: Arkline — institutional-grade market intelligence iOS app for retail crypto investors. Launching Spring 2026, invite-only with 150 founding members at $39.99/mo. Anti-influencer positioning. Voice is serious, data-driven, confident, quiet. Think Bloomberg terminal meets Penguin Random House book cover.

VISUAL SYSTEM:
- Background: #0F0F0F (near-black, "Bloomberg terminal depth")
- Primary text: #FFFFFF (pure white)
- Muted body text: #A1A1AA (subtle gray)
- Accent color: #3B82F6 (brand blue)
- Display font: Urbanist (weights 700/800/900) — load via Google Fonts
- Body font: Inter (weights 400/500/600) — load via Google Fonts

DESIGN PRINCIPLES:
- Pure dark backgrounds. No gradients. No noise textures.
- Generous padding (~90px on 1080-wide canvas).
- One small accent element max (a thin blue line, a small period in blue). NEVER more.
- No imagery, no stock photos, no people in static text-only ads.
- No emojis. No exclamation points. No "🚀" or hype language.
- Sentence punctuation matters — periods at the end of hooks make them feel declarative, not fragmentary.

ASPECT RATIOS NEEDED FOR EACH CONCEPT:
- 1:1 Square (1080 × 1080) — primary Feed placement
- 4:5 Portrait (1080 × 1350) — Feed alternative, often outperforms 1:1
- 9:16 Vertical (1080 × 1920) — Stories and Reels
```

---

## PROMPT 1 — Concept #2 "Stop investing on influencer takes"

```
Generate three HTML files for an ad campaign — same design at three aspect ratios. Each file should be a standalone HTML page that renders a single ad design at exact pixel dimensions, with Google Fonts loaded via <link> tag (NOT via @import in <style> — link tag in head).

[PASTE THE SHARED BRAND CONTEXT BLOCK ABOVE]

AD CONTENT:

Hook (large, top, white, Urbanist 800, letter-spacing -3px, line-height 1.05):
Line 1: Stop investing on
Line 2: influencer takes.

Below hook: 80px × 3px thin blue accent line (#3B82F6)

Body opening (white, Inter 500, size 26-32 depending on aspect ratio):
Built by an investor tired of crypto Twitter noise.

Body main (muted #A1A1AA, Inter 400, size 24-28, line-height 1.5):
Multi-factor risk scoring. Macro regime detection.
AI-generated briefings. For retail investors who
want signal, not screaming.

Tagline (white, Inter 500, same size as opening):
Arkline. Invest with conviction.

CTA button (#3B82F6 background, 10px border-radius, white text, Inter 600, size 22-26):
Reserve early access →

Footer row at bottom (positioned 70-90px from bottom edge):
Left: small triangle logo (a blue triangle/A shape made with CSS clip-path, 32-40px) + "Arkline" wordmark in Urbanist 700
Right: "arkline.io" in Inter 400 muted gray

LAYOUT BEHAVIOR ACROSS RATIOS:
- 1:1 (1080×1080): hook starts ~280px from top, size 96px
- 4:5 (1080×1350): hook starts ~370px from top, size 104px, more vertical breathing room
- 9:16 (1080×1920): hook starts ~560px from top, size 116px, much more empty space top/bottom for vertical feel

Provide three complete HTML files: concept-2_1x1.html, concept-2_4x5.html, concept-2_9x16.html. Each one self-contained, openable in Chrome to take a screenshot at exact dimensions. Use Chrome DevTools "Capture node screenshot" workflow — design the page so the ad lives in a single .ad div that can be captured.
```

---

## PROMPT 2 — Concept #5 "150 founding spots"

```
Generate three HTML files for a scarcity-themed ad — three aspect ratios. Each file standalone, openable in Chrome, ad lives in a single capturable .ad div.

[PASTE THE SHARED BRAND CONTEXT BLOCK ABOVE]

AD CONTENT:

The hero element is the number "150" — render it ENORMOUS. Use Urbanist 900 weight, size around 360-480px depending on aspect ratio. Center it visually on the canvas. White color.

Below the giant 150, a small accent line (80px × 3px, #3B82F6).

Below the line, a tight headline (Urbanist 700, size 48-64, white):
Founding members.

Followed by body copy (Inter 400, muted #A1A1AA, size 24-28, line-height 1.55):
$39.99 per month. Locked forever.
Arkline launches on iOS this spring.
After 150, standard pricing applies.

CTA button (same blue button style as Concept #2, Inter 600):
Reserve a spot →

Footer (same pattern as Concept #2): Arkline logo+wordmark left, arkline.io right.

LAYOUT: The "150" should dominate. It's the entire visual identity of this ad. Everything else is supportive. Use generous whitespace above and below the number.

DIMENSIONS: 1080×1080, 1080×1350, 1080×1920. Filenames: concept-5_1x1.html, concept-5_4x5.html, concept-5_9x16.html.
```

---

## PROMPT 3 — Concept #1 "Today's BTC Risk"

```
Generate three HTML files for a data-authority ad. Standalone, openable in Chrome, .ad div is the capture target.

[PASTE THE SHARED BRAND CONTEXT BLOCK ABOVE]

AD CONTENT:

The hero element is a risk score number. For now, use the placeholder "0.42" — the user will swap this with the actual current reading before exporting.

Number rendering: Urbanist 900, size 280-360px depending on aspect ratio, white. Center-aligned horizontally OR left-aligned depending on ratio (your call for best composition).

Subtle context line directly above the number (small, muted, Inter 400, size 18-22, #A1A1AA, letter-spacing 2px, uppercase):
BTC RISK SCORE · TODAY

Faint background detail (optional but recommended): a very low-opacity (0.06 opacity) horizontal line chart graphic behind the number to suggest "data." Make it look like a real risk-score timeline. Single thin line. Don't compete with the number.

Below the number, headline (Urbanist 700, size 36-52, white):
Historically favorable accumulation.

Body copy (Inter 400, #A1A1AA, size 22-28):
Arkline's 8-factor risk model identifies
inflection points before they're obvious.

For retail investors who want signal, not screaming.

CTA button (same blue style):
See today's score →

Footer pattern: Arkline logo+wordmark left, arkline.io right.

NOTE FOR THE USER: This concept is meant to be refreshed weekly with the current actual reading. Build the HTML so the "0.42" number is in a clearly-marked element that's easy to update.

Dimensions: 1080×1080, 1080×1350, 1080×1920. Filenames: concept-1_1x1.html, concept-1_4x5.html, concept-1_9x16.html.
```

---

## PROMPT 4 — Concept #4 "8 Factors. One Score."

```
Generate three HTML files for a curiosity-driven infographic-style ad. Standalone, openable in Chrome, .ad div is the capture target.

[PASTE THE SHARED BRAND CONTEXT BLOCK ABOVE]

AD CONTENT:

Headline at top (Urbanist 800, white, size 72-96):
Eight factors.
One score.

Below headline, a thin blue accent line (#3B82F6, 80×3px).

Central element: a 4×2 grid of small "factor cards" (8 total). Each card is a small subtle rectangle (~140-180px wide, ~80px tall) with:
- Card background: a slightly lighter shade than the page bg (#1A1A1A or #1F1F1F)
- Inside each card: a small icon (use Unicode geometric shape or emoji-free symbol like ◆ ◇ ◉ ◎ △ ▽ □ ◻) in #3B82F6 color, small size
- Below the icon: a tiny label in Inter 500, white, size 13-16, like "On-Chain", "Technical", "Macro", "Sentiment", "Liquidity", "Momentum", "Volume", "Volatility"
- Cards arranged in clean grid with ~12px gap

Below the grid, a simple line (Inter 400, #A1A1AA, size 22-26):
Distilled into a single 0-1 score.
Updated in real time.

CTA: Get the model →

Footer: Arkline logo+wordmark + arkline.io

Dimensions: 1080×1080, 1080×1350, 1080×1920.
```

---

## PROMPT 5 — Concept #3 "What you don't see on Twitter"

```
Generate three HTML files for a comparison ad. Note: this concept usually needs real product screenshots, but for v1 we'll use a stylized "before/after" with text only.

[PASTE THE SHARED BRAND CONTEXT BLOCK ABOVE]

AD CONTENT:

Headline (Urbanist 800, white, size 72-96, centered):
While Twitter argues,
Arkline shows you the data.

Below headline, a horizontal split-panel layout (vertical for 9:16):

LEFT PANEL (or top for 9:16) — "Twitter":
- Subtle desaturated panel
- Background: very dark gray (#1A1A1A)
- Inside: tiny mock tweet bubbles with blurred-out text (use CSS blur filter or just generic gray bars representing chaotic content)
- Small label at top of panel: "Influencer takes" in Inter 500, #71717A, size 14, uppercase letter-spaced

RIGHT PANEL (or bottom for 9:16) — "Arkline":
- Cleaner panel
- Background: same as page (#0F0F0F) with thin border in #3B82F6
- Inside: a few clean elements like "BTC Risk: 0.42" "VIX: 14.2" "DXY: 99.1" in mock-dashboard style — small text in mixed white/muted
- Small label at top of panel: "Arkline" in Inter 500, #FFFFFF, size 14, uppercase letter-spaced

Below the split panels, body copy (Inter 400, #A1A1AA, size 24-28):
Crypto influencers profit from your attention,
not your performance.

Tagline (white, Inter 500):
Build your strategy on data, not takes.

CTA: Get early access →

Footer: Arkline logo+wordmark + arkline.io

Dimensions: 1080×1080, 1080×1350, 1080×1920. The split panels should be horizontal on 1:1 and 4:5, vertical on 9:16.
```

---

## VIDEO CONCEPTS (#8, #9, #10) — PROMPTS FOR STORYBOARDS

These can't be generated as static designs. The prompts below produce shot-by-shot storyboards / script docs you (Matt) can use as a guide when filming or recording.

### PROMPT 6 — Concept #9 "Founder's Note" (30s video)

```
Generate a complete production brief for a 30-second founder-led video ad. Output should be a markdown document with: shot list, exact script (memorized, not read), wardrobe/setting notes, lighting tips, multiple take variants for A/B testing, and post-production notes (captions, end card).

[PASTE THE SHARED BRAND CONTEXT BLOCK ABOVE]

Founder name: Matt Neal. Filming on iPhone, no professional crew. Plain background, natural window light. Authentic, not polished — the awkwardness is the point.

Script (≤80 words):
For two years, I went looking for a tool that gave retail investors the same kind of intelligence institutions have. Risk models, macro context, AI briefings.

I couldn't find one. So I built it.

It's called Arkline. Launches on iOS this spring, capped at 150 founding members. If you're tired of investing on influencer takes, get on the early access list at arkline.io.

Talk soon.

Generate the full brief.
```

### PROMPT 7 — Concept #8 "Noise to Data" (15s video, no people)

```
Generate a complete production brief for a 15-second video ad that contrasts "noise" (influencer chaos) with "signal" (Arkline calm). No people on camera.

[PASTE THE SHARED BRAND CONTEXT BLOCK ABOVE]

Concept: rapid-cut chaos in first 5 seconds (generic crypto Twitter screenshots, YouTube thumbnail vibes, no real handles), then HARD CUT to silence/blackness for half a second, then Arkline dashboard appears calmly with the BTC risk score zooming in. End on text card: "Arkline. Invest with conviction." with arkline.io URL.

Output: shot-by-shot storyboard, music recommendations (start chaotic, end with single held low note), caption track for the muted-feed case, and editing software recommendations (CapCut for iPhone, DaVinci Resolve for desktop).
```

---

## TIPS FOR USING THESE PROMPTS

1. **Always paste the SHARED BRAND CONTEXT block at the top of each prompt.** Don't assume the AI has it from a previous session — give it fresh context each time.

2. **Request HTML output, not images.** AI image generators (DALL-E, Midjourney, etc.) reliably mangle specific text. HTML rendered in Chrome with Google Fonts is pixel-perfect.

3. **After receiving the HTML, screenshot in Chrome:**
   - Open the HTML in Chrome
   - DevTools (Cmd+Opt+I) → Elements
   - Click the `.ad` div
   - Cmd+Shift+P → "Capture node screenshot"
   - PNG downloads at exact dimensions

4. **For A/B testing**, ask the AI to also generate 2 alternate copy variants for each hook line. Keep the same visual design, change only the words. Test which lands best.

5. **Don't try to generate the entire ad set in one prompt.** One concept × three ratios = one prompt. Anything more loses fidelity.

6. **For product screenshot-dependent ads (#1, #3, #6, #10):** you'll need to provide actual screenshots from your Arkline app/dashboard. Tell the AI the screenshot paths or paste them — it can embed them into the HTML.

---

## CONCEPT-TO-PRIORITY MAP

| Concept | Type | Priority | Use this prompt for the first ad batch? |
|---|---|---|---|
| #2 Stop investing on influencer takes | Static text | 🥇 | Yes — already-recommended for launch set |
| #5 150 founding spots | Static text | 🥇 | Yes |
| #9 Founder's note | Video | 🥇 | Yes — but film instead of generate |
| #1 Today's BTC Risk | Static + data | 🥈 | Add after launch, refresh weekly |
| #6 Six Pillars carousel | Multi-slide | 🥈 | Add when you have product screenshots |
| #3 What you don't see on Twitter | Static comparison | 🥉 | Optional |
| #4 Eight factors. One score. | Static infographic | 🥉 | Optional |
