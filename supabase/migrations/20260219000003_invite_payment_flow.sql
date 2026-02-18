-- Batch 3: Admin-Initiated Invite & Payment Flow
-- Expand payment_status to support pending_payment and comped invites
-- Add checkout_url for storing Stripe Checkout Session URLs

-- Expand payment_status constraint
ALTER TABLE public.invite_codes DROP CONSTRAINT IF EXISTS invite_codes_payment_status_check;
ALTER TABLE public.invite_codes ADD CONSTRAINT invite_codes_payment_status_check
    CHECK (payment_status IN ('paid', 'free_trial', 'none', 'pending_payment', 'comped'));

-- Add checkout_url column for Stripe Checkout Session URL (admin can re-share)
ALTER TABLE public.invite_codes ADD COLUMN IF NOT EXISTS checkout_url TEXT;

-- Index for payment_status lookups (webhook finds pending invites)
CREATE INDEX IF NOT EXISTS idx_invite_codes_payment_status ON public.invite_codes(payment_status);
