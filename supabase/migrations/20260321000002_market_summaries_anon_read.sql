-- Allow anon role to read market summaries (needed for unauthenticated/anonymous sessions)
DROP POLICY IF EXISTS "Authenticated users can read market summaries" ON market_summaries;
CREATE POLICY "Anyone can read market summaries"
  ON market_summaries FOR SELECT
  TO anon, authenticated
  USING (true);
