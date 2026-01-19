-- ============================================
-- SPARELINK LOCAL ADDRESS REGISTRY
-- ============================================
-- This table stores addresses that users enter manually
-- when Photon (OpenStreetMap) returns no results.
-- These addresses become available for future searches,
-- building an internal network of South African addresses.
-- ============================================

-- Create the local_addresses table
CREATE TABLE IF NOT EXISTS local_addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Address components (matching Photon/PlaceDetails schema)
  street_address TEXT NOT NULL,           -- "123 Main Street"
  suburb TEXT,                            -- "Sandton"
  city TEXT NOT NULL,                     -- "Johannesburg"
  province TEXT NOT NULL,                 -- "Gauteng"
  postal_code TEXT,                       -- "2196"
  country TEXT DEFAULT 'South Africa',    -- Always "South Africa"
  
  -- Full formatted address for display and search
  formatted_address TEXT NOT NULL,        -- "123 Main Street, Sandton, Johannesburg, Gauteng, 2196, South Africa"
  
  -- Search optimization - normalized lowercase for text search
  search_text TEXT GENERATED ALWAYS AS (
    LOWER(
      COALESCE(street_address, '') || ' ' ||
      COALESCE(suburb, '') || ' ' ||
      COALESCE(city, '') || ' ' ||
      COALESCE(province, '') || ' ' ||
      COALESCE(postal_code, '')
    )
  ) STORED,
  
  -- Optional coordinates (if user provides or we geocode later)
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  
  -- Metadata
  created_by UUID REFERENCES auth.users(id),  -- User who added this address
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Usage tracking (for ranking popular addresses)
  use_count INTEGER DEFAULT 1,
  last_used_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Verification status
  is_verified BOOLEAN DEFAULT FALSE,      -- Can be verified by admin later
  
  -- Prevent exact duplicates
  UNIQUE(street_address, suburb, city, province)
);

-- Create indexes for fast searching
CREATE INDEX IF NOT EXISTS idx_local_addresses_search_text 
  ON local_addresses USING GIN (to_tsvector('english', search_text));

CREATE INDEX IF NOT EXISTS idx_local_addresses_city 
  ON local_addresses(LOWER(city));

CREATE INDEX IF NOT EXISTS idx_local_addresses_suburb 
  ON local_addresses(LOWER(suburb));

CREATE INDEX IF NOT EXISTS idx_local_addresses_province 
  ON local_addresses(LOWER(province));

CREATE INDEX IF NOT EXISTS idx_local_addresses_use_count 
  ON local_addresses(use_count DESC);

-- Enable Row Level Security
ALTER TABLE local_addresses ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Anyone can read local addresses (for search)
CREATE POLICY "Anyone can read local addresses"
  ON local_addresses FOR SELECT
  USING (true);

-- Authenticated users can insert new addresses
CREATE POLICY "Authenticated users can insert local addresses"
  ON local_addresses FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Users can update addresses they created (increment use_count)
CREATE POLICY "Users can update their own addresses"
  ON local_addresses FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid() OR created_by IS NULL);

-- Function to search local addresses
CREATE OR REPLACE FUNCTION search_local_addresses(search_query TEXT, result_limit INTEGER DEFAULT 10)
RETURNS TABLE (
  id UUID,
  street_address TEXT,
  suburb TEXT,
  city TEXT,
  province TEXT,
  postal_code TEXT,
  country TEXT,
  formatted_address TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  use_count INTEGER,
  is_verified BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    la.id,
    la.street_address,
    la.suburb,
    la.city,
    la.province,
    la.postal_code,
    la.country,
    la.formatted_address,
    la.latitude,
    la.longitude,
    la.use_count,
    la.is_verified
  FROM local_addresses la
  WHERE 
    la.search_text ILIKE '%' || LOWER(search_query) || '%'
    OR la.formatted_address ILIKE '%' || search_query || '%'
  ORDER BY 
    la.is_verified DESC,           -- Verified addresses first
    la.use_count DESC,             -- Then by popularity
    la.created_at DESC             -- Then by recency
  LIMIT result_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment use count when an address is selected
CREATE OR REPLACE FUNCTION increment_address_use_count(address_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE local_addresses
  SET 
    use_count = use_count + 1,
    last_used_at = NOW(),
    updated_at = NOW()
  WHERE id = address_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION search_local_addresses TO authenticated;
GRANT EXECUTE ON FUNCTION search_local_addresses TO anon;
GRANT EXECUTE ON FUNCTION increment_address_use_count TO authenticated;

-- ============================================
-- SAMPLE DATA (Optional - for testing)
-- ============================================
-- INSERT INTO local_addresses (street_address, suburb, city, province, postal_code, formatted_address)
-- VALUES 
--   ('123 Test Street', 'Sandton', 'Johannesburg', 'Gauteng', '2196', '123 Test Street, Sandton, Johannesburg, Gauteng, 2196, South Africa'),
--   ('456 Sample Road', 'Centurion', 'Pretoria', 'Gauteng', '0157', '456 Sample Road, Centurion, Pretoria, Gauteng, 0157, South Africa');
