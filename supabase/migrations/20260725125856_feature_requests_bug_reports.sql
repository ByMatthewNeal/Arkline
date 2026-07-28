-- Bugs share the feature-request pipeline (one inbox) with a type discriminator.
ALTER TABLE public.feature_requests
  ADD COLUMN IF NOT EXISTS request_type text NOT NULL DEFAULT 'feature'
    CHECK (request_type IN ('feature','bug')),
  ADD COLUMN IF NOT EXISTS app_version text,
  ADD COLUMN IF NOT EXISTS device_info text;
