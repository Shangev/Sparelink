-- =====================================================
-- SPARELINK: MISSING INDEXES FOR SCALE
-- Target: Prepare database for 100K+ users
-- Run in Supabase SQL Editor
-- =====================================================

-- =====================================================
-- CRITICAL INDEXES (Run before 50K users)
-- =====================================================

-- MI-01: User's request history (CRITICAL)
-- Used by: My Requests screen, request history queries
CREATE INDEX IF NOT EXISTS idx_part_requests_mechanic_id 
ON part_requests(mechanic_id);

-- MI-02: Recent requests sorted (CRITICAL)
-- Used by: Dashboard, admin views, recent activity
CREATE INDEX IF NOT EXISTS idx_part_requests_created_at 
ON part_requests(created_at DESC);

-- MI-03: Offers per request (CRITICAL)
-- Used by: Request detail, offer listing, quote comparison
CREATE INDEX IF NOT EXISTS idx_offers_request_id 
ON offers(request_id);

-- MI-04: Shop's sent quotes (HIGH)
-- Used by: Shop dashboard, quote management
CREATE INDEX IF NOT EXISTS idx_offers_shop_id 
ON offers(shop_id);

-- MI-05: Offer status filtering (HIGH)
-- Used by: Filtering pending/accepted/rejected offers
CREATE INDEX IF NOT EXISTS idx_offers_status 
ON offers(status);

-- =====================================================
-- HIGH PRIORITY INDEXES (Run before 100K users)
-- =====================================================

-- MI-06: Order by offer lookup (HIGH)
-- Used by: Order creation, offer-to-order mapping
CREATE INDEX IF NOT EXISTS idx_orders_offer_id 
ON orders(offer_id);

-- MI-07: Orders by request (HIGH)
-- Used by: Request detail showing order status
CREATE INDEX IF NOT EXISTS idx_orders_request_id 
ON orders(request_id);

-- MI-08: Recent orders (HIGH)
-- Used by: Order history, admin dashboard
CREATE INDEX IF NOT EXISTS idx_orders_created_at 
ON orders(created_at DESC);

-- =====================================================
-- MEDIUM PRIORITY INDEXES (Run before 500K users)
-- =====================================================

-- MI-09: Customer lookup (MEDIUM)
-- Used by: Shop CRM, customer history
CREATE INDEX IF NOT EXISTS idx_shop_customers_customer_id 
ON shop_customers(customer_id);

-- MI-10: Items per request (MEDIUM)
-- Used by: Multi-part requests, request detail
CREATE INDEX IF NOT EXISTS idx_request_items_request_id 
ON request_items(request_id);

-- =====================================================
-- COMPOSITE INDEXES (Performance optimization)
-- =====================================================

-- Offers by request + status (common filter pattern)
CREATE INDEX IF NOT EXISTS idx_offers_request_status 
ON offers(request_id, status);

-- Orders by status + date (dashboard queries)
CREATE INDEX IF NOT EXISTS idx_orders_status_created 
ON orders(status, created_at DESC);

-- Part requests by mechanic + status (my requests filtering)
CREATE INDEX IF NOT EXISTS idx_part_requests_mechanic_status 
ON part_requests(mechanic_id, status);

-- Offers by shop + status (shop dashboard)
CREATE INDEX IF NOT EXISTS idx_offers_shop_status 
ON offers(shop_id, status);

-- Orders by payment status (payment reconciliation)
CREATE INDEX IF NOT EXISTS idx_orders_payment_created 
ON orders(payment_status, created_at DESC);

-- =====================================================
-- PARTIAL INDEXES (Space-efficient for specific queries)
-- =====================================================

-- Pending offers only (most common query)
CREATE INDEX IF NOT EXISTS idx_offers_pending 
ON offers(request_id, created_at DESC) 
WHERE status = 'pending';

-- Unpaid orders only (payment follow-up)
CREATE INDEX IF NOT EXISTS idx_orders_unpaid 
ON orders(created_at DESC) 
WHERE payment_status = 'pending';

-- Active requests only (excludes expired/cancelled)
CREATE INDEX IF NOT EXISTS idx_part_requests_active 
ON part_requests(mechanic_id, created_at DESC) 
WHERE status IN ('pending', 'offered');

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- List all indexes on core tables
-- SELECT indexname, indexdef 
-- FROM pg_indexes 
-- WHERE tablename IN ('part_requests', 'offers', 'orders', 'shop_customers', 'request_items')
-- ORDER BY tablename, indexname;

-- Check index sizes
-- SELECT 
--     indexrelname as index_name,
--     pg_size_pretty(pg_relation_size(indexrelid)) as size
-- FROM pg_stat_user_indexes
-- WHERE schemaname = 'public'
-- ORDER BY pg_relation_size(indexrelid) DESC
-- LIMIT 20;

-- =====================================================
-- AUDIT LOG
-- =====================================================

DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'audit_logs') THEN
        INSERT INTO audit_logs (event_type, description, severity, metadata)
        VALUES (
            'migration', 
            'SCALE: Added missing indexes for 100K+ users', 
            'info',
            jsonb_build_object(
                'indexes_added', 15,
                'priority', 'scale_preparation',
                'timestamp', NOW()
            )
        );
    END IF;
END $$;

-- =====================================================
-- COMPLETE
-- =====================================================
-- Total indexes added: 15
-- - 5 Critical (MI-01 to MI-05)
-- - 3 High priority (MI-06 to MI-08)
-- - 2 Medium priority (MI-09 to MI-10)
-- - 5 Composite/partial indexes for optimization
-- =====================================================
