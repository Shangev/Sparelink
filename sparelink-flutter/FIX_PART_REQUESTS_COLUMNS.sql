-- =====================================================
-- FIX PART_REQUESTS COLUMNS FOR BUDGET & URGENCY
-- =====================================================
-- Run this ENTIRE script in Supabase SQL Editor
-- This will add the missing columns with correct types
-- =====================================================

-- Step 1: Check current columns
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'part_requests'
ORDER BY ordinal_position;

-- Step 2: Add columns if they don't exist (with explicit types)

-- Add urgency_level (VARCHAR, nullable, default 'normal')
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'part_requests' 
        AND column_name = 'urgency_level'
    ) THEN
        ALTER TABLE public.part_requests 
        ADD COLUMN urgency_level VARCHAR(20) DEFAULT 'normal';
        RAISE NOTICE 'Added urgency_level column';
    ELSE
        RAISE NOTICE 'urgency_level column already exists';
    END IF;
END $$;

-- Add budget_min (NUMERIC, nullable)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'part_requests' 
        AND column_name = 'budget_min'
    ) THEN
        ALTER TABLE public.part_requests 
        ADD COLUMN budget_min NUMERIC(10,2) NULL;
        RAISE NOTICE 'Added budget_min column';
    ELSE
        RAISE NOTICE 'budget_min column already exists';
    END IF;
END $$;

-- Add budget_max (NUMERIC, nullable)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'part_requests' 
        AND column_name = 'budget_max'
    ) THEN
        ALTER TABLE public.part_requests 
        ADD COLUMN budget_max NUMERIC(10,2) NULL;
        RAISE NOTICE 'Added budget_max column';
    ELSE
        RAISE NOTICE 'budget_max column already exists';
    END IF;
END $$;

-- Add notes (TEXT, nullable)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'part_requests' 
        AND column_name = 'notes'
    ) THEN
        ALTER TABLE public.part_requests 
        ADD COLUMN notes TEXT NULL;
        RAISE NOTICE 'Added notes column';
    ELSE
        RAISE NOTICE 'notes column already exists';
    END IF;
END $$;

-- Step 3: Ensure RLS policies allow insert on new columns
-- (RLS is usually at row level, not column level, but let's be safe)

-- Drop and recreate the insert policy to ensure it covers all columns
DROP POLICY IF EXISTS "Users can insert own requests" ON public.part_requests;

CREATE POLICY "Users can insert own requests" 
ON public.part_requests 
FOR INSERT 
WITH CHECK (auth.uid() = mechanic_id);

-- Step 4: Grant column-level permissions (belt and suspenders)
GRANT SELECT, INSERT, UPDATE ON public.part_requests TO authenticated;
GRANT SELECT ON public.part_requests TO anon;

-- Step 5: CRITICAL - Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';

-- Step 6: Verify the columns now exist
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'part_requests'
AND column_name IN ('urgency_level', 'budget_min', 'budget_max', 'notes')
ORDER BY column_name;

-- =====================================================
-- EXPECTED OUTPUT:
-- =====================================================
-- column_name    | data_type | is_nullable | column_default
-- budget_max     | numeric   | YES         | NULL
-- budget_min     | numeric   | YES         | NULL  
-- notes          | text      | YES         | NULL
-- urgency_level  | varchar   | YES         | 'normal'
-- =====================================================

-- If you STILL get PGRST204 after running this:
-- 1. Go to Supabase Dashboard -> Settings -> API
-- 2. Look for "Reload Schema" button and click it
-- 3. Or restart the project: Settings -> General -> Restart Project
