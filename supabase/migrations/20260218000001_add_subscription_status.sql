-- Add subscription_status to profiles table for quick access checks

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS subscription_status TEXT DEFAULT 'none';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'profiles_subscription_status_check'
    ) THEN
        ALTER TABLE public.profiles
            ADD CONSTRAINT profiles_subscription_status_check
            CHECK (subscription_status IN ('active', 'past_due', 'canceled', 'trialing', 'none'));
    END IF;
END $$;
