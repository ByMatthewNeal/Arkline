-- Learn trail lessons (Foundations, Crypto, and future trails).
-- Content lives here so lessons can be edited from the in-app admin panel
-- without shipping an App Store update. The app ships a hardcoded copy of every
-- lesson as an offline fallback and as the admin editor's starting text; any row
-- present here (published) overrides the built-in copy for that (trail, position).

CREATE TABLE IF NOT EXISTS public.trail_lessons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trail_key text NOT NULL,            -- foundations | crypto
  position int NOT NULL,              -- 1-based order + stable progress key
  title text NOT NULL,
  idea text NOT NULL,
  see_in_app text,
  mindset_check text,
  takeaway text NOT NULL,
  one_more_thing text,
  preview text NOT NULL DEFAULT '',
  deep_link text,                     -- home|cryptoRisk|signalChanges|fearGreed|dca|settings|learn
  is_published boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT date_trunc('milliseconds', now()),
  updated_at timestamptz NOT NULL DEFAULT date_trunc('milliseconds', now()),
  UNIQUE (trail_key, position)
);

CREATE INDEX IF NOT EXISTS idx_trail_lessons_published
  ON public.trail_lessons (trail_key, position)
  WHERE is_published = true;

ALTER TABLE public.trail_lessons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can read published lessons" ON public.trail_lessons;
CREATE POLICY "Anyone authenticated can read published lessons"
  ON public.trail_lessons FOR SELECT
  USING (auth.role() = 'authenticated' AND is_published = true);

DROP POLICY IF EXISTS "Admins manage trail lessons" ON public.trail_lessons;
CREATE POLICY "Admins manage trail lessons"
  ON public.trail_lessons FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE OR REPLACE FUNCTION public.touch_trail_lessons_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := date_trunc('milliseconds', now());
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_touch_trail_lessons ON public.trail_lessons;
CREATE TRIGGER trg_touch_trail_lessons
  BEFORE UPDATE ON public.trail_lessons
  FOR EACH ROW EXECUTE FUNCTION public.touch_trail_lessons_updated_at();
