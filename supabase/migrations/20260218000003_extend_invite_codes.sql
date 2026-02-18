-- Extend invite_codes table with Stripe and trial support
-- Safe to run multiple times (IF NOT EXISTS / IF NOT EXISTS)

CREATE TABLE IF NOT EXISTS public.invite_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    used_by UUID,
    used_at TIMESTAMPTZ,
    recipient_name TEXT,
    note TEXT,
    is_revoked BOOLEAN NOT NULL DEFAULT false
);

-- Add Stripe and trial columns
ALTER TABLE public.invite_codes
    ADD COLUMN IF NOT EXISTS email TEXT,
    ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'none',
    ADD COLUMN IF NOT EXISTS stripe_checkout_session_id TEXT,
    ADD COLUMN IF NOT EXISTS trial_days INTEGER;

-- Add constraint for payment_status values (skip if exists)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'invite_codes_payment_status_check'
    ) THEN
        ALTER TABLE public.invite_codes
            ADD CONSTRAINT invite_codes_payment_status_check
            CHECK (payment_status IN ('paid', 'free_trial', 'none'));
    END IF;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_invite_codes_code ON public.invite_codes(code);
CREATE INDEX IF NOT EXISTS idx_invite_codes_email ON public.invite_codes(email);
CREATE INDEX IF NOT EXISTS idx_invite_codes_stripe_session ON public.invite_codes(stripe_checkout_session_id);

-- Row Level Security
ALTER TABLE public.invite_codes ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if re-running
DROP POLICY IF EXISTS "Anyone can read invite codes" ON public.invite_codes;
DROP POLICY IF EXISTS "Admins can insert invite codes" ON public.invite_codes;
DROP POLICY IF EXISTS "Admins can update invite codes" ON public.invite_codes;
DROP POLICY IF EXISTS "Admins can delete invite codes" ON public.invite_codes;
DROP POLICY IF EXISTS "Users can redeem invite codes" ON public.invite_codes;

-- Anyone can validate a code (needed during onboarding before full auth)
CREATE POLICY "Anyone can read invite codes" ON public.invite_codes
    FOR SELECT USING (true);

-- Admins can create codes
CREATE POLICY "Admins can insert invite codes" ON public.invite_codes
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- Admins can update any code (revoke, edit)
CREATE POLICY "Admins can update invite codes" ON public.invite_codes
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- Admins can delete codes
CREATE POLICY "Admins can delete invite codes" ON public.invite_codes
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- Authenticated users can redeem an unused code (update used_by/used_at)
CREATE POLICY "Users can redeem invite codes" ON public.invite_codes
    FOR UPDATE USING (
        auth.uid() IS NOT NULL AND used_by IS NULL
    ) WITH CHECK (
        used_by = auth.uid()
    );
