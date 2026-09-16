-- Last-active signal for the admin members panel. auth.sessions.updated_at
-- tracks each session's most recent token refresh (~last time the app was
-- opened/foregrounded). auth schema isn't exposed to PostgREST, so the admin
-- edge functions (service role) reach it through this SECURITY DEFINER helper.
CREATE OR REPLACE FUNCTION public.admin_last_active(uids uuid[])
RETURNS TABLE(user_id uuid, last_active_at timestamptz)
LANGUAGE sql
SECURITY DEFINER
SET search_path = auth, public
AS $$
  SELECT s.user_id, max(s.updated_at) AS last_active_at
  FROM auth.sessions s
  WHERE s.user_id = ANY(uids)
  GROUP BY s.user_id;
$$;

REVOKE ALL ON FUNCTION public.admin_last_active(uuid[]) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_last_active(uuid[]) TO service_role;

COMMENT ON FUNCTION public.admin_last_active(uuid[]) IS
  'Admin-only (service role): last session activity per user, for active/dormant member metrics.';
