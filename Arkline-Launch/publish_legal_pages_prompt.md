# Claude Code Prompt — Publish Privacy + Terms to arkline.io

> **When to use:** The moment you receive Stable's "ID verification approved" email (1–3 business days from 2026-05-11).
> **Why wait:** The privacy + terms drafts now reference your Stable address. If you publish before Stable can accept mail in your name, any inbound legal/regulatory mail would bounce. The wait is conservative but worth it.
> **Time to run:** ~10–15 minutes including Claude Code's review and your final approval.

---

## How to use this prompt

1. Open Claude Code in your terminal
2. `cd ~/Arkline` (or wherever your monorepo root is)
3. Paste the entire prompt block below
4. Review the diff Claude Code proposes before approving
5. After it commits and pushes, verify the live site updates at arkline.io/privacy and arkline.io/terms

---

## The prompt

```
I need to publish the updated Arkline privacy policy and terms of service to the live arkline.io site. The source-of-truth markdown files have already been updated with finalized legal details — please sync the live Next.js pages to match.

Source files (already updated, treat as canonical — do not modify these):
- /Users/matt/Documents/Arkline-Launch/05_privacy_policy.md
- /Users/matt/Documents/Arkline-Launch/06_terms_of_service.md

Target: the privacy and terms pages in the arkline.io Next.js project, likely at:
- web/src/app/privacy/page.tsx
- web/src/app/terms/page.tsx

If those paths don't exist, search the project for files containing "Privacy Policy" or "Terms of Service" — the pages might live elsewhere (e.g., under app/(legal)/, or as MDX files in content/, or hardcoded inside another component). Find the actual files before editing.

Tasks:

1. Locate the existing privacy and terms pages. Confirm they render at /privacy and /terms by inspecting the routing structure.

2. Inspect each page's current rendering pattern (raw JSX strings, MDX import, markdown rendered through react-markdown, etc.). Match that pattern when applying the new content — do NOT rewrite the page structure.

3. Replace ONLY the legal content with the content from the source markdown files. Preserve all of the following:
   - Existing page-level layout components (header, footer, nav, container wrappers)
   - Typography/styling utilities (Tailwind classes, prose classes, etc.)
   - SEO metadata exports (generateMetadata, export const metadata)
   - Any breadcrumbs or related UI

4. Fill in the [DATE TO PUBLISH] and [SAME AS ABOVE] placeholders with today's date in "Month DD, YYYY" format (e.g., "May 14, 2026"). Use the actual current date at the time you make the commit.

5. Preserve these placeholders exactly as they appear (they're awaiting attorney review):
   - "[CITY, STATE]" in Section 13 of terms_of_service.md
   - "[ARBITRATION CLAUSE — review with attorney before publishing...]" block in Section 13

6. Remove the "Drafting notes" sections at the bottom of both source files — these are internal notes, not part of the published documents. They start with "> **Drafting notes (delete before publishing):**" and should NOT appear on the live site.

7. Remove the top "Note for review" block from each source file when publishing. These start with "> **Note for review (delete before publishing):**".

8. Run available checks before committing:
   - npm run lint (or pnpm/yarn equivalent)
   - npm run typecheck (or tsc --noEmit if no script)
   - npm run build to confirm the pages render

9. Commit with this exact message:
   docs: update privacy policy and terms with Stable address and finalized legal details

10. Push to main.

After pushing, tell me:
- Which files you modified
- Any placeholders you preserved (should be only the arbitration clause + city/state)
- Any lint/typecheck/build warnings or errors
- The commit hash
```

---

## What to verify after Claude Code runs

When the deploy finishes (Vercel usually takes 1–2 minutes), open both pages live and check:

- [ ] **arkline.io/privacy** loads without errors
- [ ] **arkline.io/terms** loads without errors
- [ ] Both show today's date as "Last updated" and "Effective date"
- [ ] Both show your Stable address: `1908 Thomes Ave STE 63374, Cheyenne, WY 82001`
- [ ] Both use `Arkline Technologies LLC` as the legal name
- [ ] Privacy contact email is `privacy@arkline.io`
- [ ] Terms contact email is `support@arkline.io`
- [ ] Section 13 of terms still shows `[CITY, STATE]` and the arbitration placeholder (these are deliberate — attorney review pending)
- [ ] No "Drafting notes" or "Note for review" text appears on either live page
- [ ] Footer links to /privacy and /terms still work

If anything looks wrong, tell me what you see and we'll fix it.

---

## What happens after this is published

Once these pages are live with your Stable address, the next sequence is:

1. **Loops Company Address** swap (Settings → Domain → Company Address → Stable)
2. **D&B record update** via https://iupdate.dnb.com — swap home address to Stable
3. **Activate the Loops welcome workflow** — click Start on "Welcome - Early Access"
4. **Run the 22-signup CSV import** in Loops (existing waitlist members get the welcome email)
5. Welcome emails are now live for all new signups going forward 🎉

This is the "we are now operationally live for marketing" moment. Worth taking 30 seconds to acknowledge before plowing into the next thing.
