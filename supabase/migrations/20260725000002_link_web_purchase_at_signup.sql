-- Web (Stripe) purchases made before the buyer has an Arkline account: stash the
-- buyer's email on the (user_id-less) subscription row so we can link it when
-- they sign up.
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS pending_email text;

-- Combined signup handler: link any orphaned web subscription by email, AND apply
-- a pending comp if one exists. Replaces apply_pending_comp().
CREATE OR REPLACE FUNCTION public.link_entitlements_on_signup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  pc public.pending_comps;
BEGIN
  IF NEW.email IS NULL THEN RETURN NEW; END IF;

  -- 1) Link an orphaned web (Stripe) subscription bought before signup, by email.
  UPDATE public.subscriptions
     SET user_id = NEW.id, pending_email = NULL, updated_at = now()
   WHERE user_id IS NULL
     AND pending_email IS NOT NULL
     AND lower(pending_email) = lower(NEW.email);

  -- 2) Apply a pending comp if one is waiting for this email.
  SELECT * INTO pc
    FROM public.pending_comps
   WHERE lower(email) = lower(NEW.email) AND redeemed_at IS NULL
   LIMIT 1;

  IF pc.id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.subscriptions WHERE user_id = NEW.id AND source = 'comp'
    ) THEN
      INSERT INTO public.subscriptions
        (user_id, source, status, tier, plan, current_period_start, current_period_end)
      VALUES
        (NEW.id, 'comp', 'active', pc.tier, pc.plan, now(),
         CASE WHEN pc.days > 0 THEN now() + make_interval(days => pc.days) ELSE NULL END);
    END IF;
    UPDATE public.pending_comps
       SET redeemed_at = now(), redeemed_user_id = NEW.id
     WHERE id = pc.id;
  END IF;

  -- 3) Keep the profile cache in sync if they now have any valid subscription.
  UPDATE public.profiles SET subscription_status = 'active'
   WHERE id = NEW.id AND EXISTS (
     SELECT 1 FROM public.subscriptions s
      WHERE s.user_id = NEW.id
        AND s.status IN ('active','trialing')
        AND (s.current_period_end IS NULL OR s.current_period_end > now())
   );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS apply_pending_comp_on_signup ON auth.users;
DROP TRIGGER IF EXISTS link_entitlements_on_signup ON auth.users;
CREATE TRIGGER link_entitlements_on_signup
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.link_entitlements_on_signup();

DROP FUNCTION IF EXISTS public.apply_pending_comp();
