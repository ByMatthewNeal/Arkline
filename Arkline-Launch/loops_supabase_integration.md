# Arkline — Supabase → Loops Integration

> **Goal:** When a new email lands in `early_access_signups`, automatically add the contact to Loops, which triggers the "Welcome - Early Access" workflow.
> **Date:** 2026-05-10

---

## The Architecture (and why)

**Current setup:** Your React component (`web/src/components/marketing/email-capture.tsx`) calls Supabase JS client directly to insert into `early_access_signups`. The Supabase row appears in your admin app immediately. ✅

**What we're adding:** A Next.js API route that the React component will call. The API route does the Supabase insert AND adds the contact to Loops in one server-side step. This keeps your Loops API key off the browser (critical — exposing it in client code would let anyone send emails as Arkline).

**Why an API route instead of just adding `fetch` to the React component:**
- Loops API key must stay server-side. Period.
- Centralizes signup logic — easier to add validation, rate limiting, spam protection later.
- One transactional unit: Supabase insert + Loops add happen together.

---

## Step 1: Add environment variable

In your Next.js project, add to `.env.local` (for local dev) and your Vercel project settings (for production):

```
LOOPS_API_KEY=<your_loops_api_key_here>
```

Get the key from Loops Settings → API. **Do NOT commit it to git.** `.env.local` should be in `.gitignore` (default for Next.js).

For Vercel:
1. Go to your project on Vercel
2. Settings → Environment Variables
3. Add `LOOPS_API_KEY` with the value
4. Apply to: Production, Preview, Development

---

## Step 2: Create the API route

**Assuming you're using Next.js App Router** (the modern default — files live under `src/app/`).

Create this file:

**`web/src/app/api/early-access/route.ts`**

```typescript
import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

// Server-side Supabase client using service role key
// (gives bypass-RLS access, server-only)
const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!  // server-only key
)

const LOOPS_API_KEY = process.env.LOOPS_API_KEY!

export async function POST(req: Request) {
  try {
    const body = await req.json()
    const email = body.email?.trim().toLowerCase()
    const referral_code = body.referral_code || null

    // Basic validation
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return NextResponse.json(
        { error: 'Please provide a valid email address.' },
        { status: 400 }
      )
    }

    // 1. Insert into Supabase
    const { error: dbError } = await supabaseAdmin
      .from('early_access_signups')
      .insert({ email, referral_code })

    if (dbError) {
      // Unique constraint violation (already on list)
      if (dbError.code === '23505') {
        return NextResponse.json(
          { error: "You're already on the list — check your inbox." },
          { status: 409 }
        )
      }
      console.error('Supabase insert error:', dbError)
      return NextResponse.json(
        { error: 'Could not save your signup. Please try again.' },
        { status: 500 }
      )
    }

    // 2. Add contact to Loops (fires the Welcome workflow)
    // We don't fail the signup if this errors — Supabase is source of truth
    try {
      const loopsResp = await fetch('https://app.loops.so/api/v1/contacts/create', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${LOOPS_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          email,
          source: 'arkline.io early access',
          userGroup: 'Early Access',
          ...(referral_code && { referralCode: referral_code }),
        }),
      })

      if (!loopsResp.ok) {
        const text = await loopsResp.text()
        console.error('Loops API non-OK response:', loopsResp.status, text)
      }
    } catch (loopsError) {
      // Log but don't fail the signup — we can backfill Loops manually if needed
      console.error('Loops API request failed:', loopsError)
    }

    return NextResponse.json({ success: true }, { status: 200 })
  } catch (error) {
    console.error('Early access route error:', error)
    return NextResponse.json(
      { error: 'Something went wrong. Please try again.' },
      { status: 500 }
    )
  }
}
```

---

## Step 3: Update the React component

**`web/src/components/marketing/email-capture.tsx`**

Find the existing Supabase insert (around line 47-49):

```typescript
const { error } = await supabase
  .from('early_access_signups')
  .insert(insertData);
```

Replace it with a call to your new API route:

```typescript
const response = await fetch('/api/early-access', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(insertData),
})

const result = await response.json()

if (!response.ok) {
  // result.error contains the user-friendly message
  // Show this in your existing error UI
  setError(result.error || 'Something went wrong. Please try again.')
  return
}

// Success — show your existing success state
setSuccess(true)
```

(Adjust the variable names like `setError`, `setSuccess` to match what your component actually uses for state.)

---

## Step 4: Check your Supabase env vars

Your `.env.local` should already have:

```
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJh...
SUPABASE_SERVICE_ROLE_KEY=eyJh...   # <-- make sure this exists, server-only
```

If `SUPABASE_SERVICE_ROLE_KEY` isn't set:
1. Go to Supabase Dashboard → Project Settings → API
2. Copy the `service_role` key (NOT the anon key — service role bypasses RLS)
3. Add to `.env.local` and Vercel env vars

⚠️ **NEVER expose the service role key in client code.** It can read/write your entire database. The `SUPABASE_` prefix (without `NEXT_PUBLIC_`) keeps it server-side only.

---

## Step 5: Test locally before deploying

1. `npm run dev` in your web directory
2. Open `http://localhost:3000` and submit the form with a test email (use one you can check)
3. Verify three things:
   - ✅ Row appears in Supabase `early_access_signups` table
   - ✅ Contact appears in Loops → Audience
   - ✅ Welcome email arrives in your inbox within ~30 seconds

If any step fails, check:
- Browser console (network tab) for the API response
- Vercel/Next.js server logs (`npm run dev` terminal output)
- Loops dashboard → Audience → check if the contact was added
- Loops dashboard → Workflows → "Welcome - Early Access" → check Activity / Runs

---

## Step 6: Deploy and activate the workflow

1. Commit + push → Vercel auto-deploys
2. Test the live form on arkline.io with a real signup
3. Confirm welcome email arrives
4. Go to Loops → Workflows → "Welcome - Early Access" → click **Start** (activates the workflow)

Once Start is clicked, every contact added to Loops will trigger the welcome email. Including the 22 existing signups in your Supabase if you decide to import them — see "Backfilling existing signups" below.

---

## Backfilling existing 22 signups

Your 22 existing early-access signups aren't in Loops yet. To get them on the welcome sequence:

**Option A — Manual import via CSV:**
1. Supabase Dashboard → `early_access_signups` table → Export as CSV
2. Loops → Audience → Import → CSV → email column
3. After import, contacts get the welcome email IF the workflow is set to fire on "Contact Added" (which it is)

**Option B — Skip the welcome for existing 22, only send to new signups:**
Either:
- Activate the workflow only AFTER importing existing contacts (with workflow paused, contacts join silently)
- Or send the 22 a separate one-off campaign explaining what's coming

I'd recommend **Option A with the workflow active** — those 22 people signed up weeks ago and deserve the welcome email they never got. Just send Matt's note to them too.

---

## Things NOT to do

- ❌ Don't put `LOOPS_API_KEY` in any file prefixed with `NEXT_PUBLIC_` — that exposes it to the browser
- ❌ Don't commit `.env.local` to git
- ❌ Don't use the Loops API key in the React component directly, even with `try/catch`
- ❌ Don't activate the workflow until the company address is fixed (Stable mailbox or verified Republic TOS)

---

## What changes when you switch to live trial signups (post-launch)

When the iOS app launches and the signup form becomes a Stripe trial signup (instead of email-only):

1. Add another field to the API route for `name`, `stripe_customer_id`
2. Update the Loops contact with those properties for richer segmentation
3. Add a second Loops workflow for "Trial Started" triggered by a different event/property
4. The welcome workflow can stay as the first email everyone gets

Code is structured to make this easy — just expand the JSON sent to Loops with more fields.
