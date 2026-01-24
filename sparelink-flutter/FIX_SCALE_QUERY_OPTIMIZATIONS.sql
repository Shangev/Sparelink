-- =====================================================
-- FIX: SCALE QUERY OPTIMIZATIONS
-- Run this in Supabase SQL Editor to fix the view error
-- =====================================================

-- 1. Drop the existing view first
DROP VIEW IF EXISTS part_requests_with_counts CASCADE;

-- 2. Recreate the view with correct structure
-- NOTE: part_requests table may already have offer_count column, so we use COALESCE
-- to prefer the computed count over the stored value, and exclude duplicates
CREATE OR REPLACE VIEW part_requests_with_counts AS
SELECT 
    pr.id,
    pr.mechanic_id,
    pr.vehicle_make,
    pr.vehicle_model,
    pr.vehicle_year,
    pr.part_name,
    pr.part_category,
    pr.description,
    pr.image_url,
    pr.suburb,
    pr.city,
    pr.status,
    pr.created_at,
    pr.updated_at,
    pr.expires_at,
    pr.accepted_shop_id,
    pr.budget_min,
    pr.budget_max,
    pr.urgency,
    pr.part_number,
    -- Computed counts (these override any existing columns)
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

-- 3. Grant access to authenticated users
GRANT SELECT ON part_requests_with_counts TO authenticated;

-- 4. Fix the get_last_messages_batch function (use 'content' instead of 'text')
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
        rcm.content as message_text,  -- FIXED: was 'text', now 'content'
        rcm.sent_at,
        rcm.sender_id,
        rcm.is_read
    FROM request_chat_messages rcm
    WHERE (rcm.request_id || ':' || rcm.shop_id) = ANY(p_chat_keys)
    ORDER BY rcm.request_id, rcm.shop_id, rcm.sent_at DESC;
END;
$$;

-- 5. Grant execute permission
GRANT EXECUTE ON FUNCTION get_last_messages_batch(TEXT[]) TO authenticated;

-- 6. Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';

-- =====================================================
-- VERIFICATION
-- =====================================================
-- Test the view:
-- SELECT * FROM part_requests_with_counts LIMIT 5;

-- Check view columns:
-- SELECT column_name FROM information_schema.columns 
-- WHERE table_name = 'part_requests_with_counts' ORDER BY ordinal_position;

DO $$
BEGIN
    RAISE NOTICE '✅ View part_requests_with_counts recreated successfully';
    RAISE NOTICE '✅ Function get_last_messages_batch fixed (content column)';
    RAISE NOTICE '✅ Schema cache reload triggered';
END $$;
