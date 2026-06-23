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

// ── Payment state ────────────────────────────────────────────────────────────

export interface OnboardingState {
  isActive: boolean;   // subscription active or trialing
  hasInvite: boolean;  // arrived with a (paid) invite code → no in-flow payment
  needsPayment: boolean;
}

const ACTIVE_STATUSES = new Set(['active', 'trialing']);

export async function getOnboardingState(): Promise<OnboardingState> {
  const supabase = createClient();
  const { data: userData } = await supabase.auth.getUser();
  const user = userData?.user;
  if (!user) return { isActive: false, hasInvite: false, needsPayment: true };

  const hasInvite = !!(user.user_metadata?.invite_code as string | undefined);

  const { data: profile } = await supabase
    .from('profiles')
    .select('subscription_status')
    .eq('id', user.id)
    .maybeSingle();

  const isActive = ACTIVE_STATUSES.has(profile?.subscription_status ?? '');
  // Invite users paid upstream; everyone else must pay unless already active.
  const needsPayment = !hasInvite && !isActive;
  return { isActive, hasInvite, needsPayment };
}

// ── Self-serve Stripe checkout ───────────────────────────────────────────────

export async function startSelfCheckout(priceId: string): Promise<{ ok: boolean; url?: string; error?: string }> {
  const supabase = createClient();
  const { data, error } = await supabase.functions.invoke('create-self-checkout', {
    body: { price_id: priceId },
  });
  if (error) return { ok: false, error: 'Could not start checkout. Please try again.' };
  const url = (data as { checkout_url?: string })?.checkout_url;
  if (!url) return { ok: false, error: 'Checkout is temporarily unavailable.' };
  return { ok: true, url };
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

  // Payment gate: self-serve users (no paid invite) must have an active
  // subscription before onboarding can complete. Invite users paid upstream.
  let activateNow = false;
  if (inviteCode) {
    activateNow = true; // paid invite → safe to mark active
  } else {
    const { data: profile } = await supabase
      .from('profiles')
      .select('subscription_status')
      .eq('id', user.id)
      .maybeSingle();
    if (!ACTIVE_STATUSES.has(profile?.subscription_status ?? '')) {
      return { ok: false, error: 'Payment not completed. Please finish checkout to continue.' };
    }
  }

  const profilePayload: Record<string, unknown> = {
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
    is_active: true,
  };
  // Only force-activate for invite users; for self-serve the webhook owns status.
  if (activateNow) profilePayload.subscription_status = 'active';

  const { error: profileErr } = await supabase
    .from('profiles')
    .upsert(profilePayload, { onConflict: 'id' });

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
