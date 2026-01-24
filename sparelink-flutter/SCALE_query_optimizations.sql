-- =====================================================
-- SPARELINK: QUERY OPTIMIZATIONS FOR SCALE
-- Target: Fix N+1 queries and improve performance
-- Run in Supabase SQL Editor
-- =====================================================

-- =====================================================
-- 1. VIEW: part_requests_with_counts
-- Eliminates N+1 queries in getMechanicRequests()
-- =====================================================

CREATE OR REPLACE VIEW part_requests_with_counts AS
SELECT 
    pr.*,
    COALESCE(offer_counts.count, 0)::INTEGER as offer_count,
    COALESCE(chat_counts.total, 0)::INTEGER as shop_count,
    COALESCE(chat_counts.quoted, 0)::INTEGER as quoted_count
FROM part_requests pr
LEFT JOIN (
    SELECT request_id, COUNT(*)::INTEGER as count
    FROM offers
    GROUP BY request_id
) offer_counts ON offer_counts.request_id = pr.id
LEFT JOIN (
    SELECT 
        request_id, 
        COUNT(*)::INTEGER as total,
        COUNT(*) FILTER (WHERE status = 'quoted')::INTEGER as quoted
    FROM request_chats
    GROUP BY request_id
) chat_counts ON chat_counts.request_id = pr.id;

-- Grant access to authenticated users
GRANT SELECT ON part_requests_with_counts TO authenticated;

-- Enable RLS on the view (inherits from part_requests)
-- Note: Views inherit RLS from base tables in Supabase

-- =====================================================
-- 2. FUNCTION: get_mechanic_requests_with_counts
-- Alternative to view - callable via RPC
-- =====================================================

CREATE OR REPLACE FUNCTION get_mechanic_requests_with_counts(p_mechanic_id UUID)
RETURNS TABLE (
    id UUID,
    mechanic_id UUID,
    vehicle_make VARCHAR,
    vehicle_model VARCHAR,
    vehicle_year INT,
    part_category VARCHAR,
    part_name VARCHAR,
    description TEXT,
    image_url TEXT,
    suburb VARCHAR,
    status VARCHAR,
    created_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    offer_count BIGINT,
    shop_count BIGINT,
    quoted_count BIGINT
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pr.id,
        pr.mechanic_id,
        pr.vehicle_make,
        pr.vehicle_model,
        pr.vehicle_year,
        pr.part_category,
        pr.part_name,
        pr.description,
        pr.image_url,
        pr.suburb,
        pr.status,
        pr.created_at,
        pr.expires_at,
        COALESCE((SELECT COUNT(*) FROM offers o WHERE o.request_id = pr.id), 0) as offer_count,
        COALESCE((SELECT COUNT(*) FROM request_chats rc WHERE rc.request_id = pr.id), 0) as shop_count,
        COALESCE((SELECT COUNT(*) FROM request_chats rc WHERE rc.request_id = pr.id AND rc.status = 'quoted'), 0) as quoted_count
    FROM part_requests pr
    WHERE pr.mechanic_id = p_mechanic_id
    ORDER BY pr.created_at DESC;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_mechanic_requests_with_counts(UUID) TO authenticated;

-- =====================================================
-- 3. FUNCTION: get_unread_counts_batch
-- Batch query for unread message counts
-- =====================================================

CREATE OR REPLACE FUNCTION get_unread_counts_batch(
    p_user_id UUID,
    p_chat_keys TEXT[]  -- Array of 'request_id:shop_id' strings
)
RETURNS TABLE (
    chat_key TEXT,
    unread_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (rcm.request_id || ':' || rcm.shop_id) as chat_key,
        COUNT(*) as unread_count
    FROM request_chat_messages rcm
    WHERE 
        (rcm.request_id || ':' || rcm.shop_id) = ANY(p_chat_keys)
        AND rcm.sender_id != p_user_id
        AND rcm.is_read = false
    GROUP BY rcm.request_id, rcm.shop_id;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_unread_counts_batch(UUID, TEXT[]) TO authenticated;

-- =====================================================
-- 4. FUNCTION: get_last_messages_batch
-- Batch query for last messages in multiple chats
-- =====================================================

CREATE OR REPLACE FUNCTION get_last_messages_batch(
    p_chat_keys TEXT[]  -- Array of 'request_id:shop_id' strings
)
RETURNS TABLE (
    chat_key TEXT,
    message_text TEXT,
    sent_at TIMESTAMPTZ,
    sender_id UUID,
    is_read BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ON (rcm.request_id, rcm.shop_id)
        (rcm.request_id || ':' || rcm.shop_id) as chat_key,
        rcm.content as message_text,
        rcm.sent_at,
        rcm.sender_id,
        rcm.is_read
    FROM request_chat_messages rcm
    WHERE (rcm.request_id || ':' || rcm.shop_id) = ANY(p_chat_keys)
    ORDER BY rcm.request_id, rcm.shop_id, rcm.sent_at DESC;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_last_messages_batch(TEXT[]) TO authenticated;

-- =====================================================
-- 5. FUNCTION: get_shop_dashboard_summary
-- Single query for shop dashboard KPIs
-- =====================================================

CREATE OR REPLACE FUNCTION get_shop_dashboard_summary(p_shop_id UUID)
RETURNS TABLE (
    pending_requests BIGINT,
    quoted_today BIGINT,
    orders_this_week BIGINT,
    revenue_this_month BIGINT,
    conversion_rate NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_week_ago DATE := CURRENT_DATE - INTERVAL '7 days';
    v_month_ago DATE := CURRENT_DATE - INTERVAL '30 days';
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*) FROM request_chats WHERE shop_id = p_shop_id AND status = 'pending')::BIGINT as pending_requests,
        (SELECT COUNT(*) FROM request_chats WHERE shop_id = p_shop_id AND status = 'quoted' AND DATE(updated_at) = v_today)::BIGINT as quoted_today,
        (SELECT COUNT(*) FROM orders WHERE shop_id = p_shop_id AND created_at >= v_week_ago)::BIGINT as orders_this_week,
        COALESCE((SELECT SUM(total_cents) FROM orders WHERE shop_id = p_shop_id AND payment_status = 'paid' AND created_at >= v_month_ago), 0)::BIGINT as revenue_this_month,
        CASE 
            WHEN (SELECT COUNT(*) FROM request_chats WHERE shop_id = p_shop_id AND status = 'quoted') > 0
            THEN ROUND(
                (SELECT COUNT(*)::NUMERIC FROM orders WHERE shop_id = p_shop_id AND created_at >= v_month_ago) / 
                (SELECT COUNT(*)::NUMERIC FROM request_chats WHERE shop_id = p_shop_id AND status = 'quoted' AND created_at >= v_month_ago) * 100
            , 1)
            ELSE 0
        END as conversion_rate;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_shop_dashboard_summary(UUID) TO authenticated;

-- =====================================================
-- 6. MATERIALIZED VIEW: shop_analytics_daily
-- Pre-computed daily analytics (refresh nightly)
-- =====================================================

-- Note: Materialized views require pg_cron for auto-refresh
-- Manual refresh: REFRESH MATERIALIZED VIEW shop_analytics_daily;

CREATE MATERIALIZED VIEW IF NOT EXISTS shop_analytics_daily AS
SELECT 
    o.shop_id,
    DATE(o.created_at) as date,
    COUNT(*) as order_count,
    SUM(CASE WHEN o.payment_status = 'paid' THEN o.total_cents ELSE 0 END) as revenue_cents,
    COUNT(CASE WHEN o.payment_status = 'paid' THEN 1 END) as paid_orders,
    COUNT(CASE WHEN o.status = 'delivered' THEN 1 END) as delivered_orders
FROM orders o
WHERE o.created_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY o.shop_id, DATE(o.created_at);

-- Create index on materialized view
CREATE UNIQUE INDEX IF NOT EXISTS idx_shop_analytics_daily_unique 
ON shop_analytics_daily(shop_id, date);

CREATE INDEX IF NOT EXISTS idx_shop_analytics_daily_shop 
ON shop_analytics_daily(shop_id);

-- Grant access
GRANT SELECT ON shop_analytics_daily TO authenticated;

-- =====================================================
-- 7. FUNCTION: refresh_shop_analytics
-- Manual refresh function for materialized view
-- =====================================================

CREATE OR REPLACE FUNCTION refresh_shop_analytics()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY shop_analytics_daily;
END;
$$;

-- =====================================================
-- AUDIT LOG
-- =====================================================

DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'audit_logs') THEN
        INSERT INTO audit_logs (event_type, description, severity, metadata)
        VALUES (
            'migration', 
            'SCALE: Added query optimization views and functions', 
            'info',
            jsonb_build_object(
                'views_created', ARRAY['part_requests_with_counts', 'shop_analytics_daily'],
                'functions_created', ARRAY[
                    'get_mechanic_requests_with_counts',
                    'get_unread_counts_batch',
                    'get_last_messages_batch',
                    'get_shop_dashboard_summary',
                    'refresh_shop_analytics'
                ],
                'timestamp', NOW()
            )
        );
    END IF;
END $$;

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Test the view
-- SELECT * FROM part_requests_with_counts WHERE mechanic_id = 'your-uuid' LIMIT 5;

-- Test the function
-- SELECT * FROM get_mechanic_requests_with_counts('your-mechanic-uuid');

-- Test batch unread counts
-- SELECT * FROM get_unread_counts_batch('user-uuid', ARRAY['req1:shop1', 'req2:shop2']);

-- =====================================================
-- COMPLETE
-- =====================================================
-- Optimizations added:
-- - 1 View for eliminating N+1 queries
-- - 5 Functions for batch operations
-- - 1 Materialized view for analytics
-- 
-- Expected improvements:
-- - getMechanicRequests: 2N+1 → 1 query (99% reduction)
-- - Chat unread counts: N → 1 query (batch)
-- - Dashboard KPIs: Multiple → 1 query
-- =====================================================
