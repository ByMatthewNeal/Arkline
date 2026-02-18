-- Fix infinite recursion in profiles RLS policies.
-- The admin check was querying profiles within a profiles policy, causing
-- PostgreSQL error 42P17. Replace with a SECURITY DEFINER function that
-- bypasses RLS to check the caller's role.

-- 1. Create a helper function that bypasses RLS
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 2. Drop the recursive policies
DROP POLICY IF EXISTS "Admins can read all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON public.profiles;

-- 3. Recreate with the non-recursive helper
CREATE POLICY "Admins can read all profiles" ON public.profiles
    FOR SELECT USING (auth.uid() = id OR public.is_admin());

CREATE POLICY "Admins can update all profiles" ON public.profiles
    FOR UPDATE USING (auth.uid() = id OR public.is_admin());
