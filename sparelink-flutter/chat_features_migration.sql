-- =====================================================
-- CHAT & MESSAGING FEATURES MIGRATION
-- Run this in Supabase SQL Editor
-- =====================================================

-- 1. TYPING STATUS TABLE
-- Tracks when users are typing in a conversation
CREATE TABLE IF NOT EXISTS typing_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    is_typing BOOLEAN DEFAULT false,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(conversation_id, user_id)
);

-- Enable RLS
ALTER TABLE typing_status ENABLE ROW LEVEL SECURITY;

-- RLS Policies for typing_status
CREATE POLICY "Users can view typing status in their conversations" ON typing_status
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM conversations c 
            WHERE c.id = typing_status.conversation_id 
            AND (c.mechanic_id = auth.uid() OR c.shop_id = auth.uid())
        )
    );

CREATE POLICY "Users can update their own typing status" ON typing_status
    FOR ALL USING (user_id = auth.uid());

-- Enable realtime for typing_status
ALTER PUBLICATION supabase_realtime ADD TABLE typing_status;

-- 2. USER PRESENCE TABLE
-- Tracks online/offline status
CREATE TABLE IF NOT EXISTS user_presence (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    is_online BOOLEAN DEFAULT false,
    last_seen TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_presence ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_presence
CREATE POLICY "Anyone can view presence" ON user_presence
    FOR SELECT USING (true);

CREATE POLICY "Users can update their own presence" ON user_presence
    FOR ALL USING (user_id = auth.uid());

-- Enable realtime for user_presence
ALTER PUBLICATION supabase_realtime ADD TABLE user_presence;

-- 3. MESSAGE REACTIONS TABLE
-- Stores emoji reactions to messages
CREATE TABLE IF NOT EXISTS message_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    emoji VARCHAR(10) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(message_id, user_id, emoji)
);

-- Enable RLS
ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for message_reactions
CREATE POLICY "Users can view reactions in their conversations" ON message_reactions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM messages m
            JOIN conversations c ON m.conversation_id = c.id
            WHERE m.id = message_reactions.message_id
            AND (c.mechanic_id = auth.uid() OR c.shop_id = auth.uid())
        )
    );

CREATE POLICY "Users can add reactions" ON message_reactions
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can remove their own reactions" ON message_reactions
    FOR DELETE USING (user_id = auth.uid());

-- 4. BLOCKED USERS TABLE
-- Stores blocked user relationships
CREATE TABLE IF NOT EXISTS blocked_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(blocker_id, blocked_id)
);

-- Enable RLS
ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;

-- RLS Policies for blocked_users
CREATE POLICY "Users can view their blocked list" ON blocked_users
    FOR SELECT USING (blocker_id = auth.uid());

CREATE POLICY "Users can block others" ON blocked_users
    FOR INSERT WITH CHECK (blocker_id = auth.uid());

CREATE POLICY "Users can unblock others" ON blocked_users
    FOR DELETE USING (blocker_id = auth.uid());

-- 5. USER REPORTS TABLE
-- Stores user reports for safety
CREATE TABLE IF NOT EXISTS user_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reported_user_id UUID NOT NULL,
    conversation_id UUID REFERENCES conversations(id) ON DELETE SET NULL,
    reason TEXT NOT NULL,
    details TEXT,
    status VARCHAR(20) DEFAULT 'pending', -- pending, reviewed, resolved, dismissed
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_reports ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_reports
CREATE POLICY "Users can create reports" ON user_reports
    FOR INSERT WITH CHECK (reporter_id = auth.uid());

CREATE POLICY "Users can view their own reports" ON user_reports
    FOR SELECT USING (reporter_id = auth.uid());

-- 6. FCM TOKENS TABLE (for push notifications)
CREATE TABLE IF NOT EXISTS user_fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform VARCHAR(20) NOT NULL, -- 'android', 'ios', 'web'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, token)
);

-- Enable RLS
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_fcm_tokens
CREATE POLICY "Users can manage their own tokens" ON user_fcm_tokens
    FOR ALL USING (user_id = auth.uid());

-- 7. ADD COLUMNS TO MESSAGES TABLE (if not exists)
-- For voice messages, file attachments, editing, deletion
DO $$ 
BEGIN
    -- message_type: 'text', 'image', 'voice', 'file'
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'message_type') THEN
        ALTER TABLE messages ADD COLUMN message_type VARCHAR(20) DEFAULT 'text';
    END IF;
    
    -- attachment_url: URL to uploaded file/image/voice
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'attachment_url') THEN
        ALTER TABLE messages ADD COLUMN attachment_url TEXT;
    END IF;
    
    -- file_name: Original filename for file attachments
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'file_name') THEN
        ALTER TABLE messages ADD COLUMN file_name VARCHAR(255);
    END IF;
    
    -- duration_seconds: For voice messages
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'duration_seconds') THEN
        ALTER TABLE messages ADD COLUMN duration_seconds INTEGER;
    END IF;
    
    -- edited_at: Timestamp when message was edited
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'edited_at') THEN
        ALTER TABLE messages ADD COLUMN edited_at TIMESTAMPTZ;
    END IF;
    
    -- deleted_at: Soft delete timestamp
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'deleted_at') THEN
        ALTER TABLE messages ADD COLUMN deleted_at TIMESTAMPTZ;
    END IF;
END $$;

-- 8. ADD ARCHIVED_AT TO CONVERSATIONS TABLE
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'conversations' AND column_name = 'archived_at') THEN
        ALTER TABLE conversations ADD COLUMN archived_at TIMESTAMPTZ;
    END IF;
END $$;

-- 9. CREATE STORAGE BUCKETS (run these in Supabase Dashboard > Storage)
-- Note: These need to be created via Supabase Dashboard or API
-- Bucket names: chat-images, chat-files, chat-voice

-- 10. INDEXES FOR PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_typing_status_conversation ON typing_status(conversation_id);
CREATE INDEX IF NOT EXISTS idx_message_reactions_message ON message_reactions(message_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker ON blocked_users(blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_reports_status ON user_reports(status);
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user ON user_fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_type ON messages(message_type);
CREATE INDEX IF NOT EXISTS idx_conversations_archived ON conversations(archived_at) WHERE archived_at IS NOT NULL;

-- 11. FUNCTION TO SEND PUSH NOTIFICATION (called via Edge Function or external service)
-- This creates a notification record which can trigger a webhook to send push
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert notification for the recipient
    INSERT INTO notifications (user_id, type, title, body, reference_id)
    SELECT 
        CASE 
            WHEN c.mechanic_id = NEW.sender_id THEN c.shop_id
            ELSE c.mechanic_id
        END,
        'message',
        'New Message',
        LEFT(NEW.text, 100),
        NEW.conversation_id
    FROM conversations c
    WHERE c.id = NEW.conversation_id
    AND NOT EXISTS (
        SELECT 1 FROM blocked_users bu
        WHERE bu.blocker_id = CASE 
            WHEN c.mechanic_id = NEW.sender_id THEN c.shop_id
            ELSE c.mechanic_id
        END
        AND bu.blocked_id = NEW.sender_id
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new messages
DROP TRIGGER IF EXISTS on_new_message ON messages;
CREATE TRIGGER on_new_message
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_message();

-- =====================================================
-- STORAGE BUCKET SETUP (Run in Supabase Dashboard)
-- =====================================================
-- 1. Go to Storage in Supabase Dashboard
-- 2. Create buckets: chat-images, chat-files, chat-voice
-- 3. Set bucket policies to allow authenticated users to upload/download
-- 
-- Example policy for chat-images bucket:
-- INSERT policy: (auth.role() = 'authenticated')
-- SELECT policy: (auth.role() = 'authenticated')
