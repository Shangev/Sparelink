-- =====================================================
-- AUDIT LOGS TABLE FOR SPARELINK
-- =====================================================
-- This table stores comprehensive audit logs for tracking
-- user actions and system events.
-- 
-- Run this in Supabase SQL Editor to create the table.
-- =====================================================

-- Create audit_logs table
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- Event identification
    event_type VARCHAR(50) NOT NULL,
    description TEXT NOT NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'info',
    
    -- Target entity (what was affected)
    target_type VARCHAR(50),
    target_id UUID,
    
    -- Who performed the action
    user_id UUID REFERENCES auth.users(id),
    
    -- Additional context
    metadata JSONB DEFAULT '{}',
    ip_address INET,
    user_agent TEXT,
    
    -- Timestamp
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_event_type ON audit_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target ON audit_logs(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_severity ON audit_logs(severity);

-- Enable Row Level Security
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only read their own audit logs
CREATE POLICY "Users can view own audit logs"
ON audit_logs FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Insert allowed for authenticated users (for their own actions)
CREATE POLICY "Authenticated users can insert audit logs"
ON audit_logs FOR INSERT
WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Policy: Admin can view all audit logs (create admin role first)
-- Uncomment when admin role is set up:
-- CREATE POLICY "Admins can view all audit logs"
-- ON audit_logs FOR SELECT
-- USING (
--     EXISTS (
--         SELECT 1 FROM profiles
--         WHERE profiles.id = auth.uid()
--         AND profiles.role = 'admin'
--     )
-- );

-- =====================================================
-- AUDIT LOG CLEANUP FUNCTION
-- =====================================================
-- Automatically delete audit logs older than retention period

CREATE OR REPLACE FUNCTION cleanup_old_audit_logs(retention_days INTEGER DEFAULT 90)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM audit_logs
    WHERE created_at < NOW() - (retention_days || ' days')::INTERVAL
    AND severity NOT IN ('error', 'critical'); -- Keep error/critical logs longer
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Log the cleanup action
    INSERT INTO audit_logs (event_type, description, severity, metadata)
    VALUES (
        'system_cleanup',
        'Automated audit log cleanup completed',
        'info',
        jsonb_build_object('deleted_count', deleted_count, 'retention_days', retention_days)
    );
    
    RETURN deleted_count;
END;
$$;

-- =====================================================
-- SCHEDULED CLEANUP (run via pg_cron if available)
-- =====================================================
-- If pg_cron extension is enabled, uncomment to schedule:
-- SELECT cron.schedule('cleanup-audit-logs', '0 3 * * 0', 'SELECT cleanup_old_audit_logs(90)');

-- =====================================================
-- HELPFUL VIEWS
-- =====================================================

-- View: Recent security alerts
CREATE OR REPLACE VIEW recent_security_alerts AS
SELECT 
    id,
    event_type,
    description,
    user_id,
    metadata,
    ip_address,
    created_at
FROM audit_logs
WHERE severity IN ('error', 'critical')
   OR event_type IN ('security_alert', 'rate_limit_exceeded')
ORDER BY created_at DESC
LIMIT 100;

-- View: User activity summary (last 24 hours)
CREATE OR REPLACE VIEW user_activity_summary AS
SELECT 
    user_id,
    COUNT(*) as total_events,
    COUNT(DISTINCT event_type) as unique_event_types,
    MAX(created_at) as last_activity,
    jsonb_object_agg(event_type, event_count) as event_breakdown
FROM (
    SELECT 
        user_id,
        event_type,
        COUNT(*) as event_count
    FROM audit_logs
    WHERE created_at > NOW() - INTERVAL '24 hours'
    GROUP BY user_id, event_type
) sub
GROUP BY user_id;

-- Grant access to views
GRANT SELECT ON recent_security_alerts TO authenticated;
GRANT SELECT ON user_activity_summary TO authenticated;

-- =====================================================
-- SAMPLE QUERIES FOR ADMINISTRATORS
-- =====================================================
-- 
-- 1. Get all login attempts in last hour:
-- SELECT * FROM audit_logs 
-- WHERE event_type = 'auth_login' 
-- AND created_at > NOW() - INTERVAL '1 hour';
--
-- 2. Get failed operations:
-- SELECT * FROM audit_logs 
-- WHERE severity IN ('error', 'critical')
-- ORDER BY created_at DESC;
--
-- 3. Get activity for specific user:
-- SELECT * FROM audit_logs 
-- WHERE user_id = 'user-uuid-here'
-- ORDER BY created_at DESC;
--
-- 4. Count events by type:
-- SELECT event_type, COUNT(*) 
-- FROM audit_logs 
-- GROUP BY event_type 
-- ORDER BY COUNT(*) DESC;
