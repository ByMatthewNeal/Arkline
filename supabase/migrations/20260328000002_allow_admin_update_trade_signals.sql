-- Replace the blanket "Deny updates" policy with one that allows admin updates on trade_signals
-- This enables the manual signal resolution feature for admins

DROP POLICY IF EXISTS "Deny updates on trade_signals" ON public.trade_signals;

-- Deny updates for non-admin authenticated users
CREATE POLICY "Deny updates on trade_signals"
  ON public.trade_signals
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
