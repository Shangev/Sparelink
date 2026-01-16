-- =============================================
-- FIX SHOP LOCATIONS (NULL suburb/city)
-- Run this in Supabase SQL Editor
-- =============================================

-- Update shops with NULL suburb/city to have proper locations
-- Based on the shop names, assigning appropriate South African locations

UPDATE shops 
SET suburb = 'Sandton', city = 'Johannesburg'
WHERE name = 'AutoZone Sandton' AND suburb IS NULL;

UPDATE shops 
SET suburb = 'Johannesburg CBD', city = 'Johannesburg'
WHERE name = 'Parts Plus JHB' AND suburb IS NULL;

UPDATE shops 
SET suburb = 'Rosebank', city = 'Johannesburg'
WHERE name = 'Midas Rosebank' AND suburb IS NULL;

UPDATE shops 
SET suburb = 'Fourways', city = 'Johannesburg'
WHERE name = 'Goldwagen Fourways' AND suburb IS NULL;

UPDATE shops 
SET suburb = 'Midrand', city = 'Johannesburg'
WHERE name = 'Sparesworld Midrand' AND suburb IS NULL;

-- Verify the fix
SELECT id, name, suburb, city FROM shops ORDER BY name;
