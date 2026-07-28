-- Exported from the live database on 2026-07-27.
-- Originally applied directly (not via `supabase db push`), so no repo file
-- existed and the migrations could not reproduce production.
-- Filename version matches the applied migration version exactly.
-- NOTE: the source CHECK constraint here allows ('stripe','apple'); it is
-- later widened to include 'comp' by 20260724042627.

-- Phase 2: Add Apple IAP support to the existing subscriptions table.
-- The table already tracks Stripe subscriptions; we're extending it to also
-- track Apple IAP subscriptions from RevenueCat webhooks.

-- 1. Add columns for Apple IAP tracking.
ALTER TABLE public.subscriptions
  ADD COLUMN IF NOT EXISTS source text,
  ADD COLUMN IF NOT EXISTS apple_original_transaction_id text,
  ADD COLUMN IF NOT EXISTS apple_product_id text,
  ADD COLUMN IF NOT EXISTS revenuecat_subscriber_id text;

-- 2. Backfill existing rows as Stripe source.
-- (All current 7 rows are Stripe subscribers based on stripe_subscription_id presence.)
UPDATE public.subscriptions
  SET source = 'stripe'
  WHERE source IS NULL;

-- 3. Make source non-nullable now that it's backfilled, and constrain values.
ALTER TABLE public.subscriptions
  ALTER COLUMN source SET NOT NULL,
  ALTER COLUMN source SET DEFAULT 'stripe';

ALTER TABLE public.subscriptions
  ADD CONSTRAINT subscriptions_source_check
  CHECK (source IN ('stripe', 'apple'));

-- 4. Index for fast lookup by Apple transaction (used by RevenueCat webhook).
CREATE INDEX IF NOT EXISTS subscriptions_apple_original_transaction_id_idx
  ON public.subscriptions (apple_original_transaction_id)
  WHERE apple_original_transaction_id IS NOT NULL;

-- 5. Uniqueness: one user-subscription per Apple original_transaction_id.
CREATE UNIQUE INDEX IF NOT EXISTS subscriptions_apple_otx_unique
  ON public.subscriptions (apple_original_transaction_id)
  WHERE apple_original_transaction_id IS NOT NULL;

-- 6. Helper RPC: unified subscription check across both sources.
-- Returns true if the user has an 'active' or 'trialing' subscription from EITHER source.
CREATE OR REPLACE FUNCTION public.is_user_subscribed(check_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.subscriptions
    WHERE user_id = check_user_id
      AND status IN ('active', 'trialing')
      AND (current_period_end IS NULL OR current_period_end > now())
  );
$$;

COMMENT ON FUNCTION public.is_user_subscribed(uuid) IS
  'Returns true if the user has an active or trialing subscription from either Stripe or Apple IAP.';

-- 7. Grant execute to authenticated users (for RLS-checked client access).
GRANT EXECUTE ON FUNCTION public.is_user_subscribed(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_user_subscribed(uuid) TO service_role;
