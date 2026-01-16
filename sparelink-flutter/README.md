# SpareLink Flutter App

**Auto Parts Marketplace for Mechanics**

Built with Flutter, Riverpod, and GoRouter. Connects to Node.js backend with PostgreSQL + PostGIS.

---

## 🚀 Quick Start

### Prerequisites

1. **Flutter SDK** (3.0.0 or higher)
   ```bash
   # Check installation
   flutter --version
   ```

2. **Install Flutter**: https://flutter.dev/docs/get-started/install

### Installation

```bash
# 1. Get dependencies
flutter pub get

# 2. Run code generation (for Riverpod)
flutter pub run build_runner build --delete-conflicting-outputs

# 3. Run the app
flutter run
```

### Platform-Specific Setup

#### Android
- Minimum SDK: 21 (Android 5.0)
- Camera permissions auto-configured

#### iOS
- Minimum iOS: 12.0
- Camera permissions: Already configured in Info.plist (will be added)

---

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point
├── core/
│   ├── theme/
│   │   └── app_theme.dart            # Dark theme + glassmorphism
│   ├── router/
│   │   └── app_router.dart           # GoRouter configuration
│   └── constants/
│       └── api_constants.dart        # Backend API URLs
├── features/
│   ├── auth/
│   │   ├── presentation/
│   │   │   └── screens/
│   │   │       ├── login_screen.dart
│   │   │       └── register_screen.dart
│   │   ├── data/                     # Data layer (models, repos)
│   │   └── domain/                   # Business logic
│   ├── home/
│   │   └── presentation/
│   │       └── home_screen.dart
│   ├── camera/
│   │   └── presentation/
│   │       └── camera_screen.dart    # WEEK 1 TODO
│   ├── requests/
│   │   └── presentation/
│   │       └── my_requests_screen.dart
│   └── chat/
│       └── presentation/
│           └── chats_screen.dart
└── shared/
    ├── widgets/                      # Reusable UI components
    ├── models/                       # Shared data models
    └── services/
        ├── api_service.dart          # HTTP client (Dio)
        └── storage_service.dart      # Secure storage (JWT)
```

---

## 🔑 Backend Configuration

### Update API URL

Edit `lib/core/constants/api_constants.dart`:

```dart
// For emulator/simulator
static const String baseUrl = 'http://localhost:3333/api';

// For physical Android device (use your computer's IP)
static const String baseUrl = 'http://192.168.1.100:3333/api';

// For physical iOS device (use your computer's IP)
static const String baseUrl = 'http://192.168.1.100:3333/api';
```

### Start Backend Server

```bash
cd ../sparelink-backend
npm run dev
# Server runs on http://localhost:3333
```

### Verify Backend

```bash
curl http://localhost:3333/api/health
```

---

## 📦 Dependencies

### State Management
- `flutter_riverpod` - Modern state management
- `riverpod_annotation` - Code generation

### Navigation
- `go_router` - Declarative routing

### HTTP & Storage
- `dio` - HTTP client with interceptors
- `flutter_secure_storage` - Encrypted JWT storage
- `pretty_dio_logger` - Request/response logging

### Camera & Images
- `camera` (official) - Camera access
- `image_picker` - Gallery picker
- `permission_handler` - Permission management

### UI
- `lucide_icons_flutter` - Icon library
- `flutter_animate` - Smooth animations

---

## 🎨 Design System

### Colors
```dart
Primary Black:   #000000
Dark Gray:       #1A1A1A
Medium Gray:     #2A2A2A
Light Gray:      #888888
Accent Green:    #4CAF50
White:           #FFFFFF

Glassmorphism:   rgba(255,255,255,0.12)
Glass Border:    rgba(255,255,255,0.2)
```

### Typography
- Font: Inter
- Display Large: 36px, 800 weight
- Title Large: 20px, 700 weight
- Body Large: 17px, 400 weight
- Body Small: 13px, 400 weight

### Glassmorphism
```dart
import 'dart:ui';

ClipRRect(
  borderRadius: BorderRadius.circular(20),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: Container(
      decoration: AppTheme.glassDecoration(borderRadius: 20),
      child: YourContent(),
    ),
  ),
)
```

---

## 🔐 Authentication Flow

1. User opens app → Login screen
2. User enters phone number (+27123456789)
3. App calls `POST /api/auth/login`
4. Backend returns JWT token + user data
5. App stores token in secure storage
6. App navigates to home screen

### Accessing Stored Data

```dart
final storageService = ref.read(storageServiceProvider);

// Get user ID
final userId = await storageService.getUserId();

// Get JWT token
final token = await storageService.getToken();

// Check if logged in
final isLoggedIn = await storageService.isLoggedIn();

// Logout
await storageService.clearAll();
```

---

## 📱 Screens Implemented

### ✅ Week 0 (Completed)
- [x] Login Screen (with glassmorphism)
- [x] Register Screen (mechanic/shop selection)
- [x] Home Screen (2x2 action grid)
- [x] API Service (all 10 backend endpoints)
- [x] Secure Storage (JWT management)
- [x] GoRouter (navigation)
- [x] Dark Theme (glassmorphism)

### 🚧 Week 1 (In Progress)
- [ ] Camera Screen (full implementation)
- [ ] Vehicle Selection (make/model/year)
- [ ] Part Category Selection
- [ ] Image Preview & Multi-capture
- [ ] Submit Request to Backend

### 📅 Week 2 (Planned)
- [ ] My Requests List Screen
- [ ] Request Details Screen
- [ ] Offer Details Screen
- [ ] Chat Thread Screen

---

## 🧪 Testing

### Test Login Flow

1. Start backend:
   ```bash
   cd sparelink-backend
   npm run dev
   ```

2. Seed test data:
   ```bash
   curl -X POST http://localhost:3333/api/seed/shops
   ```

3. Register test user:
   - Phone: `+27111111111`
   - Name: `Test Mechanic`
   - Role: Mechanic

4. Login with same phone number

### Test API Directly

```bash
# Register
curl -X POST http://localhost:3333/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "role": "mechanic",
    "name": "Test User",
    "phone": "+27123456789"
  }'

# Login
curl -X POST http://localhost:3333/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone": "+27123456789"}'
```

---

## 🐛 Common Issues

### 1. "Connection refused" when calling API

**Problem:** App can't reach backend

**Solution:**
- Emulator: Use `http://10.0.2.2:3333/api` (Android) or `http://localhost:3333/api` (iOS)
- Physical device: Use your computer's IP address (e.g., `http://192.168.1.100:3333/api`)

### 2. Camera not working

**Problem:** Camera package requires permissions

**Solution:**
- Ensure `permission_handler` is configured
- Check platform-specific permission settings (will be added in Week 1)

### 3. "No material widget found"

**Problem:** Widget not wrapped in MaterialApp

**Solution:** Already handled in `main.dart` with `MaterialApp.router`

### 4. Build runner errors

**Problem:** Code generation failing

**Solution:**
```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 📚 Resources

- **Flutter Docs**: https://flutter.dev/docs
- **Riverpod Docs**: https://riverpod.dev
- **GoRouter Docs**: https://pub.dev/packages/go_router
- **Backend API Reference**: See `../sparelink-backend/README.md`

---

## 🎯 Week 1 Goals

**Current Status:** Auth screens complete, navigation working, API service ready

**This Week's Focus:**
1. ✅ Login/Register screens (DONE)
2. 🚧 Camera implementation
3. 🚧 Vehicle selection dropdowns
4. 🚧 Connect to POST /api/requests
5. 🚧 Test full request flow

**Next Week:** My Requests list, Offer details, Chat interface

---

## 🚀 Development Commands

```bash
# Run app
flutter run

# Run with specific device
flutter run -d chrome  # Web
flutter run -d android # Android emulator
flutter run -d ios     # iOS simulator

# Generate code (Riverpod)
flutter pub run build_runner watch

# Clean build
flutter clean
flutter pub get
flutter run

# Build APK (Android)
flutter build apk --release

# Build iOS
flutter build ios --release
```

---

## 📄 License

Proprietary - SpareLink 2025

---

**Questions?** Check the full migration analysis: `../tmp_rovodev_flutter_migration_analysis.md`
