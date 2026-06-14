# Ad Creative Production Brief — Concept #2

> **Concept:** "Stop investing on influencer takes." Anti-influencer static. Lowest production lift in the launch set.
> **Tool:** Figma or Canva. Either works. Figma if you want pixel control; Canva if you want speed.
> **Time budget:** 20–30 min for the first aspect ratio, then duplicate + adjust for the other two (another 15–20 min).

---

## The deliverables

You need **3 aspect ratios** of the same ad:

| Format | Dimensions | Used for |
|---|---|---|
| **1:1 (Square)** | 1080 × 1080 | Feed (Facebook, Instagram) |
| **4:5 (Portrait)** | 1080 × 1350 | Feed (often outperforms 1:1) |
| **9:16 (Vertical)** | 1080 × 1920 | Stories, Reels, full-screen mobile |

Export each as PNG (or JPG at quality 90+). File naming: `arkline_concept-2_1x1_v1.png`, `arkline_concept-2_4x5_v1.png`, `arkline_concept-2_9x16_v1.png`.

---

## Copy (use exactly this)

### Headline (the hook)
```
Stop investing on
influencer takes.
```

(Break on two lines for visual rhythm. The period at the end is important — it makes the statement feel final.)

### Body copy (smaller, below hook)
```
Built by an investor tired of crypto Twitter noise.

Multi-factor risk scoring. Macro regime detection.
AI-generated briefings. For retail investors who
want signal, not screaming.

Arkline. Invest with conviction.
```

### CTA (button mock or just text)
```
Reserve early access →
```

(Mock the button — you don't need a real interactive button since the actual click target is on Meta's ad UI. Just visually represent it.)

---

## Visual style

### Look-and-feel
- **Penguin Random House book cover meets terminal financial software.**
- Pure dark background. White text. One small accent. No imagery, no people, no stock photos.
- Should feel **confident, quiet, and slightly defiant.** Like a Bloomberg subscription, not a crypto pump.

### Color palette (pull from arkline.io)
- **Background:** the same dark navy / near-black you use on the website. Check your existing Tailwind config or just eyedrop from arkline.io. Common values would be something like `#0A0E1A` or `#0F1115`.
- **Primary text:** Pure white (#FFFFFF) or off-white (#F5F5F5)
- **Body text:** Slightly muted (#A0A8B5 or similar gray)
- **Accent (optional):** The same blue/purple gradient your homepage uses on the word "informed." Use sparingly — maybe on one period, the CTA arrow, or a small horizontal line.

### Typography
- **Hook headline:** Use the same display font your homepage hero uses for "The market rewards the informed." Large, tight letter-spacing.
- **Body:** Use your body font (Inter or Urbanist — whatever your site uses). Regular weight.
- **CTA:** Medium weight, slightly smaller than hook.

If you don't know the exact font names, eyedrop / inspect your website to confirm:
- Open arkline.io
- Right-click → Inspect → click the hero text → Computed tab → look at `font-family`

---

## Layout direction (per aspect ratio)

### 1:1 Square (1080 × 1080)

```
┌────────────────────────┐
│                        │
│                        │
│   Stop investing on    │
│   influencer takes.    │  ← Hook, large, centered or left-aligned
│                        │
│   ─────                │  ← Optional thin horizontal accent line
│                        │
│   Built by an investor │
│   tired of crypto      │  ← Body copy, smaller, comfortable line height
│   Twitter noise.       │
│                        │
│   Multi-factor risk... │
│   ...                  │
│                        │
│   Arkline. Invest      │
│   with conviction.     │
│                        │
│                        │
│   [Reserve early       │
│    access →]           │  ← CTA, button mock or text
│                        │
│   ◇ arkline.io         │  ← Logo + URL, bottom corner
└────────────────────────┘
```

**Margins:** ~80–100px padding from edges. Don't cram to the edge — let it breathe.

### 4:5 Portrait (1080 × 1350)

Same layout as 1:1, but you have more vertical space. Push the hook up slightly (35% from top) and let the body have more room to breathe. The extra height makes the design feel more premium.

### 9:16 Vertical (1080 × 1920)

For Stories/Reels. Two design choices to make:

**Option A — same layout, scaled vertically:**
Use the same layout as 1:1 but stretched. Lots of empty space top and bottom. Looks intentional.

**Option B — split-screen:**
- Top 60%: Hook (extra large, centered)
- Bottom 40%: Body + CTA + logo

I'd go with **Option A** for first iteration — less design work, looks cleaner. Save Option B for v2 testing.

---

## Production checklist

Before exporting, verify each variant:

- [ ] **Background:** matches arkline.io exactly (eyedrop to confirm)
- [ ] **Hook:** "Stop investing on influencer takes." — exactly this text, period at end
- [ ] **Body copy:** matches the script above, no typos, line breaks intentional
- [ ] **No emojis, no exclamation points** anywhere
- [ ] **CTA:** "Reserve early access →" (the arrow is part of the button)
- [ ] **Logo placement:** small, bottom of frame, not competing with the hook
- [ ] **Text contrast:** white-on-dark, AAA readable on mobile
- [ ] **Hook is readable in <3 seconds** on a small phone screen (do the "squint test" — squint your eyes; can you still read the hook? If not, make it bigger)
- [ ] **No third-party logos** (your X handle going on arkline.io ≠ X logo on the ad — keep it clean)

---

## Common mistakes to avoid

1. **Adding too many elements.** Resist the urge to add decorative shapes, icons, or visual flourishes. The power of this ad is its restraint. White text on black with one accent line = more sophisticated than anything with stock graphics.

2. **Using exclamation points or hype words.** "Stop investing on influencer takes!!!" reads as desperate. The period reads as authoritative.

3. **Making the body copy too small.** People will read it. ~36–44pt on a 1080-wide canvas (so ~3.5% of canvas width) is a good starting point. Use Figma/Canva's preview at "actual size" to confirm.

4. **Forgetting the period.** "Stop investing on influencer takes." vs "Stop investing on influencer takes" — the period changes the tone from a fragment to a declaration. Keep it.

5. **Going too dark.** If the background is too close to pure black, it'll get crushed on cheap phone screens. Aim for very dark navy / charcoal, not pure #000.

---

## Once exported

1. Drop the three files (1:1, 4:5, 9:16) into a `/ad-assets` folder somewhere accessible (Google Drive, Dropbox, or `~/Documents/Arkline-Launch/ads/`)
2. Note the filenames in the ad creative concepts doc so future-you remembers
3. We'll upload them to Meta Ads Manager when we get to campaign setup

---

## Variants to ship later (after the first 3 are done)

When you have time:
- **Variant 1B:** Same layout but different hook — "The market doesn't reward the loudest. It rewards the informed."
- **Variant 1C:** Same layout but different hook — "Crypto Twitter is not your strategy."

A/B testing 2–3 hook variants on the same visual template is the fastest way to find your highest-converting line.

---

## If you get stuck

Three escape hatches:

1. **Pull a Figma template.** Search "minimalist ad" or "Bloomberg-style" on Figma Community — find a layout you like, replace the copy and colors with yours.
2. **Hire someone on Fiverr/Upwork.** $30–80 for the three aspect ratios. Send them this brief. Done in 24 hours.
3. **Ship a "good enough" v1 today, iterate later.** Don't let perfect be the enemy of shipped. The hook does most of the work; the layout just needs to not get in the way.
