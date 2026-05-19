import { NextResponse } from 'next/server';
import { getSignupCount, TOTAL_SPOTS, SOCIAL_PROOF_THRESHOLD } from '@/lib/signup-count';

export const runtime = 'edge';

export async function GET() {
  const signupCount = await getSignupCount();
  const spotsRemaining = Math.max(0, TOTAL_SPOTS - signupCount);
  const showSocialProof = signupCount >= SOCIAL_PROOF_THRESHOLD;

  return NextResponse.json(
    { signupCount, spotsRemaining, showSocialProof },
    { headers: { 'Cache-Control': 's-maxage=60, stale-while-revalidate=30' } }
  );
}
