-- ============================================================
-- Arkline Database Schema + Row Level Security (RLS) Policies
-- Supabase (PostgreSQL)
-- ============================================================
-- This file documents the full database schema and serves as
-- a runnable migration for new Supabase projects or disaster
-- recovery. Run against a fresh Supabase project with auth
-- already configured.
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. PROFILES
-- ============================================================
CREATE TABLE profiles (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username        TEXT,
    email           TEXT,
    full_name       TEXT,
    avatar_url      TEXT,
    use_photo_avatar BOOLEAN DEFAULT false,
    date_of_birth   TIMESTAMPTZ,
    career_industry TEXT,
    experience_level TEXT,
    social_links    JSONB,
    preferred_currency TEXT NOT NULL DEFAULT 'usd',
    risk_coins      JSONB DEFAULT '[]'::jsonb,
    dark_mode       TEXT NOT NULL DEFAULT 'system',
    notifications   JSONB,
    passcode_hash   TEXT,
    face_id_enabled BOOLEAN DEFAULT false,
    role            TEXT NOT NULL DEFAULT 'user',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Users can read their own profile
CREATE POLICY "profiles_select_own" ON profiles
    FOR SELECT USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "profiles_update_own" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- Allow insert on signup (triggered by auth hook or client)
CREATE POLICY "profiles_insert_own" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, username, created_at, updated_at)
    VALUES (
        NEW.id,
        NEW.email,
        split_part(NEW.email, '@', 1),
        now(),
        now()
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 2. PORTFOLIOS
-- ============================================================
CREATE TABLE portfolios (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    is_public   BOOLEAN NOT NULL DEFAULT false,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE portfolios ENABLE ROW LEVEL SECURITY;

-- Users can CRUD their own portfolios
CREATE POLICY "portfolios_select_own" ON portfolios
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "portfolios_insert_own" ON portfolios
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "portfolios_update_own" ON portfolios
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "portfolios_delete_own" ON portfolios
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 3. HOLDINGS
-- ============================================================
CREATE TABLE holdings (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id    UUID NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
    asset_type      TEXT NOT NULL,
    symbol          TEXT NOT NULL,
    name            TEXT NOT NULL,
    quantity        NUMERIC(18,8) NOT NULL DEFAULT 0,
    average_buy_price NUMERIC(18,8),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE holdings ENABLE ROW LEVEL SECURITY;

-- Users can CRUD holdings in their own portfolios
CREATE POLICY "holdings_select_own" ON holdings
    FOR SELECT USING (
        portfolio_id IN (SELECT id FROM portfolios WHERE user_id = auth.uid())
    );

CREATE POLICY "holdings_insert_own" ON holdings
    FOR INSERT WITH CHECK (
        portfolio_id IN (SELECT id FROM portfolios WHERE user_id = auth.uid())
    );

CREATE POLICY "holdings_update_own" ON holdings
    FOR UPDATE USING (
        portfolio_id IN (SELECT id FROM portfolios WHERE user_id = auth.uid())
    );

CREATE POLICY "holdings_delete_own" ON holdings
    FOR DELETE USING (
        portfolio_id IN (SELECT id FROM portfolios WHERE user_id = auth.uid())
    );

-- ============================================================
-- 4. TRANSACTIONS
-- ============================================================
CREATE TABLE transactions (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id            UUID NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
    holding_id              UUID REFERENCES holdings(id) ON DELETE SET NULL,
    type                    TEXT NOT NULL,
    asset_type              TEXT NOT NULL,
    symbol                  TEXT NOT NULL,
    quantity                NUMERIC(18,8) NOT NULL,
    price_per_unit          NUMERIC(18,8) NOT NULL,
    gas_fee                 NUMERIC(18,8),
    total_value             NUMERIC(18,8) NOT NULL,
    transaction_date        TIMESTAMPTZ NOT NULL,
    notes                   TEXT,
    emotional_state         TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    cost_basis_per_unit     NUMERIC(18,8),
    realized_profit_loss    NUMERIC(18,8),
    destination_portfolio_id UUID REFERENCES portfolios(id) ON DELETE SET NULL,
    related_transaction_id  UUID REFERENCES transactions(id) ON DELETE SET NULL
);

ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "transactions_select_own" ON transactions
    FOR SELECT USING (
        portfolio_id IN (SELECT id FROM portfolios WHERE user_id = auth.uid())
    );

CREATE POLICY "transactions_insert_own" ON transactions
    FOR INSERT WITH CHECK (
        portfolio_id IN (SELECT id FROM portfolios WHERE user_id = auth.uid())
    );

CREATE POLICY "transactions_update_own" ON transactions
    FOR UPDATE USING (
        portfolio_id IN (SELECT id FROM portfolios WHERE user_id = auth.uid())
    );

CREATE POLICY "transactions_delete_own" ON transactions
    FOR DELETE USING (
        portfolio_id IN (SELECT id FROM portfolios WHERE user_id = auth.uid())
    );

-- ============================================================
-- 5. PORTFOLIO HISTORY
-- ============================================================
CREATE TABLE portfolio_history (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id    UUID NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
    total_value     NUMERIC(18,2) NOT NULL,
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE portfolio_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "portfolio_history_select_own" ON portfolio_history
    FOR SELECT USING (
        portfolio_id IN (SELECT id FROM portfolios WHERE user_id = auth.uid())
    );

CREATE POLICY "portfolio_history_insert_own" ON portfolio_history
    FOR INSERT WITH CHECK (
        portfolio_id IN (SELECT id FROM portfolios WHERE user_id = auth.uid())
    );

-- ============================================================
-- 6. DCA REMINDERS
-- ============================================================
CREATE TABLE dca_reminders (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    symbol              TEXT NOT NULL,
    name                TEXT NOT NULL,
    amount              NUMERIC(18,2) NOT NULL,
    frequency           TEXT NOT NULL,
    total_purchases     INTEGER,
    completed_purchases INTEGER NOT NULL DEFAULT 0,
    notification_time   TIMESTAMPTZ NOT NULL,
    start_date          TIMESTAMPTZ NOT NULL,
    next_reminder_date  TIMESTAMPTZ,
    is_active           BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE dca_reminders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "dca_reminders_select_own" ON dca_reminders
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "dca_reminders_insert_own" ON dca_reminders
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "dca_reminders_update_own" ON dca_reminders
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "dca_reminders_delete_own" ON dca_reminders
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 7. RISK-BASED DCA REMINDERS
-- ============================================================
CREATE TABLE risk_based_dca_reminders (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    symbol              TEXT NOT NULL,
    name                TEXT NOT NULL,
    base_amount         NUMERIC(18,2) NOT NULL,
    frequency           TEXT NOT NULL,
    is_active           BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE risk_based_dca_reminders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "risk_dca_reminders_select_own" ON risk_based_dca_reminders
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "risk_dca_reminders_insert_own" ON risk_based_dca_reminders
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "risk_dca_reminders_update_own" ON risk_based_dca_reminders
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "risk_dca_reminders_delete_own" ON risk_based_dca_reminders
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 8. RISK DCA INVESTMENTS
-- ============================================================
CREATE TABLE risk_dca_investments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reminder_id     UUID NOT NULL REFERENCES risk_based_dca_reminders(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    amount          NUMERIC(18,2) NOT NULL,
    risk_level      TEXT,
    invested_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE risk_dca_investments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "risk_dca_investments_select_own" ON risk_dca_investments
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "risk_dca_investments_insert_own" ON risk_dca_investments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 9. FAVORITES
-- ============================================================
CREATE TABLE favorites (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    asset_id    TEXT NOT NULL,
    asset_type  TEXT NOT NULL DEFAULT 'crypto',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, asset_id)
);

ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "favorites_select_own" ON favorites
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "favorites_insert_own" ON favorites
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "favorites_delete_own" ON favorites
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 10. CHAT SESSIONS (AI Chat)
-- ============================================================
CREATE TABLE chat_sessions (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title       TEXT,
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chat_sessions_select_own" ON chat_sessions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "chat_sessions_insert_own" ON chat_sessions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "chat_sessions_update_own" ON chat_sessions
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "chat_sessions_delete_own" ON chat_sessions
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 11. CHAT MESSAGES (AI Chat)
-- ============================================================
CREATE TABLE chat_messages (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id  UUID NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    role        TEXT NOT NULL,
    content     TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chat_messages_select_own" ON chat_messages
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "chat_messages_insert_own" ON chat_messages
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "chat_messages_delete_own" ON chat_messages
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 12. CHAT ROOMS (Community)
-- ============================================================
CREATE TABLE chat_rooms (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT NOT NULL,
    description TEXT,
    type        TEXT NOT NULL DEFAULT 'general',
    is_premium  BOOLEAN NOT NULL DEFAULT false,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read chat rooms
CREATE POLICY "chat_rooms_select_all" ON chat_rooms
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Only admins can create/update chat rooms
CREATE POLICY "chat_rooms_insert_admin" ON chat_rooms
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "chat_rooms_update_admin" ON chat_rooms
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- ============================================================
-- 13. CHAT ROOM MESSAGES (Community)
-- ============================================================
CREATE TABLE chat_room_messages (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id     UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    content     TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE chat_room_messages ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read messages
CREATE POLICY "chat_room_messages_select_all" ON chat_room_messages
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Authenticated users can post messages
CREATE POLICY "chat_room_messages_insert_own" ON chat_room_messages
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can delete their own messages
CREATE POLICY "chat_room_messages_delete_own" ON chat_room_messages
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 14. COMMUNITY POSTS
-- ============================================================
CREATE TABLE community_posts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    content         TEXT NOT NULL,
    image_url       TEXT,
    category        TEXT,
    likes_count     INTEGER NOT NULL DEFAULT 0,
    comments_count  INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read posts
CREATE POLICY "community_posts_select_all" ON community_posts
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Users can create their own posts
CREATE POLICY "community_posts_insert_own" ON community_posts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own posts
CREATE POLICY "community_posts_update_own" ON community_posts
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own posts
CREATE POLICY "community_posts_delete_own" ON community_posts
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 15. COMMENTS
-- ============================================================
CREATE TABLE comments (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id     UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    parent_id   UUID REFERENCES comments(id) ON DELETE CASCADE,
    content     TEXT NOT NULL,
    likes_count INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read comments
CREATE POLICY "comments_select_all" ON comments
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Users can create their own comments
CREATE POLICY "comments_insert_own" ON comments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can delete their own comments
CREATE POLICY "comments_delete_own" ON comments
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 16. BROADCASTS
-- ============================================================
CREATE TABLE broadcasts (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title               TEXT NOT NULL,
    content             TEXT NOT NULL,
    audio_url           TEXT,
    images              JSONB DEFAULT '[]'::jsonb,
    app_references      JSONB DEFAULT '[]'::jsonb,
    portfolio_attachment JSONB,
    target_audience     JSONB DEFAULT '{"type":"all"}'::jsonb,
    status              TEXT NOT NULL DEFAULT 'draft',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    published_at        TIMESTAMPTZ,
    scheduled_at        TIMESTAMPTZ,
    template_id         UUID,
    tags                JSONB DEFAULT '[]'::jsonb,
    author_id           UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    view_count          INTEGER DEFAULT 0,
    reaction_count      INTEGER DEFAULT 0
);

ALTER TABLE broadcasts ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read published broadcasts
CREATE POLICY "broadcasts_select_published" ON broadcasts
    FOR SELECT USING (
        status = 'published'
        OR (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'))
    );

-- Only admins can create broadcasts
CREATE POLICY "broadcasts_insert_admin" ON broadcasts
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- Only admins can update broadcasts
CREATE POLICY "broadcasts_update_admin" ON broadcasts
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- Only admins can delete broadcasts
CREATE POLICY "broadcasts_delete_admin" ON broadcasts
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- ============================================================
-- 17. BROADCAST READS
-- ============================================================
CREATE TABLE broadcast_reads (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    broadcast_id    UUID NOT NULL REFERENCES broadcasts(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    read_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(broadcast_id, user_id)
);

ALTER TABLE broadcast_reads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "broadcast_reads_select_own" ON broadcast_reads
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "broadcast_reads_insert_own" ON broadcast_reads
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 18. BROADCAST REACTIONS
-- ============================================================
CREATE TABLE broadcast_reactions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    broadcast_id    UUID NOT NULL REFERENCES broadcasts(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    emoji           TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(broadcast_id, user_id, emoji)
);

ALTER TABLE broadcast_reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "broadcast_reactions_select_all" ON broadcast_reactions
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "broadcast_reactions_insert_own" ON broadcast_reactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "broadcast_reactions_delete_own" ON broadcast_reactions
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 19. FEATURE REQUESTS
-- ============================================================
CREATE TABLE feature_requests (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title           TEXT NOT NULL,
    description     TEXT NOT NULL,
    category        TEXT NOT NULL,
    author_id       UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    author_email    TEXT,
    status          TEXT NOT NULL DEFAULT 'pending',
    priority        TEXT,
    vote_count      INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    reviewed_at     TIMESTAMPTZ,
    reviewed_by     UUID REFERENCES profiles(id),
    admin_notes     TEXT,
    ai_analysis     TEXT
);

ALTER TABLE feature_requests ENABLE ROW LEVEL SECURITY;

-- Users can read their own feature requests
CREATE POLICY "feature_requests_select_own" ON feature_requests
    FOR SELECT USING (
        auth.uid() = author_id
        OR (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'))
    );

-- Users can create feature requests
CREATE POLICY "feature_requests_insert_own" ON feature_requests
    FOR INSERT WITH CHECK (auth.uid() = author_id);

-- Only admins can update (review) feature requests
CREATE POLICY "feature_requests_update_admin" ON feature_requests
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- ============================================================
-- 20. USER DEVICES (Push Notifications)
-- ============================================================
CREATE TABLE user_devices (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    device_token    TEXT NOT NULL,
    platform        TEXT NOT NULL DEFAULT 'ios',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, device_token)
);

ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_devices_select_own" ON user_devices
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "user_devices_insert_own" ON user_devices
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_devices_update_own" ON user_devices
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "user_devices_delete_own" ON user_devices
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 21. APP STORE RANKINGS (Admin data)
-- ============================================================
CREATE TABLE app_store_rankings (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    app_name        TEXT NOT NULL,
    ranking         SMALLINT,
    btc_price       NUMERIC,
    recorded_date   DATE NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE app_store_rankings ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read rankings
CREATE POLICY "app_store_rankings_select_all" ON app_store_rankings
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Only admins can insert/update rankings
CREATE POLICY "app_store_rankings_insert_admin" ON app_store_rankings
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "app_store_rankings_update_admin" ON app_store_rankings
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- ============================================================
-- 22. SENTIMENT HISTORY (Admin data)
-- ============================================================
CREATE TABLE sentiment_history (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    metric_type     TEXT NOT NULL,
    value           NUMERIC NOT NULL,
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    metadata        JSONB
);

ALTER TABLE sentiment_history ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read sentiment data
CREATE POLICY "sentiment_history_select_all" ON sentiment_history
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Only admins can insert/update sentiment data
CREATE POLICY "sentiment_history_insert_admin" ON sentiment_history
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "sentiment_history_update_admin" ON sentiment_history
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- ============================================================
-- 23. SUPPLY IN PROFIT (Admin data)
-- ============================================================
CREATE TABLE supply_in_profit (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    date        DATE NOT NULL,
    value       NUMERIC NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE supply_in_profit ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read
CREATE POLICY "supply_in_profit_select_all" ON supply_in_profit
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Only admins can insert
CREATE POLICY "supply_in_profit_insert_admin" ON supply_in_profit
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "supply_in_profit_update_admin" ON supply_in_profit
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- ============================================================
-- 24. GOOGLE TRENDS HISTORY (Admin data)
-- ============================================================
CREATE TABLE google_trends_history (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    search_index    SMALLINT NOT NULL,
    btc_price       NUMERIC,
    recorded_date   DATE NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE google_trends_history ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read
CREATE POLICY "google_trends_history_select_all" ON google_trends_history
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Only admins can insert/update
CREATE POLICY "google_trends_history_insert_admin" ON google_trends_history
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "google_trends_history_update_admin" ON google_trends_history
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- ============================================================
-- 25. MARKET SNAPSHOTS (Daily crypto asset data)
-- ============================================================
CREATE TABLE market_snapshots (
    id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    coin_id                     TEXT NOT NULL,
    recorded_date               DATE NOT NULL,
    current_price               NUMERIC NOT NULL,
    market_cap                  NUMERIC,
    total_volume                NUMERIC,
    price_change_24h            NUMERIC,
    price_change_pct_24h        NUMERIC,
    high_24h                    NUMERIC,
    low_24h                     NUMERIC,
    market_cap_rank             INTEGER,
    circulating_supply          NUMERIC,
    total_supply                NUMERIC,
    max_supply                  NUMERIC,
    ath                         NUMERIC,
    ath_change_percentage       NUMERIC,
    atl                         NUMERIC,
    atl_change_percentage       NUMERIC,
    created_at                  TIMESTAMPTZ DEFAULT now(),
    UNIQUE(recorded_date, coin_id)
);

ALTER TABLE market_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "market_snapshots_select_all" ON market_snapshots
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "market_snapshots_insert_admin" ON market_snapshots
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "market_snapshots_update_admin" ON market_snapshots
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- ============================================================
-- 26. INDICATOR SNAPSHOTS (VIX, DXY, M2, Fear/Greed, etc.)
-- ============================================================
CREATE TABLE indicator_snapshots (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    indicator         TEXT NOT NULL,
    recorded_date     DATE NOT NULL,
    value             NUMERIC NOT NULL,
    metadata          JSONB,
    created_at        TIMESTAMPTZ DEFAULT now(),
    UNIQUE(recorded_date, indicator)
);

ALTER TABLE indicator_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "indicator_snapshots_select_all" ON indicator_snapshots
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "indicator_snapshots_insert_admin" ON indicator_snapshots
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "indicator_snapshots_update_admin" ON indicator_snapshots
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- ============================================================
-- 27. TECHNICALS SNAPSHOTS (RSI, SMA, Bollinger, etc.)
-- ============================================================
CREATE TABLE technicals_snapshots (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    coin_id           TEXT NOT NULL,
    recorded_date     DATE NOT NULL,
    rsi               NUMERIC,
    sma_21            NUMERIC,
    sma_50            NUMERIC,
    sma_200           NUMERIC,
    bb_upper          NUMERIC,
    bb_middle         NUMERIC,
    bb_lower          NUMERIC,
    bb_bandwidth      NUMERIC,
    bmsb_sma_20w      NUMERIC,
    bmsb_ema_21w      NUMERIC,
    trend_direction   TEXT,
    trend_strength    TEXT,
    current_price     NUMERIC,
    metadata          JSONB,
    created_at        TIMESTAMPTZ DEFAULT now(),
    UNIQUE(recorded_date, coin_id)
);

ALTER TABLE technicals_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "technicals_snapshots_select_all" ON technicals_snapshots
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "technicals_snapshots_insert_admin" ON technicals_snapshots
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "technicals_snapshots_update_admin" ON technicals_snapshots
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- ============================================================
-- 28. RISK SNAPSHOTS (Daily composite risk score)
-- ============================================================
CREATE TABLE risk_snapshots (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recorded_date     DATE NOT NULL UNIQUE,
    composite_score   INTEGER NOT NULL,
    tier              TEXT NOT NULL,
    recommendation    TEXT,
    components        JSONB,
    created_at        TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE risk_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "risk_snapshots_select_all" ON risk_snapshots
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "risk_snapshots_insert_admin" ON risk_snapshots
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "risk_snapshots_update_admin" ON risk_snapshots
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- ============================================================
-- 29. ANALYTICS EVENTS (User behavior tracking)
-- ============================================================
CREATE TABLE analytics_events (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id       UUID REFERENCES auth.users(id),
    event_name    TEXT NOT NULL,
    properties    JSONB,
    session_id    UUID,
    device_info   JSONB,
    created_at    TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

-- Users can only read their own events
CREATE POLICY "analytics_events_select_own" ON analytics_events
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own events
CREATE POLICY "analytics_events_insert_own" ON analytics_events
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Admins can read all events
CREATE POLICY "analytics_events_select_admin" ON analytics_events
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- ============================================================
-- 30. DAILY ACTIVE USERS (Aggregated daily usage)
-- ============================================================
CREATE TABLE daily_active_users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID REFERENCES auth.users(id) NOT NULL,
    recorded_date   DATE NOT NULL,
    session_count   INTEGER DEFAULT 1,
    screen_views    INTEGER DEFAULT 0,
    coins_viewed    TEXT[] DEFAULT '{}',
    app_version     TEXT,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now(),
    UNIQUE(recorded_date, user_id)
);

ALTER TABLE daily_active_users ENABLE ROW LEVEL SECURITY;

-- Users can read their own data
CREATE POLICY "daily_active_users_select_own" ON daily_active_users
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert/update their own data
CREATE POLICY "daily_active_users_insert_own" ON daily_active_users
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "daily_active_users_update_own" ON daily_active_users
    FOR UPDATE USING (auth.uid() = user_id);

-- Admins can read all
CREATE POLICY "daily_active_users_select_admin" ON daily_active_users
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- ============================================================
-- STORAGE BUCKETS (configured via Supabase Dashboard)
-- ============================================================
-- avatars         - Profile pictures (public read, owner write)
-- post-images     - Community post images (public read, owner write)
-- attachments     - General file attachments (owner read/write)
-- broadcast-media - Broadcast images/audio (public read, admin write)

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_portfolios_user_id ON portfolios(user_id);
CREATE INDEX idx_holdings_portfolio_id ON holdings(portfolio_id);
CREATE INDEX idx_transactions_portfolio_id ON transactions(portfolio_id);
CREATE INDEX idx_transactions_date ON transactions(transaction_date);
CREATE INDEX idx_portfolio_history_portfolio_id ON portfolio_history(portfolio_id);
CREATE INDEX idx_dca_reminders_user_id ON dca_reminders(user_id);
CREATE INDEX idx_risk_dca_reminders_user_id ON risk_based_dca_reminders(user_id);
CREATE INDEX idx_risk_dca_investments_reminder_id ON risk_dca_investments(reminder_id);
CREATE INDEX idx_favorites_user_id ON favorites(user_id);
CREATE INDEX idx_chat_sessions_user_id ON chat_sessions(user_id);
CREATE INDEX idx_chat_messages_session_id ON chat_messages(session_id);
CREATE INDEX idx_chat_room_messages_room_id ON chat_room_messages(room_id);
CREATE INDEX idx_community_posts_user_id ON community_posts(user_id);
CREATE INDEX idx_comments_post_id ON comments(post_id);
CREATE INDEX idx_broadcasts_status ON broadcasts(status);
CREATE INDEX idx_broadcasts_published_at ON broadcasts(published_at);
CREATE INDEX idx_broadcast_reads_broadcast_id ON broadcast_reads(broadcast_id);
CREATE INDEX idx_broadcast_reactions_broadcast_id ON broadcast_reactions(broadcast_id);
CREATE INDEX idx_feature_requests_author_id ON feature_requests(author_id);
CREATE INDEX idx_user_devices_user_id ON user_devices(user_id);
CREATE INDEX idx_app_store_rankings_date ON app_store_rankings(recorded_date);
CREATE INDEX idx_sentiment_history_type ON sentiment_history(metric_type);
CREATE INDEX idx_supply_in_profit_date ON supply_in_profit(date);
CREATE INDEX idx_google_trends_date ON google_trends_history(recorded_date);
CREATE INDEX idx_market_snapshots_coin_date ON market_snapshots(coin_id, recorded_date);
CREATE INDEX idx_indicator_snapshots_indicator_date ON indicator_snapshots(indicator, recorded_date);
CREATE INDEX idx_technicals_snapshots_coin_date ON technicals_snapshots(coin_id, recorded_date);
CREATE INDEX idx_risk_snapshots_date ON risk_snapshots(recorded_date);
CREATE INDEX idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX idx_analytics_events_name ON analytics_events(event_name);
CREATE INDEX idx_analytics_events_created ON analytics_events(created_at);
CREATE INDEX idx_daily_active_users_user_date ON daily_active_users(user_id, recorded_date);
