-- =============================================
-- FIX NOTIFICATIONS RLS POLICY
-- Run this in Supabase SQL Editor
-- =============================================

-- Option 1: Create a database function to send notifications (RECOMMENDED)
-- This function runs with SECURITY DEFINER, meaning it bypasses RLS
-- and runs with the privileges of the function owner (postgres)

CREATE OR REPLACE FUNCTION send_notification(
    p_user_id UUID,
    p_title VARCHAR(255),
    p_body TEXT,
    p_type VARCHAR(50) DEFAULT 'system',
    p_reference_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER  -- This allows the function to bypass RLS
SET search_path = public
AS $$
DECLARE
    v_notification_id UUID;
BEGIN
    INSERT INTO notifications (user_id, title, body, type, reference_id)
    VALUES (p_user_id, p_title, p_body, p_type, p_reference_id)
    RETURNING id INTO v_notification_id;
    
    RETURN v_notification_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION send_notification TO authenticated;

-- Option 2 (Alternative): Update RLS policy to allow any authenticated user to INSERT
-- This is simpler but less secure - uncomment if you prefer this approach
/*
-- First, enable RLS if not already enabled
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Allow any authenticated user to insert notifications (for sending to others)
CREATE POLICY "Authenticated users can create notifications"
ON notifications FOR INSERT
TO authenticated
WITH CHECK (true);

-- Users can only view their own notifications
CREATE POLICY "Users can view own notifications"
ON notifications FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Users can only update their own notifications (mark as read)
CREATE POLICY "Users can update own notifications"
ON notifications FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Users can only delete their own notifications
CREATE POLICY "Users can delete own notifications"
ON notifications FOR DELETE
TO authenticated
USING (auth.uid() = user_id);
*/

-- Verify the function was created
SELECT proname, prosecdef FROM pg_proc WHERE proname = 'send_notification';
