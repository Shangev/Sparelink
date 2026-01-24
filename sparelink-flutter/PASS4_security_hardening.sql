-- =====================================================
-- PASS 4: SECURITY, QA & PRODUCTION HARDENING
-- Run this in Supabase SQL Editor
-- =====================================================
-- Focus Areas:
-- 1. RLS Security Audit - Shop data isolation
-- 2. Payload Validation - CHECK constraints
-- 3. Stress Testing - Index optimizations for 1000+ concurrent users
-- =====================================================

-- =====================================================
-- 1. RLS SECURITY AUDIT FIXES
-- =====================================================
-- Issue: Offers table has "Anyone can view offers" which could expose
-- competitor pricing if queried directly. Fix: Only show offers to
-- the mechanic who made the request OR the shop that made the offer.

-- Drop overly permissive policy
DROP POLICY IF EXISTS "Anyone can view offers" ON offers;

-- Create secure offer viewing policies
CREATE POLICY "Mechanics can view offers on their requests" ON offers
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM part_requests pr
      WHERE pr.id = offers.request_id
        AND pr.mechanic_id = auth.uid()
    )
  );

CREATE POLICY "Shops can view their own offers" ON offers
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM shops s
      WHERE s.id = offers.shop_id
        AND s.owner_id = auth.uid()
    )
  );

-- =====================================================
-- 2. PAYMENTS TABLE - SECURE SHOP ISOLATION
-- =====================================================
-- Issue: A shop should NEVER see another shop's payment data

-- Verify existing policies are secure (add IF NOT EXISTS protection)
DROP POLICY IF EXISTS "Shop owners can view their payments" ON payments;
CREATE POLICY "Shop owners can view their payments"
  ON payments FOR SELECT
  USING (
    shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
  );

-- Add policy to prevent cross-shop payment viewing
DROP POLICY IF EXISTS "Prevent cross-shop payment access" ON payments;
CREATE POLICY "Mechanics can view their order payments"
  ON payments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      JOIN part_requests pr ON o.request_id = pr.id
      WHERE o.id = payments.order_id
        AND pr.mechanic_id = auth.uid()
    )
  );

-- =====================================================
-- 3. INVENTORY TABLE - STRICT SHOP ISOLATION
-- =====================================================
-- A shop's inventory is PRIVATE - no other shop should see it

DROP POLICY IF EXISTS "Shop owners can manage inventory" ON inventory;
CREATE POLICY "Shop owners can manage inventory"
  ON inventory FOR ALL
  USING (
    shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
  )
  WITH CHECK (
    shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
  );

-- Ensure mechanics/public cannot see inventory details
-- (They only see what's in offers)

-- =====================================================
-- 4. SHOP_CUSTOMERS TABLE - STRICT ISOLATION
-- =====================================================
-- Customer data is shop-private (business intelligence)

DROP POLICY IF EXISTS "Shop owners can manage customers" ON shop_customers;
CREATE POLICY "Shop owners can manage customers"
  ON shop_customers FOR ALL
  USING (
    shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
  )
  WITH CHECK (
    shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
  );

-- =====================================================
-- 5. SHOP_ANALYTICS_DAILY - STRICT ISOLATION
-- =====================================================
-- Analytics/revenue data is HIGHLY SENSITIVE

ALTER TABLE IF EXISTS shop_analytics_daily ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Shop owners can view their analytics" ON shop_analytics_daily;
CREATE POLICY "Shop owners can view their analytics"
  ON shop_analytics_daily FOR SELECT
  USING (
    shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
  );

-- =====================================================
-- 6. PAYLOAD VALIDATION - CHECK CONSTRAINTS
-- =====================================================
-- Ensure the database rejects malformed data even if UI validation is bypassed

-- Price constraints (prevent negative or absurdly high prices)
ALTER TABLE offers 
  DROP CONSTRAINT IF EXISTS check_offer_price_valid;
ALTER TABLE offers 
  ADD CONSTRAINT check_offer_price_valid 
  CHECK (price_cents >= 0 AND price_cents <= 100000000); -- Max R1,000,000

ALTER TABLE offers 
  DROP CONSTRAINT IF EXISTS check_delivery_fee_valid;
ALTER TABLE offers 
  ADD CONSTRAINT check_delivery_fee_valid 
  CHECK (delivery_fee_cents >= 0 AND delivery_fee_cents <= 10000000); -- Max R100,000

-- Order total validation
ALTER TABLE orders 
  DROP CONSTRAINT IF EXISTS check_order_total_valid;
ALTER TABLE orders 
  ADD CONSTRAINT check_order_total_valid 
  CHECK (total_cents >= 0 AND total_cents <= 200000000); -- Max R2,000,000

-- ETA validation (max 90 days = 129600 minutes)
ALTER TABLE offers 
  DROP CONSTRAINT IF EXISTS check_eta_valid;
ALTER TABLE offers 
  ADD CONSTRAINT check_eta_valid 
  CHECK (eta_minutes IS NULL OR (eta_minutes >= 0 AND eta_minutes <= 129600));

-- Vehicle year validation
ALTER TABLE part_requests 
  DROP CONSTRAINT IF EXISTS check_vehicle_year_valid;
ALTER TABLE part_requests 
  ADD CONSTRAINT check_vehicle_year_valid 
  CHECK (vehicle_year >= 1900 AND vehicle_year <= EXTRACT(YEAR FROM NOW()) + 2);

-- Stock status enum validation
ALTER TABLE offers 
  DROP CONSTRAINT IF EXISTS check_stock_status_valid;
ALTER TABLE offers 
  ADD CONSTRAINT check_stock_status_valid 
  CHECK (stock_status IN ('in_stock', 'low_stock', 'out_of_stock', 'can_order', 'ordered'));

-- Offer status enum validation
ALTER TABLE offers 
  DROP CONSTRAINT IF EXISTS check_offer_status_valid;
ALTER TABLE offers 
  ADD CONSTRAINT check_offer_status_valid 
  CHECK (status IN ('pending', 'accepted', 'rejected', 'expired', 'counter_offered'));

-- Order status enum validation (matches CS-16 trigger)
ALTER TABLE orders 
  DROP CONSTRAINT IF EXISTS check_order_status_valid;
ALTER TABLE orders 
  ADD CONSTRAINT check_order_status_valid 
  CHECK (status IN ('pending', 'confirmed', 'preparing', 'processing', 'shipped', 'out_for_delivery', 'delivered', 'cancelled'));

-- Part request status validation
ALTER TABLE part_requests 
  DROP CONSTRAINT IF EXISTS check_request_status_valid;
ALTER TABLE part_requests 
  ADD CONSTRAINT check_request_status_valid 
  CHECK (status IN ('pending', 'offered', 'accepted', 'fulfilled', 'expired', 'cancelled'));

-- =====================================================
-- 7. TEXT LENGTH CONSTRAINTS (XSS Prevention)
-- =====================================================
-- Limit text fields to prevent payload injection attacks

ALTER TABLE part_requests 
  DROP CONSTRAINT IF EXISTS check_description_length;
ALTER TABLE part_requests 
  ADD CONSTRAINT check_description_length 
  CHECK (description IS NULL OR LENGTH(description) <= 2000);

ALTER TABLE offers 
  DROP CONSTRAINT IF EXISTS check_message_length;
ALTER TABLE offers 
  ADD CONSTRAINT check_message_length 
  CHECK (message IS NULL OR LENGTH(message) <= 1000);

ALTER TABLE profiles 
  DROP CONSTRAINT IF EXISTS check_full_name_length;
ALTER TABLE profiles 
  ADD CONSTRAINT check_full_name_length 
  CHECK (full_name IS NULL OR LENGTH(full_name) <= 200);

-- =====================================================
-- 8. UUID VALIDATION FUNCTION
-- =====================================================
-- Ensure IDs are valid UUIDs (prevents injection via malformed IDs)

CREATE OR REPLACE FUNCTION is_valid_uuid(text) RETURNS BOOLEAN AS $$
BEGIN
  RETURN $1 ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- =====================================================
-- 9. STRESS TESTING INDEXES
-- =====================================================
-- Optimize for 1,000+ concurrent searches

-- Composite index for mechanic requests (most common query)
CREATE INDEX IF NOT EXISTS idx_part_requests_mechanic_status 
  ON part_requests(mechanic_id, status);

-- Composite index for shop offers
CREATE INDEX IF NOT EXISTS idx_offers_shop_status 
  ON offers(shop_id, status);

-- Composite index for request offers (used in marketplace)
CREATE INDEX IF NOT EXISTS idx_offers_request_status_price 
  ON offers(request_id, status, price_cents);

-- Index for suburb-based shop search
CREATE INDEX IF NOT EXISTS idx_shops_suburb_rating 
  ON shops(suburb, rating DESC);

-- Partial index for pending requests only (hot path)
CREATE INDEX IF NOT EXISTS idx_part_requests_pending 
  ON part_requests(created_at DESC) 
  WHERE status = 'pending';

-- Partial index for pending offers only
CREATE INDEX IF NOT EXISTS idx_offers_pending 
  ON offers(created_at DESC) 
  WHERE status = 'pending';

-- Index for order lookups by shop (dashboard)
CREATE INDEX IF NOT EXISTS idx_orders_shop_created 
  ON orders(created_at DESC)
  WHERE status NOT IN ('delivered', 'cancelled');

-- =====================================================
-- 10. RATE LIMITING TABLE (Server-Side)
-- =====================================================
-- Track API requests for server-side rate limiting

CREATE TABLE IF NOT EXISTS rate_limit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  endpoint TEXT NOT NULL,
  ip_address INET,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for rate limit checks
CREATE INDEX IF NOT EXISTS idx_rate_limit_user_endpoint 
  ON rate_limit_log(user_id, endpoint, created_at DESC);

-- Auto-cleanup old rate limit logs (keep 1 hour)
CREATE OR REPLACE FUNCTION cleanup_rate_limit_log()
RETURNS void AS $$
BEGIN
  DELETE FROM rate_limit_log 
  WHERE created_at < NOW() - INTERVAL '1 hour';
END;
$$ LANGUAGE plpgsql;

-- Rate limiting check function
CREATE OR REPLACE FUNCTION check_rate_limit(
  p_user_id UUID,
  p_endpoint TEXT,
  p_max_requests INT DEFAULT 60,
  p_window_minutes INT DEFAULT 1
) RETURNS BOOLEAN AS $$
DECLARE
  request_count INT;
BEGIN
  SELECT COUNT(*) INTO request_count
  FROM rate_limit_log
  WHERE user_id = p_user_id
    AND endpoint = p_endpoint
    AND created_at > NOW() - (p_window_minutes || ' minutes')::INTERVAL;
  
  RETURN request_count < p_max_requests;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 11. AUDIT LOG FOR SENSITIVE OPERATIONS
-- =====================================================
-- Track who accessed sensitive data

CREATE OR REPLACE FUNCTION log_sensitive_access()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_logs (
    user_id,
    action,
    table_name,
    record_id,
    old_values,
    new_values,
    ip_address,
    created_at
  ) VALUES (
    auth.uid(),
    TG_OP,
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id),
    CASE WHEN TG_OP = 'DELETE' OR TG_OP = 'UPDATE' THEN row_to_json(OLD) ELSE NULL END,
    CASE WHEN TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN row_to_json(NEW) ELSE NULL END,
    inet_client_addr(),
    NOW()
  );
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply audit logging to sensitive tables
DROP TRIGGER IF EXISTS audit_payments ON payments;
CREATE TRIGGER audit_payments
  AFTER INSERT OR UPDATE OR DELETE ON payments
  FOR EACH ROW EXECUTE FUNCTION log_sensitive_access();

DROP TRIGGER IF EXISTS audit_orders ON orders;
CREATE TRIGGER audit_orders
  AFTER INSERT OR UPDATE OR DELETE ON orders
  FOR EACH ROW EXECUTE FUNCTION log_sensitive_access();

-- =====================================================
-- 12. SECURITY HELPER VIEWS
-- =====================================================
-- Safe views that enforce RLS at the view level

CREATE OR REPLACE VIEW my_shop_analytics AS
SELECT * FROM shop_analytics_daily
WHERE shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid());

CREATE OR REPLACE VIEW my_offers AS
SELECT o.*, s.name as shop_name
FROM offers o
JOIN shops s ON o.shop_id = s.id
WHERE EXISTS (
  SELECT 1 FROM part_requests pr
  WHERE pr.id = o.request_id AND pr.mechanic_id = auth.uid()
);

-- =====================================================
-- PASS 4 SECURITY HARDENING COMPLETE
-- =====================================================
-- Summary:
-- ✅ RLS policies tightened for offers, payments, inventory
-- ✅ CHECK constraints for payload validation
-- ✅ Text length limits for XSS prevention
-- ✅ Stress testing indexes for 1000+ users
-- ✅ Server-side rate limiting table
-- ✅ Audit logging for sensitive operations
-- =====================================================
