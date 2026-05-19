import { createClient } from '@supabase/supabase-js';

const BASELINE_COUNT = 87;
const CACHE_TTL_MS = 60_000; // 60 seconds

let cachedCount: number | null = null;
let cachedAt = 0;

/**
 * Returns the current early-access signup count from Supabase.
 * Caches for 60 seconds. Falls back to BASELINE_COUNT on any error.
 * Safe to call from server components and API routes.
 */
export async function getSignupCount(): Promise<number> {
  const now = Date.now();
  if (cachedCount !== null && now - cachedAt < CACHE_TTL_MS) {
    return cachedCount;
  }

  try {
    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    );

    const { count, error } = await supabase
      .from('early_access_signups')
      .select('*', { count: 'exact', head: true });

    if (error || count === null) {
      return cachedCount ?? BASELINE_COUNT;
    }

    cachedCount = count;
    cachedAt = now;
    return count;
  } catch {
    return cachedCount ?? BASELINE_COUNT;
  }
}

export const TOTAL_SPOTS = 150;
export const SOCIAL_PROOF_THRESHOLD = 250;
