-- =====================================================
-- CS-16 FIX: ORDER STATUS TRANSITION VALIDATION
-- Enforces valid status transitions (state machine)
-- Run this migration in Supabase SQL Editor
-- =====================================================

-- Function to validate order status transitions
CREATE OR REPLACE FUNCTION validate_order_status_transition()
RETURNS TRIGGER AS $$
DECLARE
  valid_transitions JSONB := '{
    "pending": ["confirmed", "cancelled"],
    "confirmed": ["preparing", "cancelled"],
    "preparing": ["processing", "shipped", "cancelled"],
    "processing": ["shipped", "cancelled"],
    "shipped": ["out_for_delivery", "delivered"],
    "out_for_delivery": ["delivered"],
    "delivered": [],
    "cancelled": []
  }'::JSONB;
  allowed_next JSONB;
BEGIN
  -- Skip if status hasn't changed
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;
  
  -- Skip validation for new records (INSERT)
  IF TG_OP = 'INSERT' THEN
    RETURN NEW;
  END IF;
  
  -- Get allowed transitions for current status
  allowed_next := valid_transitions -> OLD.status;
  
  -- If current status not in map, allow any transition (backward compatibility)
  IF allowed_next IS NULL THEN
    RAISE NOTICE 'Unknown status %, allowing transition to %', OLD.status, NEW.status;
    RETURN NEW;
  END IF;
  
  -- Check if new status is in allowed list
  IF NOT (allowed_next ? NEW.status) THEN
    RAISE EXCEPTION 'INVALID_STATUS_TRANSITION: Cannot transition from % to %. Allowed transitions: %', 
      OLD.status, NEW.status, allowed_next
      USING ERRCODE = 'P0010';
  END IF;
  
  -- Set timestamp for delivered status
  IF NEW.status = 'delivered' AND OLD.status != 'delivered' THEN
    NEW.delivered_at := NOW();
  END IF;
  
  -- Set timestamp for cancelled status
  IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
    NEW.cancelled_at := NOW();
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger (drop if exists first)
DROP TRIGGER IF EXISTS trigger_validate_order_status ON orders;
CREATE TRIGGER trigger_validate_order_status
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION validate_order_status_transition();

-- Add cancelled_at column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'orders' AND column_name = 'cancelled_at') THEN
    ALTER TABLE orders ADD COLUMN cancelled_at TIMESTAMPTZ;
  END IF;
END $$;

-- Create index for status queries
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON orders(payment_status);

-- Log the migration
DO $$
BEGIN
  INSERT INTO audit_logs (event_type, description, severity, metadata)
  VALUES (
    'migration', 
    'CS-16 FIX: Added order status transition validation trigger', 
    'info',
    '{"fix_id": "CS-16", "version": "1.0"}'::jsonb
  );
EXCEPTION
  WHEN undefined_table THEN
    -- audit_logs table doesn't exist, skip logging
    RAISE NOTICE 'audit_logs table not found, skipping migration log';
END $$;

-- =====================================================
-- VERIFICATION QUERIES (run after migration)
-- =====================================================

-- Check trigger exists
-- SELECT tgname, tgtype FROM pg_trigger WHERE tgname = 'trigger_validate_order_status';

-- Test invalid transition (should fail)
-- UPDATE orders SET status = 'delivered' WHERE status = 'pending' AND id = 'test-id';

-- Test valid transition (should succeed)
-- UPDATE orders SET status = 'confirmed' WHERE status = 'pending' AND id = 'test-id';
