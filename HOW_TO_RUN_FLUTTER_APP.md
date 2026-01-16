# 🚀 How to Run SpareLink Flutter App

**Goal:** See the app running on your device with camera functionality

---

## ⚠️ IMPORTANT: Flutter vs Web

**Flutter apps run on:**
- ✅ Android emulator/device
- ✅ iOS simulator/device (Mac only)
- ⚠️ Web browser (but camera won't work properly)

**Note:** Unlike React Native Expo, Flutter doesn't have a "localhost" web preview with full camera support. You need to run on a mobile device or emulator.

---

## 📋 PREREQUISITES

### 1. Install Flutter SDK

**Windows:**
```powershell
# Download from: https://flutter.dev/docs/get-started/install/windows
# Or use Chocolatey:
choco install flutter
```

**Mac:**
```bash
# Download from: https://flutter.dev/docs/get-started/install/macos
# Or use Homebrew:
brew install flutter
```

**Verify Installation:**
```bash
flutter doctor
```

**Expected output:**
```
[✓] Flutter (Channel stable, 3.x.x)
[✓] Android toolchain
[✓] VS Code / Android Studio
[✓] Connected device
```

---

### 2. Set Up Android Emulator (Easiest Option)

**Install Android Studio:**
1. Download: https://developer.android.com/studio
2. Install Android Studio
3. Open Android Studio → Tools → AVD Manager
4. Click "Create Virtual Device"
5. Select "Pixel 5" (recommended)
6. Select system image: "Android 13 (API 33)"
7. Click "Finish"

**Start Emulator:**
```bash
# List available emulators
flutter emulators

# Start emulator
flutter emulators --launch <emulator_id>
```

---

### 3. Alternative: Use Physical Device

**Android:**
1. Enable Developer Options on your phone
   - Settings → About Phone → Tap "Build Number" 7 times
2. Enable USB Debugging
   - Settings → Developer Options → USB Debugging
3. Connect phone via USB
4. Accept USB debugging prompt on phone

**iOS (Mac only):**
1. Connect iPhone via USB
2. Trust computer on iPhone
3. Open Xcode and register device

---

## 🚀 STEP-BY-STEP RUN INSTRUCTIONS

### Step 1: Navigate to Flutter Project
```bash
cd sparelink-flutter
```

---

### Step 2: Install Dependencies
```bash
flutter pub get
```

**Expected output:**
```
Running "flutter pub get" in sparelink-flutter...
Resolving dependencies... 
+ camera 0.10.5
+ dio 5.4.0
+ flutter_riverpod 2.4.9
...
Got dependencies!
```

---

### Step 3: Check Connected Devices
```bash
flutter devices
```

**Expected output:**
```
2 connected devices:

sdk gphone64 x86 64 (mobile) • emulator-5554 • android-x64    • Android 13 (API 33)
Chrome (web)                 • chrome        • web-javascript • Google Chrome 120.0
```

**If no devices:**
- Start Android emulator (see prerequisites)
- Or connect physical device

---

### Step 4: Start Backend (Terminal 1)
```bash
# In a separate terminal
cd sparelink-backend
npm run dev
```

**Expected output:**
```
Server running on http://localhost:3333
Database connected
✓ All APIs ready
```

**Verify backend:**
```bash
curl http://localhost:3333/api/health
```

---

### Step 5: Run Flutter App (Terminal 2)
```bash
cd sparelink-flutter
flutter run
```

**Expected output:**
```
Launching lib/main.dart on sdk gphone64 x86 64 in debug mode...
Running Gradle task 'assembleDebug'...
✓ Built build/app/outputs/flutter-apk/app-debug.apk
Installing build/app/outputs/flutter-apk/app-debug.apk...
Syncing files to device sdk gphone64 x86 64...

Flutter run key commands.
r Hot reload. 🔥
R Hot restart.
h List all available interactive commands.
d Detach (terminate "flutter run" but leave application running).
c Clear the screen
q Quit (terminate the application on the device).

💪 Running with sound null safety 💪

An Observatory debugger and profiler on sdk gphone64 x86 64 is available at: http://127.0.0.1:xxxxx/
The Flutter DevTools debugger and profiler on sdk gphone64 x86 64 is available at: http://127.0.0.1:xxxxx/
```

**App should now be running on your device/emulator!**

---

## 📱 WHAT YOU'LL SEE

### 1. Login Screen
- Dark background with glassmorphism card
- "SpareLink" title
- Phone number input
- "Register" button

### 2. Tap "Register"
- Role selection (Mechanic vs Parts Shop)
- Name input
- Phone input (+27 country code)
- Email input (optional)
- "Create Account" button

### 3. Register Test User
**Fill in:**
- Role: Mechanic
- Name: Test User
- Phone: +27111111111
- Email: test@sparelink.com

**Tap "Create Account"**

### 4. Home Screen
- Welcome message with your name
- 2x2 action grid:
  - 🎥 Request Part (green)
  - 📋 My Requests (blue)
  - 💬 Chats (purple)
  - 📍 Nearby Shops (orange)
- Bottom navigation bar

### 5. Tap "Request Part" → Camera Screen
**Permission prompt appears:**
- "SpareLink needs camera access..."
- Tap "Allow" or "While using the app"

**Camera preview loads:**
- Full-screen camera
- Flash button (top right)
- Zoom buttons (1x, 2x, 3x) on right side
- Gallery picker (bottom left)
- Capture button (bottom center)
- Rotate camera (bottom right)

### 6. Capture Photos
- Tap capture button 2-3 times
- See thumbnails appear on left side
- Tap "Next" (green FAB, bottom right)

### 7. Vehicle Form Screen
- Images preview at top
- **Make dropdown** → Select "Toyota"
- **Model dropdown** → Select "Corolla"
- **Year dropdown** → Select "2020"
- **Part Category** → Select "Brakes"
- (Optional) Add description
- Tap "Submit Request"

### 8. Success!
- Loading spinner appears
- Success message: "Request created! ID: xxx"
- Navigates back to home

---

## 🐛 TROUBLESHOOTING

### Issue 1: "flutter: command not found"
**Solution:** Flutter not installed or not in PATH
```bash
# Check installation
where flutter  # Windows
which flutter  # Mac/Linux

# If not found, reinstall Flutter and add to PATH
```

---

### Issue 2: "No devices found"
**Solution:** Start emulator or connect device
```bash
# List emulators
flutter emulators

# Start emulator
flutter emulators --launch Pixel_5_API_33
```

---

### Issue 3: Camera permission denied
**Solution:** Grant permission manually
- Android: Settings → Apps → SpareLink → Permissions → Camera → Allow
- iOS: Settings → SpareLink → Camera → Allow

---

### Issue 4: "Connection refused" when submitting request
**Solution:** Backend not reachable

**For emulator:**
```dart
// In lib/core/constants/api_constants.dart
// Change:
static const String baseUrl = 'http://localhost:3333/api';

// To (Android emulator):
static const String baseUrl = 'http://10.0.2.2:3333/api';
```

**For physical device:**
```dart
// Use your computer's IP address
static const String baseUrl = 'http://192.168.1.100:3333/api';

// Find your IP:
// Windows: ipconfig
// Mac: ifconfig en0 | grep inet
```

**Then restart app:**
```bash
# In Flutter terminal, press:
r  # Hot reload
```

---

### Issue 5: Build errors
**Solution:** Clean and rebuild
```bash
flutter clean
flutter pub get
flutter run
```

---

## 🎥 ALTERNATIVE: Run on Web (Limited)

**Note:** Camera won't work properly on web, but you can see the UI

```bash
flutter run -d chrome
```

**What works on web:**
- ✅ Login/Register screens
- ✅ Home screen
- ✅ Navigation
- ✅ Glassmorphism effects
- ❌ Camera (browser limitation)

---

## 📊 TESTING CHECKLIST

### ✅ When App Runs Successfully:

**Auth Flow:**
- [ ] Login screen displays with glassmorphism
- [ ] Register screen shows role selection
- [ ] Can register test user
- [ ] JWT token stored (check logs)
- [ ] Navigates to home after registration

**Home Screen:**
- [ ] Welcome message shows user name
- [ ] 2x2 action grid displays
- [ ] Icons load correctly
- [ ] Bottom navigation visible
- [ ] Dark theme applied

**Camera Flow:**
- [ ] Permission dialog appears (first time)
- [ ] Camera preview loads
- [ ] Flash toggle works
- [ ] Zoom buttons work (1x, 2x, 3x)
- [ ] Can capture photos
- [ ] Thumbnails appear on left
- [ ] Can delete photos
- [ ] Next button appears

**Vehicle Form:**
- [ ] Images display in preview
- [ ] Make dropdown opens (20 options)
- [ ] Model dropdown filters by make
- [ ] Year dropdown shows 1980-2026
- [ ] Can select part category
- [ ] Can add description
- [ ] Submit button works

**Backend Integration:**
- [ ] Loading spinner shows
- [ ] Success message appears
- [ ] Request ID displayed
- [ ] Navigates to home
- [ ] Request saved in database

---

## 🎯 EXPECTED RESULT

**Successful Run:**
```
✓ Flutter app running on Android emulator
✓ Backend running on localhost:3333
✓ Can register user
✓ Can navigate to camera
✓ Can capture photos
✓ Can submit request
✓ Request created in database
```

**Time to First Run:** ~10 minutes (after Flutter installed)

---

## 📞 NEXT STEPS AFTER SUCCESSFUL RUN

1. **Test full flow** with different vehicles
2. **Verify database** - Check requests table
3. **Test errors** - Try without backend, without permissions
4. **Performance** - Check FPS on old Android device
5. **Start Week 2** - Implement My Requests screen

---

## 🎉 YOU'RE READY!

**Commands Summary:**
```bash
# Terminal 1: Backend
cd sparelink-backend
npm run dev

# Terminal 2: Flutter
cd sparelink-flutter
flutter pub get
flutter run
```

**Then:** Test the camera flow!

---

**Need help?** Check the troubleshooting section or ask for assistance!
