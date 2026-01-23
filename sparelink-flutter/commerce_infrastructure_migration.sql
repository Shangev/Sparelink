-- =====================================================
-- SPARELINK CORE COMMERCE INFRASTRUCTURE MIGRATION
-- =====================================================
-- This migration creates all tables required for:
-- 1. Payment Processing (Paystack integration)
-- 2. Invoice Generation
-- 3. Inventory Management
-- 4. Customer Database/CRM
-- 5. Analytics/Reports
-- =====================================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- 1. PAYMENTS TABLE
-- =====================================================
-- Tracks all payment transactions from Paystack

CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    
    -- Amount
    amount_cents INTEGER NOT NULL,
    currency VARCHAR(3) DEFAULT 'ZAR',
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    -- pending, completed, failed, refunded, cancelled
    
    -- Provider info
    provider VARCHAR(50) DEFAULT 'paystack',
    provider_reference VARCHAR(255),
    provider_transaction_id VARCHAR(255),
    
    -- Payment method
    payment_method VARCHAR(50), -- card, bank, bank_transfer, eft
    payment_type VARCHAR(20) DEFAULT 'payment', -- payment, refund
    card_last4 VARCHAR(4),
    card_brand VARCHAR(50),
    
    -- Customer info (for guest checkouts)
    customer_email VARCHAR(255),
    
    -- Error handling
    error_message TEXT,
    
    -- Metadata
    metadata JSONB,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for payments
CREATE INDEX idx_payments_order_id ON payments(order_id);
CREATE INDEX idx_payments_shop_id ON payments(shop_id);
CREATE INDEX idx_payments_customer_id ON payments(customer_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_provider_reference ON payments(provider_reference);
CREATE INDEX idx_payments_created_at ON payments(created_at DESC);

-- =====================================================
-- 2. PAYMENT LOGS TABLE
-- =====================================================
-- Audit trail for payment operations

CREATE TABLE IF NOT EXISTS payment_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    shop_id UUID REFERENCES shops(id) ON DELETE SET NULL,
    
    action VARCHAR(50) NOT NULL,
    -- payment_initialized, payment_completed, payment_failed, refund_initiated, refund_completed
    
    reference VARCHAR(255),
    amount_cents INTEGER,
    provider VARCHAR(50),
    
    -- Request/Response data
    metadata JSONB,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_payment_logs_order_id ON payment_logs(order_id);
CREATE INDEX idx_payment_logs_shop_id ON payment_logs(shop_id);

-- =====================================================
-- 3. INVOICE EMAILS TABLE
-- =====================================================
-- Tracks sent invoice emails

CREATE TABLE IF NOT EXISTS invoice_emails (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    invoice_number VARCHAR(50) NOT NULL,
    recipient_email VARCHAR(255) NOT NULL,
    
    -- Email provider tracking
    email_provider_id VARCHAR(255),
    
    -- Status
    status VARCHAR(20) DEFAULT 'sent',
    -- sent, delivered, opened, bounced, failed
    
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    delivered_at TIMESTAMPTZ,
    opened_at TIMESTAMPTZ
);

CREATE INDEX idx_invoice_emails_order_id ON invoice_emails(order_id);
CREATE INDEX idx_invoice_emails_invoice_number ON invoice_emails(invoice_number);

-- =====================================================
-- 4. INVENTORY TABLE
-- =====================================================
-- Shop inventory/parts catalog

CREATE TABLE IF NOT EXISTS inventory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    
    -- Part information
    part_name VARCHAR(255) NOT NULL,
    part_number VARCHAR(100),
    category VARCHAR(100) NOT NULL,
    description TEXT,
    
    -- Pricing
    cost_price INTEGER DEFAULT 0, -- in cents
    selling_price INTEGER DEFAULT 0, -- in cents
    
    -- Stock
    stock_quantity INTEGER DEFAULT 0,
    reorder_level INTEGER DEFAULT 5,
    status VARCHAR(20) DEFAULT 'in_stock',
    -- in_stock, out_of_stock, discontinued
    
    -- Vehicle compatibility
    compatible_vehicles JSONB DEFAULT '[]'::jsonb,
    -- Array of {make, model, year_from, year_to}
    
    -- Additional info
    condition VARCHAR(20) DEFAULT 'new', -- new, used, refurbished
    warranty_months INTEGER DEFAULT 0,
    supplier VARCHAR(255),
    location VARCHAR(100), -- warehouse location/bin
    
    -- Images
    images JSONB DEFAULT '[]'::jsonb,
    
    -- Alerts
    alert_enabled BOOLEAN DEFAULT true,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for inventory
CREATE INDEX idx_inventory_shop_id ON inventory(shop_id);
CREATE INDEX idx_inventory_category ON inventory(category);
CREATE INDEX idx_inventory_part_number ON inventory(part_number);
CREATE INDEX idx_inventory_status ON inventory(status);
CREATE INDEX idx_inventory_stock_quantity ON inventory(stock_quantity);
CREATE INDEX idx_inventory_part_name_search ON inventory USING gin(to_tsvector('english', part_name));

-- =====================================================
-- 5. SHOP CUSTOMERS TABLE (CRM)
-- =====================================================
-- Links customers to shops with loyalty tracking

CREATE TABLE IF NOT EXISTS shop_customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    -- Loyalty
    loyalty_tier VARCHAR(20) DEFAULT 'bronze',
    -- bronze, silver, gold, platinum
    loyalty_points INTEGER DEFAULT 0,
    
    -- Spending
    total_spend INTEGER DEFAULT 0, -- in cents
    order_count INTEGER DEFAULT 0,
    
    -- Order history
    first_order_at TIMESTAMPTZ,
    last_order_at TIMESTAMPTZ,
    
    -- CRM fields
    notes TEXT,
    tags JSONB DEFAULT '[]'::jsonb,
    
    -- Communication preferences
    email_opt_in BOOLEAN DEFAULT true,
    sms_opt_in BOOLEAN DEFAULT true,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Unique constraint
    UNIQUE(shop_id, customer_id)
);

-- Indexes for shop_customers
CREATE INDEX idx_shop_customers_shop_id ON shop_customers(shop_id);
CREATE INDEX idx_shop_customers_customer_id ON shop_customers(customer_id);
CREATE INDEX idx_shop_customers_loyalty_tier ON shop_customers(loyalty_tier);
CREATE INDEX idx_shop_customers_total_spend ON shop_customers(total_spend DESC);

-- =====================================================
-- 6. SHOP NOTIFICATIONS TABLE
-- =====================================================
-- Internal notifications for shop dashboard

CREATE TABLE IF NOT EXISTS shop_notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    
    type VARCHAR(50) NOT NULL,
    -- payment_received, payment_failed, low_stock, new_order, new_request
    
    title VARCHAR(255) NOT NULL,
    message TEXT,
    data JSONB,
    
    -- Status
    read BOOLEAN DEFAULT false,
    read_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_shop_notifications_shop_id ON shop_notifications(shop_id);
CREATE INDEX idx_shop_notifications_read ON shop_notifications(read);
CREATE INDEX idx_shop_notifications_created_at ON shop_notifications(created_at DESC);

-- =====================================================
-- 7. ADD COLUMNS TO ORDERS TABLE
-- =====================================================
-- Extend orders table for payment and invoice tracking

ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_status VARCHAR(20) DEFAULT 'pending';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_reference VARCHAR(255);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_card_last4 VARCHAR(4);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_card_brand VARCHAR(50);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_error TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS invoice_number VARCHAR(50);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS refund_reference VARCHAR(255);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS refund_amount_cents INTEGER;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES profiles(id);

-- Index for payment status
CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON orders(payment_status);
CREATE INDEX IF NOT EXISTS idx_orders_invoice_number ON orders(invoice_number);

-- =====================================================
-- 8. FUNCTIONS AND TRIGGERS
-- =====================================================

-- Function to increment customer spend
CREATE OR REPLACE FUNCTION increment_customer_spend(
    p_customer_id UUID,
    p_amount INTEGER
) RETURNS VOID AS $$
BEGIN
    UPDATE shop_customers
    SET 
        total_spend = total_spend + p_amount,
        order_count = order_count + 1,
        last_order_at = NOW(),
        first_order_at = COALESCE(first_order_at, NOW()),
        loyalty_tier = CASE
            WHEN total_spend + p_amount >= 5000000 THEN 'platinum'  -- R50,000+
            WHEN total_spend + p_amount >= 2000000 THEN 'gold'      -- R20,000+
            WHEN total_spend + p_amount >= 500000 THEN 'silver'     -- R5,000+
            ELSE 'bronze'
        END,
        updated_at = NOW()
    WHERE customer_id = p_customer_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get high demand low stock items
CREATE OR REPLACE FUNCTION get_high_demand_low_stock(p_shop_id UUID)
RETURNS TABLE (
    id UUID,
    part_name VARCHAR,
    stock_quantity INTEGER,
    request_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.id,
        i.part_name,
        i.stock_quantity,
        COUNT(pr.id) as request_count
    FROM inventory i
    LEFT JOIN part_requests pr ON 
        pr.part_category = i.category AND
        pr.created_at >= NOW() - INTERVAL '30 days'
    WHERE i.shop_id = p_shop_id
        AND i.stock_quantity <= i.reorder_level
    GROUP BY i.id, i.part_name, i.stock_quantity
    HAVING COUNT(pr.id) > 5
    ORDER BY request_count DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update customer relationship on order
CREATE OR REPLACE FUNCTION update_customer_on_order()
RETURNS TRIGGER AS $$
BEGIN
    -- Create or update shop_customers entry
    INSERT INTO shop_customers (shop_id, customer_id, first_order_at, last_order_at, order_count)
    VALUES (NEW.shop_id, NEW.customer_id, NOW(), NOW(), 1)
    ON CONFLICT (shop_id, customer_id)
    DO UPDATE SET
        last_order_at = NOW(),
        order_count = shop_customers.order_count + 1,
        updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_customer_on_order
    AFTER INSERT ON orders
    FOR EACH ROW
    WHEN (NEW.customer_id IS NOT NULL)
    EXECUTE FUNCTION update_customer_on_order();

-- =====================================================
-- 9. ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS on all new tables
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_emails ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_notifications ENABLE ROW LEVEL SECURITY;

-- Payments policies
CREATE POLICY "Shop owners can view their payments"
    ON payments FOR SELECT
    USING (shop_id IN (
        SELECT id FROM shops WHERE owner_id = auth.uid()
    ));

CREATE POLICY "Shop staff can view their shop payments"
    ON payments FOR SELECT
    USING (shop_id IN (
        SELECT shop_id FROM shop_staff WHERE user_id = auth.uid()
    ));

-- Inventory policies
CREATE POLICY "Shop owners can manage inventory"
    ON inventory FOR ALL
    USING (shop_id IN (
        SELECT id FROM shops WHERE owner_id = auth.uid()
    ));

CREATE POLICY "Shop staff can view inventory"
    ON inventory FOR SELECT
    USING (shop_id IN (
        SELECT shop_id FROM shop_staff WHERE user_id = auth.uid()
    ));

CREATE POLICY "Shop staff can update inventory"
    ON inventory FOR UPDATE
    USING (shop_id IN (
        SELECT shop_id FROM shop_staff WHERE user_id = auth.uid() AND role IN ('admin', 'manager')
    ));

-- Shop customers policies
CREATE POLICY "Shop owners can manage customers"
    ON shop_customers FOR ALL
    USING (shop_id IN (
        SELECT id FROM shops WHERE owner_id = auth.uid()
    ));

CREATE POLICY "Shop staff can view customers"
    ON shop_customers FOR SELECT
    USING (shop_id IN (
        SELECT shop_id FROM shop_staff WHERE user_id = auth.uid()
    ));

-- Shop notifications policies
CREATE POLICY "Shop owners can manage notifications"
    ON shop_notifications FOR ALL
    USING (shop_id IN (
        SELECT id FROM shops WHERE owner_id = auth.uid()
    ));

CREATE POLICY "Shop staff can view notifications"
    ON shop_notifications FOR SELECT
    USING (shop_id IN (
        SELECT shop_id FROM shop_staff WHERE user_id = auth.uid()
    ));

-- =====================================================
-- 10. SAMPLE DATA CATEGORIES
-- =====================================================

-- Insert standard part categories for reference
CREATE TABLE IF NOT EXISTS part_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    icon VARCHAR(50),
    sort_order INTEGER DEFAULT 0
);

INSERT INTO part_categories (name, description, icon, sort_order) VALUES
    ('Engine', 'Engine components and parts', 'engine', 1),
    ('Brake', 'Brake pads, discs, calipers', 'disc', 2),
    ('Suspension', 'Shocks, struts, springs', 'car', 3),
    ('Electrical', 'Batteries, alternators, starters', 'zap', 4),
    ('Body', 'Panels, bumpers, mirrors', 'square', 5),
    ('Interior', 'Seats, dashboard, trim', 'layout', 6),
    ('Transmission', 'Gearbox, clutch, driveshaft', 'settings', 7),
    ('Exhaust', 'Mufflers, catalytic converters', 'wind', 8),
    ('Cooling', 'Radiators, fans, hoses', 'thermometer', 9),
    ('Steering', 'Rack, pumps, tie rods', 'navigation', 10),
    ('Filters', 'Oil, air, fuel, cabin filters', 'filter', 11),
    ('Lighting', 'Headlights, taillights, bulbs', 'lightbulb', 12)
ON CONFLICT (name) DO NOTHING;

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================
-- Run this migration with: psql -d your_database -f commerce_infrastructure_migration.sql
-- Or execute via Supabase SQL Editor
