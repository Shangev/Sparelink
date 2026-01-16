-- ============================================
-- SQL MIGRATION: Add Missing Columns to shops and profiles tables
-- For SpareLink Shop Dashboard & Flutter App
-- ============================================
-- 
-- ISSUE: The Shop Dashboard settings page is trying to save columns that don't exist
-- This migration adds the missing columns to both tables
--
-- Run this in your Supabase SQL Editor
-- ============================================

-- ============================================
-- PART 1: ADD MISSING COLUMNS TO SHOPS TABLE
-- ============================================

-- Description: Shop bio/about text
ALTER TABLE public.shops 
ADD COLUMN IF NOT EXISTS description text NULL;

-- Working Hours: Store as JSONB for flexibility
-- Example format: {"monday": {"open": "08:00", "close": "17:00", "closed": false}, ...}
ALTER TABLE public.shops 
ADD COLUMN IF NOT EXISTS working_hours jsonb NULL DEFAULT '{}'::jsonb;

-- Delivery Settings
ALTER TABLE public.shops 
ADD COLUMN IF NOT EXISTS delivery_enabled boolean NULL DEFAULT false;

ALTER TABLE public.shops 
ADD COLUMN IF NOT EXISTS delivery_radius_km numeric NULL DEFAULT 0;

ALTER TABLE public.shops 
ADD COLUMN IF NOT EXISTS delivery_fee numeric NULL DEFAULT 0;

-- ============================================
-- PART 2: ADD MISSING COLUMNS TO PROFILES TABLE
-- (For shop owners who want to save personal info too)
-- ============================================

-- Province is in schema but let's ensure it exists
-- (Already exists based on schema, but adding IF NOT EXISTS for safety)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS province text NULL;

-- Full Name (already exists but ensuring it's there)
-- ALTER TABLE public.profiles 
-- ADD COLUMN IF NOT EXISTS full_name text NULL;

-- ============================================
-- PART 3: ADD COMMENTS FOR DOCUMENTATION
-- ============================================

COMMENT ON COLUMN public.shops.description IS 'Shop description/about text shown to customers';
COMMENT ON COLUMN public.shops.working_hours IS 'JSON object containing working hours for each day of the week';
COMMENT ON COLUMN public.shops.delivery_enabled IS 'Whether the shop offers delivery service';
COMMENT ON COLUMN public.shops.delivery_radius_km IS 'Maximum delivery radius in kilometers';
COMMENT ON COLUMN public.shops.delivery_fee IS 'Base delivery fee in Rands (ZAR)';

-- ============================================
-- PART 4: VERIFY THE CHANGES
-- ============================================

-- Run this query to verify columns were added to shops:
-- SELECT column_name, data_type, is_nullable, column_default 
-- FROM information_schema.columns 
-- WHERE table_schema = 'public' AND table_name = 'shops'
-- ORDER BY ordinal_position;

-- Run this query to verify columns in profiles:
-- SELECT column_name, data_type, is_nullable, column_default 
-- FROM information_schema.columns 
-- WHERE table_schema = 'public' AND table_name = 'profiles'
-- ORDER BY ordinal_position;

-- ============================================
-- EXPECTED SHOPS TABLE STRUCTURE AFTER MIGRATION:
-- ============================================
-- id                  uuid (PK)
-- owner_id            uuid (FK -> profiles.id)
-- name                text
-- phone               text
-- email               text
-- address             text
-- location            geometry
-- rating              numeric
-- review_count        integer
-- is_verified         boolean
-- created_at          timestamptz
-- lat                 double precision
-- lng                 double precision
-- avatar_url          text
-- updated_at          timestamptz
-- street_address      text
-- suburb              text
-- city                text
-- postal_code         text
-- province            text
-- vehicle_brands      text[]
-- is_active           boolean
-- description         text          <- NEW
-- working_hours       jsonb         <- NEW
-- delivery_enabled    boolean       <- NEW
-- delivery_radius_km  numeric       <- NEW
-- delivery_fee        numeric       <- NEW

-- ============================================
-- EXPECTED PROFILES TABLE STRUCTURE:
-- ============================================
-- id                  uuid (PK, FK -> auth.users.id)
-- phone               text
-- role                user_role
-- full_name           text
-- created_at          timestamptz
-- street_address      text
-- suburb              text
-- city                text
-- postal_code         text
-- province            text
-- updated_at          timestamptz
