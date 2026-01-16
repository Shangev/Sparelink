# SpareLink Technical Documentation

**Last Updated:** January 16, 2026  
**Version:** 2.0  
**Last Commit:** January 16, 2026 - Documentation update and full project commit

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [Database Schema](#database-schema)
4. [Flutter Mobile App (Mechanic App)](#flutter-mobile-app)
5. [Next.js Shop Dashboard](#nextjs-shop-dashboard)
6. [Key Data Flows](#key-data-flows)
7. [Known Issues & Fixes Applied](#known-issues--fixes-applied)
8. [Environment Setup](#environment-setup)
9. [Common SQL Commands](#common-sql-commands)

---

## Project Overview

**SpareLink** is an auto parts marketplace connecting **mechanics** (who need spare parts) with **spare parts shops** (who sell them). Think of it as "Uber Eats for car parts."

### Core User Flows:
1. **Mechanic** creates a part request via the Flutter app
2. **Shop owners** see requests and send quotes via the Shop Dashboard
3. **Mechanic** receives offer notifications, views quotes, and accepts one
4. **Order** is created and tracked until delivery

### Target Market:
- **Location:** South Africa
- **Currency:** ZAR (South African Rand)
- **Delivery:** Same day delivery with fixed R140 delivery fee

---

## System Architecture

```
┌─────────────────────────┐     ┌─────────────────────────┐
│   Flutter Mobile App    │     │   Next.js Shop Dashboard│
│   (Mechanics)           │     │   (Shop Owners)         │
│   - iOS / Android / Web │     │   - Web Only            │
└───────────┬─────────────┘     └───────────┬─────────────┘
            │                               │
            └───────────┬───────────────────┘
                        │
                        ▼
            ┌───────────────────────┐
            │      Supabase         │
            │  - PostgreSQL DB      │
            │  - Auth (Phone OTP)   │
            │  - Realtime           │
            │  - Storage            │
            └───────────────────────┘
```

---

## Database Schema

### Core Tables

#### `profiles`
User profiles for both mechanics and shop owners.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid (PK) | Links to Supabase auth.users |
| full_name | text | User's full name |
| phone | text | Phone number |
| role | text | 'mechanic' or 'shop' |
| suburb | text | User's suburb/area |
| street_address | text | Street address |
| city | text | City |
| postal_code | text | Postal code |
| created_at | timestamptz | Account creation time |
| updated_at | timestamptz | Last update time |

#### `shops`
Shop information for spare parts stores.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid (PK) | Shop ID |
| owner_id | uuid (FK) | Links to profiles.id |
| name | text | Shop name |
| phone | text | Shop phone |
| email | text | Shop email |
| address | text | Shop address |
| suburb | text | Shop suburb |
| rating | decimal | Average rating (1-5) |
| review_count | integer | Number of reviews |
| is_verified | boolean | Verification status |
| working_hours | jsonb | Operating hours per day |
| delivery_enabled | boolean | Offers delivery |
| delivery_radius_km | integer | Delivery radius |
| delivery_fee | decimal | Delivery fee (deprecated - now fixed R140) |
| created_at | timestamptz | Creation time |

#### `part_requests`
Part requests created by mechanics.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid (PK) | Request ID |
| mechanic_id | uuid (FK) | Links to profiles.id |
| vehicle_make | text | e.g., "Volkswagen" |
| vehicle_model | text | e.g., "Tiguan" |
| vehicle_year | integer | e.g., 2019 |
| part_category | text | e.g., "Brakes" |
| description | text | Additional details |
| vin | text | Vehicle VIN (optional) |
| engine_number | text | Engine number (optional) |
| image_urls | text[] | Array of image URLs |
| status | request_status ENUM | 'pending', 'offered', 'accepted', 'completed', 'cancelled' |
| offer_count | integer | Number of offers received |
| created_at | timestamptz | Creation time |
| updated_at | timestamptz | Last update time |

#### `offers`
Quotes from shops for part requests.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid (PK) | Offer ID |
| request_id | uuid (FK) | Links to part_requests.id |
| shop_id | uuid (FK) | Links to shops.id |
| price_cents | integer | Part price in cents (e.g., 15000 = R150) |
| delivery_fee_cents | integer | Delivery fee in cents (default 14000 = R140) |
| eta_minutes | integer | Estimated delivery time in minutes |
| stock_status | stock_status ENUM | 'in_stock', 'available', 'order_in' |
| part_condition | text | 'new', 'used', 'refurbished' |
| warranty | text | e.g., "6 months", "12 months", null |
| message | text | Additional notes from shop |
| status | offer_status ENUM | 'pending', 'accepted', 'rejected', 'expired' |
| created_at | timestamptz | Creation time |
| updated_at | timestamptz | Last update time |

#### `orders`
Orders created when a mechanic accepts an offer.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid (PK) | Order ID |
| request_id | uuid (FK) | Links to part_requests.id |
| offer_id | uuid (FK) | Links to offers.id |
| total_cents | integer | Total price in cents |
| status | order_status ENUM | 'confirmed', 'processing', 'shipped', 'delivered' |
| delivery_destination | delivery_destination ENUM | 'user' or 'mechanic' |
| delivery_address | text | Delivery address |
| driver_name | text | Assigned driver name |
| driver_phone | text | Driver phone number |
| created_at | timestamptz | Creation time |

#### `notifications`
Push notifications for users.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid (PK) | Notification ID |
| user_id | uuid (FK) | Links to profiles.id |
| type | text | 'quote', 'order', 'message', 'system' |
| title | text | Notification title |
| body | text | Notification body |
| reference_id | uuid | Related entity ID (request, order, etc.) |
| read | boolean | Read status |
| created_at | timestamptz | Creation time |

#### `conversations`
Chat threads between mechanics and shops.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid (PK) | Conversation ID |
| request_id | uuid (FK) | Links to part_requests.id |
| mechanic_id | uuid (FK) | Links to profiles.id |
| shop_id | uuid (FK) | Links to shops.id |
| created_at | timestamptz | Creation time |

#### `messages`
Individual chat messages.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid (PK) | Message ID |
| conversation_id | uuid (FK) | Links to conversations.id |
| sender_id | uuid (FK) | Links to profiles.id |
| text | text | Message content |
| sent_at | timestamptz | Send time |

#### `deliveries`
Delivery tracking information.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid (PK) | Delivery ID |
| order_id | uuid (FK) | Links to orders.id |
| driver_id | uuid (FK) | Links to drivers.id |
| shop_id | uuid (FK) | Links to shops.id |
| mechanic_id | uuid (FK) | Links to profiles.id |
| pickup_address | text | Shop address |
| delivery_address | text | Delivery address |
| status | text | 'pending', 'picked_up', 'in_transit', 'delivered' |
| pickup_time | timestamptz | Actual pickup time |
| delivery_time | timestamptz | Actual delivery time |
| notes | text | Delivery notes |
| created_at | timestamptz | Creation time |

#### `drivers`
Delivery drivers (linked to shops).

| Column | Type | Description |
|--------|------|-------------|
| id | uuid (PK) | Driver ID |
| user_id | uuid (FK) | Links to profiles.id |
| shop_id | uuid (FK) | Links to shops.id |
| full_name | text | Driver name |
| phone | text | Phone number |
| vehicle_type | text | Vehicle type |
| vehicle_registration | text | Vehicle registration |
| is_active | boolean | Active status |
| is_available | boolean | Currently available |
| created_at | timestamptz | Creation time |

### ENUM Types

```sql
-- Request status
CREATE TYPE request_status AS ENUM ('pending', 'offered', 'accepted', 'completed', 'cancelled');

-- Offer status
CREATE TYPE offer_status AS ENUM ('pending', 'accepted', 'rejected', 'expired');

-- Order status
CREATE TYPE order_status AS ENUM ('confirmed', 'processing', 'shipped', 'delivered');

-- Delivery destination
CREATE TYPE delivery_destination AS ENUM ('user', 'mechanic');

-- Stock status
CREATE TYPE stock_status AS ENUM ('in_stock', 'available', 'order_in');
```

### Database Triggers

#### `on_offer_change` (on offers table)
- **Event:** INSERT, DELETE
- **Function:** `update_offer_count()`
- **Purpose:** Updates `offer_count` in `part_requests` when offers are added/removed

#### `update_offers_updated_at` (on offers table)
- **Event:** UPDATE
- **Function:** `update_updated_at_column()`
- **Purpose:** Auto-updates `updated_at` timestamp

#### `update_part_requests_updated_at` (on part_requests table)
- **Event:** UPDATE
- **Function:** `update_updated_at()`
- **Purpose:** Auto-updates `updated_at` timestamp

---

## Flutter Mobile App

### Location
```
sparelink-flutter/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── constants/
│   │   ├── router/app_router.dart
│   │   └── theme/app_theme.dart
│   ├── features/
│   │   ├── auth/
│   │   ├── camera/
│   │   ├── chat/
│   │   ├── home/
│   │   ├── marketplace/
│   │   ├── notifications/
│   │   ├── orders/
│   │   ├── profile/
│   │   └── requests/
│   └── shared/
│       ├── models/
│       ├── services/
│       └── widgets/
```

### Tech Stack
- **Framework:** Flutter
- **State Management:** Riverpod
- **Navigation:** GoRouter
- **Backend:** Supabase
- **Icons:** Lucide Icons

### Key Screens

| Screen | Path | Description |
|--------|------|-------------|
| Login | `/login` | Phone + OTP authentication |
| Register | `/register` | New user registration |
| Home | `/home` | Main dashboard |
| Request Part | `/request-part` | Multi-step part request wizard |
| My Requests | `/my-requests` | List of user's requests |
| Marketplace | `/marketplace/:requestId` | View offers for a request |
| Shop Detail | `/shop/:shopId` | View offer details & confirm order |
| Order Tracking | `/order/:orderId` | Real-time order tracking |
| Notifications | `/notifications` | View all notifications |
| Chats | `/chats` | Chat list |
| Profile | `/profile` | User profile |

### Key Services

#### `SupabaseService` (`lib/shared/services/supabase_service.dart`)
Main service for all Supabase interactions:
- `signInWithOtp()` - Send OTP to phone
- `verifyOtp()` - Verify OTP code
- `createPartRequest()` - Create new part request
- `getMechanicRequests()` - Get user's requests
- `getOffersForRequest()` - Get offers for a request
- `acceptOffer()` - Accept offer and create order
- `getMechanicOrders()` - Get user's orders
- `getUserNotifications()` - Get notifications
- `sendMessage()` - Send chat message

### Key Models

#### `Offer` (`lib/shared/models/marketplace.dart`)
```dart
class Offer {
  final String id;
  final String requestId;
  final String shopId;
  final int priceCents;
  final int deliveryFeeCents;  // Default 14000 (R140)
  final int? etaMinutes;
  final StockStatus stockStatus;
  final String? partCondition;
  final String? warranty;
  final String? message;
  final OfferStatus status;
  final Shop? shop;
  
  // Computed properties
  double get priceRands => priceCents / 100;
  double get deliveryFeeRands => deliveryFeeCents / 100;
  double get totalRands => (priceCents + deliveryFeeCents) / 100;
  String get formattedPrice => 'R ${priceRands.toStringAsFixed(2)}';
  String get formattedTotal => 'R ${totalRands.toStringAsFixed(2)}';
}
```

---

## Next.js Shop Dashboard

### Location
```
sparelink-flutter/shop-dashboard/
├── src/
│   ├── app/
│   │   ├── globals.css
│   │   ├── layout.tsx
│   │   ├── page.tsx
│   │   ├── login/page.tsx
│   │   └── dashboard/
│   │       ├── layout.tsx
│   │       ├── page.tsx
│   │       ├── requests/page.tsx
│   │       ├── quotes/page.tsx
│   │       ├── orders/page.tsx
│   │       └── settings/page.tsx
│   ├── components/
│   └── lib/
│       └── supabase.ts
```

### Tech Stack
- **Framework:** Next.js 14
- **Styling:** Tailwind CSS
- **Backend:** Supabase
- **Icons:** Lucide React

### Key Pages

| Page | Path | Description |
|------|------|-------------|
| Login | `/login` | Shop owner authentication |
| Dashboard | `/dashboard` | Overview with stats |
| Requests | `/dashboard/requests` | Browse & quote on part requests |
| Quotes | `/dashboard/quotes` | View sent quotes & status |
| Orders | `/dashboard/orders` | Manage orders |
| Settings | `/dashboard/settings` | Shop profile & settings |

### Quote Form Fields
When sending a quote, shops fill in:
- **Part Price (ZAR)** - Required
- **Part Condition** - New / Used / Refurbished
- **Warranty** - No Warranty / 6 Months / 12 Months
- **Message/Notes** - Optional

**Fixed values:**
- Delivery Fee: R140 (auto-added)
- Delivery Time: Same Day

---

## Key Data Flows

### 1. Part Request Flow
```
Mechanic (Flutter) → Creates Request → part_requests table
                                           ↓
Shop Dashboard sees request → notifications table (optional)
                                           ↓
Shop sends quote → offers table + notifications table
                                           ↓
Mechanic sees notification → Marketplace screen
                                           ↓
Mechanic accepts offer → orders table
                         ↓ (also updates)
                    offers.status = 'accepted'
                    part_requests.status = 'accepted'
```

### 2. Price Calculation
```
Part Price (shop enters)     = R150.00 (stored as 15000 cents)
+ Delivery Fee (fixed)       = R140.00 (stored as 14000 cents)
─────────────────────────────────────────────────────────────
= Total Price                = R290.00 (stored as 29000 cents)
```

### 3. Status Transitions

**Part Request Status:**
```
pending → offered (when first offer received)
        → accepted (when offer accepted)
        → completed (when delivered)
        → cancelled (if cancelled)
```

**Offer Status:**
```
pending → accepted (when mechanic accepts)
        → rejected (when another offer accepted, or declined)
        → expired (after timeout)
```

**Order Status:**
```
confirmed → processing → shipped → delivered
```

---

## Known Issues & Fixes Applied

### Issue 1: Offer Insert Failing
**Problem:** Shop Dashboard couldn't save quotes - wrong column names.

**Fix Applied:**
- Changed `price` → `price_cents` (integer, in cents)
- Changed `notes` → `message`
- Changed `delivery_days` → `eta_minutes`
- Added `delivery_fee_cents`, `part_condition`, `warranty`

### Issue 2: Missing ENUM Values
**Problem:** `delivery_destination` ENUM missing 'user' and 'mechanic'.

**Fix Applied:**
```sql
ALTER TYPE delivery_destination ADD VALUE IF NOT EXISTS 'user';
ALTER TYPE delivery_destination ADD VALUE IF NOT EXISTS 'mechanic';
```

### Issue 3: Missing `updated_at` Column
**Problem:** Trigger on `part_requests` referenced non-existent `updated_at` column.

**Fix Applied:**
```sql
ALTER TABLE part_requests ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
```

### Issue 4: Offer Status Not Updating
**Problem:** When order placed, offer status stayed "pending".

**Fix Applied:** Updated `acceptOffer()` function in Flutter to:
1. Return response from update to verify success
2. Throw error if update fails
3. Also reject other pending offers for same request

### Issue 5: Price Display Wrong
**Problem:** UI showing part price instead of total price.

**Fix Applied:** Changed `offer.formattedPrice` → `offer.formattedTotal` in marketplace screen.

---

## Environment Setup

### Flutter App

1. **Prerequisites:**
   - Flutter SDK 3.x
   - Dart SDK
   - Chrome (for web development)

2. **Environment Variables:**
   Located in `lib/core/constants/supabase_constants.dart`:
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_URL';
   static const String supabaseAnonKey = 'YOUR_ANON_KEY';
   ```

3. **Run Commands:**
   ```bash
   # Install dependencies
   flutter pub get
   
   # Run on Chrome (web)
   flutter run -d chrome
   
   # Run on connected device
   flutter run
   ```

### Shop Dashboard

1. **Prerequisites:**
   - Node.js 18+
   - npm or yarn

2. **Environment Variables:**
   Located in `shop-dashboard/.env.local`:
   ```env
   NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
   ```

3. **Run Commands:**
   ```bash
   cd shop-dashboard
   
   # Install dependencies
   npm install
   
   # Run development server
   npm run dev
   ```
   
   Dashboard runs on: http://localhost:3000

---

## Common SQL Commands

### View Recent Data

```sql
-- View recent part requests
SELECT id, vehicle_make, vehicle_model, part_category, status, created_at 
FROM part_requests 
ORDER BY created_at DESC 
LIMIT 10;

-- View recent offers
SELECT id, request_id, shop_id, price_cents, status, created_at 
FROM offers 
ORDER BY created_at DESC 
LIMIT 10;

-- View recent orders
SELECT id, offer_id, total_cents, status, delivery_destination, created_at 
FROM orders 
ORDER BY created_at DESC 
LIMIT 10;

-- View notifications
SELECT id, user_id, type, title, read, created_at 
FROM notifications 
ORDER BY created_at DESC 
LIMIT 10;
```

### Fix Common Issues

```sql
-- Update offer status to accepted for offers that have orders
UPDATE offers 
SET status = 'accepted' 
WHERE id IN (SELECT offer_id FROM orders);

-- Update request status for requests that have orders
UPDATE part_requests 
SET status = 'accepted' 
WHERE id IN (SELECT request_id FROM orders);

-- Clean up test notifications (keep only offer notifications)
DELETE FROM notifications WHERE type != 'quote';

-- Add missing ENUM values
ALTER TYPE delivery_destination ADD VALUE IF NOT EXISTS 'user';
ALTER TYPE delivery_destination ADD VALUE IF NOT EXISTS 'mechanic';

-- Add missing columns
ALTER TABLE part_requests ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE offers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
```

### Check ENUM Values

```sql
-- Check offer_status values
SELECT enum_range(NULL::offer_status);

-- Check order_status values
SELECT enum_range(NULL::order_status);

-- Check delivery_destination values
SELECT enum_range(NULL::delivery_destination);

-- Check request_status values
SELECT enum_range(NULL::request_status);
```

### Trigger Management

```sql
-- View triggers on a table
SELECT trigger_name, event_manipulation, action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'offers';

-- Disable triggers (for debugging)
ALTER TABLE offers DISABLE TRIGGER ALL;

-- Re-enable triggers
ALTER TABLE offers ENABLE TRIGGER ALL;
```

---

## Development History & Changelog

### Project Timeline

| Date | Milestone | Description |
|------|-----------|-------------|
| Dec 4, 2025 | Initial Commit | SpareLink React Native UI screens (10+ screens) |
| Dec 4, 2025 | Step 1 Complete | Project setup with documentation |
| Dec 4, 2025 | Step 2 Complete | Drizzle ORM and APIs integrated |
| Dec 4, 2025 | Step 3 Complete | Backend 100% operational, all APIs tested |
| Dec 6, 2025 | Flutter Migration | SpareLink mobile app migrated to Flutter, fully functional |
| Dec 6, 2025 | Camera Flow | Complete camera flow with vehicle details |
| Dec 6, 2025 | Chats Feature | ChatsScreen added with navigation (frontend only) |
| Dec 6, 2025 | Navigation Fix | Migrated to proper React Navigation stack |
| Jan 16, 2026 | Documentation | Comprehensive technical documentation update |

### Last Development Session (December 6, 2025)

The last significant development work included:

1. **Flutter Migration Complete** - The app was migrated from React Native (Expo) to Flutter
2. **Camera Flow Implementation** - Full camera functionality for capturing vehicle/part images
3. **ChatsScreen Added** - Chat interface implemented (frontend only, backend integration pending)
4. **Navigation Stack** - Proper React Navigation stack implemented
5. **Code Cleanup** - Console.log statements removed, TODO items documented

### Pending Work / TODOs

Based on the last session, the following items are pending:

1. **Chat Backend Integration** - ChatsScreen is frontend only; needs Supabase realtime integration
2. **Push Notifications** - Firebase Cloud Messaging setup for real push notifications
3. **Image Upload Optimization** - Compress images before upload to Supabase Storage
4. **Offline Support** - Cache requests locally when offline
5. **Performance Analytics** - Shop dashboard performance metrics (response rate, acceptance rate)

---

## File Structure Overview

### Flutter Mobile App (`sparelink-flutter/`)

```
sparelink-flutter/
├── lib/
│   ├── main.dart                          # App entry point, Supabase init
│   ├── core/
│   │   ├── constants/
│   │   │   ├── api_constants.dart         # API endpoint constants
│   │   │   └── supabase_constants.dart    # Supabase URL & keys
│   │   ├── router/
│   │   │   └── app_router.dart            # GoRouter configuration (20+ routes)
│   │   └── theme/
│   │       └── app_theme.dart             # Dark theme configuration
│   ├── features/
│   │   ├── auth/                          # Authentication screens
│   │   │   └── presentation/screens/
│   │   │       ├── login_screen.dart      # Phone + OTP login
│   │   │       ├── register_screen.dart   # New user registration
│   │   │       └── complete_profile_screen.dart
│   │   ├── camera/                        # Camera functionality
│   │   │   └── presentation/
│   │   │       ├── camera_screen.dart
│   │   │       ├── camera_screen_full.dart # Main camera implementation
│   │   │       └── vehicle_form_screen.dart
│   │   ├── chat/                          # Chat functionality
│   │   │   └── presentation/
│   │   │       ├── chats_screen.dart      # Chat list
│   │   │       ├── individual_chat_screen.dart
│   │   │       └── request_chat_screen.dart
│   │   ├── home/                          # Home dashboard
│   │   │   └── presentation/
│   │   │       └── home_screen.dart
│   │   ├── marketplace/                   # Offer viewing
│   │   │   └── presentation/
│   │   │       ├── marketplace_results_screen.dart
│   │   │       └── shop_detail_screen.dart
│   │   ├── notifications/
│   │   │   └── presentation/
│   │   │       └── notifications_screen.dart
│   │   ├── orders/                        # Order tracking
│   │   │   └── presentation/
│   │   │       └── order_tracking_screen.dart
│   │   ├── profile/                       # User profile
│   │   │   └── presentation/
│   │   │       ├── profile_screen.dart
│   │   │       ├── edit_profile_screen.dart
│   │   │       ├── settings_screen.dart
│   │   │       ├── help_support_screen.dart
│   │   │       └── about_screen.dart
│   │   └── requests/                      # Part requests
│   │       └── presentation/
│   │           ├── my_requests_screen.dart
│   │           ├── request_part_screen.dart  # Multi-step wizard
│   │           └── request_chats_screen.dart
│   └── shared/
│       ├── models/
│       │   ├── marketplace.dart           # Offer, Shop, Order models
│       │   └── vehicle.dart               # Vehicle data models
│       ├── services/
│       │   ├── api_service.dart
│       │   ├── storage_service.dart       # Local storage
│       │   └── supabase_service.dart      # Main Supabase API service (800+ lines)
│       └── widgets/
│           ├── dropdown_modal.dart
│           └── sparelink_logo.dart
├── shop-dashboard/                        # Next.js shop dashboard
├── pubspec.yaml                           # Flutter dependencies
└── SPARELINK_TECHNICAL_DOCUMENTATION.md   # This file
```

### Shop Dashboard (`shop-dashboard/`)

```
shop-dashboard/
├── src/
│   ├── app/
│   │   ├── globals.css                    # Tailwind + custom styles
│   │   ├── layout.tsx                     # Root layout with auth check
│   │   ├── page.tsx                       # Redirect to dashboard
│   │   ├── login/
│   │   │   └── page.tsx                   # Shop owner login
│   │   └── dashboard/
│   │       ├── layout.tsx                 # Dashboard sidebar layout
│   │       ├── page.tsx                   # Dashboard overview with stats
│   │       ├── requests/
│   │       │   └── page.tsx               # Browse & quote on requests
│   │       ├── quotes/
│   │       │   └── page.tsx               # View sent quotes
│   │       ├── orders/
│   │       │   └── page.tsx               # Manage orders
│   │       ├── chats/
│   │       │   └── page.tsx               # Chat with mechanics
│   │       └── settings/
│   │           └── page.tsx               # Shop settings
│   ├── components/
│   │   └── ui/                            # Reusable UI components
│   └── lib/
│       └── supabase.ts                    # Supabase client config
├── .env.local                             # Environment variables
├── package.json                           # Node dependencies
├── tailwind.config.js                     # Tailwind configuration
└── next.config.js                         # Next.js configuration
```

---

## Running the Applications

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Flutter SDK | 3.x+ | Mobile app development |
| Node.js | 18+ | Shop dashboard |
| Chrome | Latest | Web testing |
| Git | Latest | Version control |

### Flutter Mobile App

```bash
# Navigate to Flutter project
cd sparelink-flutter

# Install dependencies
flutter pub get

# Run on Chrome (web)
flutter run -d chrome

# Run on connected Android device
flutter run -d android

# Run on Windows desktop
flutter run -d windows

# Check available devices
flutter devices
```

**Default Port:** Flutter web runs on `http://localhost:3000` (or next available)

### Shop Dashboard (Next.js)

```bash
# Navigate to shop dashboard
cd sparelink-flutter/shop-dashboard

# Install dependencies
npm install

# Run development server
npm run dev
```

**Default Port:** `http://localhost:3000`

**Note:** If both apps need to run simultaneously, start the shop dashboard first (it will use port 3000), then Flutter web will auto-select the next available port.

---

## Authentication Flow

### Mobile App (Mechanics)

1. User enters phone number on Login screen
2. App calls `signInWithOtp()` → Supabase sends SMS with OTP
3. User enters 6-digit OTP
4. App calls `verifyOtp()` → Supabase validates and returns session
5. If new user → redirect to Complete Profile screen
6. If existing user → redirect to Home screen

### Shop Dashboard (Shop Owners)

1. Shop owner enters email/phone on Login page
2. Supabase authenticates and returns session
3. App checks if user has a linked shop in `shops` table
4. If shop exists → redirect to Dashboard
5. If no shop → show "Create Shop" flow

### Test Accounts

For development, use Supabase test phone numbers:
- Phone: `+27123456789` (any test number configured in Supabase)
- OTP: `123456` (pre-configured test OTP)

---

## API Reference (SupabaseService)

### Authentication

| Method | Parameters | Description |
|--------|------------|-------------|
| `signInWithOtp()` | `phone` | Send OTP to phone number |
| `verifyOtp()` | `phone`, `otp` | Verify OTP and create session |
| `signOut()` | - | Sign out current user |

### Profiles

| Method | Parameters | Description |
|--------|------------|-------------|
| `getProfile()` | `userId` | Get user profile data |
| `updateProfile()` | `userId`, `fullName`, `phone`, `suburb`, etc. | Update profile |

### Part Requests

| Method | Parameters | Description |
|--------|------------|-------------|
| `createPartRequest()` | `vehicleMake`, `vehicleModel`, `vehicleYear`, `partCategory`, `description`, `imageUrls` | Create new request |
| `getMechanicRequests()` | - | Get current user's requests |
| `getRequestDetails()` | `requestId` | Get single request with offers |

### Offers

| Method | Parameters | Description |
|--------|------------|-------------|
| `getOffersForRequest()` | `requestId` | Get all offers for a request |
| `acceptOffer()` | `offerId`, `requestId` | Accept offer and create order |

### Orders

| Method | Parameters | Description |
|--------|------------|-------------|
| `getMechanicOrders()` | - | Get current user's orders |
| `getOrderDetails()` | `orderId` | Get single order with details |

### Notifications

| Method | Parameters | Description |
|--------|------------|-------------|
| `getUserNotifications()` | - | Get user's notifications |
| `markNotificationRead()` | `notificationId` | Mark as read |

---

## Styling & Theming

### Flutter App Theme

- **Primary Color:** Orange accent (`#FF6B35`)
- **Background:** Dark (`#0D0D0D`)
- **Card Background:** `#1A1A1A`
- **Text:** White primary, Gray secondary
- **Font:** System default

### Shop Dashboard Theme

- **Primary Color:** Orange accent (`#FF6B35`)
- **Background:** Dark (`#0D0D0D`)
- **Card Background:** `#1A1A1A`
- **Border Color:** `#2D2D2D`
- **Uses:** Tailwind CSS with custom color palette

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Flutter web not loading | Run `flutter clean` then `flutter pub get` |
| Supabase connection failed | Check `.env` / constants file for correct URL & key |
| OTP not received | Use test phone numbers in development |
| Shop dashboard 404 | Ensure `npm install` completed successfully |
| Camera not working | Check camera permissions in browser |

### Debug Commands

```bash
# Flutter diagnostics
flutter doctor -v

# Clear Flutter cache
flutter clean
flutter pub get

# Check Supabase connection
# In Flutter app, check console for Supabase init logs

# Shop dashboard logs
npm run dev  # Watch console for errors
```

---

## Contact & Support

For questions about this codebase, refer to:
- This documentation
- Code comments in source files
- Supabase dashboard for database inspection
- Previous session reports in parent directory (`../*.md`)

---

## Related Documentation Files

Located in parent directory (`../`):

| File | Description |
|------|-------------|
| `HOW_TO_RUN_FLUTTER_APP.md` | Quick start guide for Flutter app |
| `FLUTTER_MIGRATION_ROADMAP.md` | Migration plan from React Native |
| `WEEK1_COMPLETE_SUMMARY.md` | Week 1 development summary |
| `DAY3_COMPLETION_REPORT.md` | Day 3 completion details |
| `STEP3_COMPLETION_REPORT.md` | Backend completion report |

---

*Document updated by Rovo Dev AI Assistant - January 16, 2026*
