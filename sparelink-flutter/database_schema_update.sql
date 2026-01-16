-- =============================================
-- SPARELINK DATABASE SCHEMA UPDATE
-- Run these in Supabase SQL Editor
-- =============================================

-- =============================================
-- 1. UPDATE PROFILES TABLE - Add Address Fields
-- =============================================
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS street_address TEXT,
ADD COLUMN IF NOT EXISTS suburb TEXT,
ADD COLUMN IF NOT EXISTS city TEXT,
ADD COLUMN IF NOT EXISTS postal_code TEXT,
ADD COLUMN IF NOT EXISTS province TEXT;

-- =============================================
-- 2. UPDATE SHOPS TABLE - Add Specializations & Address
-- =============================================
ALTER TABLE shops
ADD COLUMN IF NOT EXISTS street_address TEXT,
ADD COLUMN IF NOT EXISTS suburb TEXT,
ADD COLUMN IF NOT EXISTS city TEXT,
ADD COLUMN IF NOT EXISTS postal_code TEXT,
ADD COLUMN IF NOT EXISTS province TEXT,
ADD COLUMN IF NOT EXISTS vehicle_brands TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- =============================================
-- 3. CREATE VEHICLE MAKES TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS vehicle_makes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    logo_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert common vehicle makes
INSERT INTO vehicle_makes (name) VALUES
('Toyota'), ('Volkswagen'), ('BMW'), ('Mercedes-Benz'), ('Ford'),
('Audi'), ('Honda'), ('Nissan'), ('Mazda'), ('Hyundai'),
('Kia'), ('Chevrolet'), ('Opel'), ('Renault'), ('Peugeot'),
('Jeep'), ('Land Rover'), ('Volvo'), ('Subaru'), ('Mitsubishi'),
('Isuzu'), ('Suzuki'), ('Fiat'), ('Alfa Romeo'), ('Citroën'),
('Mini'), ('Porsche'), ('Lexus'), ('Jaguar'), ('Haval'),
('GWM'), ('Chery'), ('BAIC'), ('JAC'), ('Mahindra')
ON CONFLICT (name) DO NOTHING;

-- =============================================
-- 4. CREATE VEHICLE MODELS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS vehicle_models (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    make_id UUID REFERENCES vehicle_makes(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    year_start INT,
    year_end INT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(make_id, name)
);

-- Insert common models (sample - expand as needed)
INSERT INTO vehicle_models (make_id, name, year_start, year_end)
SELECT m.id, model.name, model.year_start, model.year_end
FROM vehicle_makes m
CROSS JOIN (VALUES
    ('Toyota', 'Corolla', 2000, 2024),
    ('Toyota', 'Hilux', 2000, 2024),
    ('Toyota', 'Fortuner', 2005, 2024),
    ('Toyota', 'RAV4', 2000, 2024),
    ('Toyota', 'Yaris', 2005, 2024),
    ('Volkswagen', 'Polo', 2000, 2024),
    ('Volkswagen', 'Golf', 2000, 2024),
    ('Volkswagen', 'Tiguan', 2008, 2024),
    ('Volkswagen', 'Amarok', 2010, 2024),
    ('BMW', '3 Series', 2000, 2024),
    ('BMW', '5 Series', 2000, 2024),
    ('BMW', 'X3', 2004, 2024),
    ('BMW', 'X5', 2000, 2024),
    ('Ford', 'Ranger', 2000, 2024),
    ('Ford', 'EcoSport', 2012, 2024),
    ('Ford', 'Everest', 2015, 2024),
    ('Mercedes-Benz', 'C-Class', 2000, 2024),
    ('Mercedes-Benz', 'E-Class', 2000, 2024),
    ('Mercedes-Benz', 'GLC', 2015, 2024),
    ('Hyundai', 'Tucson', 2004, 2024),
    ('Hyundai', 'i20', 2008, 2024),
    ('Hyundai', 'Creta', 2015, 2024),
    ('Nissan', 'NP200', 2008, 2024),
    ('Nissan', 'NP300', 2008, 2024),
    ('Nissan', 'X-Trail', 2001, 2024),
    ('Honda', 'Jazz', 2002, 2024),
    ('Honda', 'CR-V', 2000, 2024),
    ('Mazda', 'CX-5', 2012, 2024),
    ('Mazda', '3', 2003, 2024),
    ('Kia', 'Sportage', 2005, 2024),
    ('Kia', 'Seltos', 2019, 2024)
) AS model(make_name, name, year_start, year_end)
WHERE m.name = model.make_name
ON CONFLICT (make_id, name) DO NOTHING;

-- =============================================
-- 5. CREATE PART CATEGORIES TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS part_categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    icon TEXT,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO part_categories (name, icon, sort_order) VALUES
('Engine', 'engine', 1),
('Brakes', 'disc', 2),
('Suspension', 'car', 3),
('Steering', 'steering-wheel', 4),
('Transmission', 'cog', 5),
('Electrical', 'zap', 6),
('Cooling System', 'thermometer', 7),
('Exhaust', 'wind', 8),
('Body Parts', 'car-front', 9),
('Interior', 'armchair', 10),
('Lights', 'lightbulb', 11),
('Filters', 'filter', 12),
('Belts & Hoses', 'link', 13),
('Fuel System', 'fuel', 14),
('Ignition', 'flame', 15),
('Accessories', 'package', 16)
ON CONFLICT (name) DO NOTHING;

-- =============================================
-- 6. CREATE PARTS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS parts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    category_id UUID REFERENCES part_categories(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(category_id, name)
);

-- Insert common parts per category
INSERT INTO parts (category_id, name) 
SELECT c.id, p.name
FROM part_categories c
CROSS JOIN (VALUES
    -- Brakes
    ('Brakes', 'Brake Pads (Front)'),
    ('Brakes', 'Brake Pads (Rear)'),
    ('Brakes', 'Brake Discs (Front)'),
    ('Brakes', 'Brake Discs (Rear)'),
    ('Brakes', 'Brake Calipers'),
    ('Brakes', 'Brake Master Cylinder'),
    ('Brakes', 'Brake Fluid'),
    ('Brakes', 'Handbrake Cable'),
    -- Engine
    ('Engine', 'Cylinder Head'),
    ('Engine', 'Timing Belt'),
    ('Engine', 'Timing Chain'),
    ('Engine', 'Water Pump'),
    ('Engine', 'Thermostat'),
    ('Engine', 'Engine Mount'),
    ('Engine', 'Gasket Set'),
    ('Engine', 'Piston Rings'),
    ('Engine', 'Crankshaft'),
    ('Engine', 'Camshaft'),
    ('Engine', 'Valve Cover'),
    -- Suspension
    ('Suspension', 'Shock Absorbers (Front)'),
    ('Suspension', 'Shock Absorbers (Rear)'),
    ('Suspension', 'Coil Springs'),
    ('Suspension', 'Control Arms'),
    ('Suspension', 'Ball Joints'),
    ('Suspension', 'Tie Rod Ends'),
    ('Suspension', 'Stabilizer Links'),
    ('Suspension', 'Bushings'),
    -- Electrical
    ('Electrical', 'Alternator'),
    ('Electrical', 'Starter Motor'),
    ('Electrical', 'Battery'),
    ('Electrical', 'Spark Plugs'),
    ('Electrical', 'Ignition Coil'),
    ('Electrical', 'Fuse Box'),
    ('Electrical', 'Wiring Harness'),
    -- Filters
    ('Filters', 'Oil Filter'),
    ('Filters', 'Air Filter'),
    ('Filters', 'Fuel Filter'),
    ('Filters', 'Cabin Filter'),
    -- Cooling System
    ('Cooling System', 'Radiator'),
    ('Cooling System', 'Radiator Hose'),
    ('Cooling System', 'Coolant'),
    ('Cooling System', 'Fan Belt'),
    ('Cooling System', 'Water Pump'),
    -- Transmission
    ('Transmission', 'Clutch Kit'),
    ('Transmission', 'Clutch Plate'),
    ('Transmission', 'Pressure Plate'),
    ('Transmission', 'Flywheel'),
    ('Transmission', 'Gearbox Mount'),
    ('Transmission', 'CV Joint'),
    ('Transmission', 'Driveshaft'),
    -- Lights
    ('Lights', 'Headlight (Left)'),
    ('Lights', 'Headlight (Right)'),
    ('Lights', 'Taillight (Left)'),
    ('Lights', 'Taillight (Right)'),
    ('Lights', 'Fog Light'),
    ('Lights', 'Indicator Light'),
    ('Lights', 'Headlight Bulb'),
    -- Body Parts
    ('Body Parts', 'Front Bumper'),
    ('Body Parts', 'Rear Bumper'),
    ('Body Parts', 'Bonnet/Hood'),
    ('Body Parts', 'Fender'),
    ('Body Parts', 'Door (Front)'),
    ('Body Parts', 'Door (Rear)'),
    ('Body Parts', 'Side Mirror'),
    ('Body Parts', 'Windscreen'),
    ('Body Parts', 'Grille')
) AS p(category_name, name)
WHERE c.name = p.category_name
ON CONFLICT (category_id, name) DO NOTHING;

-- =============================================
-- 7. UPDATE PART_REQUESTS TABLE
-- =============================================
ALTER TABLE part_requests
ADD COLUMN IF NOT EXISTS vin_number TEXT,
ADD COLUMN IF NOT EXISTS engine_code TEXT,
ADD COLUMN IF NOT EXISTS suburb TEXT,
ADD COLUMN IF NOT EXISTS city TEXT;

-- =============================================
-- 8. CREATE REQUEST_ITEMS TABLE (Multiple parts per request)
-- =============================================
CREATE TABLE IF NOT EXISTS request_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    request_id UUID REFERENCES part_requests(id) ON DELETE CASCADE,
    part_category_id UUID REFERENCES part_categories(id),
    part_id UUID REFERENCES parts(id),
    part_name TEXT NOT NULL,
    quantity INT DEFAULT 1,
    image_url TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- 9. CREATE DRIVERS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS drivers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    shop_id UUID REFERENCES shops(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    vehicle_type TEXT,
    vehicle_registration TEXT,
    is_active BOOLEAN DEFAULT true,
    is_available BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- 10. CREATE DELIVERIES TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS deliveries (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES drivers(id),
    shop_id UUID REFERENCES shops(id),
    mechanic_id UUID REFERENCES auth.users(id),
    pickup_address TEXT,
    delivery_address TEXT,
    status TEXT DEFAULT 'pending',
    pickup_time TIMESTAMPTZ,
    delivery_time TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Delivery status: pending, assigned, picked_up, in_transit, delivered, cancelled

-- =============================================
-- 11. UPDATE OFFERS TABLE (Quotes)
-- =============================================
ALTER TABLE offers
ADD COLUMN IF NOT EXISTS condition TEXT DEFAULT 'new',
ADD COLUMN IF NOT EXISTS is_available BOOLEAN DEFAULT true;

-- condition: new, used, refurbished, oem, aftermarket

-- =============================================
-- 12. INDEXES FOR PERFORMANCE
-- =============================================
CREATE INDEX IF NOT EXISTS idx_profiles_suburb ON profiles(suburb);
CREATE INDEX IF NOT EXISTS idx_shops_suburb ON shops(suburb);
CREATE INDEX IF NOT EXISTS idx_shops_vehicle_brands ON shops USING GIN(vehicle_brands);
CREATE INDEX IF NOT EXISTS idx_part_requests_suburb ON part_requests(suburb);
CREATE INDEX IF NOT EXISTS idx_request_items_request_id ON request_items(request_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_status ON deliveries(status);
CREATE INDEX IF NOT EXISTS idx_deliveries_driver_id ON deliveries(driver_id);

-- =============================================
-- 13. ROW LEVEL SECURITY
-- =============================================
ALTER TABLE vehicle_makes ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_models ENABLE ROW LEVEL SECURITY;
ALTER TABLE part_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE parts ENABLE ROW LEVEL SECURITY;
ALTER TABLE request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE deliveries ENABLE ROW LEVEL SECURITY;

-- Public read access for reference tables
CREATE POLICY "Public read vehicle_makes" ON vehicle_makes FOR SELECT USING (true);
CREATE POLICY "Public read vehicle_models" ON vehicle_models FOR SELECT USING (true);
CREATE POLICY "Public read part_categories" ON part_categories FOR SELECT USING (true);
CREATE POLICY "Public read parts" ON parts FOR SELECT USING (true);

-- Request items - users can manage their own
CREATE POLICY "Users can view request items" ON request_items FOR SELECT USING (true);
CREATE POLICY "Users can insert request items" ON request_items FOR INSERT WITH CHECK (true);

-- Drivers
CREATE POLICY "Drivers can view own data" ON drivers FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Shops can view their drivers" ON drivers FOR SELECT USING (
    shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
);
CREATE POLICY "Shops can manage their drivers" ON drivers FOR ALL USING (
    shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
);

-- Deliveries
CREATE POLICY "Users can view relevant deliveries" ON deliveries FOR SELECT USING (
    mechanic_id = auth.uid() OR 
    driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()) OR
    shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
);
CREATE POLICY "Shops can manage deliveries" ON deliveries FOR ALL USING (
    shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
);

-- =============================================
-- DONE! Run this entire script in Supabase SQL Editor
-- =============================================
