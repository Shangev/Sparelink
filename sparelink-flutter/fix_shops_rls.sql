-- =============================================
-- FIX SHOPS TABLE - RLS & COLUMNS
-- Run this in Supabase SQL Editor
-- =============================================

-- 1. First, add the missing columns if they don't exist
ALTER TABLE shops
ADD COLUMN IF NOT EXISTS street_address TEXT,
ADD COLUMN IF NOT EXISTS suburb TEXT,
ADD COLUMN IF NOT EXISTS city TEXT,
ADD COLUMN IF NOT EXISTS postal_code TEXT,
ADD COLUMN IF NOT EXISTS email TEXT,
ADD COLUMN IF NOT EXISTS description TEXT,
ADD COLUMN IF NOT EXISTS working_hours JSONB,
ADD COLUMN IF NOT EXISTS delivery_enabled BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS delivery_radius_km INTEGER DEFAULT 20,
ADD COLUMN IF NOT EXISTS delivery_fee INTEGER DEFAULT 140,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 2. Enable RLS on shops table (if not already enabled)
ALTER TABLE shops ENABLE ROW LEVEL SECURITY;

-- 3. Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Shop owners can view their own shop" ON shops;
DROP POLICY IF EXISTS "Shop owners can update their own shop" ON shops;
DROP POLICY IF EXISTS "Public can view shops" ON shops;
DROP POLICY IF EXISTS "Users can create shops" ON shops;

-- 4. Create RLS policies for shops table

-- Allow anyone to view shops (public read)
CREATE POLICY "Public can view shops" 
ON shops FOR SELECT 
USING (true);

-- Allow authenticated users to create shops
CREATE POLICY "Users can create shops" 
ON shops FOR INSERT 
WITH CHECK (auth.uid() = owner_id);

-- Allow shop owners to update their own shop
CREATE POLICY "Shop owners can update their own shop" 
ON shops FOR UPDATE 
USING (auth.uid() = owner_id)
WITH CHECK (auth.uid() = owner_id);

-- Allow shop owners to delete their own shop
CREATE POLICY "Shop owners can delete their own shop" 
ON shops FOR DELETE 
USING (auth.uid() = owner_id);

-- 5. Create index for suburb (for matching mechanics)
CREATE INDEX IF NOT EXISTS idx_shops_suburb ON shops(suburb);

-- 6. Verify the columns exist
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'shops' 
ORDER BY ordinal_position;
