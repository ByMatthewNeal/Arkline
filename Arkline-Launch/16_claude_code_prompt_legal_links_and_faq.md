# Claude Code Prompt — Add Privacy/Terms Links to About + Fix FAQ "Pro Subscribers" Copy

Copy everything below the `---` line and paste into Claude Code as a single prompt. Two small fixes flagged in the pre-ship audit, both required for Apple App Review.

---

# Task

Two App-Review-critical fixes:

**Part A: Add in-app Privacy Policy and Terms of Service links to the About view.** Apple frequently rejects apps for missing in-app legal links. The pages already exist at `https://arkline.io/privacy` and `https://arkline.io/terms` — just need them surfaced.

**Part B: Fix misleading "Pro subscribers" copy in the FAQ.** Per `CLAUDE.md`, ArkLine has a single subscription tier — no Pro/free split. The current FAQ entry implies a tiered paywall that doesn't exist, which is both misleading copy and a potential App Review red flag (Apple looks for accurate descriptions of in-app paywalls; we have none).

---

## Part A: Privacy + Terms links in `AboutView`

### File involved

- `ArkLine/Features/Settings/Views/AboutView.swift`

### Current state

The `AboutView` is a clean centered card with app icon, name, version, tagline, and copyright. There are NO tappable links to legal pages. The Settings flow gets here via Settings → About.

### Change

Add a section with two link rows below the copyright block (before the final `Spacer()` or as a new VStack section above the bottom safe area). Each row should:

- Be tappable, opening the URL in Safari (use `Link(destination:)` so the user gets the system handling — taps either open in-app SFSafariViewController or Safari depending on user preference).
- Match the existing visual rhythm of the About view (use the same `AppFonts.body14` or similar, `AppColors.accent` for the link color to make tap-affordance clear).
- Use Tabler-style icons or SF Symbols at small size (~14pt) — e.g., `lock.shield` for privacy, `doc.text` for terms.

Suggested implementation, placed inside the existing VStack after the copyright block, separated by a small `Spacer().frame(height: 24)`:

```swift
VStack(spacing: 12) {
    Link(destination: URL(string: "https://arkline.io/privacy")!) {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 14))
            Text("Privacy Policy")
                .font(AppFonts.body14)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11))
        }
        .foregroundColor(AppColors.accent)
    }

    Link(destination: URL(string: "https://arkline.io/terms")!) {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 14))
            Text("Terms of Service")
                .font(AppFonts.body14)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11))
        }
        .foregroundColor(AppColors.accent)
    }
}
.padding(.top, 24)
```

Note: the force-unwrap on `URL(string:)` is acceptable here because the URLs are static literals — but if your linter complains, use `URL(string: "...")!` or fall back to a `if let url = URL(string: ...) { Link(...) }` guard.

### Part A test plan

1. Build and run.
2. Settings → About.
3. Two new tappable links visible: "Privacy Policy" and "Terms of Service", in accent blue.
4. Tap "Privacy Policy" → opens `arkline.io/privacy` in Safari (or in-app browser if user has that preference).
5. Tap "Terms of Service" → opens `arkline.io/terms`.
6. Visual styling is consistent with the rest of the About view — not cramped, not floating, matches the existing centered layout.

---

## Part B: Fix FAQ copy

### File involved

- `ArkLine/Features/Settings/Views/FAQView.swift`

### Current state (line 16)

```swift
FAQItem(question: "What are Risk Coins?", answer: "Risk Coins let you choose which assets display risk level widgets on your Home Screen. BTC is available for all users, and Pro subscribers can add additional coins like ETH. Go to Settings > Risk Coins to customize."),
```

The "**Pro subscribers can add additional coins like ETH**" clause is misleading. Per `CLAUDE.md` ("Business Model" section), ArkLine has a single subscription tier — all paying users have full access. There is no Pro tier and no free tier. This copy describes a paywall that doesn't exist.

### Change

Replace the entire answer string with:

```swift
"Risk Coins let you choose which assets display risk level widgets on your Home Screen. You can pick any combination of supported crypto and stocks. Go to Settings > Risk Coins to customize."
```

The new copy:
- Drops the "Pro subscribers" reference entirely.
- Drops the "BTC is available for all users" framing (which implies BTC is the free-tier-only option — also misleading).
- Stays true to the actual product behavior: any authenticated user can pick any supported asset.

### Part B test plan

1. Build and run.
2. Settings → FAQ (wherever the FAQ surfaces from).
3. Find "What are Risk Coins?" entry — expand it.
4. Confirm the new copy renders, no "Pro subscribers" reference anywhere.

---

## Search for other "Pro" / "premium" / "upgrade" copy leaks (bonus)

While you're in the codebase, run a quick sweep for other places that might imply tiering. Grep these patterns and review any hits:

- `"Pro subscribers"`
- `"Pro members"`
- `"Pro plan"`
- `"Upgrade to"`
- `"premium subscribers"`
- `"premium plan"`
- `"unlock"` (in user-facing copy, not in code logic)
- `"free trial"` (where it implies the user is currently on a free tier — context-dependent)

For each hit:
- If it's UI copy that implies tiering: rewrite to match the single-tier model.
- If it's an internal model field name (like `User.role == .premium`), leave alone — those are scaffolding per CLAUDE.md.

Report all findings even if you don't fix them — I want to see what's still in the codebase.

---

## Out of scope (do NOT do)

- Do not change `User.role` enum cases (`.premium` stays as forward-compatible scaffolding).
- Do not modify `isPremium` or `isPro` properties — those are intentional.
- Do not add "Open Source Licenses" or "Acknowledgements" sections (separate task, post-launch).
- Do not change the existing Settings > Privacy section (the analytics toggle stays).
- Do not modify or remove the Stripe Payment Link admin UI — admin-only views are gated correctly.

## Reporting

Briefly:

1. Files modified, line ranges.
2. List of any other "Pro/premium/upgrade" copy hits found in the bonus sweep, with file:line and decision (fixed or left alone).
3. Build status.
4. Screenshots of: (a) the updated About view showing the legal links, (b) the FAQ entry with the updated answer.

Keep it under 200 words.
