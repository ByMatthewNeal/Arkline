-- Allow admins to delete early access signups
CREATE POLICY "Admins can delete signups" ON early_access_signups
  FOR DELETE TO authenticated USING (public.is_admin());
