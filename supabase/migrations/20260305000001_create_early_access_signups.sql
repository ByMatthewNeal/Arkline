CREATE TABLE early_access_signups (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE early_access_signups ENABLE ROW LEVEL SECURITY;

-- Anonymous inserts allowed (public signup)
CREATE POLICY "Anyone can sign up" ON early_access_signups
  FOR INSERT TO anon, authenticated WITH CHECK (true);

-- Only admins can read
CREATE POLICY "Admins can read signups" ON early_access_signups
  FOR SELECT TO authenticated USING (public.is_admin());
