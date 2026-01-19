-- =============================================
-- ADD MESSAGE READ STATUS FOR SEEN/UNSEEN BADGES
-- Run this in Supabase SQL Editor
-- =============================================

-- Add is_read column to messages table
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE;

-- Add read_at timestamp for when the message was read
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

-- Create index for faster unread message queries
CREATE INDEX IF NOT EXISTS idx_messages_unread 
ON messages(conversation_id, is_read) 
WHERE is_read = FALSE;

-- Create index for sender filtering
CREATE INDEX IF NOT EXISTS idx_messages_sender_read 
ON messages(conversation_id, sender_id, is_read);

-- Function to get unread message count for a user in a conversation
CREATE OR REPLACE FUNCTION get_unread_message_count(
  p_conversation_id UUID,
  p_user_id UUID
)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM messages m
    WHERE m.conversation_id = p_conversation_id
    AND m.sender_id != p_user_id  -- Only count messages from others
    AND m.is_read = FALSE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark all messages as read for a user in a conversation
CREATE OR REPLACE FUNCTION mark_messages_as_read(
  p_conversation_id UUID,
  p_user_id UUID
)
RETURNS VOID AS $$
BEGIN
  UPDATE messages
  SET 
    is_read = TRUE,
    read_at = NOW()
  WHERE conversation_id = p_conversation_id
  AND sender_id != p_user_id  -- Only mark messages from others as read
  AND is_read = FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_unread_message_count TO authenticated;
GRANT EXECUTE ON FUNCTION mark_messages_as_read TO authenticated;

-- Update existing messages to be marked as read (historical data)
UPDATE messages SET is_read = TRUE WHERE is_read IS NULL OR is_read = FALSE;

-- Verify column was added
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'messages' 
AND column_name IN ('is_read', 'read_at');
