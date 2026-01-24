-- =====================================================
-- SPARELINK: DATA INTEGRITY CHECK CONSTRAINTS
-- Target: Ensure data validity at database level
-- Run in Supabase SQL Editor
-- =====================================================

-- =====================================================
-- OFFERS TABLE CONSTRAINTS
-- =====================================================

-- MC-01: Prevent negative prices on offers
-- Ensures shops cannot accidentally submit negative prices
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_offers_price_positive'
    ) THEN
        ALTER TABLE offers ADD CONSTRAINT chk_offers_price_positive 
        CHECK (price_cents IS NULL OR price_cents >= 0);
        RAISE NOTICE 'Added constraint: chk_offers_price_positive';
    ELSE
        RAISE NOTICE 'Constraint chk_offers_price_positive already exists';
    END IF;
END $$;

-- MC-02: Prevent negative delivery fees
-- Ensures delivery fees are always non-negative
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_offers_delivery_fee_positive'
    ) THEN
        ALTER TABLE offers ADD CONSTRAINT chk_offers_delivery_fee_positive 
        CHECK (delivery_fee_cents IS NULL OR delivery_fee_cents >= 0);
        RAISE NOTICE 'Added constraint: chk_offers_delivery_fee_positive';
    ELSE
        RAISE NOTICE 'Constraint chk_offers_delivery_fee_positive already exists';
    END IF;
END $$;

-- Additional: Ensure counter offers are positive
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_offers_counter_offer_positive'
    ) THEN
        ALTER TABLE offers ADD CONSTRAINT chk_offers_counter_offer_positive 
        CHECK (counter_offer_cents IS NULL OR counter_offer_cents >= 0);
        RAISE NOTICE 'Added constraint: chk_offers_counter_offer_positive';
    ELSE
        RAISE NOTICE 'Constraint chk_offers_counter_offer_positive already exists';
    END IF;
END $$;

-- =====================================================
-- ORDERS TABLE CONSTRAINTS
-- =====================================================

-- MC-03: Ensure orders have positive totals
-- Critical: prevents free orders from being created
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_orders_total_positive'
    ) THEN
        ALTER TABLE orders ADD CONSTRAINT chk_orders_total_positive 
        CHECK (total_cents > 0);
        RAISE NOTICE 'Added constraint: chk_orders_total_positive';
    ELSE
        RAISE NOTICE 'Constraint chk_orders_total_positive already exists';
    END IF;
END $$;

-- Additional: Valid payment status values
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_orders_payment_status_valid'
    ) THEN
        ALTER TABLE orders ADD CONSTRAINT chk_orders_payment_status_valid 
        CHECK (payment_status IS NULL OR payment_status IN ('pending', 'paid', 'failed', 'refunded', 'pending_verification'));
        RAISE NOTICE 'Added constraint: chk_orders_payment_status_valid';
    ELSE
        RAISE NOTICE 'Constraint chk_orders_payment_status_valid already exists';
    END IF;
END $$;

-- Additional: Valid order status values (aligned with CS-15)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_orders_status_valid'
    ) THEN
        ALTER TABLE orders ADD CONSTRAINT chk_orders_status_valid 
        CHECK (status IN ('pending', 'confirmed', 'preparing', 'processing', 'shipped', 'out_for_delivery', 'delivered', 'cancelled'));
        RAISE NOTICE 'Added constraint: chk_orders_status_valid';
    ELSE
        RAISE NOTICE 'Constraint chk_orders_status_valid already exists';
    END IF;
END $$;

-- =====================================================
-- INVENTORY TABLE CONSTRAINTS
-- =====================================================

-- MC-04: Prevent negative stock
-- Ensures stock quantity is always non-negative
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_inventory_stock_positive'
    ) THEN
        ALTER TABLE inventory ADD CONSTRAINT chk_inventory_stock_positive 
        CHECK (stock_quantity >= 0);
        RAISE NOTICE 'Added constraint: chk_inventory_stock_positive';
    ELSE
        RAISE NOTICE 'Constraint chk_inventory_stock_positive already exists';
    END IF;
EXCEPTION
    WHEN undefined_table THEN
        RAISE NOTICE 'Table inventory does not exist, skipping constraint';
END $$;

-- MC-05: Prevent negative cost prices
-- Ensures cost price is always non-negative
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_inventory_cost_positive'
    ) THEN
        ALTER TABLE inventory ADD CONSTRAINT chk_inventory_cost_positive 
        CHECK (cost_price IS NULL OR cost_price >= 0);
        RAISE NOTICE 'Added constraint: chk_inventory_cost_positive';
    ELSE
        RAISE NOTICE 'Constraint chk_inventory_cost_positive already exists';
    END IF;
EXCEPTION
    WHEN undefined_table THEN
        RAISE NOTICE 'Table inventory does not exist, skipping constraint';
    WHEN undefined_column THEN
        RAISE NOTICE 'Column cost_price does not exist, skipping constraint';
END $$;

-- Additional: Prevent negative selling prices
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_inventory_sell_price_positive'
    ) THEN
        ALTER TABLE inventory ADD CONSTRAINT chk_inventory_sell_price_positive 
        CHECK (sell_price IS NULL OR sell_price >= 0);
        RAISE NOTICE 'Added constraint: chk_inventory_sell_price_positive';
    ELSE
        RAISE NOTICE 'Constraint chk_inventory_sell_price_positive already exists';
    END IF;
EXCEPTION
    WHEN undefined_table THEN
        RAISE NOTICE 'Table inventory does not exist, skipping constraint';
    WHEN undefined_column THEN
        RAISE NOTICE 'Column sell_price does not exist, skipping constraint';
END $$;

-- =====================================================
-- REQUEST_ITEMS TABLE CONSTRAINTS
-- =====================================================

-- MC-06: Ensure quantity is at least 1
-- Prevents zero-quantity part requests
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_request_items_quantity_positive'
    ) THEN
        ALTER TABLE request_items ADD CONSTRAINT chk_request_items_quantity_positive 
        CHECK (quantity > 0);
        RAISE NOTICE 'Added constraint: chk_request_items_quantity_positive';
    ELSE
        RAISE NOTICE 'Constraint chk_request_items_quantity_positive already exists';
    END IF;
EXCEPTION
    WHEN undefined_table THEN
        RAISE NOTICE 'Table request_items does not exist, skipping constraint';
END $$;

-- =====================================================
-- PART_REQUESTS TABLE CONSTRAINTS
-- =====================================================

-- Valid request status values
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_part_requests_status_valid'
    ) THEN
        ALTER TABLE part_requests ADD CONSTRAINT chk_part_requests_status_valid 
        CHECK (status IN ('pending', 'offered', 'accepted', 'fulfilled', 'expired', 'cancelled'));
        RAISE NOTICE 'Added constraint: chk_part_requests_status_valid';
    ELSE
        RAISE NOTICE 'Constraint chk_part_requests_status_valid already exists';
    END IF;
EXCEPTION
    WHEN undefined_table THEN
        RAISE NOTICE 'Table part_requests does not exist, skipping constraint';
END $$;

-- Valid urgency level values
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_part_requests_urgency_valid'
    ) THEN
        ALTER TABLE part_requests ADD CONSTRAINT chk_part_requests_urgency_valid 
        CHECK (urgency_level IS NULL OR urgency_level IN ('low', 'normal', 'high', 'urgent'));
        RAISE NOTICE 'Added constraint: chk_part_requests_urgency_valid';
    ELSE
        RAISE NOTICE 'Constraint chk_part_requests_urgency_valid already exists';
    END IF;
EXCEPTION
    WHEN undefined_table THEN
        RAISE NOTICE 'Table part_requests does not exist, skipping constraint';
    WHEN undefined_column THEN
        RAISE NOTICE 'Column urgency_level does not exist, skipping constraint';
END $$;

-- Budget range validation
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_part_requests_budget_range'
    ) THEN
        ALTER TABLE part_requests ADD CONSTRAINT chk_part_requests_budget_range 
        CHECK (
            (budget_min IS NULL AND budget_max IS NULL) OR
            (budget_min IS NULL AND budget_max >= 0) OR
            (budget_min >= 0 AND budget_max IS NULL) OR
            (budget_min >= 0 AND budget_max >= budget_min)
        );
        RAISE NOTICE 'Added constraint: chk_part_requests_budget_range';
    ELSE
        RAISE NOTICE 'Constraint chk_part_requests_budget_range already exists';
    END IF;
EXCEPTION
    WHEN undefined_table THEN
        RAISE NOTICE 'Table part_requests does not exist, skipping constraint';
    WHEN undefined_column THEN
        RAISE NOTICE 'Budget columns do not exist, skipping constraint';
END $$;

-- =====================================================
-- OFFERS TABLE - STATUS VALIDATION
-- =====================================================

-- Valid offer status values
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_offers_status_valid'
    ) THEN
        ALTER TABLE offers ADD CONSTRAINT chk_offers_status_valid 
        CHECK (status IN ('pending', 'accepted', 'rejected', 'expired', 'counter_offered'));
        RAISE NOTICE 'Added constraint: chk_offers_status_valid';
    ELSE
        RAISE NOTICE 'Constraint chk_offers_status_valid already exists';
    END IF;
END $$;

-- =====================================================
-- DELIVERIES TABLE CONSTRAINTS
-- =====================================================

-- Valid delivery status values
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_deliveries_status_valid'
    ) THEN
        ALTER TABLE deliveries ADD CONSTRAINT chk_deliveries_status_valid 
        CHECK (status IN ('pending', 'assigned', 'picked_up', 'in_transit', 'delivered', 'cancelled'));
        RAISE NOTICE 'Added constraint: chk_deliveries_status_valid';
    ELSE
        RAISE NOTICE 'Constraint chk_deliveries_status_valid already exists';
    END IF;
EXCEPTION
    WHEN undefined_table THEN
        RAISE NOTICE 'Table deliveries does not exist, skipping constraint';
END $$;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- List all CHECK constraints
-- SELECT 
--     tc.table_name, 
--     tc.constraint_name,
--     cc.check_clause
-- FROM information_schema.table_constraints tc
-- JOIN information_schema.check_constraints cc 
--     ON tc.constraint_name = cc.constraint_name
-- WHERE tc.constraint_type = 'CHECK'
--     AND tc.table_schema = 'public'
-- ORDER BY tc.table_name, tc.constraint_name;

-- =====================================================
-- AUDIT LOG
-- =====================================================

DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'audit_logs') THEN
        INSERT INTO audit_logs (event_type, description, severity, metadata)
        VALUES (
            'migration', 
            'SCALE: Added CHECK constraints for data integrity', 
            'info',
            jsonb_build_object(
                'constraints_added', 14,
                'tables_affected', ARRAY['offers', 'orders', 'inventory', 'request_items', 'part_requests', 'deliveries'],
                'timestamp', NOW()
            )
        );
    END IF;
END $$;

-- =====================================================
-- COMPLETE
-- =====================================================
-- Total constraints added: 14
-- - 3 Price/fee constraints (offers)
-- - 3 Order constraints (total, payment_status, status)
-- - 3 Inventory constraints (stock, cost, sell_price)
-- - 1 Request items constraint (quantity)
-- - 3 Part requests constraints (status, urgency, budget)
-- - 1 Deliveries constraint (status)
-- =====================================================
