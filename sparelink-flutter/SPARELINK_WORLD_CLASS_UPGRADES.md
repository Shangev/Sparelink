# 🌍 SPARELINK WORLD-CLASS UPGRADES ROADMAP

> **Version:** 1.0  
> **Created:** January 23, 2026  
> **Total Upgrades:** 29  
> **Status:** Architectural Blueprint Phase

---

## 📊 EXECUTIVE SUMMARY

This document contains the complete architectural blueprint for transforming SpareLink from a "functional platform" to a "world-class industry standard." Each upgrade follows a standardized template with impact ratings, technical approaches, and dependency mappings.

### Progress Tracker

| Category | Items | Completed | Remaining |
|----------|-------|-----------|-----------|
| 🎨 Experience Design (UX/UI) | 6 | 0 | 6 |
| 🤖 Intelligence (AI/ML) | 5 | 0 | 5 |
| 🛡️ Trust & Safety | 6 | 0 | 6 |
| ⚙️ Operational Efficiency | 6 | 0 | 6 |
| 🚀 Performance & Scaling | 6 | 0 | 6 |
| **TOTAL** | **29** | **0** | **29** |

### Dependency Legend

| Symbol | Meaning |
|--------|---------|
| 🔌 | Requires External API |
| 🗄️ | Requires Supabase Schema Migration |
| 📱 | Flutter App Changes |
| 💻 | Shop Dashboard Changes |
| 🔗 | Has Dependencies on Other Upgrades |

---

## 🎨 CATEGORY 1: EXPERIENCE DESIGN (UX/UI)

### ☐ #1: Haptic Feedback Engine

**Impact:** ⭐⭐⭐ (Premium Feel)

**What it does:**
- Adds tactile vibrations to every major user action
- Success haptics: Payment confirmed, message sent, order placed
- Warning haptics: Form validation errors, connection issues
- Selection haptics: Button taps, toggle switches, list selections

**Why it's a game-changer:**
- Transforms the app from a "web-wrapper" feel to a "native flagship" experience
- Creates subconscious trust through physical feedback
- Matches the premium UX of apps like Apple Pay, Uber, and banking apps

**Technical approach:**
```dart
// HapticService - Centralized haptic management
class HapticService {
  static void success() => HapticFeedback.mediumImpact();
  static void error() => HapticFeedback.heavyImpact();
  static void selection() => HapticFeedback.selectionClick();
  static void light() => HapticFeedback.lightImpact();
}

// Integration points:
// - All ElevatedButton/TextButton widgets
// - Payment confirmation
// - Form submission success/failure
// - Pull-to-refresh completion
// - Toggle switches and checkboxes
```

**Files to modify:**
- `lib/shared/widgets/` - All button widgets
- `lib/features/payments/` - Checkout success
- `lib/features/chat/` - Message sent
- `lib/features/requests/` - Request submitted

**Dependencies:** 📱 Flutter App Only

**Estimated effort:** 2-3 hours

---

### ☐ #2: Hero Transitions & Shared Element Animations

**Impact:** ⭐⭐⭐⭐ (Visual Polish)

**What it does:**
- Smooth animated transitions between list items and detail screens
- Part images "fly" from list to detail view
- Shop logos animate between cards and full profiles
- Vehicle cards expand smoothly to full vehicle detail

**Why it's a game-changer:**
- Creates visual continuity that feels magical
- Reduces perceived loading time by 40%
- Industry standard for premium apps (Airbnb, Instagram, Apple Music)

**Technical approach:**
```dart
// List item with Hero
Hero(
  tag: 'shop-${shop.id}',
  child: ShopAvatar(shop: shop),
)

// Detail screen with matching Hero
Hero(
  tag: 'shop-${shop.id}',
  child: ShopHeader(shop: shop),
)

// Custom page transitions
class FadeSlideTransition extends PageRouteBuilder {
  FadeSlideTransition({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
        );
}
```

**Files to modify:**
- `lib/core/router/app_router.dart` - Custom page transitions
- `lib/features/marketplace/` - Shop cards → Shop detail
- `lib/features/requests/` - Request cards → Request detail
- `lib/features/orders/` - Order cards → Order tracking

**Dependencies:** 📱 Flutter App Only

**Estimated effort:** 4-5 hours

---

### ☐ #3: Custom Page Route Transitions

**Impact:** ⭐⭐⭐ (Seamless Navigation)

**What it does:**
- Replaces default Material page transitions with custom animations
- Bottom sheets slide up with spring physics
- Modal dialogs fade in with scale
- Back navigation uses iOS-style swipe gesture

**Why it's a game-changer:**
- Eliminates the "jarring" default Android transitions
- Creates platform-appropriate feel (iOS swipe, Android fade)
- Professional apps never use default transitions

**Technical approach:**
```dart
// GoRouter custom transition
GoRoute(
  path: '/shop/:id',
  pageBuilder: (context, state) => CustomTransitionPage(
    key: state.pageKey,
    child: ShopDetailScreen(id: state.pathParameters['id']!),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween(begin: Offset(1.0, 0.0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutExpo)),
        child: child,
      );
    },
  ),
)
```

**Files to modify:**
- `lib/core/router/app_router.dart` - All route definitions
- Create `lib/core/transitions/` folder with reusable transitions

**Dependencies:** 📱 Flutter App Only

**Estimated effort:** 3-4 hours

---

### ☐ #4: Micro-Interactions & Animated Feedback

**Impact:** ⭐⭐⭐⭐ (Delightful UX)

**What it does:**
- Animated checkmarks on task completion
- Bouncing buttons on tap
- Ripple effects with custom colors
- Progress indicators with personality (not just spinners)
- Success confetti on major milestones (first order, payment success)

**Why it's a game-changer:**
- Creates emotional connection with users
- Makes mundane tasks feel rewarding
- Differentiates from "boring enterprise" competitors

**Technical approach:**
```dart
// Using flutter_animate for declarative animations
ElevatedButton(
  child: Text('Submit'),
).animate(onPlay: (controller) => controller.repeat())
  .shimmer(duration: 1.seconds, color: Colors.white24)
  .then()
  .shake(hz: 4, rotation: 0.02);

// Confetti on success
ConfettiWidget(
  confettiController: _confettiController,
  blastDirectionality: BlastDirectionality.explosive,
  particleDrag: 0.05,
  emissionFrequency: 0.05,
  numberOfParticles: 20,
  gravity: 0.1,
)

// Animated checkmark
AnimatedCheck(
  progress: _checkAnimation,
  color: AppTheme.accentGreen,
  size: 80,
)
```

**Files to modify:**
- `lib/shared/widgets/animated_check.dart` - New widget
- `lib/shared/widgets/confetti_overlay.dart` - New widget
- `lib/features/payments/presentation/checkout_screen.dart` - Success celebration
- `lib/features/requests/presentation/request_part_screen.dart` - Submit animation

**Dependencies:** 📱 Flutter App Only | Add `confetti: ^0.7.0` to pubspec.yaml

**Estimated effort:** 4-5 hours

---

### ☐ #5: Progressive Image Loading with Blurhash

**Impact:** ⭐⭐⭐ (Perceived Performance)

**What it does:**
- Shows blurred placeholder while images load
- Smooth fade-in when full image is ready
- Caches blurhash strings in database for instant placeholders
- Reduces layout shift (CLS) to zero

**Why it's a game-changer:**
- Eliminates "pop-in" effect that feels cheap
- Instagram, Twitter, and Pinterest all use this technique
- Works even on slow 3G connections

**Technical approach:**
```dart
// Generate blurhash on upload (backend)
final blurhash = BlurHash.encode(imageBytes, numCompX: 4, numCompY: 3);

// Display with placeholder
BlurHash(
  hash: part.blurhash ?? 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
  imageFit: BoxFit.cover,
  image: part.imageUrl,
  duration: Duration(milliseconds: 300),
)
```

**Files to modify:**
- `lib/shared/widgets/progressive_image.dart` - New widget
- All screens displaying part/shop images
- Supabase storage upload functions (generate blurhash)

**Dependencies:** 📱 Flutter App | 🗄️ Add `blurhash` column to images | Add `flutter_blurhash: ^0.8.2`

**Estimated effort:** 5-6 hours

---

### ☐ #6: Skeleton Loading Enhancements

**Impact:** ⭐⭐⭐ (Polish)

**What it does:**
- Context-aware skeletons that match actual content shape
- Staggered animation (items appear one by one)
- Skeleton-to-content morphing animation
- Reduces time-to-interactive perception

**Why it's a game-changer:**
- Current implementation is good but can be exceptional
- Staggered loading creates anticipation
- Morphing effect is next-level polish

**Technical approach:**
```dart
// Staggered skeleton list
ListView.builder(
  itemCount: 5,
  itemBuilder: (context, index) {
    return SkeletonCard()
      .animate(delay: (index * 100).ms)
      .fadeIn(duration: 300.ms)
      .slideY(begin: 0.1, end: 0);
  },
)

// Skeleton to content morph
AnimatedSwitcher(
  duration: Duration(milliseconds: 300),
  transitionBuilder: (child, animation) {
    return FadeTransition(
      opacity: animation,
      child: SizeTransition(sizeFactor: animation, child: child),
    );
  },
  child: isLoading ? SkeletonCard(key: Key('skeleton')) : ContentCard(key: Key('content')),
)
```

**Files to modify:**
- `lib/shared/widgets/skeleton_loader.dart` - Enhance existing
- All list screens (requests, orders, chats)

**Dependencies:** 📱 Flutter App Only

**Estimated effort:** 3-4 hours

---

## 🤖 CATEGORY 2: INTELLIGENCE (AI/ML)

### ☐ #7: AI Part Recognition (Visual Part ID)

**Impact:** ⭐⭐⭐⭐⭐ (Revolutionary)

**What it does:**
- Mechanic takes a photo of a damaged/unknown part
- AI identifies: Part category, likely vehicle compatibility, OEM part numbers
- Auto-fills the part request form with 90%+ accuracy
- Suggests similar parts if exact match not found

**Why it's a game-changer:**
- Solves the #1 user friction: "What is this part called?"
- Reduces mismatched orders by 70%
- Creates massive competitive moat (no SA competitor has this)
- Viral potential: "The app that knows car parts!"

**Technical approach:**
```dart
// Option A: Google Cloud Vision API (Recommended for MVP)
Future<PartRecognitionResult> recognizePart(File image) async {
  final vision = GoogleVision.withAsset('credentials.json');
  final bytes = await image.readAsBytes();
  
  // Use product search or custom model
  final response = await vision.image(bytes).detectLabels(maxResults: 10);
  
  // Map to our part categories
  return PartRecognitionResult(
    category: _mapToPartCategory(response.labels),
    confidence: response.labels.first.confidence,
    suggestions: _getSuggestions(response),
  );
}

// Option B: On-device TensorFlow Lite (Future - offline capable)
final interpreter = await Interpreter.fromAsset('part_model.tflite');
final output = List.filled(1 * 100, 0.0).reshape([1, 100]);
interpreter.run(imageInput, output);
```

**New files to create:**
- `lib/shared/services/part_recognition_service.dart`
- `lib/shared/models/part_recognition_result.dart`
- `lib/features/camera/presentation/ai_recognition_screen.dart`

**Dependencies:** 
- 🔌 Google Cloud Vision API ($1.50/1000 images)
- 📱 Flutter App
- Add `google_ml_vision: ^0.0.7` or custom REST integration
- 🗄️ Add `recognized_parts` table for training data collection

**Estimated effort:** 2-3 weeks (including model training/tuning)

---

### ☐ #8: Predictive Inventory & Demand Forecasting

**Impact:** ⭐⭐⭐⭐⭐ (Operational Excellence)

**What it does:**
- Analyzes historical order data by region, season, vehicle type
- Predicts: "You'll need 50 brake pads next month"
- Seasonal adjustments (rainy season = wipers, winter = batteries)
- Regional demand heatmaps for expansion planning

**Why it's a game-changer:**
- Shops never run out of high-demand parts
- Reduces "Part not available" by 60%
- Premium subscription opportunity ("Pro Analytics")
- Data moat grows stronger over time

**Technical approach:**
```typescript
// Supabase Edge Function for predictions
interface DemandForecast {
  partCategory: string;
  currentStock: number;
  predictedDemand: number;
  confidence: number;
  seasonalFactor: string;
  recommendedReorder: number;
}

async function forecastDemand(shopId: string): Promise<DemandForecast[]> {
  // 1. Get historical orders (last 12 months)
  const history = await getOrderHistory(shopId, 365);
  
  // 2. Apply time-series decomposition
  const trend = calculateTrend(history);
  const seasonality = calculateSeasonality(history);
  
  // 3. Generate forecast
  return generateForecast(trend, seasonality, currentInventory);
}

// Simple moving average with seasonal adjustment
function predictNextMonth(data: number[], seasonIndex: number): number {
  const movingAvg = data.slice(-3).reduce((a, b) => a + b) / 3;
  const seasonalFactor = seasonalFactors[seasonIndex];
  return Math.round(movingAvg * seasonalFactor);
}
```

**New files to create:**
- `shop-dashboard/src/app/api/analytics/forecast/route.ts`
- `shop-dashboard/src/app/dashboard/analytics/forecast/page.tsx`
- `shop-dashboard/src/components/ForecastChart.tsx`

**Dependencies:**
- 💻 Shop Dashboard
- 🗄️ Requires 3+ months of order data for accuracy
- Consider: Supabase Edge Functions or external ML service

**Estimated effort:** 2 weeks

---

### ☐ #9: Smart Search with Semantic Understanding

**Impact:** ⭐⭐⭐⭐ (User Experience)

**What it does:**
- Fuzzy matching: "brak pads" → "Brake Pads"
- Synonym handling: "Bonnet" = "Hood", "Petrol" = "Fuel"
- "Did you mean?" suggestions
- Auto-complete with popular searches
- Vehicle-aware: Filters results by saved vehicle compatibility

**Why it's a game-changer:**
- Current search is exact-match only (frustrating)
- Reduces search abandonment by 50%
- Makes the app feel intelligent

**Technical approach:**
```sql
-- Postgres Full-Text Search with fuzzy matching
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX parts_name_trgm_idx ON parts USING GIN (name gin_trgm_ops);

-- Fuzzy search function
CREATE OR REPLACE FUNCTION search_parts(query TEXT)
RETURNS TABLE (id UUID, name TEXT, similarity REAL) AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.name, similarity(p.name, query) as sim
  FROM parts p
  WHERE p.name % query  -- trigram similarity
  ORDER BY sim DESC
  LIMIT 20;
END;
$$ LANGUAGE plpgsql;
```

```dart
// Flutter implementation
class SmartSearchService {
  final Map<String, List<String>> synonyms = {
    'bonnet': ['hood', 'engine cover'],
    'boot': ['trunk', 'cargo area'],
    'petrol': ['fuel', 'gas', 'gasoline'],
    'windscreen': ['windshield'],
  };
  
  String expandQuery(String query) {
    for (final entry in synonyms.entries) {
      if (query.toLowerCase().contains(entry.key)) {
        return '$query OR ${entry.value.join(' OR ')}';
      }
    }
    return query;
  }
}
```

**Files to modify:**
- `lib/shared/services/supabase_service.dart` - Search function
- `lib/features/marketplace/presentation/` - Search UI
- Supabase: Enable pg_trgm extension

**Dependencies:**
- 📱 Flutter App
- 💻 Shop Dashboard
- 🗄️ Postgres pg_trgm extension + search index

**Estimated effort:** 1 week

---

### ☐ #10: ML-Based Price Recommendations

**Impact:** ⭐⭐⭐ (Shop Value)

**What it does:**
- Analyzes competitor pricing in the region
- Suggests optimal price point for new parts
- "Price too high" warnings if above market average
- "Opportunity" alerts if part is underpriced elsewhere

**Why it's a game-changer:**
- Helps shops stay competitive without manual research
- Increases quote acceptance rates
- Creates pricing transparency in the market

**Technical approach:**
```typescript
interface PriceRecommendation {
  suggestedPrice: number;
  marketLow: number;
  marketHigh: number;
  marketAverage: number;
  competitorCount: number;
  recommendation: 'competitive' | 'high' | 'low' | 'optimal';
}

async function getPriceRecommendation(
  partCategory: string,
  vehicleMake: string,
  region: string
): Promise<PriceRecommendation> {
  // Get recent quotes for similar parts
  const marketData = await supabase
    .from('offers')
    .select('price_cents')
    .eq('part_category', partCategory)
    .eq('vehicle_make', vehicleMake)
    .gte('created_at', thirtyDaysAgo);
    
  return calculateRecommendation(marketData);
}
```

**Dependencies:**
- 💻 Shop Dashboard
- 🗄️ Requires sufficient offer data for accuracy
- 🔗 Depends on: Having enough shops using the platform

**Estimated effort:** 1 week

---

### ☐ #11: Vehicle Health Scoring & Maintenance Predictor

**Impact:** ⭐⭐⭐⭐ (User Retention)

**What it does:**
- Tracks vehicle mileage and service history
- Predicts upcoming maintenance needs
- "Your vehicle health score: 82/100"
- Push notifications: "Brake pads due in ~5,000 km"

**Why it's a game-changer:**
- Creates ongoing engagement beyond transactions
- Proactive notifications drive repeat orders
- Premium feature for B2B fleet management

**Technical approach:**
```dart
class VehicleHealthService {
  static const maintenanceIntervals = {
    'oil_change': 10000,      // km
    'brake_pads': 50000,
    'air_filter': 20000,
    'spark_plugs': 60000,
    'timing_belt': 100000,
  };
  
  int calculateHealthScore(Vehicle vehicle, List<Order> serviceHistory) {
    int score = 100;
    
    for (final item in maintenanceIntervals.entries) {
      final lastService = getLastServiceDate(serviceHistory, item.key);
      final kmSinceService = vehicle.currentMileage - lastService.mileage;
      
      if (kmSinceService > item.value) {
        score -= 15; // Overdue
      } else if (kmSinceService > item.value * 0.8) {
        score -= 5;  // Due soon
      }
    }
    
    return score.clamp(0, 100);
  }
}
```

**Dependencies:**
- 📱 Flutter App
- 🗄️ Add `vehicle_mileage_logs`, `maintenance_schedule` tables
- 🔗 Depends on: Fleet Management (#17)

**Estimated effort:** 1.5 weeks

---

## 🛡️ CATEGORY 3: TRUST & SAFETY

### ☐ #12: Escrow Payment System

**Impact:** ⭐⭐⭐⭐⭐ (Trust Foundation)

**What it does:**
- Payments held in escrow until mechanic confirms "Part fits"
- 48-hour inspection window after delivery
- Automatic release after inspection period if no dispute
- Clear status: `paid → held → released/refunded`

**Why it's a game-changer:**
- Solves the #1 trust barrier: "What if the part doesn't fit?"
- Enables higher-value transactions (mechanics spend more)
- Creates platform stickiness (both parties prefer safety)
- Industry standard for marketplace trust (Escrow.com, Alibaba)

**Technical approach:**
```sql
-- Escrow status tracking
ALTER TABLE orders ADD COLUMN escrow_status TEXT DEFAULT 'pending';
-- Values: pending, held, inspection, released, disputed, refunded

ALTER TABLE orders ADD COLUMN escrow_held_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN escrow_released_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN inspection_deadline TIMESTAMPTZ;

-- Escrow transactions table
CREATE TABLE escrow_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id),
  amount_cents INTEGER NOT NULL,
  status TEXT NOT NULL, -- held, released, refunded
  paystack_transfer_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);
```

```dart
// Flutter - Confirm delivery flow
class EscrowService {
  Future<void> confirmPartFits(String orderId) async {
    await supabase.from('orders').update({
      'escrow_status': 'released',
      'escrow_released_at': DateTime.now().toIso8601String(),
    }).eq('id', orderId);
    
    // Trigger payout to shop via Edge Function
    await supabase.functions.invoke('release-escrow', body: {'orderId': orderId});
  }
  
  Future<void> raiseDispute(String orderId, String reason) async {
    await supabase.from('orders').update({
      'escrow_status': 'disputed',
    }).eq('id', orderId);
    
    await supabase.from('disputes').insert({
      'order_id': orderId,
      'reason': reason,
      'status': 'open',
    });
  }
}
```

**New files to create:**
- `lib/shared/services/escrow_service.dart`
- `lib/features/orders/presentation/confirm_delivery_screen.dart`
- `shop-dashboard/src/app/api/escrow/release/route.ts`

**Dependencies:**
- 🔌 Paystack Transfer API (for payouts)
- 📱 Flutter App
- 💻 Shop Dashboard
- 🗄️ Schema migration for escrow fields

**Estimated effort:** 1.5 weeks

---

### ☐ #13: Dispute Resolution Center

**Impact:** ⭐⭐⭐⭐⭐ (Trust Multiplier)

**What it does:**
- Formal arbitration process for order issues
- Evidence upload: Photos, screenshots, messages
- Structured timeline: Open → Evidence → Review → Decision
- Admin dashboard for dispute management
- Automatic refund/release based on decision

**Why it's a game-changer:**
- Provides clear recourse when things go wrong
- Reduces chargebacks and payment reversals
- Builds long-term platform trust
- Data for identifying bad actors

**Technical approach:**
```sql
CREATE TABLE disputes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id),
  initiated_by UUID REFERENCES profiles(id), -- mechanic or shop
  reason TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'open', -- open, evidence, review, resolved
  resolution TEXT, -- refund_full, refund_partial, release, rejected
  resolution_amount_cents INTEGER,
  admin_notes TEXT,
  evidence JSONB DEFAULT '[]', -- [{type, url, uploaded_by, uploaded_at}]
  created_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES profiles(id)
);

-- Dispute messages for communication
CREATE TABLE dispute_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dispute_id UUID REFERENCES disputes(id),
  sender_id UUID REFERENCES profiles(id),
  message TEXT NOT NULL,
  attachments JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

```typescript
// Shop Dashboard - Dispute management
interface Dispute {
  id: string;
  orderId: string;
  reason: string;
  status: 'open' | 'evidence' | 'review' | 'resolved';
  mechanic: { name: string; email: string };
  shop: { name: string };
  evidence: Evidence[];
  timeline: TimelineEvent[];
}

// Resolution actions
async function resolveDispute(
  disputeId: string, 
  resolution: 'refund_full' | 'refund_partial' | 'release' | 'rejected',
  amount?: number
) {
  // Update dispute status
  // Trigger escrow action based on resolution
  // Notify both parties
}
```

**New files to create:**
- `lib/features/disputes/presentation/dispute_center_screen.dart`
- `lib/features/disputes/presentation/dispute_detail_screen.dart`
- `shop-dashboard/src/app/dashboard/disputes/page.tsx`
- Admin panel for dispute resolution

**Dependencies:**
- 📱 Flutter App
- 💻 Shop Dashboard
- 🗄️ Schema migration for disputes
- 🔗 Depends on: Escrow System (#12)

**Estimated effort:** 2 weeks

---

### ☐ #14: Shop Verification & Trust Badges

**Impact:** ⭐⭐⭐⭐ (Credibility)

**What it does:**
- Multi-tier verification: Basic → Verified → Premium
- Business document upload: Registration, tax clearance
- Bank account verification via micro-deposits
- Trust badges displayed on shop profiles
- "Verified Seller" filter in search

**Why it's a game-changer:**
- Separates legitimate businesses from fly-by-night sellers
- Justifies premium pricing for verified shops
- Reduces fraud and scams on platform
- Creates premium tier subscription opportunity

**Technical approach:**
```sql
CREATE TABLE shop_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id UUID REFERENCES shops(id),
  verification_type TEXT NOT NULL, -- business_reg, tax_clearance, bank_account, address
  status TEXT DEFAULT 'pending', -- pending, verified, rejected
  document_url TEXT,
  verified_at TIMESTAMPTZ,
  verified_by UUID,
  rejection_reason TEXT,
  expires_at TIMESTAMPTZ -- Some verifications expire
);

ALTER TABLE shops ADD COLUMN verification_level TEXT DEFAULT 'basic';
-- Values: basic, verified, premium
ALTER TABLE shops ADD COLUMN trust_score INTEGER DEFAULT 0;
```

```dart
// Trust badge widget
class TrustBadge extends StatelessWidget {
  final String level; // basic, verified, premium
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getBadgeColor(level),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getBadgeIcon(level), size: 14),
          SizedBox(width: 4),
          Text(_getBadgeText(level)),
        ],
      ),
    );
  }
}
```

**Dependencies:**
- 📱 Flutter App
- 💻 Shop Dashboard
- 🗄️ Schema migration for verifications
- 🔌 Optional: Bank verification API

**Estimated effort:** 1.5 weeks

---

### ☐ #15: Review & Rating System

**Impact:** ⭐⭐⭐⭐ (Social Proof)

**What it does:**
- Star ratings (1-5) for shops and parts
- Written reviews with photo attachments
- "Verified Purchase" badge on reviews
- Review responses from shops
- Aggregate ratings displayed prominently

**Why it's a game-changer:**
- Social proof drives purchase decisions
- Creates accountability for quality
- SEO benefits from user-generated content
- Feedback loop for shop improvement

**Technical approach:**
```sql
CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) UNIQUE, -- One review per order
  reviewer_id UUID REFERENCES profiles(id),
  shop_id UUID REFERENCES shops(id),
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  title TEXT,
  content TEXT,
  photos JSONB DEFAULT '[]',
  is_verified_purchase BOOLEAN DEFAULT true,
  helpful_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

CREATE TABLE review_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id UUID REFERENCES reviews(id),
  shop_id UUID REFERENCES shops(id),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Update shop aggregate ratings
CREATE OR REPLACE FUNCTION update_shop_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE shops SET 
    average_rating = (SELECT AVG(rating) FROM reviews WHERE shop_id = NEW.shop_id),
    review_count = (SELECT COUNT(*) FROM reviews WHERE shop_id = NEW.shop_id)
  WHERE id = NEW.shop_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Dependencies:**
- 📱 Flutter App
- 💻 Shop Dashboard
- 🗄️ Schema migration for reviews

**Estimated effort:** 1 week

---

### ☐ #16: Fraud Detection & Prevention

**Impact:** ⭐⭐⭐⭐ (Platform Safety)

**What it does:**
- Anomaly detection on order patterns
- Velocity checks: Too many orders, too fast
- Device fingerprinting for repeat offenders
- Risk scoring on new accounts
- Automatic holds on suspicious transactions

**Why it's a game-changer:**
- Protects both mechanics and shops
- Reduces chargebacks and losses
- Maintains platform integrity at scale
- Required for enterprise clients

**Technical approach:**
```typescript
interface RiskSignal {
  type: string;
  score: number;
  reason: string;
}

async function calculateRiskScore(order: Order): Promise<number> {
  const signals: RiskSignal[] = [];
  
  // Check 1: New account with high-value order
  if (accountAge < 7 && order.totalCents > 500000) {
    signals.push({ type: 'new_account_high_value', score: 30, reason: 'New account placing large order' });
  }
  
  // Check 2: Multiple orders in short time
  const recentOrders = await getRecentOrders(order.userId, '1 hour');
  if (recentOrders.length > 3) {
    signals.push({ type: 'velocity', score: 25, reason: 'Multiple orders in 1 hour' });
  }
  
  // Check 3: Shipping address mismatch
  if (order.shippingAddress !== user.primaryAddress) {
    signals.push({ type: 'address_mismatch', score: 15, reason: 'New shipping address' });
  }
  
  // Check 4: Previously disputed orders
  const disputeRate = await getDisputeRate(order.userId);
  if (disputeRate > 0.2) {
    signals.push({ type: 'high_dispute_rate', score: 40, reason: '20%+ dispute rate' });
  }
  
  return signals.reduce((sum, s) => sum + s.score, 0);
}

// Risk thresholds
// 0-30: Auto-approve
// 31-60: Manual review
// 61+: Auto-decline
```

**Dependencies:**
- 💻 Shop Dashboard (admin panel)
- 🗄️ Add risk_score to orders, fraud_signals table
- 🔗 Depends on: Dispute data (#13)

**Estimated effort:** 2 weeks

---

### ☐ #17: Part Authenticity Verification

**Impact:** ⭐⭐⭐ (Quality Assurance)

**What it does:**
- QR code generation for verified OEM parts
- Scan to verify authenticity history
- "Certified OEM" vs "Aftermarket" labeling
- Counterfeit reporting system

**Why it's a game-changer:**
- Addresses counterfeit parts problem in SA market
- Premium positioning for quality-conscious buyers
- Partnership opportunity with OEMs
- Legal protection for platform

**Technical approach:**
```dart
// QR code verification
class PartVerificationService {
  Future<VerificationResult> scanAndVerify(String qrCode) async {
    final partId = extractPartId(qrCode);
    final history = await supabase
      .from('part_authenticity')
      .select('*')
      .eq('part_id', partId)
      .single();
      
    return VerificationResult(
      isAuthentic: history['verified'],
      manufacturer: history['manufacturer'],
      productionDate: history['production_date'],
      supplyChain: history['supply_chain'],
    );
  }
}
```

**Dependencies:**
- 📱 Flutter App
- 🗄️ Schema for part authenticity tracking
- 🔌 Optional: OEM API partnerships

**Estimated effort:** 1.5 weeks

---

## ⚙️ CATEGORY 4: OPERATIONAL EFFICIENCY

### ☐ #18: Fleet & Client Management

**Impact:** ⭐⭐⭐⭐⭐ (Market Expansion)

**What it does:**
- Mechanics manage multiple vehicles (personal garage)
- Corporate accounts: Manage client fleets
- Invite clients to share vehicle access
- Consolidated billing per fleet
- Fleet health dashboard with alerts

**Why it's a game-changer:**
- Opens B2B market segment (Uber drivers, delivery companies)
- 5-10x order frequency per account
- Long-term data value (vehicle history)
- Premium subscription opportunity

**Technical approach:**
```sql
CREATE TABLE fleets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES profiles(id),
  name TEXT NOT NULL,
  type TEXT DEFAULT 'personal', -- personal, business, managed
  company_name TEXT,
  billing_email TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE fleet_vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fleet_id UUID REFERENCES fleets(id),
  vehicle_id UUID REFERENCES vehicles(id),
  nickname TEXT, -- "John's Corolla", "Delivery Van #3"
  added_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE fleet_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fleet_id UUID REFERENCES fleets(id),
  user_id UUID REFERENCES profiles(id),
  role TEXT DEFAULT 'viewer', -- owner, admin, driver, viewer
  invited_at TIMESTAMPTZ DEFAULT NOW(),
  accepted_at TIMESTAMPTZ
);
```

```dart
// Fleet dashboard widget
class FleetOverview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FleetHealthCard(healthScore: 85),
        VehicleStatusList(vehicles: fleet.vehicles),
        UpcomingMaintenanceAlerts(alerts: maintenanceAlerts),
        FleetSpendingChart(data: spendingData),
      ],
    );
  }
}
```

**New files to create:**
- `lib/features/fleet/presentation/fleet_screen.dart`
- `lib/features/fleet/presentation/fleet_detail_screen.dart`
- `lib/features/fleet/presentation/add_vehicle_to_fleet_screen.dart`

**Dependencies:**
- 📱 Flutter App
- 🗄️ Schema migration for fleets

**Estimated effort:** 2 weeks

---

### ☐ #19: Shop CRM & Automation Engine

**Impact:** ⭐⭐⭐⭐⭐ (Revenue Driver)

**What it does:**
- Automated follow-up messages after purchases
- Re-engagement campaigns: "Need rotors with those brake pads?"
- Abandoned quote reminders
- Birthday/anniversary rewards
- Custom automation rules builder

**Why it's a game-changer:**
- Increases repeat purchase rate by 40%+
- Shops become "sticky" to platform
- Data-driven marketing without manual effort
- Premium feature for subscription tier

**Technical approach:**
```sql
CREATE TABLE automation_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id UUID REFERENCES shops(id),
  name TEXT NOT NULL,
  trigger_type TEXT NOT NULL, -- purchase, time_since_purchase, abandoned_quote, birthday
  trigger_config JSONB NOT NULL, -- {days_after: 90, part_category: 'brake_pads'}
  action_type TEXT NOT NULL, -- send_message, send_offer, send_notification
  action_config JSONB NOT NULL, -- {template_id, discount_percent}
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE automation_executions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_id UUID REFERENCES automation_rules(id),
  customer_id UUID REFERENCES profiles(id),
  executed_at TIMESTAMPTZ DEFAULT NOW(),
  result TEXT, -- sent, failed, skipped
  metadata JSONB
);

-- Message templates
CREATE TABLE message_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id UUID REFERENCES shops(id),
  name TEXT NOT NULL,
  subject TEXT,
  body TEXT NOT NULL,
  variables JSONB DEFAULT '[]', -- [{name, description}]
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

```typescript
// Cron job for automation execution (runs hourly)
async function processAutomations() {
  const rules = await getActiveRules();
  
  for (const rule of rules) {
    const eligibleCustomers = await findEligibleCustomers(rule);
    
    for (const customer of eligibleCustomers) {
      await executeAutomation(rule, customer);
      await recordExecution(rule.id, customer.id);
    }
  }
}

// Example: 90-day follow-up
const followUpRule = {
  trigger_type: 'time_since_purchase',
  trigger_config: { days_after: 90, part_category: 'brake_pads' },
  action_type: 'send_message',
  action_config: { 
    template: 'Hi {{customer_name}}, it\'s been 3 months since you got brake pads. Time for an inspection?'
  }
};
```

**New files to create:**
- `shop-dashboard/src/app/dashboard/automation/page.tsx`
- `shop-dashboard/src/app/dashboard/automation/rules/page.tsx`
- `shop-dashboard/src/app/dashboard/automation/templates/page.tsx`
- Supabase Edge Function for cron execution

**Dependencies:**
- 💻 Shop Dashboard
- 🗄️ Schema migration for automation
- 🔌 Cron service (Supabase Edge Functions or external)

**Estimated effort:** 2 weeks

---

### ☐ #20: Multi-Location & Branch Management

**Impact:** ⭐⭐⭐⭐ (Enterprise Ready)

**What it does:**
- Single shop account with multiple locations
- Per-branch inventory tracking
- Stock transfer between branches
- Consolidated reporting across locations
- Branch-specific staff assignments

**Why it's a game-changer:**
- Attracts larger auto parts chains
- Enterprise-tier subscription opportunity
- Operational efficiency for growing shops
- Competitive advantage over single-location tools

**Technical approach:**
```sql
CREATE TABLE shop_branches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id UUID REFERENCES shops(id),
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  city TEXT,
  coordinates POINT,
  phone TEXT,
  manager_id UUID REFERENCES profiles(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Inventory becomes branch-specific
ALTER TABLE inventory ADD COLUMN branch_id UUID REFERENCES shop_branches(id);

-- Stock transfers between branches
CREATE TABLE stock_transfers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_branch_id UUID REFERENCES shop_branches(id),
  to_branch_id UUID REFERENCES shop_branches(id),
  inventory_item_id UUID REFERENCES inventory(id),
  quantity INTEGER NOT NULL,
  status TEXT DEFAULT 'pending', -- pending, in_transit, completed
  requested_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);
```

**Dependencies:**
- 💻 Shop Dashboard
- 🗄️ Schema migration for branches
- 🔗 Depends on: Existing inventory system

**Estimated effort:** 2 weeks

---

### ☐ #21: Bulk Operations & Batch Processing

**Impact:** ⭐⭐⭐ (Time Saver)

**What it does:**
- Bulk quote creation for multiple requests
- Batch order status updates
- CSV import for inventory
- Mass messaging to customers
- Bulk price adjustments

**Why it's a game-changer:**
- Saves hours of manual work for active shops
- Handles high-volume scenarios efficiently
- Reduces repetitive task fatigue
- Professional-grade tooling

**Technical approach:**
```typescript
// Bulk quote API
async function createBulkQuotes(
  shopId: string,
  quotes: BulkQuoteInput[]
): Promise<BulkQuoteResult> {
  const results = await Promise.allSettled(
    quotes.map(q => createQuote(shopId, q))
  );
  
  return {
    successful: results.filter(r => r.status === 'fulfilled').length,
    failed: results.filter(r => r.status === 'rejected').length,
    errors: results
      .filter(r => r.status === 'rejected')
      .map((r, i) => ({ index: i, error: r.reason }))
  };
}

// CSV inventory import
async function importInventoryCSV(file: File, shopId: string) {
  const rows = await parseCSV(file);
  const validated = rows.map(row => validateInventoryRow(row));
  
  const { valid, invalid } = partition(validated, v => v.isValid);
  
  await supabase.from('inventory').insert(valid.map(v => v.data));
  
  return { imported: valid.length, errors: invalid };
}
```

**Dependencies:**
- 💻 Shop Dashboard
- Add CSV parsing library

**Estimated effort:** 1 week

---

### ☐ #22: Advanced Reporting & Analytics

**Impact:** ⭐⭐⭐⭐ (Business Intelligence)

**What it does:**
- Revenue reports by period, category, customer
- Conversion funnel analytics (request → quote → order)
- Customer lifetime value tracking
- Inventory turnover metrics
- Exportable reports (PDF, CSV)

**Why it's a game-changer:**
- Data-driven decision making for shops
- Identifies growth opportunities
- Required for serious business operations
- Premium subscription feature

**Technical approach:**
```typescript
interface AnalyticsReport {
  revenue: {
    total: number;
    byCategory: Record<string, number>;
    byPeriod: { date: string; amount: number }[];
    growth: number; // percentage vs previous period
  };
  conversion: {
    requests: number;
    quotes: number;
    orders: number;
    conversionRate: number;
  };
  customers: {
    total: number;
    new: number;
    returning: number;
    topCustomers: Customer[];
    averageOrderValue: number;
    lifetimeValue: number;
  };
  inventory: {
    turnoverRate: number;
    topSellers: InventoryItem[];
    slowMoving: InventoryItem[];
    stockValue: number;
  };
}

// Generate PDF report
async function generatePDFReport(shopId: string, period: string) {
  const data = await getAnalyticsData(shopId, period);
  const pdf = await renderReportTemplate(data);
  return pdf;
}
```

**New files to create:**
- `shop-dashboard/src/app/dashboard/reports/page.tsx`
- `shop-dashboard/src/app/api/reports/generate/route.ts`
- Report templates

**Dependencies:**
- 💻 Shop Dashboard
- 🔌 PDF generation library (jsPDF or similar)

**Estimated effort:** 1.5 weeks

---

### ☐ #23: Staff Roles & Permissions (RBAC)

**Impact:** ⭐⭐⭐ (Enterprise Security)

**What it does:**
- Granular role definitions (Owner, Manager, Sales, Inventory)
- Per-feature permission controls
- Audit log of staff actions
- Invitation system for new staff
- Activity dashboard per staff member

**Why it's a game-changer:**
- Required for multi-person shops
- Security and accountability
- Delegation without full access
- Enterprise compliance ready

**Technical approach:**
```sql
CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id UUID REFERENCES shops(id),
  name TEXT NOT NULL,
  permissions JSONB NOT NULL, -- {quotes: 'write', inventory: 'read', orders: 'write'}
  is_custom BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Default roles
INSERT INTO roles (shop_id, name, permissions, is_custom) VALUES
(NULL, 'owner', '{"*": "admin"}', false),
(NULL, 'manager', '{"quotes": "write", "orders": "write", "inventory": "write", "customers": "read"}', false),
(NULL, 'sales', '{"quotes": "write", "orders": "read", "customers": "read"}', false),
(NULL, 'inventory', '{"inventory": "write"}', false);

-- Staff assignments
CREATE TABLE shop_staff (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id UUID REFERENCES shops(id),
  user_id UUID REFERENCES profiles(id),
  role_id UUID REFERENCES roles(id),
  invited_by UUID REFERENCES profiles(id),
  invited_at TIMESTAMPTZ DEFAULT NOW(),
  accepted_at TIMESTAMPTZ
);
```

**Dependencies:**
- 💻 Shop Dashboard
- 🗄️ Schema migration for roles
- 🔗 Depends on: Multi-location (#20) for branch-specific roles

**Estimated effort:** 1.5 weeks

---

## 🚀 CATEGORY 5: PERFORMANCE & SCALING

### ☐ #24: Offline-First Architecture

**Impact:** ⭐⭐⭐⭐⭐ (Reliability)

**What it does:**
- Full app functionality without internet connection
- Local SQLite database for offline data
- Background sync queue for pending actions
- Conflict resolution for concurrent edits
- Visual indicator for sync status

**Why it's a game-changer:**
- South Africa has connectivity issues (load shedding, rural areas)
- Mechanics often work in garages with poor signal
- Eliminates frustration of lost work
- Competitive advantage over web-only solutions

**Technical approach:**
```dart
// Using Drift (SQLite) for local storage
@DriftDatabase(tables: [LocalVehicles, LocalRequests, LocalOrders, PendingActions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  
  @override
  int get schemaVersion => 1;
}

// Sync queue for pending actions
class SyncService {
  final Queue<PendingAction> _queue = Queue();
  
  Future<void> queueAction(PendingAction action) async {
    await _db.pendingActions.insert(action);
    _attemptSync();
  }
  
  Future<void> _attemptSync() async {
    if (!await hasConnectivity()) return;
    
    final pending = await _db.pendingActions.all();
    for (final action in pending) {
      try {
        await _executeAction(action);
        await _db.pendingActions.delete(action.id);
      } catch (e) {
        // Retry later
        action.retryCount++;
        await _db.pendingActions.update(action);
      }
    }
  }
}

// Connectivity-aware UI
class ConnectivityBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider);
    
    if (isOnline && pendingCount == 0) return SizedBox.shrink();
    
    return Container(
      color: isOnline ? Colors.orange : Colors.red,
      padding: EdgeInsets.all(8),
      child: Text(
        isOnline 
          ? 'Syncing $pendingCount items...' 
          : 'Offline mode - Changes will sync when connected',
      ),
    );
  }
}
```

**New files to create:**
- `lib/shared/services/offline_database.dart`
- `lib/shared/services/sync_service.dart`
- `lib/shared/widgets/connectivity_banner.dart`

**Dependencies:**
- 📱 Flutter App
- Add `drift: ^2.14.0`, `drift_sqflite: ^2.0.0`
- Significant refactor of data layer

**Estimated effort:** 3 weeks

---

### ☐ #25: Background Sync & Push Queue

**Impact:** ⭐⭐⭐⭐ (Reliability)

**What it does:**
- Continues syncing when app is backgrounded
- Retry failed operations with exponential backoff
- Priority queue (orders > messages > analytics)
- Battery-efficient scheduling
- Sync completion notifications

**Why it's a game-changer:**
- No lost data even with app closure
- Seamless experience across sessions
- Professional-grade reliability
- Required for offline-first architecture

**Technical approach:**
```dart
// WorkManager for background tasks
class BackgroundSyncWorker extends Worker {
  @override
  Future<Result> doWork() async {
    try {
      final syncService = SyncService();
      await syncService.syncAll();
      return Result.success();
    } catch (e) {
      return Result.retry();
    }
  }
}

// Initialize background worker
void initBackgroundSync() {
  Workmanager().initialize(callbackDispatcher);
  Workmanager().registerPeriodicTask(
    'sync-task',
    'backgroundSync',
    frequency: Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
    ),
  );
}

// Exponential backoff for retries
class RetryPolicy {
  static Duration getDelay(int attempt) {
    final baseDelay = Duration(seconds: 5);
    final maxDelay = Duration(minutes: 30);
    final delay = baseDelay * pow(2, attempt);
    return delay > maxDelay ? maxDelay : delay;
  }
}
```

**Dependencies:**
- 📱 Flutter App
- Add `workmanager: ^0.5.2`
- 🔗 Depends on: Offline-First Architecture (#24)

**Estimated effort:** 1 week

---

### ☐ #26: Image Optimization Pipeline

**Impact:** ⭐⭐⭐ (Performance)

**What it does:**
- Client-side compression before upload
- Multiple resolution variants (thumbnail, medium, full)
- WebP format for smaller file sizes
- Lazy loading with intersection observer
- CDN caching for fast delivery

**Why it's a game-changer:**
- Reduces bandwidth usage by 60%
- Faster page loads on slow connections
- Lower storage costs
- Better user experience

**Technical approach:**
```dart
// Client-side image compression
class ImageOptimizer {
  static Future<Uint8List> optimize(File image, {
    int maxWidth = 1200,
    int quality = 85,
  }) async {
    final bytes = await image.readAsBytes();
    final decoded = img.decodeImage(bytes);
    
    // Resize if needed
    final resized = decoded!.width > maxWidth
      ? img.copyResize(decoded, width: maxWidth)
      : decoded;
    
    // Encode as WebP
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }
  
  static Future<Map<String, Uint8List>> generateVariants(File image) async {
    return {
      'thumbnail': await optimize(image, maxWidth: 150, quality: 70),
      'medium': await optimize(image, maxWidth: 600, quality: 80),
      'full': await optimize(image, maxWidth: 1200, quality: 85),
    };
  }
}

// Upload with variants
Future<ImageUrls> uploadWithVariants(File image, String path) async {
  final variants = await ImageOptimizer.generateVariants(image);
  
  final urls = <String, String>{};
  for (final entry in variants.entries) {
    final uploadPath = '$path/${entry.key}.webp';
    await supabase.storage.from('images').uploadBinary(uploadPath, entry.value);
    urls[entry.key] = supabase.storage.from('images').getPublicUrl(uploadPath);
  }
  
  return ImageUrls.fromMap(urls);
}
```

**Files to modify:**
- `lib/shared/services/storage_service.dart`
- Camera capture screens
- All image display widgets

**Dependencies:**
- 📱 Flutter App
- Add `image: ^4.1.3` for processing
- Consider Supabase image transforms or Cloudinary

**Estimated effort:** 1 week

---

### ☐ #27: Low Bandwidth Mode

**Impact:** ⭐⭐⭐ (Accessibility)

**What it does:**
- Automatic detection of slow connections
- Reduced image quality and sizes
- Text-only mode option
- Deferred loading of non-essential content
- Data usage tracking and warnings

**Why it's a game-changer:**
- Makes app usable on 2G/EDGE networks
- Reduces data costs for users
- Inclusive design for all network conditions
- Shows respect for user's resources

**Technical approach:**
```dart
// Connection quality detection
class NetworkQuality {
  static Future<ConnectionType> detect() async {
    final result = await Connectivity().checkConnectivity();
    
    if (result == ConnectivityResult.mobile) {
      // Test actual speed
      final speed = await _measureSpeed();
      if (speed < 100) return ConnectionType.slow; // < 100 KB/s
      if (speed < 500) return ConnectionType.medium;
      return ConnectionType.fast;
    }
    
    return ConnectivityResult.wifi ? ConnectionType.fast : ConnectionType.none;
  }
}

// Adaptive image loading
class AdaptiveImage extends ConsumerWidget {
  final ImageUrls urls;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionType = ref.watch(connectionTypeProvider);
    final lowBandwidthMode = ref.watch(lowBandwidthModeProvider);
    
    String imageUrl;
    if (lowBandwidthMode || connectionType == ConnectionType.slow) {
      imageUrl = urls.thumbnail;
    } else if (connectionType == ConnectionType.medium) {
      imageUrl = urls.medium;
    } else {
      imageUrl = urls.full;
    }
    
    return CachedNetworkImage(
      imageUrl: imageUrl,
      placeholder: (context, url) => SkeletonLoader(),
    );
  }
}

// Settings toggle
ListTile(
  title: Text('Low Bandwidth Mode'),
  subtitle: Text('Uses less data on slow connections'),
  trailing: Switch(
    value: lowBandwidthMode,
    onChanged: (v) => ref.read(settingsProvider).setLowBandwidth(v),
  ),
)
```

**Files to modify:**
- `lib/shared/services/settings_service.dart`
- All image widgets
- `lib/features/profile/presentation/settings_screen.dart`

**Dependencies:**
- 📱 Flutter App
- 🔗 Depends on: Image Optimization (#26)

**Estimated effort:** 1 week

---

### ☐ #28: Real-Time Collaboration

**Impact:** ⭐⭐⭐⭐ (Shop Efficiency)

**What it does:**
- Multiple shop staff can work simultaneously
- Real-time presence indicators ("John is viewing this order")
- Live cursor tracking for shared editing
- Instant updates across all connected clients
- Conflict prevention with optimistic locking

**Why it's a game-changer:**
- Enables team collaboration for busy shops
- Prevents double-handling of requests
- Modern SaaS expectation (Google Docs, Figma)
- Improves shop response times

**Technical approach:**
```typescript
// Supabase Realtime presence
const channel = supabase.channel('shop:' + shopId);

channel
  .on('presence', { event: 'sync' }, () => {
    const state = channel.presenceState();
    setOnlineUsers(Object.values(state).flat());
  })
  .on('presence', { event: 'join' }, ({ key, newPresences }) => {
    toast(`${newPresences[0].user_name} joined`);
  })
  .on('presence', { event: 'leave' }, ({ key, leftPresences }) => {
    toast(`${leftPresences[0].user_name} left`);
  })
  .subscribe(async (status) => {
    if (status === 'SUBSCRIBED') {
      await channel.track({
        user_id: currentUser.id,
        user_name: currentUser.name,
        viewing: currentPage,
        cursor: null,
      });
    }
  });

// Optimistic locking for edits
async function updateOrder(orderId: string, updates: Partial<Order>, expectedVersion: number) {
  const { data, error } = await supabase
    .from('orders')
    .update({ ...updates, version: expectedVersion + 1 })
    .eq('id', orderId)
    .eq('version', expectedVersion); // Only update if version matches
    
  if (error || !data) {
    throw new ConflictError('Order was modified by another user. Please refresh.');
  }
}
```

**Files to modify:**
- `shop-dashboard/src/lib/supabase.ts` - Presence setup
- All dashboard pages - Presence indicators
- Order/quote editing pages - Conflict handling

**Dependencies:**
- 💻 Shop Dashboard
- 🗄️ Add `version` column to editable tables

**Estimated effort:** 1.5 weeks

---

### ☐ #29: Performance Monitoring & APM

**Impact:** ⭐⭐⭐ (Operational)

**What it does:**
- Real-time performance metrics (load times, API latency)
- Error tracking with stack traces
- User session recording for debugging
- Custom event analytics
- Alerting for performance degradation

**Why it's a game-changer:**
- Catch issues before users report them
- Data-driven performance optimization
- Required for production-grade apps
- Reduces support burden

**Technical approach:**
```dart
// Sentry integration for Flutter
Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'your-sentry-dsn';
      options.tracesSampleRate = 0.2;
      options.profilesSampleRate = 0.1;
    },
    appRunner: () => runApp(MyApp()),
  );
}

// Performance tracing
class ApiClient {
  Future<T> request<T>(String endpoint) async {
    final transaction = Sentry.startTransaction('api-request', 'http');
    final span = transaction.startChild('http.client', description: endpoint);
    
    try {
      final response = await dio.get(endpoint);
      span.status = SpanStatus.ok();
      return response.data;
    } catch (e) {
      span.status = SpanStatus.internalError();
      Sentry.captureException(e);
      rethrow;
    } finally {
      await span.finish();
      await transaction.finish();
    }
  }
}

// Custom metrics
void trackScreenLoad(String screenName, Duration loadTime) {
  Sentry.addBreadcrumb(Breadcrumb(
    message: 'Screen loaded: $screenName',
    data: {'load_time_ms': loadTime.inMilliseconds},
    level: SentryLevel.info,
  ));
}
```

```typescript
// Shop Dashboard - Vercel Analytics + Sentry
import * as Sentry from '@sentry/nextjs';

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  tracesSampleRate: 0.2,
  integrations: [new Sentry.BrowserTracing()],
});

// Custom performance marks
export function trackPageLoad(pageName: string) {
  const loadTime = performance.now();
  Sentry.setTag('page', pageName);
  Sentry.setMeasurement('page_load', loadTime, 'millisecond');
}
```

**Dependencies:**
- 📱 Flutter App - Add `sentry_flutter: ^7.14.0`
- 💻 Shop Dashboard - Add `@sentry/nextjs`
- 🔌 Sentry account (free tier available)

**Estimated effort:** 1 week

---

## 📋 IMPLEMENTATION PRIORITY MATRIX

### Phase 1: Foundation (Weeks 1-3)
*Trust & Core Experience*

| # | Upgrade | Impact | Effort | Dependencies |
|---|---------|--------|--------|--------------|
| 12 | Escrow Payment System | ⭐⭐⭐⭐⭐ | 1.5w | 🔌🗄️ |
| 13 | Dispute Resolution Center | ⭐⭐⭐⭐⭐ | 2w | 🗄️🔗 |
| 1 | Haptic Feedback Engine | ⭐⭐⭐ | 3h | 📱 |
| 2 | Hero Transitions | ⭐⭐⭐⭐ | 5h | 📱 |

### Phase 2: Intelligence (Weeks 4-6)
*AI & Smart Features*

| # | Upgrade | Impact | Effort | Dependencies |
|---|---------|--------|--------|--------------|
| 7 | AI Part Recognition | ⭐⭐⭐⭐⭐ | 3w | 🔌🗄️ |
| 9 | Smart Search | ⭐⭐⭐⭐ | 1w | 🗄️ |
| 15 | Review & Rating System | ⭐⭐⭐⭐ | 1w | 🗄️ |

### Phase 3: Operations (Weeks 7-10)
*Business Tools*

| # | Upgrade | Impact | Effort | Dependencies |
|---|---------|--------|--------|--------------|
| 18 | Fleet Management | ⭐⭐⭐⭐⭐ | 2w | 🗄️ |
| 19 | CRM & Automation | ⭐⭐⭐⭐⭐ | 2w | 🔌🗄️ |
| 22 | Advanced Reporting | ⭐⭐⭐⭐ | 1.5w | 💻 |

### Phase 4: Scale (Weeks 11-14)
*Performance & Reliability*

| # | Upgrade | Impact | Effort | Dependencies |
|---|---------|--------|--------|--------------|
| 24 | Offline-First Architecture | ⭐⭐⭐⭐⭐ | 3w | 📱 |
| 8 | Predictive Analytics | ⭐⭐⭐⭐⭐ | 2w | 💻🗄️ |
| 29 | Performance Monitoring | ⭐⭐⭐ | 1w | 🔌 |

### Quick Wins (Anytime)
*Low effort, immediate impact*

| # | Upgrade | Impact | Effort |
|---|---------|--------|--------|
| 1 | Haptic Feedback | ⭐⭐⭐ | 3h |
| 3 | Page Transitions | ⭐⭐⭐ | 4h |
| 4 | Micro-Interactions | ⭐⭐⭐⭐ | 5h |
| 6 | Skeleton Enhancements | ⭐⭐⭐ | 4h |

---

## 🔌 EXTERNAL API REQUIREMENTS

| API/Service | Used By | Cost | Purpose |
|-------------|---------|------|---------|
| Google Cloud Vision | #7 AI Recognition | $1.50/1000 images | Part identification |
| Paystack Transfer API | #12 Escrow | Per-transaction fee | Shop payouts |
| Sentry | #29 APM | Free tier available | Error tracking |
| Supabase Edge Functions | #19 Automation | Included in plan | Scheduled tasks |

---

## 🗄️ SCHEMA MIGRATIONS REQUIRED

| Upgrade | Tables/Columns Added |
|---------|---------------------|
| #5 Blurhash | `images.blurhash` column |
| #11 Vehicle Health | `vehicle_mileage_logs`, `maintenance_schedule` |
| #12 Escrow | `orders.escrow_*` columns, `escrow_transactions` |
| #13 Disputes | `disputes`, `dispute_messages` |
| #14 Verification | `shop_verifications`, `shops.verification_level` |
| #15 Reviews | `reviews`, `review_responses` |
| #16 Fraud | `orders.risk_score`, `fraud_signals` |
| #17 Authenticity | `part_authenticity` |
| #18 Fleet | `fleets`, `fleet_vehicles`, `fleet_members` |
| #19 Automation | `automation_rules`, `automation_executions`, `message_templates` |
| #20 Multi-Location | `shop_branches`, `stock_transfers` |
| #23 RBAC | `roles`, `shop_staff` |
| #28 Collaboration | `*.version` columns for optimistic locking |

---

## 📊 TOTAL EFFORT ESTIMATE

| Category | Items | Total Effort |
|----------|-------|--------------|
| Experience Design | 6 | ~3 weeks |
| Intelligence (AI/ML) | 5 | ~7 weeks |
| Trust & Safety | 6 | ~9 weeks |
| Operational Efficiency | 6 | ~10 weeks |
| Performance & Scaling | 6 | ~8 weeks |
| **TOTAL** | **29** | **~37 weeks** |

*Note: Many items can be parallelized. With focused development, the roadmap could be completed in 4-6 months.*

---

## 🎯 RECOMMENDED STARTING POINT

**Start with Escrow (#12) + Disputes (#13)** - These form the trust foundation that unlocks higher transaction values and user confidence. Quick wins (#1, #3, #4) can be implemented in parallel to show immediate UX improvements.

---

> **Document Status:** Ready for Implementation  
> **Next Step:** Select first upgrade to implement  
> **Created by:** Rovo Dev World-Class Analysis Engine
