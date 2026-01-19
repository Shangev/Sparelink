-- =====================================================
-- STALE CHAT CLEANUP - 24-HOUR RETENTION POLICY
-- Run this in Supabase SQL Editor
-- =====================================================

-- =====================================================
-- 1. ADD last_message_at COLUMN IF NOT EXISTS
-- This column tracks the timestamp of the last message
-- =====================================================

DO $$ 
BEGIN
    -- Add last_message_at to request_chats if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'request_chats' AND column_name = 'last_message_at') THEN
        ALTER TABLE request_chats ADD COLUMN last_message_at TIMESTAMPTZ;
        COMMENT ON COLUMN request_chats.last_message_at IS 'Timestamp of the last message in this chat';
    END IF;
    
    -- Add last_message_at to conversations if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'conversations' AND column_name = 'last_message_at') THEN
        ALTER TABLE conversations ADD COLUMN last_message_at TIMESTAMPTZ;
        COMMENT ON COLUMN conversations.last_message_at IS 'Timestamp of the last message in this conversation';
    END IF;
END $$;

-- Create indexes for efficient TTL queries
CREATE INDEX IF NOT EXISTS idx_request_chats_last_message ON request_chats(last_message_at);
CREATE INDEX IF NOT EXISTS idx_conversations_last_message ON conversations(last_message_at);

-- =====================================================
-- 2. FUNCTION: Update last_message_at when new message arrives
-- =====================================================

CREATE OR REPLACE FUNCTION update_chat_last_message_at()
RETURNS TRIGGER AS $$
BEGIN
    -- Update request_chats last_message_at
    UPDATE request_chats 
    SET last_message_at = NEW.sent_at,
        updated_at = NOW()
    WHERE request_id = NEW.request_id 
      AND shop_id = NEW.shop_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for request_chat_messages
DROP TRIGGER IF EXISTS on_new_chat_message_update_timestamp ON request_chat_messages;
CREATE TRIGGER on_new_chat_message_update_timestamp
    AFTER INSERT ON request_chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_chat_last_message_at();

-- =====================================================
-- 3. FUNCTION: Delete stale conversations (24-hour rule)
-- Called by cron job or manually
-- =====================================================

CREATE OR REPLACE FUNCTION delete_stale_conversations()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER := 0;
    request_chats_deleted INTEGER := 0;
    conversations_deleted INTEGER := 0;
BEGIN
    -- Delete stale request_chats where:
    -- 1. Status is 'completed', 'rejected', or 'cancelled'
    -- 2. Last message/update was more than 24 hours ago
    DELETE FROM request_chats
    WHERE status IN ('completed', 'rejected', 'cancelled', 'accepted')
      AND COALESCE(last_message_at, updated_at, created_at) < NOW() - INTERVAL '24 hours';
    
    GET DIAGNOSTICS request_chats_deleted = ROW_COUNT;
    
    -- Delete stale conversations where:
    -- 1. Status is 'closed' or 'completed'
    -- 2. Last message was more than 24 hours ago
    DELETE FROM conversations
    WHERE status IN ('closed', 'completed')
      AND COALESCE(last_message_at, updated_at, created_at) < NOW() - INTERVAL '24 hours';
    
    GET DIAGNOSTICS conversations_deleted = ROW_COUNT;
    
    deleted_count := request_chats_deleted + conversations_deleted;
    
    RAISE NOTICE '🗑️ Deleted % stale chats (% request_chats, % conversations)', 
                 deleted_count, request_chats_deleted, conversations_deleted;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 4. AUTOMATIC CLEANUP: PostgreSQL pg_cron extension
-- NOTE: This requires pg_cron extension to be enabled
-- Run this ONLY if pg_cron is available in your Supabase plan
-- =====================================================

-- Enable pg_cron if not already enabled (requires admin)
-- CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule cleanup to run every hour
-- SELECT cron.schedule(
--     'cleanup-stale-chats',
--     '0 * * * *',  -- Every hour at minute 0
--     'SELECT delete_stale_conversations();'
-- );

-- To view scheduled jobs:
-- SELECT * FROM cron.job;

-- To remove the scheduled job:
-- SELECT cron.unschedule('cleanup-stale-chats');

-- =====================================================
-- 5. ALTERNATIVE: Supabase Edge Function trigger
-- If pg_cron is not available, use this approach
-- =====================================================

-- Create a function that can be called via HTTP (Edge Function)
CREATE OR REPLACE FUNCTION cleanup_stale_chats_http()
RETURNS JSON AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    SELECT delete_stale_conversations() INTO deleted_count;
    
    RETURN json_build_object(
        'success', true,
        'deleted_count', deleted_count,
        'timestamp', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 6. IMMEDIATE CLEANUP: Run this to clean up existing stale chats NOW
-- =====================================================

-- Uncomment and run to immediately delete stale chats:
-- SELECT delete_stale_conversations();

-- =====================================================
-- 7. ADD is_read COLUMN TO request_chat_messages IF NOT EXISTS
-- =====================================================

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'request_chat_messages' AND column_name = 'is_read') THEN
        ALTER TABLE request_chat_messages ADD COLUMN is_read BOOLEAN DEFAULT false;
        COMMENT ON COLUMN request_chat_messages.is_read IS 'Whether the message has been read by the recipient';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'request_chat_messages' AND column_name = 'read_at') THEN
        ALTER TABLE request_chat_messages ADD COLUMN read_at TIMESTAMPTZ;
        COMMENT ON COLUMN request_chat_messages.read_at IS 'Timestamp when the message was read';
    END IF;
END $$;

-- Create index for unread message queries
CREATE INDEX IF NOT EXISTS idx_request_chat_messages_unread 
ON request_chat_messages(request_id, shop_id, is_read) 
WHERE is_read = false;

-- =====================================================
-- 8. RLS POLICY: Allow users to mark messages as read
-- =====================================================

-- Drop existing policy if exists
DROP POLICY IF EXISTS "Users can mark messages as read" ON request_chat_messages;

-- Create policy allowing message recipients to mark messages as read
CREATE POLICY "Users can mark messages as read" ON request_chat_messages
    FOR UPDATE 
    USING (
        -- User is either the shop owner or the mechanic who created the request
        EXISTS (
            SELECT 1 FROM part_requests pr
            WHERE pr.id = request_chat_messages.request_id
            AND (pr.mechanic_id = auth.uid() OR request_chat_messages.shop_id = auth.uid())
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM part_requests pr
            WHERE pr.id = request_chat_messages.request_id
            AND (pr.mechanic_id = auth.uid() OR request_chat_messages.shop_id = auth.uid())
        )
    );

-- =====================================================
-- 9. RELOAD SCHEMA CACHE
-- =====================================================

NOTIFY pgrst, 'reload schema';

-- =====================================================
-- 10. VERIFICATION QUERIES
-- =====================================================

-- Check stale chats that WOULD be deleted (preview):
-- SELECT id, status, last_message_at, updated_at, created_at
-- FROM request_chats
-- WHERE status IN ('completed', 'rejected', 'cancelled', 'accepted')
--   AND COALESCE(last_message_at, updated_at, created_at) < NOW() - INTERVAL '24 hours';

-- Check columns exist:
-- SELECT column_name FROM information_schema.columns 
-- WHERE table_name = 'request_chat_messages' AND column_name IN ('is_read', 'read_at');

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '✅ Stale chat cleanup system installed!';
    RAISE NOTICE '✅ 24-hour retention policy ready';
    RAISE NOTICE '✅ Run SELECT delete_stale_conversations(); to clean up now';
    RAISE NOTICE '✅ is_read column added to request_chat_messages';
    RAISE NOTICE '✅ RLS policy for marking messages as read created';
END $$;
