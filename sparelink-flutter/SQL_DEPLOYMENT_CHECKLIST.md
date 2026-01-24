# 🚀 SQL DEPLOYMENT CHECKLIST

> **Created:** January 24, 2026  
> **Purpose:** Step-by-step guide for deploying all SQL migrations  
> **Environment:** Supabase SQL Editor

---

## DEPLOYMENT ORDER

Run these SQL files in Supabase SQL Editor **in this exact order**:

| Step | File | Purpose | Time |
|------|------|---------|------|
| 1 | `CS17_quote_expiry_validation.sql` | Quote expiry validation trigger | ~1 min |
| 2 | `CS16_order_status_transition_validation.sql` | Order status state machine | ~1 min |
| 3 | `SCALE_missing_indexes.sql` | Performance indexes (15 indexes) | ~2 min |
| 4 | `SCALE_check_constraints.sql` | Data integrity constraints (14 constraints) | ~1 min |
| 5 | `SCALE_query_optimizations.sql` | N+1 query fixes (views & functions) | ~2 min |

**Total Estimated Time:** ~7 minutes

---

## STEP 1: CS17 - Quote Expiry Validation

**File:** `CS17_quote_expiry_validation.sql`

**What it does:**
- Adds `expires_at` column to offers table
- Creates `validate_offer_acceptance()` trigger function
- Prevents accepting expired/already-accepted quotes
- Adds `unique_offer_order` constraint

**Verification after running:**
```sql
-- Check trigger exists
SELECT tgname FROM pg_trigger WHERE tgname = 'trigger_validate_offer_acceptance';

-- Check constraint exists
SELECT conname FROM pg_constraint WHERE conname = 'unique_offer_order';

-- Check column exists
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'offers' AND column_name = 'expires_at';
```

**Expected output:** 3 rows returned

---

## STEP 2: CS16 - Order Status Transitions

**File:** `CS16_order_status_transition_validation.sql`

**What it does:**
- Adds `cancelled_at` and `delivered_at` columns
- Creates `validate_order_status_transition()` trigger function
- Enforces valid status transitions (state machine)
- Auto-sets timestamps on delivered/cancelled

**Verification after running:**
```sql
-- Check trigger exists
SELECT tgname FROM pg_trigger WHERE tgname = 'trigger_validate_order_status';

-- Test invalid transition (should fail)
-- UPDATE orders SET status = 'delivered' WHERE status = 'pending' LIMIT 1;
```

**Expected output:** Trigger name returned

---

## STEP 3: Missing Indexes for Scale

**File:** `SCALE_missing_indexes.sql`

**What it does:**
- Creates 15 performance-critical indexes
- Optimizes queries for 100K+ users
- Adds composite indexes for common patterns
- Adds partial indexes for filtered queries

**Verification after running:**
```sql
-- Count indexes on core tables
SELECT 
    tablename,
    COUNT(*) as index_count
FROM pg_indexes 
WHERE tablename IN ('part_requests', 'offers', 'orders', 'shop_customers', 'request_items')
GROUP BY tablename
ORDER BY tablename;
```

**Expected output:** Higher index counts per table

---

## STEP 4: CHECK Constraints for Data Integrity

**File:** `SCALE_check_constraints.sql`

**What it does:**
- Prevents negative prices on offers
- Ensures positive order totals
- Validates status enum values
- Enforces quantity > 0 on request items

**Verification after running:**
```sql
-- List all CHECK constraints
SELECT 
    tc.table_name, 
    tc.constraint_name
FROM information_schema.table_constraints tc
WHERE tc.constraint_type = 'CHECK'
    AND tc.table_schema = 'public'
ORDER BY tc.table_name;
```

**Expected output:** 14+ constraints listed

---

## STEP 5: Query Optimizations

**File:** `SCALE_query_optimizations.sql`

**What it does:**
- Creates `part_requests_with_counts` view
- Creates `get_mechanic_requests_with_counts()` function
- Creates batch query functions for chat
- Creates `shop_analytics_daily` materialized view

**Verification after running:**
```sql
-- Check view exists
SELECT * FROM part_requests_with_counts LIMIT 1;

-- Check function exists
SELECT proname FROM pg_proc WHERE proname = 'get_mechanic_requests_with_counts';

-- Check materialized view exists
SELECT * FROM shop_analytics_daily LIMIT 1;
```

**Expected output:** No errors (may return empty sets if no data)

---

## POST-DEPLOYMENT VERIFICATION

Run this comprehensive check after all migrations:

```sql
-- FULL DEPLOYMENT VERIFICATION QUERY
SELECT 'Triggers' as category, 
       COUNT(*) as count,
       string_agg(tgname, ', ') as items
FROM pg_trigger 
WHERE tgname IN (
    'trigger_validate_offer_acceptance',
    'trigger_validate_order_status'
)
UNION ALL
SELECT 'Constraints' as category,
       COUNT(*) as count,
       string_agg(conname, ', ') as items
FROM pg_constraint
WHERE conname LIKE 'chk_%' OR conname = 'unique_offer_order'
UNION ALL
SELECT 'Functions' as category,
       COUNT(*) as count,
       string_agg(proname, ', ') as items
FROM pg_proc
WHERE proname IN (
    'validate_offer_acceptance',
    'validate_order_status_transition',
    'get_mechanic_requests_with_counts',
    'get_unread_counts_batch',
    'get_last_messages_batch',
    'get_shop_dashboard_summary'
)
UNION ALL
SELECT 'Views' as category,
       COUNT(*) as count,
       string_agg(viewname, ', ') as items
FROM pg_views
WHERE viewname IN (
    'part_requests_with_counts'
);
```

**Expected Results:**
- Triggers: 2
- Constraints: 15+
- Functions: 6
- Views: 1

---

## ROLLBACK PROCEDURES

If something goes wrong, use these rollback commands:

### Rollback CS17
```sql
DROP TRIGGER IF EXISTS trigger_validate_offer_acceptance ON offers;
DROP FUNCTION IF EXISTS validate_offer_acceptance();
ALTER TABLE orders DROP CONSTRAINT IF EXISTS unique_offer_order;
-- Note: Keep expires_at column, it's useful
```

### Rollback CS16
```sql
DROP TRIGGER IF EXISTS trigger_validate_order_status ON orders;
DROP FUNCTION IF EXISTS validate_order_status_transition();
-- Note: Keep cancelled_at/delivered_at columns
```

### Rollback Indexes
```sql
-- Only drop if causing issues (indexes are safe to keep)
DROP INDEX IF EXISTS idx_part_requests_mechanic_id;
-- ... (list continues)
```

### Rollback Constraints
```sql
-- Only drop if blocking valid data
ALTER TABLE offers DROP CONSTRAINT IF EXISTS chk_offers_price_positive;
-- ... (list continues)
```

### Rollback Query Optimizations
```sql
DROP VIEW IF EXISTS part_requests_with_counts;
DROP MATERIALIZED VIEW IF EXISTS shop_analytics_daily;
DROP FUNCTION IF EXISTS get_mechanic_requests_with_counts(UUID);
DROP FUNCTION IF EXISTS get_unread_counts_batch(UUID, TEXT[]);
DROP FUNCTION IF EXISTS get_last_messages_batch(TEXT[]);
DROP FUNCTION IF EXISTS get_shop_dashboard_summary(UUID);
```

---

## TROUBLESHOOTING

| Error | Cause | Solution |
|-------|-------|----------|
| `42601: unterminated dollar-quoted string` | Truncated SQL | Copy from GitHub raw file |
| `42703: column does not exist` | Missing column | Run earlier migration first |
| `42P07: relation already exists` | Already deployed | Safe to ignore |
| `23505: duplicate key` | Constraint violation | Fix existing data first |
| `42883: function does not exist` | Missing function | Check CREATE FUNCTION syntax |

---

## ENVIRONMENT VARIABLES REMINDER

After deploying SQL, ensure these are set in your environments:

### Vercel (Dashboard)
```
NEXT_PUBLIC_SUPABASE_URL=your-supabase-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
PAYSTACK_SECRET_KEY=your-paystack-secret
NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY=your-paystack-public-key  # NEW!
```

### Flutter (.env or build args)
```
SUPABASE_URL=your-supabase-url
SUPABASE_ANON_KEY=your-anon-key
```

---

> **Deployment Checklist Created:** January 24, 2026  
> **Total SQL Files:** 5  
> **Total Objects Created:** ~40 (triggers, constraints, indexes, functions, views)
