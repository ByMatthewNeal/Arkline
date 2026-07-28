-- Exported from the live database on 2026-07-27.
-- Originally applied directly (not via `supabase db push`), so no repo file
-- existed and the migrations could not reproduce production.
-- Filename version matches the applied migration version exactly.

CREATE TABLE IF NOT EXISTS public.resource_articles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  title text NOT NULL,
  summary text,
  body text,
  category text NOT NULL DEFAULT 'learn',   -- get_started | learn | more
  icon text,                                 -- SF Symbol name
  sort_order int NOT NULL DEFAULT 0,
  link_type text,                            -- 'dictionary' | 'referral' | null (null = markdown article)
  is_published boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT date_trunc('milliseconds', now()),
  updated_at timestamptz NOT NULL DEFAULT date_trunc('milliseconds', now())
);

CREATE INDEX IF NOT EXISTS idx_resource_articles_published
  ON public.resource_articles (category, sort_order)
  WHERE is_published = true;

ALTER TABLE public.resource_articles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can read published resources" ON public.resource_articles;
CREATE POLICY "Anyone authenticated can read published resources"
  ON public.resource_articles FOR SELECT
  USING (auth.role() = 'authenticated' AND is_published = true);

DROP POLICY IF EXISTS "Admins manage resources" ON public.resource_articles;
CREATE POLICY "Admins manage resources"
  ON public.resource_articles FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- keep updated_at fresh on edits (millisecond precision to avoid decode issues)
CREATE OR REPLACE FUNCTION public.touch_resource_articles_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := date_trunc('milliseconds', now());
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_touch_resource_articles ON public.resource_articles;
CREATE TRIGGER trg_touch_resource_articles
  BEFORE UPDATE ON public.resource_articles
  FOR EACH ROW EXECUTE FUNCTION public.touch_resource_articles_updated_at();
