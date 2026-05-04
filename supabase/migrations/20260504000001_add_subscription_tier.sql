-- Add tier column to subscriptions table
-- Mirrors the tier set on the originating invite_codes record so admin metrics
-- can compute accurate per-tier MRR/ARR without joining or looking up Stripe.

ALTER TABLE public.subscriptions
    ADD COLUMN IF NOT EXISTS tier TEXT NOT NULL DEFAULT 'standard';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'subscriptions_tier_check'
    ) THEN
        ALTER TABLE public.subscriptions
            ADD CONSTRAINT subscriptions_tier_check
            CHECK (tier IN ('founding', 'standard'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_subscriptions_tier ON public.subscriptions(tier);

-- Backfill existing rows from the originating invite_code, where available.
-- Pre-launch this should be a no-op (table is empty), but handles dev/staging data.
UPDATE public.subscriptions s
SET tier = ic.tier
FROM public.invite_codes ic
WHERE ic.used_by = s.user_id
  AND ic.tier IN ('founding', 'standard')
  AND s.tier = 'standard'   -- only touch rows still on the default
  AND s.user_id IS NOT NULL;
