-- =============================================
-- AUTO-EXPIRE OFFERS AFTER 24 HOURS
-- Run this in Supabase SQL Editor
-- =============================================

-- Create a function to expire old offers
CREATE OR REPLACE FUNCTION expire_old_offers()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    -- Update request_chats that are still pending and older than 24 hours
    UPDATE request_chats
    SET status = 'expired',
        updated_at = NOW()
    WHERE status IN ('pending', 'quoted')
    AND created_at < NOW() - INTERVAL '24 hours';
    
    GET DIAGNOSTICS expired_count = ROW_COUNT;
    
    -- Also update offers table
    UPDATE offers
    SET status = 'expired'
    WHERE status = 'pending'
    AND created_at < NOW() - INTERVAL '24 hours';
    
    -- Update part_requests that have all chats expired
    UPDATE part_requests pr
    SET status = 'expired'
    WHERE status = 'pending'
    AND created_at < NOW() - INTERVAL '24 hours'
    AND NOT EXISTS (
        SELECT 1 FROM request_chats rc 
        WHERE rc.request_id = pr.id 
        AND rc.status NOT IN ('expired', 'rejected', 'withdrawn')
    );
    
    RETURN expired_count;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION expire_old_offers TO authenticated;
GRANT EXECUTE ON FUNCTION expire_old_offers TO service_role;

-- =============================================
-- OPTION 1: Manual trigger (call this periodically)
-- =============================================
-- You can call this function manually or from your app:
-- SELECT expire_old_offers();

-- =============================================
-- OPTION 2: Use Supabase pg_cron extension (if available)
-- =============================================
-- Enable pg_cron extension first (in Supabase Dashboard > Database > Extensions)
-- Then create a scheduled job:

-- SELECT cron.schedule(
--     'expire-old-offers',           -- job name
--     '0 * * * *',                   -- every hour
--     'SELECT expire_old_offers()'   -- SQL to execute
-- );

-- To view scheduled jobs:
-- SELECT * FROM cron.job;

-- To remove the job:
-- SELECT cron.unschedule('expire-old-offers');

-- =============================================
-- OPTION 3: Create a view to check expiring offers
-- =============================================
CREATE OR REPLACE VIEW expiring_offers AS
SELECT 
    rc.id,
    rc.request_id,
    rc.shop_id,
    rc.status,
    rc.created_at,
    rc.quote_amount,
    s.name as shop_name,
    pr.vehicle_make,
    pr.vehicle_model,
    pr.part_category,
    EXTRACT(EPOCH FROM (NOW() - rc.created_at)) / 3600 as hours_since_created,
    CASE 
        WHEN rc.created_at < NOW() - INTERVAL '24 hours' THEN 'EXPIRED'
        WHEN rc.created_at < NOW() - INTERVAL '20 hours' THEN 'EXPIRING SOON'
        ELSE 'ACTIVE'
    END as expiry_status
FROM request_chats rc
JOIN shops s ON rc.shop_id = s.id
JOIN part_requests pr ON rc.request_id = pr.id
WHERE rc.status IN ('pending', 'quoted')
ORDER BY rc.created_at ASC;

-- To check expiring offers:
-- SELECT * FROM expiring_offers;
