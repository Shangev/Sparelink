-- ============================================
-- DIAGNOSTIC SQL: Check Offers and Orders Status
-- Run this in Supabase SQL Editor to diagnose the issue
-- ============================================

-- 1. Check all offers and their current status
SELECT 
  o.id as offer_id,
  o.status as offer_status,
  o.request_id,
  o.shop_id,
  o.price_cents,
  o.created_at as offer_created,
  s.name as shop_name,
  ord.id as order_id,
  ord.status as order_status,
  ord.created_at as order_created
FROM offers o
LEFT JOIN shops s ON o.shop_id = s.id
LEFT JOIN orders ord ON ord.offer_id = o.id
ORDER BY o.created_at DESC;

-- 2. Check if there are orders without the offer status being updated
SELECT 
  ord.id as order_id,
  ord.offer_id,
  o.status as offer_status,
  ord.status as order_status,
  ord.created_at
FROM orders ord
JOIN offers o ON ord.offer_id = o.id
WHERE o.status != 'accepted';

-- 3. Check offers that should be 'accepted' (have associated orders)
-- This will show if the Flutter app failed to update offer status
SELECT 
  o.id as offer_id,
  o.status as current_status,
  'should be accepted' as expected_status,
  ord.id as order_id
FROM offers o
JOIN orders ord ON ord.offer_id = o.id
WHERE o.status = 'pending';

-- ============================================
-- FIX: Update offers that have orders but status is still 'pending'
-- ============================================

-- This will fix any offers that have orders created but status wasn't updated
UPDATE offers o
SET status = 'accepted', updated_at = NOW()
FROM orders ord
WHERE ord.offer_id = o.id
  AND o.status = 'pending';

-- ============================================
-- OPTIONAL: Add is_accepted boolean column for clearer tracking
-- (This is redundant but makes queries simpler)
-- ============================================

-- Add is_accepted column to offers table
ALTER TABLE public.offers 
ADD COLUMN IF NOT EXISTS is_accepted boolean DEFAULT false;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_offers_is_accepted ON public.offers(is_accepted);

-- Update is_accepted based on current status
UPDATE offers SET is_accepted = true WHERE status = 'accepted';
UPDATE offers SET is_accepted = false WHERE status != 'accepted';

-- Create trigger to keep is_accepted in sync with status
CREATE OR REPLACE FUNCTION sync_offer_is_accepted()
RETURNS TRIGGER AS $$
BEGIN
  NEW.is_accepted = (NEW.status = 'accepted');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sync_offer_accepted_trigger ON offers;
CREATE TRIGGER sync_offer_accepted_trigger
  BEFORE INSERT OR UPDATE ON offers
  FOR EACH ROW
  EXECUTE FUNCTION sync_offer_is_accepted();

-- ============================================
-- CHECK RLS POLICIES: Make sure shop owners can see their orders
-- ============================================

-- View current RLS policies on orders table
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'orders';

-- View current RLS policies on offers table
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'offers';

-- ============================================
-- IF RLS IS BLOCKING: Add policies for offers and orders tables
-- ============================================

-- ============================================
-- OFFERS TABLE RLS POLICIES
-- ============================================

-- Enable RLS on offers if not already enabled
ALTER TABLE offers ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can view offers (needed for marketplace)
DROP POLICY IF EXISTS "Anyone can view offers" ON offers;
CREATE POLICY "Anyone can view offers" ON offers
  FOR SELECT
  USING (true);

-- Policy: Shop owners can insert offers for their shop
DROP POLICY IF EXISTS "Shop owners can create offers" ON offers;
CREATE POLICY "Shop owners can create offers" ON offers
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM shops s
      WHERE s.id = shop_id
        AND s.owner_id = auth.uid()
    )
  );

-- Policy: Shop owners can update their own offers
DROP POLICY IF EXISTS "Shop owners can update their offers" ON offers;
CREATE POLICY "Shop owners can update their offers" ON offers
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM shops s
      WHERE s.id = offers.shop_id
        AND s.owner_id = auth.uid()
    )
  );

-- CRITICAL: Mechanics can update offer status when accepting
-- This allows the mechanic to change status to 'accepted' when they accept an offer
DROP POLICY IF EXISTS "Mechanics can accept offers on their requests" ON offers;
CREATE POLICY "Mechanics can accept offers on their requests" ON offers
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM part_requests pr
      WHERE pr.id = offers.request_id
        AND pr.mechanic_id = auth.uid()
    )
  );

-- ============================================
-- ORDERS TABLE RLS POLICIES
-- ============================================

-- Enable RLS on orders if not already enabled
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Policy: Mechanics can view their own orders
DROP POLICY IF EXISTS "Mechanics can view their orders" ON orders;
CREATE POLICY "Mechanics can view their orders" ON orders
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM part_requests pr
      WHERE pr.id = orders.request_id
        AND pr.mechanic_id = auth.uid()
    )
  );

-- Policy: Shop owners can view orders linked to their shop's offers
DROP POLICY IF EXISTS "Shop owners can view their orders" ON orders;
CREATE POLICY "Shop owners can view their orders" ON orders
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM offers o
      JOIN shops s ON o.shop_id = s.id
      WHERE o.id = orders.offer_id
        AND s.owner_id = auth.uid()
    )
  );

-- Policy: Mechanics can create orders (when accepting offers)
DROP POLICY IF EXISTS "Mechanics can create orders" ON orders;
CREATE POLICY "Mechanics can create orders" ON orders
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM part_requests pr
      WHERE pr.id = request_id
        AND pr.mechanic_id = auth.uid()
    )
  );

-- Policy: Shop owners can update their orders (status changes)
DROP POLICY IF EXISTS "Shop owners can update their orders" ON orders;
CREATE POLICY "Shop owners can update their orders" ON orders
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM offers o
      JOIN shops s ON o.shop_id = s.id
      WHERE o.id = orders.offer_id
        AND s.owner_id = auth.uid()
    )
  );
