-- Add is_active flag for admin account deactivation
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;
CREATE INDEX IF NOT EXISTS idx_profiles_is_active ON public.profiles(is_active);

-- Allow admins to read all profiles (for member list)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Admins can read all profiles' AND tablename = 'profiles'
    ) THEN
        CREATE POLICY "Admins can read all profiles" ON public.profiles
            FOR SELECT USING (
                auth.uid() = id OR
                EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
            );
    END IF;
END $$;

-- Allow admins to update any profile (for deactivation)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Admins can update all profiles' AND tablename = 'profiles'
    ) THEN
        CREATE POLICY "Admins can update all profiles" ON public.profiles
            FOR UPDATE USING (
                auth.uid() = id OR
                EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
            );
    END IF;
END $$;

-- Add 'paused' to subscriptions status constraint
ALTER TABLE public.subscriptions DROP CONSTRAINT IF EXISTS subscriptions_status_check;
ALTER TABLE public.subscriptions ADD CONSTRAINT subscriptions_status_check
    CHECK (status IN ('active', 'past_due', 'canceled', 'trialing', 'incomplete', 'paused'));
