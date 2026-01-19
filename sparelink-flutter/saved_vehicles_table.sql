-- =====================================================
-- SAVED VEHICLES TABLE FOR SPARELINK
-- =====================================================
-- Allows mechanics to save their frequently used vehicles
-- for quicker part requests.
-- =====================================================

-- Create saved_vehicles table
CREATE TABLE IF NOT EXISTS saved_vehicles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Vehicle identification
    make_id UUID REFERENCES vehicle_makes(id),
    make_name VARCHAR(100) NOT NULL,
    model_id UUID REFERENCES vehicle_models(id),
    model_name VARCHAR(100) NOT NULL,
    year VARCHAR(4) NOT NULL,
    
    -- Optional details
    vin VARCHAR(17),
    engine_code VARCHAR(50),
    nickname VARCHAR(100), -- e.g., "John's Golf GTI"
    
    -- Settings
    is_default BOOLEAN DEFAULT false,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_saved_vehicles_user_id ON saved_vehicles(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_vehicles_default ON saved_vehicles(user_id, is_default);
CREATE INDEX IF NOT EXISTS idx_saved_vehicles_vin ON saved_vehicles(vin) WHERE vin IS NOT NULL;

-- Enable RLS
ALTER TABLE saved_vehicles ENABLE ROW LEVEL SECURITY;

-- Users can only see their own saved vehicles
CREATE POLICY "Users can view own saved vehicles"
ON saved_vehicles FOR SELECT
USING (auth.uid() = user_id);

-- Users can insert their own saved vehicles
CREATE POLICY "Users can insert own saved vehicles"
ON saved_vehicles FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update their own saved vehicles
CREATE POLICY "Users can update own saved vehicles"
ON saved_vehicles FOR UPDATE
USING (auth.uid() = user_id);

-- Users can delete their own saved vehicles
CREATE POLICY "Users can delete own saved vehicles"
ON saved_vehicles FOR DELETE
USING (auth.uid() = user_id);

-- =====================================================
-- ADD OEM PART NUMBER TO PARTS TABLE
-- =====================================================

-- Add OEM number column if not exists
ALTER TABLE parts ADD COLUMN IF NOT EXISTS oem_number VARCHAR(100);
ALTER TABLE parts ADD COLUMN IF NOT EXISTS cross_references TEXT[]; -- Array of alternative part numbers

-- Create index for part number searches
CREATE INDEX IF NOT EXISTS idx_parts_oem_number ON parts(oem_number) WHERE oem_number IS NOT NULL;

-- =====================================================
-- ADD URGENCY AND BUDGET TO PART_REQUESTS TABLE
-- =====================================================

-- Add urgency level
ALTER TABLE part_requests ADD COLUMN IF NOT EXISTS urgency_level VARCHAR(20) DEFAULT 'normal';
-- Values: 'urgent' (need today), 'normal' (few days), 'flexible' (can wait)

-- Add budget range
ALTER TABLE part_requests ADD COLUMN IF NOT EXISTS budget_min DECIMAL(10,2);
ALTER TABLE part_requests ADD COLUMN IF NOT EXISTS budget_max DECIMAL(10,2);

-- Add notes field
ALTER TABLE part_requests ADD COLUMN IF NOT EXISTS notes TEXT;

-- =====================================================
-- REQUEST TEMPLATES TABLE (optional - for power users)
-- =====================================================

CREATE TABLE IF NOT EXISTS request_templates (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    name VARCHAR(100) NOT NULL,
    
    -- Optional vehicle association
    make_id UUID REFERENCES vehicle_makes(id),
    make_name VARCHAR(100),
    model_id UUID REFERENCES vehicle_models(id),
    model_name VARCHAR(100),
    
    -- Template parts (JSON array)
    parts JSONB NOT NULL DEFAULT '[]',
    
    -- Usage tracking
    use_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE request_templates ENABLE ROW LEVEL SECURITY;

-- Users can only manage their own templates
CREATE POLICY "Users can manage own templates"
ON request_templates FOR ALL
USING (auth.uid() = user_id);

-- Create index
CREATE INDEX IF NOT EXISTS idx_request_templates_user ON request_templates(user_id);
