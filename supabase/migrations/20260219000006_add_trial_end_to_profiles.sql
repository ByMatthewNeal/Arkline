-- Add trial_end column to profiles for tracking Stripe trial expiration
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS trial_end TIMESTAMPTZ;
