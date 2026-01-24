# 🧪 QUERY OPTIMIZATION TEST GUIDE

> **Purpose:** Verify that optimized queries are working correctly  
> **Target:** Flutter app after SQL deployment  
> **Expected Result:** Debug logs showing "Used optimized view" instead of "Used legacy N+1 pattern"

---

## QUICK VERIFICATION

### 1. Run Flutter App in Debug Mode

```bash
cd sparelink-flutter
flutter run
```

### 2. Log In and Navigate to "My Requests"

Watch the debug console for these messages:

**✅ SUCCESS (Optimized):**
```
✅ [getMechanicRequests] Used optimized view - 1 query for 15 requests
```

**⚠️ FALLBACK (RPC Function):**
```
✅ [getMechanicRequests] Used RPC function - 1 query for 15 requests
```

**❌ LEGACY (N+1 Pattern - SQL not deployed):**
```
⚠️ [getMechanicRequests] View not available, trying RPC function...
⚠️ [getMechanicRequests] RPC not available, using legacy N+1 pattern...
⚠️ [getMechanicRequests] Used legacy N+1 pattern - 31 queries
```

---

## DETAILED TEST PROCEDURES

### Test 1: getMechanicRequests() Optimization

**What to do:**
1. Open the app
2. Log in as a mechanic
3. Navigate to "My Requests" screen
4. Watch debug console

**Expected log:**
```
✅ [getMechanicRequests] Used optimized view - 1 query for X requests
```

**Performance comparison:**

| Requests | Legacy (N+1) | Optimized | Improvement |
|----------|--------------|-----------|-------------|
| 10 | 21 queries | 1 query | 95% |
| 50 | 101 queries | 1 query | 99% |
| 100 | 201 queries | 1 query | 99.5% |

---

### Test 2: Batch Chat Unread Counts

**What to do:**
1. Navigate to "Chats" screen
2. Watch debug console

**Expected log (if RPC deployed):**
```
✅ [getUnreadCountsForChatsBatch] Batch query returned 10 results
```

**Fallback log (RPC not deployed):**
```
⚠️ [getUnreadCountsForChatsBatch] RPC not available, falling back to individual queries
```

---

### Test 3: Batch Last Messages

**What to do:**
1. Navigate to "Chats" screen
2. Watch debug console

**Expected log (if RPC deployed):**
```
✅ [getLastMessagesForChatsBatch] Batch query returned 10 results
```

---

## DATABASE VERIFICATION QUERIES

Run these in Supabase SQL Editor to verify deployments:

### Check View Exists
```sql
SELECT * FROM part_requests_with_counts LIMIT 5;
```
**Expected:** Returns rows with `offer_count`, `shop_count`, `quoted_count` columns

### Check RPC Functions Exist
```sql
-- Test getMechanicRequests function
SELECT proname FROM pg_proc WHERE proname = 'get_mechanic_requests_with_counts';

-- Test batch functions
SELECT proname FROM pg_proc WHERE proname IN (
  'get_unread_counts_batch',
  'get_last_messages_batch',
  'get_shop_dashboard_summary'
);
```
**Expected:** 4 rows returned

### Test RPC Function Directly
```sql
-- Replace with actual mechanic UUID
SELECT * FROM get_mechanic_requests_with_counts('your-mechanic-uuid-here');
```
**Expected:** Returns requests with counts

---

## TROUBLESHOOTING

### Issue: "View not available" in logs

**Cause:** `part_requests_with_counts` view not created

**Fix:** Run `SCALE_query_optimizations.sql` in Supabase SQL Editor

---

### Issue: "RPC not available" in logs

**Cause:** RPC functions not created

**Fix:** Run `SCALE_query_optimizations.sql` in Supabase SQL Editor

---

### Issue: View exists but returns wrong data

**Check:**
```sql
-- Verify view definition
SELECT definition FROM pg_views WHERE viewname = 'part_requests_with_counts';
```

**Recreate if needed:**
```sql
DROP VIEW IF EXISTS part_requests_with_counts;
-- Then run the CREATE VIEW statement from SCALE_query_optimizations.sql
```

---

### Issue: Still seeing legacy N+1 pattern after deployment

**Possible causes:**
1. **Cache:** Hot reload may cache old code. Do a full restart:
   ```bash
   flutter clean
   flutter run
   ```

2. **Wrong environment:** App may be pointing to different Supabase project

3. **RLS blocking:** View may not be accessible due to RLS
   ```sql
   -- Check RLS
   SELECT * FROM pg_policies WHERE tablename = 'part_requests';
   
   -- Grant access to view
   GRANT SELECT ON part_requests_with_counts TO authenticated;
   ```

---

## PERFORMANCE BENCHMARKING

### Manual Timing Test

Add this to measure actual performance:

```dart
// In my_requests_screen.dart or wherever getMechanicRequests is called

final stopwatch = Stopwatch()..start();
final requests = await supabaseService.getMechanicRequests(userId);
stopwatch.stop();
debugPrint('⏱️ getMechanicRequests took ${stopwatch.elapsedMilliseconds}ms for ${requests.length} requests');
```

### Expected Times

| Requests | Legacy (N+1) | Optimized | Network |
|----------|--------------|-----------|---------|
| 10 | ~2000ms | ~200ms | Good 4G |
| 50 | ~10000ms | ~300ms | Good 4G |
| 100 | ~20000ms | ~400ms | Good 4G |

---

## SUPABASE DASHBOARD MONITORING

### Check Query Performance

1. Go to Supabase Dashboard
2. Navigate to **Database** → **Query Performance**
3. Look for:
   - `SELECT * FROM part_requests_with_counts` (should be fast)
   - Multiple `SELECT * FROM offers WHERE request_id = ...` (legacy pattern - should not appear)

### Check Logs

1. Go to **Logs** → **Postgres Logs**
2. Filter by your queries
3. Verify single query pattern vs multiple queries

---

## AUTOMATED TEST (Future)

```dart
// test/query_optimization_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sparelink/shared/services/supabase_service.dart';

void main() {
  group('Query Optimization Tests', () {
    test('getMechanicRequests uses optimized view', () async {
      // This would require mocking Supabase client
      // and verifying the table name used is 'part_requests_with_counts'
    });
    
    test('getUnreadCountsForChatsBatch batches queries', () async {
      // Verify batch function is called instead of N individual queries
    });
  });
}
```

---

## SUCCESS CRITERIA

✅ **All tests pass when:**

1. Debug logs show "Used optimized view" or "Used RPC function"
2. No "Used legacy N+1 pattern" messages
3. My Requests screen loads in < 500ms (vs 5-10s before)
4. Chats screen loads counts in single batch

---

> **Test Guide Created:** January 24, 2026  
> **Optimization Type:** N+1 → Single Query  
> **Expected Improvement:** 95-99% query reduction
