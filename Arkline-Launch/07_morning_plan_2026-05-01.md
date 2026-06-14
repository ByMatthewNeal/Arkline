# Friday Morning Plan — 2026-05-01

**Start:** ~8:45am EST after school dropoff
**Total focused time:** ~2.5–3 hours
**Plus:** waiting periods you can't speed up (Apple, D-U-N-S, Stable mail forwarding)

---

## Pre-flight (5 min) — coffee check

Quick sanity checks before diving in.

- [ ] **Email check.** Open ImprovMX. Domain should be green / "Active" by now (DNS had all night to propagate). If still red, click CHECK AGAIN. If red after 30 minutes, ping me and we'll debug.
- [ ] **LLC check.** Look in your inbox for a confirmation from your filing service. You should have the **legal name**, **filing date**, and possibly a digital copy of the **Articles of Organization**.
- [ ] **Test inbound email.** From your phone (or any other email account), send a test email to `support@arkline.io`. Should land in your Gmail. If it does → email forwarding is fully working.

---

## Track 1: LLC follow-up (30–45 min)

The moment the LLC is officially formed, three things to chain in order. Each one unlocks the next.

### Step 1 — Apply for EIN (10 min)

- Go to **irs.gov/businesses/small-businesses-self-employed/apply-for-an-employer-identification-number-ein-online**
- Click "Apply Online Now"
- Available **Monday–Friday, 7am–10pm ET**, so plenty of time
- Choose: LLC → single-member (or multi if applicable) → state: Wyoming
- Most applications get the EIN issued **immediately** at the end of the form
- **Save the EIN confirmation letter as a PDF** — banks ask for it

### Step 2 — Open business bank account (15–30 min, can do online)

- Pick a bank. For a Wyoming LLC, common picks for online founders:
  - **Mercury** — startup-focused, no monthly fee, fully online, fast approval. Recommended.
  - **Relay** — similar to Mercury, also online-friendly
  - **Novo, Bluevine** — alternatives
  - Avoid traditional banks for now — they're slower and have monthly fees
- You'll need:
  - LLC legal name + EIN
  - Articles of Organization (PDF from your filing service)
  - Your driver's license / passport
  - Business address (you'll use the Stable address once you have it; for now your home is fine for the application)
- Approval is usually same-day or next-day for Mercury/Relay

### Step 3 — Sign up for Stable virtual mailbox (15–30 min)

- Go to **usestable.com**, create account, pick a city (Wyoming if you want to match the LLC, or anywhere else)
- Choose a plan ($25/mo Standard is fine for now)
- Fill out **USPS Form 1583** — Stable handles the online notarization right in the flow
- **List both names on Form 1583:** "Matthew Neal" AND "[YOUR LLC NAME] LLC"
- Address typically activates 1–2 business days after Form 1583 processes
- Once active, update your Mercury/Relay account with the new business address

---

## Track 2: Apple Developer Program enrollment (15 min to submit, then waiting)

Can run in parallel with Track 1 — you don't need the bank account or virtual mailbox before submitting these.

### Step 1 — Get a D-U-N-S Number (free, 1–5 business days)

- Go to **developer.apple.com/enrollment/duns-lookup/**
- Search for your LLC name; it likely won't exist yet
- Click "Request a D-U-N-S Number" — fill out the form with your LLC's legal name, address (home or Stable, doesn't matter — they're not picky), phone
- Free, takes 1–5 business days

### Step 2 — Apply for Apple Developer Program as Organization ($99/year, 1–7 business days)

- Go to **developer.apple.com/programs/enroll/**
- Choose "Organization" (NOT Individual)
- You'll need:
  - LLC legal name (must match D-U-N-S exactly)
  - D-U-N-S Number (have it ready)
  - Business contact info
  - Authority to bind the company (you, since you're sole member)
- $99 USD annually
- Apple typically approves in 1–7 business days. May call your business phone for verification — **make sure that phone is monitored** so you don't miss the call

> **Schedule risk:** If both D-U-N-S and Apple Dev approval take their max time (5 + 7 = 12 business days), that's about 2.5 weeks from today. The Unlisted App Distribution request adds another few days after. So realistic earliest submission to App Review: ~3 weeks out.

---

## Track 3: Documents & app prep — 1 hour with me

Once Track 1 is done and you have the LLC name + EIN + Stable address (or at least the Stable application started), come back to chat with me. We'll knock these out together:

- [ ] **Fill in Privacy Policy placeholders** — replace `[LLC LEGAL NAME]`, `[STATE OF LLC]` (Wyoming), `[BUSINESS ADDRESS]` (Stable), `[PRIVACY EMAIL]` (privacy@arkline.io). 5 min find-and-replace.
- [ ] **Fill in Terms of Service placeholders** — same exercise. Pick refund policy Option A as decided. 5 min.
- [ ] **Publish privacy/terms to arkline.io** — host at arkline.io/privacy and arkline.io/terms. I'll help draft the Next.js page files for the web repo.
- [ ] **Set up Apple Reviewer demo account** in Supabase. Permanent, fully active member account so Apple's reviewers can log in and use the app. I'll help with the SQL.
- [ ] **Have an attorney scheduled to review** the legal docs before publishing. Recommended even if it slows you down — financial-app + AI-content liability is non-trivial. LegalZoom, Rocket Lawyer, or a Wyoming small-business attorney all work; a 30-minute review of these templates should run $200–500.

---

## Track 4: Email finalization (10–15 min, do whenever)

Now that you have ImprovMX Premium, finish the Gmail "Send mail as" integration so replies come from `support@arkline.io` and `privacy@arkline.io`, not your Gmail.

- [ ] In ImprovMX, find your domain's **SMTP credentials** (under domain settings — should be a new "SMTP" tab now that you have premium). Note the server (`smtp.improvmx.com`), port, username, password.
- [ ] Gmail → ⚙️ Settings → "See all settings" → **Accounts and Import** → "Send mail as" → **Add another email address**
  - Name: "Arkline Support" (or "Matthew Neal" — your choice)
  - Email: `support@arkline.io`
  - Uncheck "Treat as an alias" if you want replies to default to coming from support@
  - SMTP server: `smtp.improvmx.com`, port `587`
  - Username + password from ImprovMX
- [ ] Gmail sends a verification code to `support@arkline.io` — should arrive in your Gmail inbox within seconds via the forwarding. Click the link to confirm.
- [ ] Repeat for `privacy@arkline.io`

After this, when composing in Gmail you'll have a "From" dropdown letting you choose which address to send as.

---

## Things you DON'T need to do tomorrow

To keep the day focused, some things are deliberately deferred:

- ❌ Don't render App Store screenshots yet — we have the spec, but no point doing this until app review is days away
- ❌ Don't write launch-day social copy / emails — same reason
- ❌ Don't update the website pricing math ($400 → $399.99) — that's irrelevant under invite-only/Stripe model
- ❌ Don't worry about the unfinished SECURITY_AUDIT.md update — small cleanup, can wait

---

## Status by end of day Friday — realistic targets

If everything goes smoothly:

✅ LLC formed (legal name confirmed)
✅ EIN issued
✅ Business bank account opened (or in approval pipeline)
✅ Stable mailbox application submitted (address activates Mon/Tue)
✅ D-U-N-S request submitted (number arrives next week)
✅ Apple Developer Program enrollment submitted (approval next week)
✅ Privacy policy + Terms of Service finalized with real LLC info
✅ Email fully working including send-from-arkline.io via Gmail
✅ Apple Reviewer demo account ready in Supabase

**Status by next Friday (2026-05-08):** All approvals likely in. Ready to file Unlisted App Distribution request and start app review prep in earnest.

---

## When you wake up

Skim this doc, then jump into Pre-flight first. Ping me back in chat when:
- LLC is formed and you have the legal name, OR
- Anything's blocked / unclear, OR
- You need help with the document placeholder fill-in

Otherwise just work down the list. You've got this.
