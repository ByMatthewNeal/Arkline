import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { createHash, randomUUID } from 'crypto'

const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)

const LOOPS_API_KEY = process.env.LOOPS_API_KEY!
const META_PIXEL_ID = process.env.NEXT_PUBLIC_META_PIXEL_ID
const META_CAPI_ACCESS_TOKEN = process.env.META_CAPI_ACCESS_TOKEN

/**
 * SHA-256 hash for Meta CAPI user_data fields.
 * Email is already lowercased + trimmed before this is called.
 */
function hashForMeta(value: string): string {
  return createHash('sha256').update(value).digest('hex')
}

export async function POST(req: Request) {
  try {
    const body = await req.json()
    const email = body.email?.trim().toLowerCase()
    const referral_code = body.referral_code || null
    const utm_source = body.utm_source || null
    const utm_medium = body.utm_medium || null
    const utm_campaign = body.utm_campaign || null
    const utm_content = body.utm_content || null
    const utm_term = body.utm_term || null

    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return NextResponse.json(
        { error: 'Please provide a valid email address.' },
        { status: 400 }
      )
    }

    // 1. Insert into Supabase
    const { error: dbError } = await supabaseAdmin
      .from('early_access_signups')
      .insert({ email, referral_code, utm_source, utm_medium, utm_campaign, utm_content, utm_term })

    if (dbError) {
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
      console.error('Loops API request failed:', loopsError)
    }

    // 3. Fire server-side Lead event to Meta Conversions API
    // Adds 20-30% conversion measurement accuracy post-iOS14 by bypassing
    // browser-level tracking restrictions. Non-blocking — Supabase is source of truth.
    if (META_PIXEL_ID && META_CAPI_ACCESS_TOKEN) {
      try {
        const forwardedFor = req.headers.get('x-forwarded-for')
        const clientIp = forwardedFor?.split(',')[0]?.trim() || undefined
        const userAgent = req.headers.get('user-agent') || undefined
        const referer = req.headers.get('referer') || 'https://arkline.io'

        const capiResp = await fetch(
          `https://graph.facebook.com/v18.0/${META_PIXEL_ID}/events?access_token=${META_CAPI_ACCESS_TOKEN}`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              data: [
                {
                  event_name: 'Lead',
                  event_time: Math.floor(Date.now() / 1000),
                  event_id: randomUUID(),
                  action_source: 'website',
                  event_source_url: referer,
                  user_data: {
                    em: [hashForMeta(email)],
                    ...(clientIp && { client_ip_address: clientIp }),
                    ...(userAgent && { client_user_agent: userAgent }),
                  },
                },
              ],
            }),
          }
        )

        if (!capiResp.ok) {
          const text = await capiResp.text()
          console.error('Meta CAPI non-OK response:', capiResp.status, text)
        }
      } catch (capiError) {
        console.error('Meta CAPI request failed:', capiError)
      }
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
