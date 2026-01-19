-- =====================================================
-- FIX PGRST204 SCHEMA CACHE ERROR
-- =====================================================
-- Run this in Supabase SQL Editor to reload the schema cache
-- =====================================================

-- Method 1: Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';

-- Method 2: If columns were added, ensure they have proper defaults
-- This ensures PostgREST can handle NULL values properly

-- Update part_requests columns with proper defaults
ALTER TABLE part_requests 
    ALTER COLUMN urgency_level SET DEFAULT 'normal',
    ALTER COLUMN budget_min DROP NOT NULL,
    ALTER COLUMN budget_max DROP NOT NULL,
    ALTER COLUMN notes DROP NOT NULL;

-- Make sure columns exist and are nullable (safe to run multiple times)
DO $$ 
BEGIN
    -- Ensure urgency_level has default
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'part_requests' AND column_name = 'urgency_level') THEN
        ALTER TABLE part_requests ALTER COLUMN urgency_level SET DEFAULT 'normal';
    END IF;
END $$;

-- Method 3: Grant proper permissions to the columns
GRANT SELECT, INSERT, UPDATE ON part_requests TO authenticated;
GRANT SELECT, INSERT, UPDATE ON part_requests TO anon;

-- Refresh the schema cache again
NOTIFY pgrst, 'reload schema';

-- =====================================================
-- VERIFY THE COLUMNS EXIST
-- =====================================================
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'part_requests'
AND column_name IN ('urgency_level', 'budget_min', 'budget_max', 'notes', 'part_name')
ORDER BY column_name;
