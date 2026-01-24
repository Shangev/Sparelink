-- =====================================================
-- CS-17 FIX: QUOTE EXPIRY VALIDATION TRIGGER
-- Prevents accepting expired or already-accepted offers
-- Run this migration in Supabase SQL Editor
-- =====================================================

-- STEP 0: Add expires_at column to offers table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'offers' AND column_name = 'expires_at') THEN
        ALTER TABLE public.offers ADD COLUMN expires_at TIMESTAMPTZ;
        RAISE NOTICE 'Added expires_at column to offers table';
    ELSE
        RAISE NOTICE 'expires_at column already exists in offers table';
    END IF;
END $$;

-- Set default expiry to 48 hours from creation for new offers (optional)
-- Uncomment if you want auto-expiry:
-- ALTER TABLE public.offers ALTER COLUMN expires_at SET DEFAULT (NOW() + INTERVAL '48 hours');

-- Function to validate offer before acceptance
CREATE OR REPLACE FUNCTION validate_offer_acceptance()
RETURNS TRIGGER AS $$
DECLARE
  offer_expires_at TIMESTAMPTZ;
  offer_current_status VARCHAR(20);
BEGIN
  -- Only check when status is being changed to 'accepted'
  IF NEW.status = 'accepted' AND (OLD.status IS NULL OR OLD.status != 'accepted') THEN
    
    -- Get current offer state (use FOR UPDATE to lock the row)
    SELECT expires_at, status INTO offer_expires_at, offer_current_status
    FROM offers
    WHERE id = NEW.id
    FOR UPDATE;
    
    -- Check if already accepted (race condition prevention)
    IF offer_current_status = 'accepted' THEN
      RAISE EXCEPTION 'QUOTE_ALREADY_ACCEPTED: This quote has already been accepted by another user'
        USING ERRCODE = 'P0001';
    END IF;
    
    -- Check if expired
    IF offer_expires_at IS NOT NULL AND offer_expires_at < NOW() THEN
      RAISE EXCEPTION 'QUOTE_EXPIRED: This quote has expired. Please request a new quote from the shop.'
        USING ERRCODE = 'P0002';
    END IF;
    
    -- Check if rejected
    IF offer_current_status = 'rejected' THEN
      RAISE EXCEPTION 'QUOTE_REJECTED: This quote has been rejected and cannot be accepted'
        USING ERRCODE = 'P0003';
    END IF;
    
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger (drop if exists first)
DROP TRIGGER IF EXISTS trigger_validate_offer_acceptance ON offers;
CREATE TRIGGER trigger_validate_offer_acceptance
  BEFORE UPDATE ON offers
  FOR EACH ROW
  EXECUTE FUNCTION validate_offer_acceptance();

-- Also add a unique constraint to prevent duplicate orders for same offer
-- This is the database-level prevention for dual-accept race condition
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'unique_offer_order'
  ) THEN
    ALTER TABLE orders ADD CONSTRAINT unique_offer_order UNIQUE (offer_id);
  END IF;
EXCEPTION
  WHEN duplicate_object THEN
    -- Constraint already exists, ignore
    NULL;
END $$;

-- Add index for faster expiry checks (only if column exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'offers' AND column_name = 'expires_at') THEN
        CREATE INDEX IF NOT EXISTS idx_offers_expires_at ON public.offers(expires_at) WHERE expires_at IS NOT NULL;
        RAISE NOTICE 'Created index idx_offers_expires_at';
    END IF;
END $$;

-- Log the migration
DO $$
BEGIN
  INSERT INTO audit_logs (event_type, description, severity, metadata)
  VALUES (
    'migration', 
    'CS-17 FIX: Added quote expiry validation trigger', 
    'info',
    '{"fix_id": "CS-17", "version": "1.0"}'::jsonb
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
-- SELECT tgname, tgtype FROM pg_trigger WHERE tgname = 'trigger_validate_offer_acceptance';

-- Check constraint exists  
-- SELECT conname FROM pg_constraint WHERE conname = 'unique_offer_order';

-- Test expired quote (should fail)
-- UPDATE offers SET status = 'accepted' WHERE id = 'test-id' AND expires_at < NOW();
