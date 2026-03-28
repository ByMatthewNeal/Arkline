-- Storage bucket for market deck admin attachments (images, PDFs)
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('deck-attachments', 'deck-attachments', false, 10485760)  -- 10MB limit
ON CONFLICT (id) DO NOTHING;

-- Admins can upload/read/delete
CREATE POLICY "Admins manage deck attachments"
  ON storage.objects FOR ALL
  USING (bucket_id = 'deck-attachments' AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'))
  WITH CHECK (bucket_id = 'deck-attachments' AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- Service role has full access (for edge functions)
CREATE POLICY "Service role access deck attachments"
  ON storage.objects FOR ALL
  USING (bucket_id = 'deck-attachments')
  WITH CHECK (bucket_id = 'deck-attachments');
