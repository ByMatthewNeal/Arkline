import { createClient } from '@/lib/supabase/client';
import type { OnboardingData } from '@/lib/onboarding/config';

// ── Invite code validation (mirrors iOS InviteCodeService.validateCode) ──────

export interface InviteValidationResult {
  ok: boolean;
  error?: string;
  code?: string;
  email?: string | null;
}

const INVITE_PREFIX = 'ARK-';

export function isInviteFormatValid(raw: string): boolean {
  const cleaned = raw.toUpperCase().trim();
  return cleaned.startsWith(INVITE_PREFIX) && cleaned.length >= 10;
}

export async function validateInviteCode(raw: string): Promise<InviteValidationResult> {
  const code = raw.toUpperCase().trim();
  if (!isInviteFormatValid(code)) {
    return { ok: false, error: 'Enter a valid invite code (ARK-XXXXXX).' };
  }

  const supabase = createClient();
  const { data, error } = await supabase
    .from('invite_codes')
    .select('code, used_by, expires_at, is_revoked, payment_status, email')
    .eq('code', code)
    .limit(1)
    .maybeSingle();

  if (error) return { ok: false, error: 'Could not verify the code. Please try again.' };
  if (!data) return { ok: false, error: 'This invite code does not exist.' };

  const invalidReason =
    data.used_by ? 'This invite code has already been used.'
    : data.is_revoked ? 'This invite code has been revoked.'
    : data.payment_status === 'pending_payment' ? 'This invite is awaiting payment. Use the link from your invite email first.'
    : data.expires_at && new Date(data.expires_at) < new Date() ? 'This invite code has expired.'
    : null;

  if (invalidReason) return { ok: false, error: invalidReason };

  return { ok: true, code, email: data.email };
}

// ── Complete onboarding (persist profile, redeem invite, activate) ───────────

export interface CompleteResult {
  ok: boolean;
  error?: string;
}

export async function completeOnboarding(data: OnboardingData): Promise<CompleteResult> {
  const supabase = createClient();

  const { data: userData, error: userErr } = await supabase.auth.getUser();
  const user = userData?.user;
  if (userErr || !user) return { ok: false, error: 'Your session expired. Please sign in again.' };

  const email = user.email ?? '';
  const inviteCode = (user.user_metadata?.invite_code as string | undefined) ?? null;
  const fullName = `${data.firstName} ${data.lastName}`.trim();
  const username = email.split('@')[0] || 'user';

  // Persist the profile. subscription_status is set to active to match the iOS
  // single-tier model (payment already happened upstream via the paid invite).
  const { error: profileErr } = await supabase.from('profiles').upsert({
    id: user.id,
    email,
    username,
    full_name: fullName,
    experience_level: data.experienceLevel,
    onboarding_data: {
      interests: data.interests,
      portfolio_size: data.portfolioSize,
      crypto_approach: data.cryptoApproach,
      goals: data.goals,
    },
    onboarding_complete: true,
    subscription_status: 'active',
    is_active: true,
  }, { onConflict: 'id' });

  if (profileErr) return { ok: false, error: profileErr.message };

  // Redeem the invite code (best-effort — don't block completion).
  if (inviteCode) {
    await supabase
      .from('invite_codes')
      .update({ used_by: user.id, used_at: new Date().toISOString() })
      .eq('code', inviteCode)
      .is('used_by', null);
  }

  return { ok: true };
}
