-- Create user_devices table for APNs push token storage
CREATE TABLE IF NOT EXISTS user_devices (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'ios',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, device_token)
);

-- Index for fast lookup by platform
CREATE INDEX IF NOT EXISTS idx_user_devices_platform ON user_devices (platform);

-- RLS: users can only manage their own device tokens
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own devices"
    ON user_devices FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own devices"
    ON user_devices FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own devices"
    ON user_devices FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own devices"
    ON user_devices FOR DELETE
    USING (auth.uid() = user_id);

-- Service role bypass for edge functions
CREATE POLICY "Service role full access"
    ON user_devices FOR ALL
    USING (auth.role() = 'service_role');
