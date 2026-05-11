import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)

const LOOPS_API_KEY = process.env.LOOPS_API_KEY!

export async function POST(req: Request) {
  try {
    const body = await req.json()
    const email = body.email?.trim().toLowerCase()
    const referral_code = body.referral_code || null

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

    return NextResponse.json({ success: true }, { status: 200 })
  } catch (error) {
    console.error('Early access route error:', error)
    return NextResponse.json(
      { error: 'Something went wrong. Please try again.' },
      { status: 500 }
    )
  }
}
