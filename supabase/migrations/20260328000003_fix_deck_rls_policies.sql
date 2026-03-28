-- Fix overly permissive RLS policies on deck-attachments, fear_greed_history, and deck_feedback

-- =============================================================================
-- 1. Storage: deck-attachments bucket — drop permissive policies, recreate properly
-- =============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Admins manage deck attachments" ON storage.objects;
DROP POLICY IF EXISTS "Service role access deck attachments" ON storage.objects;

-- SELECT: any authenticated user can read attachments (needed to view decks)
CREATE POLICY "Authenticated users can read deck attachments"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'deck-attachments');

-- INSERT: admins only
CREATE POLICY "Admins can upload deck attachments"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'deck-attachments' AND public.is_admin());

-- UPDATE: admins only
CREATE POLICY "Admins can update deck attachments"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'deck-attachments' AND public.is_admin())
  WITH CHECK (bucket_id = 'deck-attachments' AND public.is_admin());

-- DELETE: admins only
CREATE POLICY "Admins can delete deck attachments"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'deck-attachments' AND public.is_admin());

-- =============================================================================
-- 2. fear_greed_history — fix INSERT to require admin, add UPDATE/DELETE for admins
-- =============================================================================

-- Drop the overly permissive INSERT policy (allowed anon with no role check)
DROP POLICY IF EXISTS "Service role can insert fear greed" ON fear_greed_history;

-- INSERT: admins only (edge functions use service role which bypasses RLS)
CREATE POLICY "Admins can insert fear greed history"
  ON fear_greed_history FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

-- UPDATE: admins only
CREATE POLICY "Admins can update fear greed history"
  ON fear_greed_history FOR UPDATE
  TO authenticated
  USING (public.is_admin());

-- DELETE: admins only
CREATE POLICY "Admins can delete fear greed history"
  ON fear_greed_history FOR DELETE
  TO authenticated
  USING (public.is_admin());

-- =============================================================================
-- 3. deck_feedback — fix UNIQUE constraint from (deck_id) to (deck_id, user_id)
-- =============================================================================

-- Drop the old constraint (one rating per deck globally — wrong)
ALTER TABLE deck_feedback DROP CONSTRAINT IF EXISTS deck_feedback_deck_id_key;

-- Add correct constraint (one rating per user per deck)
ALTER TABLE deck_feedback ADD CONSTRAINT deck_feedback_deck_id_user_id_key UNIQUE (deck_id, user_id);
