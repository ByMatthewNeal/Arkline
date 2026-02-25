-- Helper: check if the current user is a premium subscriber or admin.
-- SECURITY DEFINER avoids infinite recursion when called from profiles RLS.
CREATE OR REPLACE FUNCTION public.is_premium_user()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    _sub text;
    _role text;
BEGIN
    SELECT subscription_status, role
      INTO _sub, _role
      FROM profiles
     WHERE id = auth.uid();

    RETURN _role IN ('admin', 'premium')
        OR _sub IN ('active', 'trialing');
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_premium_user() TO authenticated;

-- Replace the broadcasts SELECT policy with audience-aware version.
-- Drop old policy first (name may vary — drop both common names).
DROP POLICY IF EXISTS "Users can read published broadcasts" ON broadcasts;
DROP POLICY IF EXISTS "Anyone can read published broadcasts" ON broadcasts;
DROP POLICY IF EXISTS "broadcasts_select_policy" ON broadcasts;

CREATE POLICY "broadcasts_select_policy" ON broadcasts
    FOR SELECT
    USING (
        -- Admins see everything
        EXISTS (
            SELECT 1 FROM profiles
             WHERE id = auth.uid()
               AND role = 'admin'
        )
        OR (
            status = 'published'
            AND (
                -- All users
                target_audience->>'type' = 'all'
                -- Premium only
                OR (target_audience->>'type' = 'premium' AND is_premium_user())
                -- Specific user list
                OR (
                    target_audience->>'type' = 'specific'
                    AND auth.uid()::text IN (
                        SELECT jsonb_array_elements_text(target_audience->'user_ids')
                    )
                )
            )
        )
    );
