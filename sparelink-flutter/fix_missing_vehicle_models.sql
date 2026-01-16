-- =============================================
-- FIX MISSING VEHICLE MODELS
-- Run this in Supabase SQL Editor
-- =============================================

-- First, let's get the make IDs for reference
-- We'll insert models for all makes that currently have 0 models

-- AUDI Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['A1', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'Q2', 'Q3', 'Q5', 'Q7', 'Q8', 'TT', 'R8', 'e-tron']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Audi'
) as audi_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = audi_models.make_id);

-- CHERY Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['Tiggo 4 Pro', 'Tiggo 7 Pro', 'Tiggo 8 Pro', 'Arrizo 5', 'Arrizo 6 Pro']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Chery'
) as chery_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = chery_models.make_id);

-- CHEVROLET Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['Spark', 'Aveo', 'Cruze', 'Captiva', 'Trailblazer', 'Utility', 'Lumina', 'Orlando']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Chevrolet'
) as chevy_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = chevy_models.make_id);

-- FIAT Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['500', '500X', 'Panda', 'Tipo', 'Punto', 'Doblo', 'Fiorino', 'Ducato']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Fiat'
) as fiat_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = fiat_models.make_id);

-- GWM Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['Steed 5', 'Steed 6', 'P-Series', 'H6', 'H2', 'C20R']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'GWM'
) as gwm_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = gwm_models.make_id);

-- HAVAL Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['H1', 'H2', 'H6', 'H9', 'Jolion', 'F5', 'F7']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Haval'
) as haval_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = haval_models.make_id);

-- ISUZU Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['D-Max', 'KB', 'MU-X', 'N-Series', 'F-Series', 'FTR', 'FVR', 'GXR']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Isuzu'
) as isuzu_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = isuzu_models.make_id);

-- JAGUAR Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['XE', 'XF', 'XJ', 'F-Type', 'E-Pace', 'F-Pace', 'I-Pace']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Jaguar'
) as jaguar_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = jaguar_models.make_id);

-- JEEP Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['Renegade', 'Compass', 'Cherokee', 'Grand Cherokee', 'Wrangler', 'Gladiator']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Jeep'
) as jeep_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = jeep_models.make_id);

-- LAND ROVER Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['Defender', 'Discovery', 'Discovery Sport', 'Range Rover', 'Range Rover Sport', 'Range Rover Evoque', 'Range Rover Velar']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Land Rover'
) as lr_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = lr_models.make_id);

-- LEXUS Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['IS', 'ES', 'GS', 'LS', 'NX', 'RX', 'GX', 'LX', 'UX', 'LC', 'RC']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Lexus'
) as lexus_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = lexus_models.make_id);

-- MINI Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['Cooper', 'Cooper S', 'Clubman', 'Countryman', 'Paceman', 'Convertible', 'JCW']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Mini'
) as mini_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = mini_models.make_id);

-- MITSUBISHI Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['Mirage', 'ASX', 'Eclipse Cross', 'Outlander', 'Pajero', 'Pajero Sport', 'Triton', 'Xpander']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Mitsubishi'
) as mitsu_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = mitsu_models.make_id);

-- OPEL Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['Corsa', 'Astra', 'Mokka', 'Crossland', 'Grandland', 'Combo', 'Vivaro', 'Movano']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Opel'
) as opel_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = opel_models.make_id);

-- PEUGEOT Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['208', '308', '408', '508', '2008', '3008', '5008', 'Partner', 'Expert', 'Boxer']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Peugeot'
) as peugeot_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = peugeot_models.make_id);

-- PORSCHE Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['911', '718 Boxster', '718 Cayman', 'Panamera', 'Taycan', 'Macan', 'Cayenne']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Porsche'
) as porsche_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = porsche_models.make_id);

-- RENAULT Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['Kwid', 'Sandero', 'Clio', 'Megane', 'Captur', 'Duster', 'Kadjar', 'Koleos', 'Triber', 'Kiger']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Renault'
) as renault_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = renault_models.make_id);

-- SUBARU Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['Impreza', 'WRX', 'Legacy', 'Outback', 'Forester', 'XV', 'BRZ', 'Levorg']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Subaru'
) as subaru_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = subaru_models.make_id);

-- SUZUKI Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['Alto', 'Celerio', 'Swift', 'Baleno', 'Ciaz', 'Ignis', 'Vitara', 'Jimny', 'S-Presso', 'Ertiga', 'XL6']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Suzuki'
) as suzuki_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = suzuki_models.make_id);

-- VOLVO Models
INSERT INTO vehicle_models (name, make_id)
SELECT model_name, make_id FROM (
    SELECT unnest(ARRAY['S60', 'S90', 'V40', 'V60', 'V90', 'XC40', 'XC60', 'XC90', 'C40']) as model_name,
           id as make_id FROM vehicle_makes WHERE name = 'Volvo'
) as volvo_models
WHERE NOT EXISTS (SELECT 1 FROM vehicle_models vm WHERE vm.make_id = volvo_models.make_id);

-- Verify the fix
SELECT 
    vma.name as make_name,
    COUNT(vm.id) as model_count
FROM vehicle_makes vma
LEFT JOIN vehicle_models vm ON vm.make_id = vma.id
GROUP BY vma.id, vma.name
ORDER BY vma.name;
