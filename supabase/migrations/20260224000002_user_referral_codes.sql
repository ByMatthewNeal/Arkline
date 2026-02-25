-- Allow authenticated users to create their own referral invite codes.
-- Referral codes are distinguished by note = 'referral' and payment_status = 'none'.
CREATE POLICY "Users can create own referral codes"
  ON public.invite_codes
  FOR INSERT
  TO authenticated
  WITH CHECK (
    created_by = auth.uid()
    AND note = 'referral'
    AND payment_status = 'none'
  );

-- Allow authenticated users to read their own referral codes.
CREATE POLICY "Users can read own referral codes"
  ON public.invite_codes
  FOR SELECT
  TO authenticated
  USING (
    created_by = auth.uid()
    AND note = 'referral'
  );
