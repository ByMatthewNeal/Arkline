-- Exported from the live database on 2026-07-27.
-- Originally applied directly (not via `supabase db push`), so no repo file
-- existed and the migrations could not reproduce production.
-- Filename version matches the applied migration version exactly.

-- Allow 'comp' as a subscription source for TestFlight tester thank-yous
-- and any future manual/promotional grants. Same active/entitlement semantics
-- as 'stripe' and 'apple' — is_user_subscribed() will treat comp rows the same.
ALTER TABLE public.subscriptions DROP CONSTRAINT subscriptions_source_check;
ALTER TABLE public.subscriptions
  ADD CONSTRAINT subscriptions_source_check
  CHECK (source = ANY (ARRAY['stripe'::text, 'apple'::text, 'comp'::text]));
