-- Add current_period_end to profiles for subscription enforcement.
-- iOS app reads this to determine whether to lock out canceled users
-- after their paid billing period ends (Apple guideline 3.1.2 compliance).
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS current_period_end TIMESTAMPTZ;
