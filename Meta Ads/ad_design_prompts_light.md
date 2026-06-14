# Arkline Ad Design Prompts — Light Mode Variants

These are light-mode versions of the three launch concepts (#1, #2, #5) for post-launch palette A/B testing. Hand to Claude Design once dark-mode launch ads have ~2 weeks of data, then run the best-performing dark concept head-to-head against its light twin.

---

## SHARED BRAND CONTEXT (paste this with every prompt)

You are designing an ad for **Arkline**, an iOS market intelligence app for retail crypto investors. Output: a single self-contained HTML file viewable in Chrome. I will export to PNG via Chrome DevTools "Capture node screenshot."

**Voice:** investor-grade, anti-influencer, dry confidence. Not playful, not hype, not screaming. Bloomberg-terminal energy translated for retail.

**Brand:** Arkline — `arkline.io`

**Light palette (this brief):**
- Background: `#FAFAFA` (off-white, premium — NOT pure white)
- Text primary: `#0F0F0F`
- Text muted: `#52525B` (zinc-600)
- Accent (logo, accent line): `#2563EB` (blue-600 — slightly darker than the dark-mode blue for contrast on light bg)
- CTA button: `#0F0F0F` background, `#FAFAFA` text (dark button on light — premium, high-contrast)
- Subtle border on the ad container: `1px solid #E4E4E7` (for inline preview only; not visible in screenshot if you select just the `.ad` node)

**Typography:**
- Hook: `Urbanist` weight 800, large, letter-spacing -3px, line-height 1.05
- Body emphasis: `Inter` weight 500
- Body muted: `Inter` weight 400, color `#52525B`
- Brand wordmark: `Urbanist` weight 700, letter-spacing -0.5px
- URL footer: `Inter` weight 400, color `#52525B`
- Mono numerals (for stat heroes): `JetBrains Mono` weight 700 — used ONLY for large numeric stats like "0.42"

**Font loading:** Use `<link rel="stylesheet">` from Google Fonts (do NOT use `@import` inside `<style>` — it doesn't reliably load). Preconnect to `fonts.googleapis.com` and `fonts.gstatic.com`.

**Logo treatment:** Small triangle mark via CSS `clip-path`, color `#2563EB`, sits next to the "Arkline" wordmark in the footer:
```css
clip-path: polygon(50% 0%, 0% 100%, 100% 100%, 80% 100%, 50% 38%, 20% 100%);
```

**Layout system:**
- `.ad` container at the exact aspect-ratio pixel dimensions (see below), padding 90px
- Content reads top-to-bottom: hook → accent line → body → CTA, with footer (logo + URL) absolute-positioned at bottom
- Accent line is 3px tall, `#2563EB`, 80–100px wide depending on ratio
- Include a small fixed instructions banner explaining how to screenshot via DevTools (won't appear in the screenshot)

**Three aspect ratios to produce per concept:**
- 1:1 → 1080×1080
- 4:5 → 1080×1350
- 9:16 → 1080×1920

Adjust font sizes and top-margin proportionally for each ratio (taller ratios → bigger hook, more breathing room above).

---

## PROMPT 1 — Concept #1 (Light Mode)

[Paste SHARED BRAND CONTEXT above]

**Generate light-mode HTML for Concept #1 in all three aspect ratios (1:1, 4:5, 9:16). Three separate HTML files.**

Content:

- **Hook:** "Today's BTC risk score:"
- **Hero stat:** `0.42` in JetBrains Mono 700, very large (roughly 320px on 1:1, 360px on 4:5, 420px on 9:16). Color `#0F0F0F`.
- **Hero stat caption** (small, directly under the number): "Caution warranted, not panic."  — Inter 500, color `#52525B`
- **Body:** "Multi-factor model. Updated daily. Tracks volatility, on-chain flows, macro regime, and 12 other inputs."
- **CTA button:** "Reserve early access →"
- **Footer:** Arkline logo + wordmark left, `arkline.io` right

---

## PROMPT 2 — Concept #2 (Light Mode)

[Paste SHARED BRAND CONTEXT above]

**Generate light-mode HTML for Concept #2 in all three aspect ratios (1:1, 4:5, 9:16). Three separate HTML files.**

Content:

- **Hook:** "Stop investing on<br>influencer takes."
- **Accent line**
- **Body emphasis:** "Built by an investor tired of crypto Twitter noise."
- **Body muted:** "Multi-factor risk scoring. Macro regime detection. AI-generated briefings. For retail investors who want signal, not screaming."
- **Tagline (body emphasis):** "Arkline. Invest with conviction."
- **CTA button:** "Reserve early access →"
- **Footer:** Arkline logo + wordmark left, `arkline.io` right

This is a direct light-mode inversion of the dark-mode Concept #2 already shipped. Layout, hierarchy, and copy should be identical — only the palette changes.

---

## PROMPT 3 — Concept #5 (Light Mode)

[Paste SHARED BRAND CONTEXT above]

**Generate light-mode HTML for Concept #5 in all three aspect ratios (1:1, 4:5, 9:16). Three separate HTML files.**

Content:

- **Hero stat:** `150` in JetBrains Mono 700, very large (roughly 360px on 1:1, 420px on 4:5, 500px on 9:16). Color `#0F0F0F`.
- **Sub-hero:** "founding members." — Urbanist 800, smaller than the number but still display-size
- **Accent line**
- **Body emphasis:** "$39.99/mo for life."
- **Body muted:** "After that: $69.99 for the next 150. Then $99.99. Then closed."
- **Body emphasis (closer):** "If crypto Twitter exhausts you, this is for you."
- **CTA button:** "Reserve early access →"
- **Footer:** Arkline logo + wordmark left, `arkline.io` right

The "150" treatment should match the mono numeral direction we locked for the dark version — consistent typographic system across both palettes.

---

## Notes for the test

When these come back, save them alongside the dark versions:
```
/Arkline/ads/
├── concept-1_1x1.html          (dark — existing)
├── concept-1_1x1_light.html    (new)
├── concept-2_1x1.html          (dark — existing)
├── concept-2_1x1_light.html    (new)
└── ...
```

Test plan once dark ads have run ~2 weeks:
1. Identify highest-CTR / lowest-CPL dark concept
2. Pause all others
3. Launch light variant of that one concept alongside the dark winner
4. Equal budget split, 7-day run, $25/day each
5. Whichever palette wins becomes the standard going forward
