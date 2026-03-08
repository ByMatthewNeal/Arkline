CREATE TABLE contact_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE contact_messages ENABLE ROW LEVEL SECURITY;

-- Anonymous inserts allowed (public contact form)
CREATE POLICY "Anyone can submit a message" ON contact_messages
  FOR INSERT TO anon, authenticated WITH CHECK (true);

-- Only admins can read messages
CREATE POLICY "Admins can read messages" ON contact_messages
  FOR SELECT TO authenticated USING (public.is_admin());
