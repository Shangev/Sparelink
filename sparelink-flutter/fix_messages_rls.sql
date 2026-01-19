-- =============================================
-- FIX CONVERSATIONS & MESSAGES TABLES - RLS POLICIES
-- Run this in Supabase SQL Editor
-- =============================================
-- This ensures Shops and Mechanics can send messages
-- =============================================

-- =============================================
-- CONVERSATIONS TABLE
-- =============================================

-- Enable RLS on conversations table
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view their conversations" ON conversations;
DROP POLICY IF EXISTS "Users can create conversations" ON conversations;
DROP POLICY IF EXISTS "Shops can view their conversations" ON conversations;
DROP POLICY IF EXISTS "Mechanics can view their conversations" ON conversations;
DROP POLICY IF EXISTS "Shops can create conversations" ON conversations;
DROP POLICY IF EXISTS "Mechanics can create conversations" ON conversations;

-- Shops can view conversations they are part of
CREATE POLICY "Shops can view their conversations"
ON conversations FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM shops s
    WHERE s.id = conversations.shop_id
    AND s.owner_id = auth.uid()
  )
);

-- Mechanics can view conversations for their requests
CREATE POLICY "Mechanics can view their conversations"
ON conversations FOR SELECT
USING (
  mechanic_id = auth.uid()
);

-- Shops can create conversations
CREATE POLICY "Shops can create conversations"
ON conversations FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM shops s
    WHERE s.id = shop_id
    AND s.owner_id = auth.uid()
  )
);

-- Mechanics can create conversations
CREATE POLICY "Mechanics can create conversations"
ON conversations FOR INSERT
WITH CHECK (
  mechanic_id = auth.uid()
);

-- =============================================
-- MESSAGES TABLE
-- =============================================

-- Enable RLS on messages table
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view messages in their conversations" ON messages;
DROP POLICY IF EXISTS "Users can send messages to their conversations" ON messages;
DROP POLICY IF EXISTS "Participants can view messages" ON messages;
DROP POLICY IF EXISTS "Participants can send messages" ON messages;

-- Users can view messages in conversations they are part of
CREATE POLICY "Participants can view messages"
ON messages FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = messages.conversation_id
    AND (
      c.mechanic_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM shops s
        WHERE s.id = c.shop_id
        AND s.owner_id = auth.uid()
      )
    )
  )
);

-- Users can send messages to conversations they are part of
CREATE POLICY "Participants can send messages"
ON messages FOR INSERT
WITH CHECK (
  sender_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = conversation_id
    AND (
      c.mechanic_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM shops s
        WHERE s.id = c.shop_id
        AND s.owner_id = auth.uid()
      )
    )
  )
);

-- =============================================
-- CREATE INDEXES FOR PERFORMANCE
-- =============================================

CREATE INDEX IF NOT EXISTS idx_conversations_shop_id ON conversations(shop_id);
CREATE INDEX IF NOT EXISTS idx_conversations_mechanic_id ON conversations(mechanic_id);
CREATE INDEX IF NOT EXISTS idx_conversations_request_id ON conversations(request_id);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);

-- =============================================
-- VERIFY POLICIES
-- =============================================

SELECT tablename, policyname, cmd as operation
FROM pg_policies 
WHERE tablename IN ('conversations', 'messages')
ORDER BY tablename, policyname;
