-- ============================================
-- SPARELINK SHOP DASHBOARD AUTHENTICATION MIGRATION
-- Features: SSO Tokens, Device Sessions, Session Persistence
-- Date: 2026-01-22
-- ============================================

-- ============================================
-- SSO TOKENS TABLE
-- Secure single sign-on from mobile to web
-- Tokens are one-time use and expire in 5 minutes
-- ============================================

CREATE TABLE IF NOT EXISTS sso_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token TEXT NOT NULL UNIQUE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Index for fast token lookup
    CONSTRAINT sso_tokens_token_key UNIQUE (token)
);

-- Index for cleanup queries
CREATE INDEX IF NOT EXISTS idx_sso_tokens_expires_at ON sso_tokens(expires_at);
CREATE INDEX IF NOT EXISTS idx_sso_tokens_user_id ON sso_tokens(user_id);

-- RLS Policies for SSO Tokens
ALTER TABLE sso_tokens ENABLE ROW LEVEL SECURITY;

-- Users can create SSO tokens for themselves
CREATE POLICY "Users can create own SSO tokens" ON sso_tokens
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can read their own tokens (for verification)
CREATE POLICY "Users can read own SSO tokens" ON sso_tokens
    FOR SELECT
    USING (auth.uid() = user_id);

-- Users can update their own tokens (mark as used)
CREATE POLICY "Users can update own SSO tokens" ON sso_tokens
    FOR UPDATE
    USING (auth.uid() = user_id);

-- Users can delete their own expired tokens
CREATE POLICY "Users can delete own SSO tokens" ON sso_tokens
    FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================
-- DEVICE SESSIONS TABLE
-- Track active sessions across multiple devices
-- ============================================

CREATE TABLE IF NOT EXISTS device_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_name TEXT NOT NULL,
    device_type TEXT NOT NULL CHECK (device_type IN ('desktop', 'mobile', 'tablet')),
    browser TEXT,
    os TEXT,
    ip_address TEXT,
    last_active TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_device_sessions_user_id ON device_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_device_sessions_last_active ON device_sessions(last_active);

-- RLS Policies for Device Sessions
ALTER TABLE device_sessions ENABLE ROW LEVEL SECURITY;

-- Users can create their own device sessions
CREATE POLICY "Users can create own device sessions" ON device_sessions
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can read their own device sessions
CREATE POLICY "Users can read own device sessions" ON device_sessions
    FOR SELECT
    USING (auth.uid() = user_id);

-- Users can update their own device sessions (activity tracking)
CREATE POLICY "Users can update own device sessions" ON device_sessions
    FOR UPDATE
    USING (auth.uid() = user_id);

-- Users can delete their own device sessions (logout/revoke)
CREATE POLICY "Users can delete own device sessions" ON device_sessions
    FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================
-- CLEANUP FUNCTIONS
-- Automatic cleanup of expired tokens and stale sessions
-- ============================================

-- Function to clean up expired SSO tokens
CREATE OR REPLACE FUNCTION cleanup_expired_sso_tokens()
RETURNS void AS $$
BEGIN
    DELETE FROM sso_tokens 
    WHERE expires_at < NOW() OR used = TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clean up stale device sessions (inactive for 30 days)
CREATE OR REPLACE FUNCTION cleanup_stale_device_sessions()
RETURNS void AS $$
BEGIN
    DELETE FROM device_sessions 
    WHERE last_active < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- SCHEDULED CLEANUP (requires pg_cron extension)
-- Run these manually if pg_cron is not available
-- ============================================

-- Uncomment if pg_cron is enabled:
-- SELECT cron.schedule('cleanup-sso-tokens', '*/15 * * * *', 'SELECT cleanup_expired_sso_tokens()');
-- SELECT cron.schedule('cleanup-stale-sessions', '0 3 * * *', 'SELECT cleanup_stale_device_sessions()');

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

GRANT SELECT, INSERT, UPDATE, DELETE ON sso_tokens TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON device_sessions TO authenticated;

-- ============================================
-- VERIFICATION QUERIES
-- Run these to verify the migration was successful
-- ============================================

-- SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'sso_tokens');
-- SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'device_sessions');
