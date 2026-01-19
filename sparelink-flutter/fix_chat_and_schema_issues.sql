-- =====================================================
-- FIX CHAT & MESSAGING ISSUES + SCHEMA CACHE ERROR
-- Run this in Supabase SQL Editor
-- =====================================================

-- =====================================================
-- ISSUE 1: Fix messages table for read status tracking
-- =====================================================

-- Ensure is_read column exists with proper default
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'messages' AND column_name = 'is_read') THEN
        ALTER TABLE messages ADD COLUMN is_read BOOLEAN DEFAULT false;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'messages' AND column_name = 'read_at') THEN
        ALTER TABLE messages ADD COLUMN read_at TIMESTAMPTZ;
    END IF;
END $$;

-- Create index for faster unread queries
CREATE INDEX IF NOT EXISTS idx_messages_is_read ON messages(conversation_id, is_read) 
WHERE is_read = false;

-- =====================================================
-- ISSUE 2: Fix RLS policy for marking messages as read
-- The UPDATE policy must allow users to mark messages as read
-- =====================================================

-- Drop existing restrictive policy if exists
DROP POLICY IF EXISTS "Users can update messages in their conversations" ON messages;

-- Create permissive policy for updating is_read
CREATE POLICY "Users can mark messages as read in their conversations" ON messages
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM conversations c 
            WHERE c.id = messages.conversation_id 
            AND (c.mechanic_id = auth.uid() OR c.shop_id = auth.uid())
        )
    )
    WITH CHECK (
        -- Can only update is_read and read_at fields (not message content by others)
        EXISTS (
            SELECT 1 FROM conversations c 
            WHERE c.id = messages.conversation_id 
            AND (c.mechanic_id = auth.uid() OR c.shop_id = auth.uid())
        )
    );

-- =====================================================
-- ISSUE 3: Add missing budget columns to part_requests
-- This fixes the PGRST204 schema cache error
-- =====================================================

DO $$ 
BEGIN
    -- Add budget_min column if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'part_requests' AND column_name = 'budget_min') THEN
        ALTER TABLE part_requests ADD COLUMN budget_min DECIMAL(10,2);
        COMMENT ON COLUMN part_requests.budget_min IS 'Minimum budget in Rands (optional)';
    END IF;
    
    -- Add budget_max column if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'part_requests' AND column_name = 'budget_max') THEN
        ALTER TABLE part_requests ADD COLUMN budget_max DECIMAL(10,2);
        COMMENT ON COLUMN part_requests.budget_max IS 'Maximum budget in Rands (optional)';
    END IF;
    
    -- Add urgency column if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'part_requests' AND column_name = 'urgency') THEN
        ALTER TABLE part_requests ADD COLUMN urgency VARCHAR(20) DEFAULT 'normal';
        COMMENT ON COLUMN part_requests.urgency IS 'Request urgency: urgent, normal, flexible';
    END IF;
    
    -- Add part_number column if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'part_requests' AND column_name = 'part_number') THEN
        ALTER TABLE part_requests ADD COLUMN part_number VARCHAR(100);
        COMMENT ON COLUMN part_requests.part_number IS 'OEM part number if known';
    END IF;
END $$;

-- =====================================================
-- ISSUE 2 CONTINUED: Add archived_at to conversations
-- =====================================================

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'conversations' AND column_name = 'archived_at') THEN
        ALTER TABLE conversations ADD COLUMN archived_at TIMESTAMPTZ;
        COMMENT ON COLUMN conversations.archived_at IS 'Timestamp when conversation was archived';
    END IF;
END $$;

-- Create index for filtering archived conversations
CREATE INDEX IF NOT EXISTS idx_conversations_archived ON conversations(archived_at) 
WHERE archived_at IS NOT NULL;

-- =====================================================
-- RELOAD SCHEMA CACHE
-- This is CRITICAL to fix PGRST204 errors
-- =====================================================

-- Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';

-- Alternative: If using Supabase, you can also run:
-- SELECT pg_notify('pgrst', 'reload schema');

-- =====================================================
-- VERIFICATION QUERIES (run these to confirm fixes)
-- =====================================================

-- Check if columns exist:
-- SELECT column_name, data_type FROM information_schema.columns 
-- WHERE table_name = 'part_requests' AND column_name IN ('budget_min', 'budget_max', 'urgency', 'part_number');

-- Check messages columns:
-- SELECT column_name, data_type FROM information_schema.columns 
-- WHERE table_name = 'messages' AND column_name IN ('is_read', 'read_at');

-- Check conversations columns:
-- SELECT column_name, data_type FROM information_schema.columns 
-- WHERE table_name = 'conversations' AND column_name = 'archived_at';

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '✅ Schema updates completed successfully!';
    RAISE NOTICE '✅ Run NOTIFY pgrst, ''reload schema''; to refresh the API cache';
    RAISE NOTICE '✅ Unread message tracking: is_read, read_at columns added';
    RAISE NOTICE '✅ Budget columns: budget_min, budget_max added to part_requests';
    RAISE NOTICE '✅ Archive support: archived_at column added to conversations';
END $$;
