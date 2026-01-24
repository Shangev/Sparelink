# 🏗️ SPARELINK SYSTEM BLUEPRINT

> **Version:** 1.0 (Pass 1/10)  
> **Created:** January 23, 2026  
> **Purpose:** Agent Continuity & Scale-Readiness Documentation  
> **Scope:** Complete codebase architecture mapping

---

## 📋 TABLE OF CONTENTS

1. [Project Hierarchy](#1-project-hierarchy)
2. [Core Anchors (Heart Files)](#2-core-anchors-heart-files)
3. [Data Flow Mapping](#3-data-flow-mapping)
4. [Feature Locality Matrix](#4-feature-locality-matrix)
5. [Complexity Metrics](#5-complexity-metrics)
6. [Directory Deep Dive](#6-directory-deep-dive)
7. [Quick Reference](#7-quick-reference)

---

## 📌 PASS 1 REFINEMENT - DEEP DETAIL EXPANSION

> **Added:** January 23, 2026  
> **Purpose:** Developer-level specifics for agent continuity

---

## 1. PROJECT HIERARCHY

### 1.1 Repository Structure Overview

SpareLink consists of **2 main applications** in a monorepo structure:

```
sparelink-flutter/
├── 📱 Flutter Mechanic App (Root)      # Mobile app for mechanics
├── 💻 shop-dashboard/                   # Next.js shop dashboard
├── 📦 Sparelink/                        # Legacy/reference folder
├── 🌐 public/                           # Flutter web build output
└── 📄 *.sql                             # Database migrations (26 files)
```

### 1.2 Application Summary

| Application | Tech Stack | Target Users | Primary Purpose |
|------------|------------|--------------|-----------------|
| **Flutter Mechanic App** | Flutter 3.x, Riverpod, GoRouter, Supabase | Mechanics | Request parts, accept quotes, track orders, payments |
| **Shop Dashboard** | Next.js 14, TypeScript, Tailwind CSS, Supabase | Shop Owners | Manage requests, create quotes, process orders, analytics |

### 1.3 Root Directory Map

```
📁 sparelink-flutter/
│
├── 📁 lib/                          # Flutter app source code
│   ├── main.dart                    # 🔴 APP ENTRY POINT
│   ├── 📁 core/                     # App-wide configuration
│   │   ├── 📁 constants/            # API keys, env config
│   │   ├── 📁 router/               # Navigation (GoRouter)
│   │   └── 📁 theme/                # Design system
│   ├── 📁 features/                 # Feature modules (Clean Architecture)
│   │   ├── 📁 auth/                 # Authentication screens
│   │   ├── 📁 camera/               # VIN/Part photo capture
│   │   ├── 📁 chat/                 # Real-time messaging
│   │   ├── 📁 home/                 # Dashboard home
│   │   ├── 📁 marketplace/          # Shop browsing, quotes
│   │   ├── 📁 notifications/        # Push notifications
│   │   ├── 📁 onboarding/           # First-time user flow
│   │   ├── 📁 orders/               # Order tracking, history
│   │   ├── 📁 payments/             # Checkout, transactions
│   │   ├── 📁 profile/              # User settings
│   │   └── 📁 requests/             # Part request flow
│   └── 📁 shared/                   # Cross-feature code
│       ├── 📁 models/               # Data models (3 files)
│       ├── 📁 services/             # Business logic (17 files)
│       └── 📁 widgets/              # Reusable UI (10 files)
│
├── 📁 shop-dashboard/               # Next.js shop owner app
│   └── 📁 src/
│       ├── 📁 app/                  # Next.js App Router pages
│       │   ├── layout.tsx           # 🔴 ROOT LAYOUT
│       │   ├── page.tsx             # Landing/redirect page
│       │   ├── 📁 login/            # Shop authentication
│       │   ├── 📁 dashboard/        # Protected shop pages
│       │   │   ├── layout.tsx       # Dashboard shell
│       │   │   ├── page.tsx         # Main dashboard
│       │   │   ├── 📁 requests/     # Incoming part requests
│       │   │   ├── 📁 quotes/       # Quote management
│       │   │   ├── 📁 orders/       # Order fulfillment
│       │   │   ├── 📁 chats/        # Customer messaging
│       │   │   ├── 📁 inventory/    # Stock management
│       │   │   ├── 📁 customers/    # CRM
│       │   │   ├── 📁 analytics/    # Business analytics
│       │   │   └── 📁 settings/     # Shop settings
│       │   └── 📁 api/              # API routes (12 endpoints)
│       ├── 📁 lib/                  # Shared utilities
│       │   └── supabase.ts          # 🔴 SUPABASE CLIENT
│       ├── 📁 components/           # UI components (empty - inline)
│       └── 📁 __tests__/            # Test files
│
├── 📁 android/                      # Android platform code
├── 📁 ios/                          # iOS platform code
├── 📁 web/                          # Web platform config
├── 📁 public/                       # Flutter web build output
├── 📁 assets/                       # Images, fonts, icons
├── 📁 test/                         # Flutter tests
│
├── 📄 pubspec.yaml                  # Flutter dependencies
├── 📄 analysis_options.yaml         # Dart linting rules
├── 📄 vercel.json                   # Vercel deployment config
│
├── 📄 *.sql (26 files)              # Database migrations
├── 📄 SPARELINK_FEATURE_AUDIT.md    # Feature tracking
├── 📄 SPARELINK_WORLD_CLASS_UPGRADES.md # Roadmap
└── 📄 SPARELINK_TECHNICAL_DOCUMENTATION.md # API docs
```

---

## 2. CORE ANCHORS (HEART FILES)

These are the critical files that form the foundation of each application.

### 2.1 Flutter Mechanic App - Heart Files

| File | Lines | Purpose | Key Exports |
|------|-------|---------|-------------|
| `lib/main.dart` | 57 | **App Entry Point** | `SpareLinkApp`, Supabase init, ProviderScope |
| `lib/core/router/app_router.dart` | 494 | **Navigation Hub** | `routerProvider`, `AuthNotifier`, all routes |
| `lib/core/theme/app_theme.dart` | 172 | **Design System** | `AppTheme.darkTheme`, colors, glass decoration |
| `lib/shared/services/supabase_service.dart` | 1,091 | **Backend Gateway** | All Supabase CRUD operations |
| `lib/shared/services/auth_service.dart` | 397 | **Authentication** | Sign in, sign up, OTP, session management |
| `lib/shared/models/marketplace.dart` | 635 | **Core Data Models** | `Shop`, `Offer`, `Order`, `PartRequest` |

### 2.2 Shop Dashboard - Heart Files

| File | Lines | Purpose | Key Exports |
|------|-------|---------|-------------|
| `shop-dashboard/src/app/layout.tsx` | 19 | **Root Layout** | HTML wrapper, metadata |
| `shop-dashboard/src/app/dashboard/layout.tsx` | 214 | **Dashboard Shell** | Sidebar, auth guard, navigation |
| `shop-dashboard/src/lib/supabase.ts` | 325 | **Backend Gateway** | `supabase` client, SSO, session helpers |
| `shop-dashboard/src/app/login/page.tsx` | 292 | **Shop Authentication** | Login form, auth flow |
| `shop-dashboard/src/app/dashboard/page.tsx` | 575 | **Main Dashboard** | Stats cards, recent activity |

### 2.3 Initialization Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUTTER APP STARTUP                          │
├─────────────────────────────────────────────────────────────────┤
│  1. main.dart                                                   │
│     ├── WidgetsFlutterBinding.ensureInitialized()              │
│     ├── Supabase.initialize(url, anonKey)                      │
│     ├── SystemChrome.setPreferredOrientations()                │
│     └── runApp(ProviderScope(child: SpareLinkApp()))           │
│                                                                 │
│  2. SpareLinkApp (ConsumerWidget)                              │
│     ├── ref.watch(routerProvider)                              │
│     └── MaterialApp.router(theme: AppTheme.darkTheme)          │
│                                                                 │
│  3. app_router.dart                                            │
│     ├── AuthNotifier listens to Supabase auth changes          │
│     ├── redirect() guards routes based on auth state           │
│     └── ShellRoute wraps authenticated screens                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    SHOP DASHBOARD STARTUP                       │
├─────────────────────────────────────────────────────────────────┤
│  1. src/app/layout.tsx                                         │
│     └── RootLayout wraps all pages with HTML/body              │
│                                                                 │
│  2. src/app/page.tsx                                           │
│     └── Redirects to /login or /dashboard based on session     │
│                                                                 │
│  3. src/app/dashboard/layout.tsx                               │
│     ├── Checks supabase.auth.getSession()                      │
│     ├── Verifies user role === 'shop_owner'                    │
│     ├── Renders sidebar navigation                             │
│     └── Wraps children with auth context                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. DATA FLOW MAPPING

### 3.1 Supabase Client Locations

| Application | File | Client Instance | Usage |
|-------------|------|-----------------|-------|
| **Flutter App** | `lib/main.dart` | `Supabase.initialize()` | Global initialization |
| **Flutter App** | `lib/shared/services/supabase_service.dart` | `Supabase.instance.client` | All database operations |
| **Flutter App** | `lib/core/constants/supabase_constants.dart` | URL + Anon Key | Configuration |
| **Shop Dashboard** | `shop-dashboard/src/lib/supabase.ts` | `createClient()` | All dashboard operations |

### 3.2 Service Layer Architecture (Flutter)

```
┌─────────────────────────────────────────────────────────────────┐
│                      SERVICE LAYER                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │ UI Screens  │───▶│  Providers  │───▶│  Services   │         │
│  │ (features/) │    │ (Riverpod)  │    │ (shared/)   │         │
│  └─────────────┘    └─────────────┘    └──────┬──────┘         │
│                                               │                 │
│                                               ▼                 │
│                                    ┌─────────────────┐          │
│                                    │ supabase_service│          │
│                                    │     .dart       │          │
│                                    └────────┬────────┘          │
│                                             │                   │
│                                             ▼                   │
│                                    ┌─────────────────┐          │
│                                    │    SUPABASE     │          │
│                                    │   PostgreSQL    │          │
│                                    │   + Realtime    │          │
│                                    │   + Storage     │          │
│                                    │   + Auth        │          │
│                                    └─────────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

### 3.3 API Service Files

#### Flutter App Services (`lib/shared/services/`)

| Service | Lines | Primary Responsibility |
|---------|-------|----------------------|
| `supabase_service.dart` | 1,091 | **Central hub** - Auth, profiles, requests, offers, orders, chat |
| `settings_service.dart` | 873 | App settings, preferences, biometrics, notifications |
| `payment_service.dart` | 518 | Paystack integration, card tokenization, transactions |
| `auth_service.dart` | 397 | Phone/email auth, OTP, password reset |
| `vehicle_service.dart` | 350+ | VIN decoding, saved vehicles, makes/models |
| `invoice_service.dart` | 400+ | PDF generation, invoice numbering |
| `push_notification_service.dart` | 300+ | FCM integration, notification handling |
| `offline_cache_service.dart` | 200+ | Local caching, 24hr expiry |
| `storage_service.dart` | 150+ | File uploads to Supabase Storage |
| `audit_logging_service.dart` | 100+ | Activity logging |
| `rate_limiter_service.dart` | 100+ | API rate limiting |
| `request_validator_service.dart` | 100+ | Form validation |
| `photon_places_service.dart` | 100+ | OpenStreetMap address search |
| `draft_service.dart` | 100+ | Form draft persistence |
| `data_retention_service.dart` | 80+ | Data cleanup policies |
| `ux_service.dart` | 50+ | UX helpers, haptics |
| `api_service.dart` | 50+ | Generic HTTP client |

#### Shop Dashboard API Routes (`shop-dashboard/src/app/api/`)

| Route | Lines | HTTP Methods | Purpose |
|-------|-------|--------------|---------|
| `/api/payments/webhook/route.ts` | 344 | POST | Paystack webhook handler |
| `/api/invoices/send/route.ts` | 283 | POST | Email invoice delivery |
| `/api/inventory/route.ts` | 207 | GET, POST, PUT, DELETE | Inventory CRUD |
| `/api/customers/route.ts` | 165 | GET | Customer list with stats |
| `/api/inventory/alerts/route.ts` | 157 | GET | Low stock alerts |
| `/api/places/details/route.ts` | 124 | GET | Place details lookup |
| `/api/payments/initialize/route.ts` | 123 | POST | Start Paystack payment |
| `/api/analytics/route.ts` | 100+ | GET | Dashboard analytics |
| `/api/invoices/generate/route.ts` | 100+ | POST | Generate PDF invoice |
| `/api/payments/verify/route.ts` | 80+ | POST | Verify payment status |
| `/api/places/autocomplete/route.ts` | 60+ | GET | Address autocomplete |
| `/api/customers/[id]/orders/route.ts` | 50+ | GET | Customer order history |

---

## 4. FEATURE LOCALITY MATRIX

### 4.1 Flutter App Features

| Feature | Screens Location | Services Used | Models Used |
|---------|-----------------|---------------|-------------|
| **Authentication** | `lib/features/auth/presentation/screens/` | `auth_service`, `supabase_service` | - |
| **Onboarding** | `lib/features/onboarding/presentation/` | `settings_service` | - |
| **Home Dashboard** | `lib/features/home/presentation/` | `supabase_service` | `PartRequest` |
| **Camera/VIN** | `lib/features/camera/presentation/` | `vehicle_service`, `storage_service` | `Vehicle` |
| **Part Requests** | `lib/features/requests/presentation/` | `supabase_service`, `request_validator_service` | `PartRequest` |
| **Marketplace** | `lib/features/marketplace/presentation/` | `supabase_service` | `Shop`, `Offer` |
| **Chat** | `lib/features/chat/presentation/` | `supabase_service` (realtime) | `Message`, `Chat` |
| **Orders** | `lib/features/orders/presentation/` | `supabase_service`, `invoice_service` | `Order` |
| **Payments** | `lib/features/payments/presentation/` | `payment_service` | `PaymentTransaction`, `SavedCard` |
| **Notifications** | `lib/features/notifications/presentation/` | `push_notification_service` | `Notification` |
| **Profile** | `lib/features/profile/presentation/` | `supabase_service`, `settings_service` | `Profile` |

### 4.2 Shop Dashboard Features

| Feature | Page Location | API Routes Used | Supabase Tables |
|---------|--------------|-----------------|-----------------|
| **Login** | `src/app/login/page.tsx` | - | `profiles`, `shops` |
| **Dashboard Home** | `src/app/dashboard/page.tsx` | `/api/analytics` | `part_requests`, `offers`, `orders` |
| **Requests** | `src/app/dashboard/requests/page.tsx` | - | `part_requests` |
| **Quotes** | `src/app/dashboard/quotes/page.tsx` | - | `offers` |
| **Orders** | `src/app/dashboard/orders/page.tsx` | - | `orders` |
| **Chats** | `src/app/dashboard/chats/page.tsx` | - | `request_chats`, `messages` |
| **Inventory** | `src/app/dashboard/inventory/page.tsx` | `/api/inventory`, `/api/inventory/alerts` | `inventory` |
| **Customers** | `src/app/dashboard/customers/page.tsx` | `/api/customers` | `profiles`, `orders` |
| **Analytics** | `src/app/dashboard/analytics/page.tsx` | `/api/analytics` | Multiple |
| **Settings** | `src/app/dashboard/settings/page.tsx` | - | `shops`, `profiles` |

---

## 5. COMPLEXITY METRICS

### 5.1 Flutter App - Top 15 Complex Files

| Rank | File | Lines | Complexity Level | Notes |
|------|------|-------|------------------|-------|
| 1 | `individual_chat_screen.dart` | 2,099 | 🔴 Critical | Voice messages, attachments, realtime |
| 2 | `request_part_screen.dart` | 1,619 | 🔴 Critical | Multi-step form, validation, drafts |
| 3 | `my_requests_screen.dart` | 1,317 | 🟠 High | Filtering, search, status management |
| 4 | `settings_screen.dart` | 1,183 | 🟠 High | Many toggles, biometrics, sessions |
| 5 | `supabase_service.dart` | 1,091 | 🔴 Critical | **ALL** database operations |
| 6 | `order_tracking_screen.dart` | 1,015 | 🟠 High | Real-time tracking, maps |
| 7 | `home_screen.dart` | 994 | 🟠 High | Dashboard, navigation hub |
| 8 | `chats_screen.dart` | 986 | 🟠 High | Chat list, realtime updates |
| 9 | `request_chat_screen.dart` | 906 | 🟠 High | Messaging, typing indicators |
| 10 | `camera_screen_full.dart` | 879 | 🟠 High | Camera controls, permissions |
| 11 | `settings_service.dart` | 873 | 🟠 High | Persistence, encryption |
| 12 | `marketplace_results_screen.dart` | 873 | 🟠 High | Filtering, sorting, offers |
| 13 | `address_autocomplete.dart` | 836 | 🟡 Medium | Debouncing, maps integration |
| 14 | `refund_request_screen.dart` | 819 | 🟡 Medium | Photo upload, status tracking |
| 15 | `quote_comparison_screen.dart` | 776 | 🟡 Medium | Side-by-side comparison |

### 5.2 Shop Dashboard - Top 10 Complex Files

| Rank | File | Lines | Complexity Level | Notes |
|------|------|-------|------------------|-------|
| 1 | `settings/page.tsx` | 1,637 | 🔴 Critical | Shop profile, staff, sessions, SSO |
| 2 | `requests/page.tsx` | 1,153 | 🔴 Critical | Request list, quote creation |
| 3 | `orders/page.tsx` | 1,147 | 🔴 Critical | Order management, status updates |
| 4 | `chats/page.tsx` | 1,131 | 🔴 Critical | Real-time messaging, typing |
| 5 | `quotes/page.tsx` | 860 | 🟠 High | Quote management, counter-offers |
| 6 | `inventory/page.tsx` | 631 | 🟠 High | CRUD, stock alerts, CSV export |
| 7 | `page.tsx` (dashboard) | 575 | 🟡 Medium | Stats, recent activity |
| 8 | `customers/page.tsx` | 520 | 🟡 Medium | Customer CRM |
| 9 | `analytics/page.tsx` | 501 | 🟡 Medium | Charts, metrics |
| 10 | `payments.test.ts` | 372 | 🟡 Medium | Payment flow tests |

### 5.3 Total Lines of Code

| Category | File Count | Total Lines |
|----------|------------|-------------|
| Flutter Dart Files | 45+ | ~25,000 |
| Shop Dashboard TS/TSX | 20+ | ~10,000 |
| SQL Migrations | 26 | ~3,000 |
| **TOTAL** | **90+** | **~38,000** |

---

## 5.4 CRITICAL FILE BREAKDOWN (Logic Summaries)

### `individual_chat_screen.dart` (2,099 lines) - 🔴 CRITICAL

**Purpose:** Full-featured real-time chat interface between mechanics and shops.

**5 Main Logic Areas:**

| Area | Lines | Description |
|------|-------|-------------|
| **1. Real-time Messaging** | ~400 | Supabase Realtime subscriptions for messages, typing indicators, online status |
| **2. Voice Messages** | ~300 | `AudioRecorder` recording, `AudioPlayer` playback, waveform visualization |
| **3. File Attachments** | ~250 | `ImagePicker` for photos, `FilePicker` for documents, upload to Supabase Storage |
| **4. Message Actions** | ~350 | Edit messages, delete, reply, forward, copy, report, selection mode |
| **5. UI State Management** | ~400 | Search mode, scroll-to-top, loading states, error handling |

**Key State Variables:**
```dart
List<Map<String, dynamic>> _messages = [];       // All chat messages
RealtimeChannel? _messageSubscription;           // Realtime listener
RealtimeChannel? _typingSubscription;            // Typing indicator channel
bool _isRecordingVoice = false;                  // Voice recording state
Set<String> _selectedMessageIds = {};            // Multi-select for bulk actions
String? _editingMessageId;                       // Currently editing message
```

**Services Used:** `supabaseServiceProvider`, `storageServiceProvider`

---

### `request_part_screen.dart` (1,619 lines) - 🔴 CRITICAL

**Purpose:** Multi-step wizard for mechanics to create part requests.

**5 Main Logic Areas:**

| Area | Lines | Description |
|------|-------|-------------|
| **1. Vehicle Selection** | ~350 | Saved vehicles, make/model dropdowns, VIN decoding, year picker |
| **2. Part Selection** | ~300 | Category browser, part search, OEM part number lookup |
| **3. Request Details** | ~250 | Urgency level, budget range, notes, image upload |
| **4. Draft Management** | ~200 | Auto-save drafts, restore on return, clear on submit |
| **5. Form Validation** | ~150 | Step-by-step validation, error messages, required fields |

**Key State Variables:**
```dart
int _currentStep = 0;                            // Wizard step (0-3)
List<SavedVehicle> _savedVehicles = [];          // User's garage
List<Map<String, dynamic>> _selectedParts = [];  // Parts in request
String _urgencyLevel = 'normal';                 // urgent/normal/flexible
bool _hasDraft = false;                          // Draft restoration flag
```

**Services Used:** `vehicleServiceProvider`, `draftServiceProvider`, `storageServiceProvider`, `uxServiceProvider`

---

### `supabase_service.dart` (1,091 lines) - 🔴 CRITICAL

**Purpose:** Central data access layer - ALL Supabase operations go through this file.

**5 Main Logic Areas:**

| Area | Lines | Description |
|------|-------|-------------|
| **1. Authentication** | ~100 | Phone OTP, password sign-in, sign-out, session management |
| **2. Profile & Shops** | ~150 | CRUD profiles, get shops by suburb, shop details |
| **3. Requests & Offers** | ~250 | Create/read requests, get/accept/reject offers, counter-offers |
| **4. Orders** | ~150 | Create orders from offers, get orders, update status |
| **5. Chat & Notifications** | ~300 | Conversations, messages, read status, notifications CRUD |

*See Section 5.5 for complete method listing.*

---

### `settings_service.dart` (873 lines) - 🟠 HIGH

**Purpose:** App preferences, biometric auth, session management, notification settings.

**5 Main Logic Areas:**

| Area | Lines | Description |
|------|-------|-------------|
| **1. User Preferences** | ~200 | Theme, language, units, default addresses |
| **2. Biometric Auth** | ~150 | Fingerprint/Face ID setup, verification, secure storage |
| **3. Notification Settings** | ~150 | Push preferences, quiet hours, channel toggles |
| **4. Session Management** | ~150 | Active sessions, device tracking, remote logout |
| **5. Data & Privacy** | ~100 | Export data, delete account, privacy toggles |

**Services Used:** `flutter_secure_storage`, `local_auth`, `shared_preferences`

---

### `shop-dashboard/settings/page.tsx` (1,637 lines) - 🔴 CRITICAL

**Purpose:** Complete shop configuration panel with staff management and SSO.

**5 Main Logic Areas:**

| Area | Lines | Description |
|------|-------|-------------|
| **1. Shop Profile** | ~400 | Name, address, phone, operating hours, logo upload |
| **2. Staff Management** | ~350 | Add/remove staff, role assignment (owner/staff), invitations |
| **3. Session Security** | ~250 | Active sessions list, device info, force logout |
| **4. SSO Configuration** | ~200 | Google SSO toggle, email linking, provider management |
| **5. Payment Settings** | ~200 | Bank details, payout preferences, Paystack integration |

---

## 5.5 SUPABASE SERVICE METHOD MAPPING

Complete listing of all public methods in `supabase_service.dart`:

### Authentication Methods (Lines 44-108)
```dart
Future<AuthResponse> signUpWithPhone({phone, password, fullName, role})
Future<void> signInWithOtp({phone})
Future<AuthResponse> verifyOtp({phone, otp})
Future<AuthResponse> signInWithPassword({phone, password})
Future<void> signOut()
Session? get currentSession
User? get currentUser
```

### Profile Methods (Lines 110-184)
```dart
Future<Map<String, dynamic>?> getProfile(String userId)
Future<void> updateProfile({userId, fullName, phone, suburb, streetAddress, city, postalCode, province})
Future<List<Map<String, dynamic>>> getShopsBySuburb({suburb, limit})
Future<void> notifyNearbyShops({requestId, suburb, partName, vehicleInfo})
```

### Part Request Methods (Lines 186-326)
```dart
Future<Map<String, dynamic>> createPartRequest({mechanicId, vehicleMake, vehicleModel, vehicleYear, partCategory, partDescription, imageUrl, engineCode, partNumber, notes})
Future<List<Map<String, dynamic>>> getMechanicRequests(String mechanicId)
Future<Map<String, dynamic>?> getRequest(String requestId)
Future<void> updateRequestStatus(String requestId, String status)
```

### Shop Methods (Lines 328-369)
```dart
Future<List<Map<String, dynamic>>> getNearbyShops({latitude, longitude, radiusKm})
Future<Map<String, dynamic>?> getShop(String shopId)
Future<List<Map<String, dynamic>>> getAllShops()
```

### Offer Methods (Lines 371-503)
```dart
Future<List<Map<String, dynamic>>> getOffersForRequest(String requestId)
Future<void> rejectOffer({offerId, reason})
Future<Map<String, dynamic>> acceptOffer({offerId, deliveryAddress, deliveryInstructions, deliveryOption})
Future<void> sendCounterOffer({offerId, counterPrice, counterNotes})
```

### Order Methods (Lines 505-563)
```dart
Future<List<Map<String, dynamic>>> getMechanicOrders(String mechanicId)
Future<Map<String, dynamic>?> getOrder(String orderId)
Future<List<Map<String, dynamic>>> getOrdersForRequest(String requestId)
```

### Chat Methods (Lines 565-857)
```dart
Future<List<Map<String, dynamic>>> getMechanicRequestChats(String mechanicId)
Future<Map<String, dynamic>> getOrCreateConversation({requestId, shopId, mechanicId})
Future<List<Map<String, dynamic>>> getUserConversations(String userId)
Future<List<Map<String, dynamic>>> getMessages(String conversationId)
Future<Map<String, dynamic>> sendMessage({conversationId, senderId, content, messageType, attachmentUrl})
Future<int> getUnreadCountForChat(String requestId, String shopId, String userId)
Future<void> markMessagesAsRead(String conversationId, String userId)
Future<void> markRequestChatMessagesAsRead(String requestId, String shopId, String userId)
Future<Map<String, dynamic>?> getLastMessageForChat(String requestId, String shopId)
```

### Storage Methods (Lines 859-913)
```dart
Future<String> uploadPartImage({imageBytes, fileName})
Future<String> uploadPartImageFromFile({file, fileName})
Future<void> deletePartImage(String path)
```

### Notification Methods (Lines 916-989)
```dart
Future<List<Map<String, dynamic>>> getUserNotifications(String userId)
Future<int> getUnreadNotificationCount(String userId)
Future<void> markNotificationAsRead(String notificationId)
Future<void> markAllNotificationsAsRead(String userId)
Future<void> deleteNotification(String notificationId)
Future<void> notifyMechanicOfNewQuote({mechanicId, shopName, partCategory, price})
```

---

## 5.6 STATE MANAGEMENT LINKS

### Flutter App - Provider → Screen Mapping

| Provider | Type | Location | Used By Screens |
|----------|------|----------|-----------------|
| `supabaseClientProvider` | `Provider<SupabaseClient>` | `supabase_service.dart:7` | All screens via services |
| `supabaseServiceProvider` | `Provider<SupabaseService>` | `supabase_service.dart:12` | All data screens |
| `authStateProvider` | `StreamProvider<AuthState>` | `supabase_service.dart:18` | `app_router.dart` (auth guard) |
| `currentUserProvider` | `Provider<User?>` | `supabase_service.dart:23` | Profile, Settings |
| `currentUserProfileProvider` | `FutureProvider<Map?>` | `supabase_service.dart:28` | Home, Profile |
| `storageServiceProvider` | `Provider<StorageService>` | `storage_service.dart` | All screens needing user ID |
| `vehicleServiceProvider` | `Provider<VehicleService>` | `vehicle_service.dart` | RequestPart, Camera |
| `paymentServiceProvider` | `Provider<PaymentService>` | `payment_service.dart` | Checkout, Transactions |
| `settingsServiceProvider` | `Provider<SettingsService>` | `settings_service.dart` | Settings, Profile |
| `draftServiceProvider` | `Provider<DraftService>` | `draft_service.dart` | RequestPart |
| `selectedChatProvider` | `StateProvider<Map?>` | `chat_providers.dart:4` | Chats (master-detail) |
| `isDesktopChatModeProvider` | `StateProvider<bool>` | `chat_providers.dart:7` | Chats (responsive) |
| `routerProvider` | `Provider<GoRouter>` | `app_router.dart` | `main.dart` |

### Screen → Provider Dependencies

| Screen | Providers Consumed |
|--------|-------------------|
| `home_screen.dart` | `storageServiceProvider`, `supabaseServiceProvider` |
| `request_part_screen.dart` | `storageServiceProvider`, `vehicleServiceProvider`, `draftServiceProvider`, `uxServiceProvider` |
| `individual_chat_screen.dart` | `supabaseServiceProvider`, `storageServiceProvider` |
| `my_requests_screen.dart` | `supabaseServiceProvider`, `storageServiceProvider` |
| `checkout_screen.dart` | `paymentServiceProvider` |
| `transactions_screen.dart` | `paymentServiceProvider` |
| `saved_cards_screen.dart` | `paymentServiceProvider` |
| `settings_screen.dart` | `settingsServiceProvider`, `storageServiceProvider` |
| `order_tracking_screen.dart` | `supabaseServiceProvider` |
| `marketplace_results_screen.dart` | `supabaseServiceProvider` |

---

## 5.7 SHOP DASHBOARD ROUTING DEEP DIVE

### Next.js App Router Structure

```
shop-dashboard/src/app/
│
├── layout.tsx                 # Root HTML wrapper (19 lines)
│   └── Provides: <html>, <body>, metadata
│
├── page.tsx                   # Landing redirect (minimal)
│   └── Redirects to /login or /dashboard
│
├── globals.css                # Tailwind + custom CSS
│
├── login/
│   └── page.tsx (292 lines)   # Shop owner authentication
│       ├── Email/password form
│       ├── "Remember me" checkbox
│       ├── Session persistence
│       └── Redirect to /dashboard on success
│
└── dashboard/
    ├── layout.tsx (214 lines) # 🔴 DASHBOARD SHELL
    │   ├── Auth guard (redirects if not logged in)
    │   ├── Shop data fetch (id, name, phone)
    │   ├── Sidebar navigation (9 items)
    │   ├── Mobile hamburger menu
    │   ├── Session activity tracking
    │   └── Logout handler
    │
    ├── page.tsx (575 lines)   # Main dashboard
    │   ├── 4 stat cards (requests, quotes, accepted, orders)
    │   ├── Recent activity feed
    │   └── Quick action buttons
    │
    ├── requests/
    │   └── page.tsx (1,153 lines)
    │       ├── Request list with filters
    │       ├── Search by vehicle/part
    │       ├── Quote creation modal
    │       ├── Bulk quote mode
    │       ├── Priority flagging
    │       └── Auto-archive (30 days)
    │
    ├── quotes/
    │   └── page.tsx (860 lines)
    │       ├── Sent quotes list
    │       ├── Status badges (pending/accepted/rejected)
    │       ├── Counter-offer handling
    │       └── Quote editing
    │
    ├── orders/
    │   └── page.tsx (1,147 lines)
    │       ├── Order management table
    │       ├── Status updates (processing→shipped→delivered)
    │       ├── Delivery tracking
    │       └── Invoice generation
    │
    ├── chats/
    │   └── page.tsx (1,131 lines)
    │       ├── Conversation list
    │       ├── Real-time messaging
    │       ├── Typing indicators
    │       └── Read receipts
    │
    ├── inventory/
    │   └── page.tsx (631 lines)
    │       ├── Parts CRUD
    │       ├── Stock level tracking
    │       ├── Low stock alerts
    │       ├── Category management
    │       └── CSV export
    │
    ├── customers/
    │   └── page.tsx (520 lines)
    │       ├── Customer list
    │       ├── Order history per customer
    │       ├── Contact info
    │       └── Loyalty tier display
    │
    ├── analytics/
    │   └── page.tsx (501 lines)
    │       ├── Revenue charts
    │       ├── Order trends
    │       ├── Top parts sold
    │       └── Customer metrics
    │
    └── settings/
        └── page.tsx (1,637 lines)
            ├── Shop profile editing
            ├── Staff management
            ├── Session security
            ├── SSO configuration
            └── Payment settings
```

### Dashboard Layout Navigation Items

```typescript
// From dashboard/layout.tsx lines 101-111
const navItems = [
  { href: "/dashboard", icon: LayoutDashboard, label: "Overview" },
  { href: "/dashboard/requests", icon: FileText, label: "Part Requests" },
  { href: "/dashboard/quotes", icon: Send, label: "My Quotes" },
  { href: "/dashboard/chats", icon: MessageSquare, label: "Chats" },
  { href: "/dashboard/orders", icon: Package, label: "Orders" },
  { href: "/dashboard/inventory", icon: Boxes, label: "Inventory" },
  { href: "/dashboard/customers", icon: Users, label: "Customers" },
  { href: "/dashboard/analytics", icon: BarChart3, label: "Analytics" },
  { href: "/dashboard/settings", icon: Settings, label: "Settings" },
]
```

### API Routes Structure

```
shop-dashboard/src/app/api/
│
├── analytics/
│   └── route.ts              # GET: Dashboard statistics
│
├── customers/
│   ├── route.ts              # GET: Customer list with stats
│   └── [id]/
│       └── orders/
│           └── route.ts      # GET: Customer's order history
│
├── inventory/
│   ├── route.ts              # GET, POST, PUT, DELETE: Inventory CRUD
│   └── alerts/
│       └── route.ts          # GET: Low stock alerts
│
├── invoices/
│   ├── generate/
│   │   └── route.ts          # POST: Generate PDF invoice
│   └── send/
│       └── route.ts          # POST: Email invoice to customer
│
├── payments/
│   ├── initialize/
│   │   └── route.ts          # POST: Start Paystack payment
│   ├── verify/
│   │   └── route.ts          # POST: Verify payment status
│   └── webhook/
│       └── route.ts          # POST: Paystack webhook handler
│
└── places/
    ├── autocomplete/
    │   └── route.ts          # GET: Address autocomplete
    └── details/
        └── route.ts          # GET: Place details lookup
```

---

## 6. DIRECTORY DEEP DIVE

### 6.1 `lib/core/` - App Configuration

```
lib/core/
├── constants/
│   ├── api_constants.dart       # External API URLs
│   ├── environment_config.dart  # Dev/Prod environment flags
│   └── supabase_constants.dart  # Supabase URL + Anon Key
├── router/
│   └── app_router.dart          # GoRouter configuration, auth guards
└── theme/
    └── app_theme.dart           # Dark theme, colors, typography
```

**Key Insight:** All configuration is centralized. No hardcoded values in feature files.

### 6.2 `lib/features/` - Feature Modules

Each feature follows Clean Architecture principles:

```
lib/features/{feature}/
├── data/           # (empty - using shared/services)
├── domain/         # (empty - using shared/models)
└── presentation/
    ├── screens/    # Full-page widgets
    └── widgets/    # Feature-specific components
```

**Note:** Data and domain layers are consolidated in `lib/shared/` to reduce duplication.

### 6.3 `lib/shared/` - Cross-Cutting Concerns

```
lib/shared/
├── models/
│   ├── marketplace.dart    # Shop, Offer, Order, PartRequest, Message
│   ├── payment_models.dart # PaymentResult, SavedCard, RefundRequest
│   └── vehicle.dart        # CarMake, CarModel, VehicleData
├── services/               # 17 service files (business logic)
└── widgets/                # 10 reusable UI components
```

### 6.4 `shop-dashboard/src/app/` - Next.js App Router

```
shop-dashboard/src/app/
├── globals.css              # Tailwind + custom styles
├── layout.tsx               # Root HTML layout
├── page.tsx                 # Landing page (redirect)
├── login/
│   └── page.tsx            # Shop owner login
├── dashboard/
│   ├── layout.tsx          # Sidebar + auth guard
│   ├── page.tsx            # Main dashboard stats
│   ├── requests/           # Part request management
│   ├── quotes/             # Quote CRUD
│   ├── orders/             # Order fulfillment
│   ├── chats/              # Customer messaging
│   ├── inventory/          # Stock management
│   ├── customers/          # CRM
│   ├── analytics/          # Business metrics
│   └── settings/           # Shop configuration
└── api/                    # Server-side API routes
    ├── analytics/
    ├── customers/
    ├── inventory/
    ├── invoices/
    ├── payments/
    └── places/
```

### 6.5 Database Migrations (`*.sql`)

| Migration File | Lines | Purpose |
|---------------|-------|---------|
| `COMPLETE_SUPABASE_MIGRATION.sql` | 398 | Full schema setup (master file) |
| `commerce_infrastructure_migration.sql` | 405 | Orders, payments, invoices |
| `database_schema_update.sql` | 327 | Schema updates |
| `chat_features_migration.sql` | 223 | Chat tables, messages, realtime |
| `audit_logs_table.sql` | 157 | Activity logging |
| `saved_vehicles_table.sql` | 104 | Vehicle management |
| `shop_dashboard_auth_migration.sql` | 116 | Shop owner auth |

---

## 7. QUICK REFERENCE

### 7.1 Where to Find Things

| Need to... | Go to... |
|-----------|----------|
| Add a new screen | `lib/features/{category}/presentation/` |
| Add a new route | `lib/core/router/app_router.dart` |
| Modify theme/colors | `lib/core/theme/app_theme.dart` |
| Add Supabase operation | `lib/shared/services/supabase_service.dart` |
| Add new data model | `lib/shared/models/` |
| Add reusable widget | `lib/shared/widgets/` |
| Add shop dashboard page | `shop-dashboard/src/app/dashboard/{name}/page.tsx` |
| Add API endpoint | `shop-dashboard/src/app/api/{name}/route.ts` |
| Modify Supabase client | `shop-dashboard/src/lib/supabase.ts` |
| Add database table | Create new `.sql` migration file |

### 7.2 State Management

| App | Solution | Pattern |
|-----|----------|---------|
| Flutter | Riverpod | Providers for services, FutureProvider for async data |
| Shop Dashboard | React useState/useEffect | Component-level state, no global store |

### 7.3 Authentication Flow

```
Flutter App:
  Supabase Auth → Phone OTP → Profile Creation → Home
  
Shop Dashboard:
  Supabase Auth → Email/Password → Role Check (shop_owner) → Dashboard
```

### 7.4 Real-Time Features

| Feature | Implementation |
|---------|---------------|
| Chat Messages | Supabase Realtime subscription on `messages` table |
| Typing Indicators | Supabase Realtime broadcast channel |
| Order Status | Supabase Realtime subscription on `orders` table |
| Notifications | Supabase Realtime + FCM push notifications |

---

## 📊 PASS 1/10 SUMMARY

This first pass documents:

- ✅ **Project Hierarchy**: Complete directory structure mapped
- ✅ **Core Anchors**: 11 heart files identified with line counts
- ✅ **Data Flow**: Supabase client locations and service architecture
- ✅ **Feature Locality**: 11 Flutter features + 10 dashboard features mapped
- ✅ **Complexity Metrics**: Top 25 complex files identified

### Next Passes Preview

| Pass | Focus Area |
|------|-----------|
| 2/10 | Database Schema Deep Dive (all tables, relationships, RLS) |
| 3/10 | Service Layer Internals (method signatures, dependencies) |
| 4/10 | UI Component Library (all widgets documented) |
| 5/10 | API Contract Documentation (all endpoints, payloads) |
| 6/10 | State Management Patterns (all providers) |
| 7/10 | Security Architecture (auth, RLS, encryption) |
| 8/10 | Testing Coverage Map |
| 9/10 | Deployment & Infrastructure |
| 10/10 | Maintenance & Troubleshooting Guide |

---

> **Document Status:** Pass 1 Complete  
> **Next Action:** Commit to GitHub, await Pass 2 directive  
> **Generated by:** Rovo Dev System Blueprint Engine
