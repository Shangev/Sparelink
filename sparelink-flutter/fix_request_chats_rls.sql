-- =============================================
-- FIX REQUEST_CHATS TABLE - RLS POLICIES
-- Run this in Supabase SQL Editor
-- =============================================
-- This ensures Shops can see chats assigned to them
-- and Mechanics can see chats for their requests
-- =============================================

-- 1. Enable RLS on request_chats table (if not already enabled)
ALTER TABLE request_chats ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Mechanics can view their request chats" ON request_chats;
DROP POLICY IF EXISTS "Shops can view their assigned chats" ON request_chats;
DROP POLICY IF EXISTS "Mechanics can create request chats" ON request_chats;
DROP POLICY IF EXISTS "Shops can update their assigned chats" ON request_chats;
DROP POLICY IF EXISTS "Anyone can insert request_chats" ON request_chats;

-- 3. Create RLS policies for request_chats table

-- MECHANICS: Can view chats for requests they created
CREATE POLICY "Mechanics can view their request chats"
ON request_chats FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM part_requests pr
    WHERE pr.id = request_chats.request_id
    AND pr.mechanic_id = auth.uid()
  )
);

-- SHOPS: Can view chats assigned to their shop
-- This checks if the user owns the shop that was assigned the chat
CREATE POLICY "Shops can view their assigned chats"
ON request_chats FOR SELECT
USING (
  shop_owner_id = auth.uid()
  OR
  EXISTS (
    SELECT 1 FROM shops s
    WHERE s.id = request_chats.shop_id
    AND s.owner_id = auth.uid()
  )
);

-- MECHANICS: Can create request_chats when submitting a request
CREATE POLICY "Mechanics can create request chats"
ON request_chats FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM part_requests pr
    WHERE pr.id = request_id
    AND pr.mechanic_id = auth.uid()
  )
);

-- SHOPS: Can update chats assigned to them (status, quote_amount, etc.)
CREATE POLICY "Shops can update their assigned chats"
ON request_chats FOR UPDATE
USING (
  shop_owner_id = auth.uid()
  OR
  EXISTS (
    SELECT 1 FROM shops s
    WHERE s.id = request_chats.shop_id
    AND s.owner_id = auth.uid()
  )
)
WITH CHECK (
  shop_owner_id = auth.uid()
  OR
  EXISTS (
    SELECT 1 FROM shops s
    WHERE s.id = request_chats.shop_id
    AND s.owner_id = auth.uid()
  )
);

-- 4. Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_request_chats_shop_id ON request_chats(shop_id);
CREATE INDEX IF NOT EXISTS idx_request_chats_shop_owner_id ON request_chats(shop_owner_id);
CREATE INDEX IF NOT EXISTS idx_request_chats_request_id ON request_chats(request_id);
CREATE INDEX IF NOT EXISTS idx_request_chats_status ON request_chats(status);

-- 5. Verify the policies were created
SELECT 
  policyname, 
  cmd as operation,
  qual as using_expression
FROM pg_policies 
WHERE tablename = 'request_chats';
