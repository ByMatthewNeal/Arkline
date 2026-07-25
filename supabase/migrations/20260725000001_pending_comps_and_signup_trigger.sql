-- Pre-comps: an admin can comp an email before that person has signed up. The
-- pending comp is applied automatically when they create their account.

CREATE TABLE IF NOT EXISTS public.pending_comps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  tier text NOT NULL DEFAULT 'founding' CHECK (tier IN ('founding','standard')),
  plan text NOT NULL DEFAULT 'monthly' CHECK (plan IN ('monthly','annual')),
  days integer NOT NULL DEFAULT 0,           -- 0 = forever
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  redeemed_at timestamptz,
  redeemed_user_id uuid
);

-- Admin-only via RLS (edge functions use the service role and bypass RLS anyway).
ALTER TABLE public.pending_comps ENABLE ROW LEVEL SECURITY;

-- When a new auth user is created, if their email has an unredeemed pending comp,
-- create the comp subscription row and mark the pending comp redeemed. Runs as
-- definer so it can write to public.subscriptions from the auth.users trigger.
CREATE OR REPLACE FUNCTION public.apply_pending_comp()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  pc public.pending_comps;
BEGIN
  IF NEW.email IS NULL THEN RETURN NEW; END IF;

  SELECT * INTO pc
  FROM public.pending_comps
  WHERE lower(email) = lower(NEW.email) AND redeemed_at IS NULL
  LIMIT 1;

  IF pc.id IS NULL THEN RETURN NEW; END IF;

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

  UPDATE public.profiles SET subscription_status = 'active' WHERE id = NEW.id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS apply_pending_comp_on_signup ON auth.users;
CREATE TRIGGER apply_pending_comp_on_signup
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.apply_pending_comp();
