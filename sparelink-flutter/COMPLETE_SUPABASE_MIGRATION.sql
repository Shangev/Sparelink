-- =====================================================
-- SPARELINK COMPLETE SUPABASE MIGRATION
-- =====================================================
-- This SQL file contains ALL the database changes needed
-- to support the new features implemented in SpareLink.
-- 
-- Copy this entire file and run it in Supabase SQL Editor:
-- Supabase Dashboard → SQL Editor → New Query → Paste → Run
-- 
-- Features Covered:
-- 1. Audit Logging System
-- 2. Saved Vehicles
-- 3. Request Templates
-- 4. Enhanced Part Requests (urgency, budget, notes)
-- 5. Part Number Search (OEM numbers)
-- =====================================================

-- =====================================================
-- 1. AUDIT LOGS TABLE
-- =====================================================
-- Tracks all user actions for security and compliance

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

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_event_type ON audit_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target ON audit_logs(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_severity ON audit_logs(severity);

-- Enable Row Level Security
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Users can only read their own audit logs
CREATE POLICY "Users can view own audit logs"
ON audit_logs FOR SELECT
USING (auth.uid() = user_id);

-- Insert allowed for authenticated users
CREATE POLICY "Authenticated users can insert audit logs"
ON audit_logs FOR INSERT
WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Function to cleanup old audit logs
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
    AND severity NOT IN ('error', 'critical');
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
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
-- 2. SAVED VEHICLES TABLE
-- =====================================================
-- Allows mechanics to save frequently used vehicles

CREATE TABLE IF NOT EXISTS saved_vehicles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Vehicle identification
    make_id VARCHAR(100),
    make_name VARCHAR(100) NOT NULL,
    model_id VARCHAR(100),
    model_name VARCHAR(100) NOT NULL,
    year VARCHAR(4) NOT NULL,
    
    -- Optional details
    vin VARCHAR(17),
    engine_code VARCHAR(50),
    nickname VARCHAR(100),
    
    -- Settings
    is_default BOOLEAN DEFAULT false,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_saved_vehicles_user_id ON saved_vehicles(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_vehicles_default ON saved_vehicles(user_id, is_default);
CREATE INDEX IF NOT EXISTS idx_saved_vehicles_vin ON saved_vehicles(vin) WHERE vin IS NOT NULL;

-- Enable RLS
ALTER TABLE saved_vehicles ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own saved vehicles"
ON saved_vehicles FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own saved vehicles"
ON saved_vehicles FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own saved vehicles"
ON saved_vehicles FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own saved vehicles"
ON saved_vehicles FOR DELETE
USING (auth.uid() = user_id);

-- =====================================================
-- 3. REQUEST TEMPLATES TABLE
-- =====================================================
-- Save frequently requested part combinations

CREATE TABLE IF NOT EXISTS request_templates (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    name VARCHAR(100) NOT NULL,
    
    -- Optional vehicle association
    make_id VARCHAR(100),
    make_name VARCHAR(100),
    model_id VARCHAR(100),
    model_name VARCHAR(100),
    
    -- Template parts (JSON array)
    parts JSONB NOT NULL DEFAULT '[]',
    
    -- Usage tracking
    use_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE request_templates ENABLE ROW LEVEL SECURITY;

-- RLS Policy
CREATE POLICY "Users can manage own templates"
ON request_templates FOR ALL
USING (auth.uid() = user_id);

-- Index
CREATE INDEX IF NOT EXISTS idx_request_templates_user ON request_templates(user_id);

-- =====================================================
-- 4. ENHANCED PART_REQUESTS TABLE
-- =====================================================
-- Add new columns for urgency, budget, and notes

-- Add urgency level column
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'part_requests' AND column_name = 'urgency_level') THEN
        ALTER TABLE part_requests ADD COLUMN urgency_level VARCHAR(20) DEFAULT 'normal';
    END IF;
END $$;

-- Add budget columns
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'part_requests' AND column_name = 'budget_min') THEN
        ALTER TABLE part_requests ADD COLUMN budget_min DECIMAL(10,2);
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'part_requests' AND column_name = 'budget_max') THEN
        ALTER TABLE part_requests ADD COLUMN budget_max DECIMAL(10,2);
    END IF;
END $$;

-- Add notes column
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'part_requests' AND column_name = 'notes') THEN
        ALTER TABLE part_requests ADD COLUMN notes TEXT;
    END IF;
END $$;

-- Add part_name column if not exists
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'part_requests' AND column_name = 'part_name') THEN
        ALTER TABLE part_requests ADD COLUMN part_name VARCHAR(255);
    END IF;
END $$;

-- =====================================================
-- 5. PARTS TABLE ENHANCEMENTS
-- =====================================================
-- Add OEM part number for part number search

-- Add OEM number column
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'parts' AND column_name = 'oem_number') THEN
        ALTER TABLE parts ADD COLUMN oem_number VARCHAR(100);
    END IF;
END $$;

-- Add cross references column (alternative part numbers)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'parts' AND column_name = 'cross_references') THEN
        ALTER TABLE parts ADD COLUMN cross_references TEXT[];
    END IF;
END $$;

-- Index for part number searches
CREATE INDEX IF NOT EXISTS idx_parts_oem_number ON parts(oem_number) WHERE oem_number IS NOT NULL;

-- =====================================================
-- 6. NOTIFICATIONS TABLE (if not exists)
-- =====================================================
-- For notification badge feature

CREATE TABLE IF NOT EXISTS notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    title VARCHAR(255) NOT NULL,
    message TEXT,
    type VARCHAR(50) DEFAULT 'info', -- info, quote, order, message, system
    
    -- Reference to related entity
    reference_type VARCHAR(50), -- part_request, offer, order, conversation
    reference_id UUID,
    
    -- Status
    read BOOLEAN DEFAULT false,
    read_at TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, read) WHERE read = false;
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at DESC);

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications"
ON notifications FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications"
ON notifications FOR UPDATE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "System can insert notifications" ON notifications;
CREATE POLICY "System can insert notifications"
ON notifications FOR INSERT
WITH CHECK (true);

-- =====================================================
-- 7. MESSAGES TABLE - Add read status
-- =====================================================

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'messages' AND column_name = 'read') THEN
        ALTER TABLE messages ADD COLUMN read BOOLEAN DEFAULT false;
    END IF;
END $$;

-- Index for unread messages
CREATE INDEX IF NOT EXISTS idx_messages_unread ON messages(sender_id, read) WHERE read = false;

-- =====================================================
-- 8. ORDERS TABLE ENHANCEMENTS
-- =====================================================

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'buyer_id') THEN
        ALTER TABLE orders ADD COLUMN buyer_id UUID REFERENCES auth.users(id);
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'completed_at') THEN
        ALTER TABLE orders ADD COLUMN completed_at TIMESTAMPTZ;
    END IF;
END $$;

-- =====================================================
-- 9. HELPER VIEWS
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

-- Grant access to views
GRANT SELECT ON recent_security_alerts TO authenticated;

-- =====================================================
-- 10. FUNCTION: Create notification
-- =====================================================
-- Helper function to create notifications from triggers

CREATE OR REPLACE FUNCTION create_notification(
    p_user_id UUID,
    p_title VARCHAR(255),
    p_message TEXT,
    p_type VARCHAR(50) DEFAULT 'info',
    p_reference_type VARCHAR(50) DEFAULT NULL,
    p_reference_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    notification_id UUID;
BEGIN
    INSERT INTO notifications (user_id, title, message, type, reference_type, reference_id)
    VALUES (p_user_id, p_title, p_message, p_type, p_reference_type, p_reference_id)
    RETURNING id INTO notification_id;
    
    RETURN notification_id;
END;
$$;

-- =====================================================
-- 11. TRIGGER: Notify on new offer
-- =====================================================
-- Automatically notify mechanic when they receive a new quote

CREATE OR REPLACE FUNCTION notify_on_new_offer()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    mechanic_id UUID;
    part_name TEXT;
BEGIN
    -- Get the mechanic who created the request
    SELECT pr.mechanic_id, pr.part_name INTO mechanic_id, part_name
    FROM part_requests pr
    WHERE pr.id = NEW.request_id;
    
    -- Create notification
    PERFORM create_notification(
        mechanic_id,
        'New Quote Received',
        'You received a quote of R' || NEW.price || ' for ' || COALESCE(part_name, 'your part request'),
        'quote',
        'offer',
        NEW.id
    );
    
    RETURN NEW;
END;
$$;

-- Create trigger (drop first if exists)
DROP TRIGGER IF EXISTS trigger_notify_new_offer ON offers;
CREATE TRIGGER trigger_notify_new_offer
    AFTER INSERT ON offers
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_new_offer();

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================
-- All tables and functions have been created/updated.
-- The SpareLink app should now work with all new features:
-- 
-- ✅ Audit Logging
-- ✅ Saved Vehicles
-- ✅ Request Templates
-- ✅ Urgency Levels & Budget Range
-- ✅ Part Number Search
-- ✅ Notifications with badges
-- ✅ Message read status
-- =====================================================
