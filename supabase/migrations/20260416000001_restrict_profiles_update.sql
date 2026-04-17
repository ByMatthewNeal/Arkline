-- C2: Prevent users from self-assigning role, subscription_status, or trial_end
-- These columns should only be modified by service_role (webhooks, edge functions, migrations)

DROP POLICY IF EXISTS "profiles_update_own" ON profiles;

CREATE POLICY "profiles_update_own" ON profiles
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (
        role IS NOT DISTINCT FROM (SELECT p.role FROM profiles p WHERE p.id = auth.uid())
        AND subscription_status IS NOT DISTINCT FROM (SELECT p.subscription_status FROM profiles p WHERE p.id = auth.uid())
        AND trial_end IS NOT DISTINCT FROM (SELECT p.trial_end FROM profiles p WHERE p.id = auth.uid())
    );
