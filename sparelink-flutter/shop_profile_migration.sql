-- =====================================================
-- SHOP PROFILE ENHANCEMENT MIGRATION
-- =====================================================
-- Adds new columns to shops table for enhanced profile features:
-- - Logo and banner images
-- - Social media links
-- - Specialties and payment methods
-- - Business registration details
-- =====================================================

-- Add new columns to shops table
ALTER TABLE shops ADD COLUMN IF NOT EXISTS logo_url TEXT;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS banner_url TEXT;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS website TEXT;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS facebook TEXT;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS instagram TEXT;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS twitter TEXT;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS specialties JSONB DEFAULT '[]'::jsonb;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS payment_methods JSONB DEFAULT '[]'::jsonb;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS registration_number VARCHAR(50);
ALTER TABLE shops ADD COLUMN IF NOT EXISTS vat_number VARCHAR(20);
ALTER TABLE shops ADD COLUMN IF NOT EXISTS brand TEXT; -- For inventory items

-- Add brand column to inventory table if it doesn't exist
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS brand VARCHAR(255);

-- Create storage bucket for shop assets (logos and banners)
-- Note: This needs to be run in Supabase dashboard or via API
-- INSERT INTO storage.buckets (id, name, public) 
-- VALUES ('shop-assets', 'shop-assets', true)
-- ON CONFLICT (id) DO NOTHING;

-- Storage policy for shop-assets bucket (authenticated users can upload)
-- CREATE POLICY "Shop owners can upload assets"
-- ON storage.objects FOR INSERT
-- WITH CHECK (
--   bucket_id = 'shop-assets' AND
--   auth.role() = 'authenticated'
-- );

-- CREATE POLICY "Anyone can view shop assets"
-- ON storage.objects FOR SELECT
-- USING (bucket_id = 'shop-assets');

-- =====================================================
-- INDEXES for new columns
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_shops_specialties ON shops USING gin(specialties);
CREATE INDEX IF NOT EXISTS idx_shops_payment_methods ON shops USING gin(payment_methods);

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================
-- Run this migration with: psql -d your_database -f shop_profile_migration.sql
-- Or execute via Supabase SQL Editor
