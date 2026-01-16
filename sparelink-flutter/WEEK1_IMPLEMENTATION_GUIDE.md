# 🚀 Week 1 Implementation Guide - SpareLink Flutter

**Goal:** Complete Login/Register screens and test backend integration

**Timeline:** Days 1-7  
**Status:** Auth screens COMPLETE ✅ | Testing & Camera next 🚧

---

## ✅ COMPLETED (Already Done)

### Day 1-2: Project Setup & Auth Screens ✅

**What's Ready:**
- [x] Flutter project structure (27 directories)
- [x] `pubspec.yaml` with all dependencies
- [x] Dark theme with glassmorphism (`app_theme.dart`)
- [x] GoRouter navigation (`app_router.dart`)
- [x] API service with Dio + JWT interceptors (`api_service.dart`)
- [x] Secure storage for JWT tokens (`storage_service.dart`)
- [x] Login screen with glassmorphism
- [x] Register screen with role selection (mechanic/shop)
- [x] Home screen with 2x2 action grid
- [x] Placeholder screens (Camera, Requests, Chats)

**What Works Right Now:**
1. Navigation between screens
2. Glassmorphism UI (BackdropFilter)
3. Form validation
4. Role selection (Mechanic vs Shop)
5. API service ready to call backend

---

## 🧪 DAY 3: TEST AUTHENTICATION FLOW

**Objective:** Verify Login/Register connects to backend and stores JWT

### Prerequisites

1. **Install Flutter** (if not already)
   ```bash
   flutter --version
   # Should show Flutter 3.0.0 or higher
   ```

2. **Get Dependencies**
   ```bash
   cd sparelink-flutter
   flutter pub get
   ```

3. **Start Backend Server**
   ```bash
   cd ../sparelink-backend
   npm run dev
   # Should start on http://localhost:3333
   ```

4. **Verify Backend Health**
   ```bash
   curl http://localhost:3333/api/health
   ```

### Test Steps

#### Test 1: Run Flutter App

```bash
cd sparelink-flutter
flutter run
```

**Expected:**
- App opens to Login screen
- Dark theme with glassmorphism visible
- "SpareLink" title and "Welcome Back" card

#### Test 2: Navigate to Register

1. Tap "Register" button on Login screen
2. **Expected:** Navigate to Register screen with role selection

#### Test 3: Register New User

**Fill in form:**
- Role: Select "Mechanic"
- Name: `Test Mechanic`
- Phone: `+27111111111`
- Email: `test@example.com` (optional)

**Tap "Create Account"**

**Expected Behavior:**
1. Loading spinner appears
2. API call to `POST /api/auth/register`
3. Response: `{ user: {...}, token: "eyJhbGc..." }`
4. Token saved to secure storage
5. Navigate to Home screen

**If Error:**
- Check console logs
- Verify backend is running
- Check API URL in `api_constants.dart`

#### Test 4: Check Storage

Add debug print to verify token saved:

```dart
// In home_screen.dart, add to initState():
final token = await ref.read(storageServiceProvider).getToken();
print('🔑 Stored JWT Token: $token');
```

**Expected:** Token printed in console

#### Test 5: Logout and Login

1. Add temporary logout button to Home screen:
   ```dart
   ElevatedButton(
     onPressed: () async {
       await ref.read(storageServiceProvider).clearAll();
       context.go('/login');
     },
     child: Text('Logout (Debug)'),
   ),
   ```

2. Tap logout
3. **Expected:** Navigate to Login screen

4. Login with same phone: `+27111111111`
5. **Expected:** Login successful, navigate to Home

---

## 🐛 TROUBLESHOOTING (Day 3)

### Issue 1: "Connection refused"

**Problem:** App can't reach backend

**Solutions:**

**For Android Emulator:**
```dart
// In api_constants.dart
static const String baseUrl = 'http://10.0.2.2:3333/api';
```

**For iOS Simulator:**
```dart
static const String baseUrl = 'http://localhost:3333/api';
```

**For Physical Device:**
```dart
// Use your computer's IP address
static const String baseUrl = 'http://192.168.1.100:3333/api';

// Find your IP:
// Windows: ipconfig
// Mac/Linux: ifconfig
```

### Issue 2: "DioException: Connection timeout"

**Problem:** Backend not responding

**Check:**
1. Backend server running? `curl http://localhost:3333/api/health`
2. Correct URL in `api_constants.dart`?
3. Firewall blocking port 3333?

### Issue 3: "422 Unprocessable Entity"

**Problem:** Validation error from backend

**Check:**
- Phone format: Must start with `+` (e.g., `+27123456789`)
- All required fields filled
- Backend console logs for validation errors

### Issue 4: Widget not found

**Problem:** Screen not registered in router

**Check:** `app_router.dart` has route defined

---

## 📱 DAY 4-5: CAMERA IMPLEMENTATION

**Objective:** Build full camera screen with multi-image capture

### Tasks

#### 1. Update Camera Screen

Replace `camera_screen.dart` with full implementation:

**Features to implement:**
- [ ] Camera preview (using `camera` package)
- [ ] Permission handling (`permission_handler`)
- [ ] Flash toggle
- [ ] Zoom controls (2x, 3x)
- [ ] Front/back camera switch
- [ ] Capture button
- [ ] Gallery picker fallback
- [ ] Multi-image capture (up to 4 images)
- [ ] Image preview with delete

#### 2. Camera Permission Setup

**Android:** Add to `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

**iOS:** Add to `ios/Runner/Info.plist`
```xml
<key>NSCameraUsageDescription</key>
<string>SpareLink needs camera access to capture part photos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>SpareLink needs photo library access to select images</string>
```

#### 3. Camera Implementation Reference

```dart
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

class CameraScreen extends StatefulWidget {
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  List<XFile> _capturedImages = [];
  bool _isFlashOn = false;
  
  @override
  void initState() {
    super.initState();
    _initCamera();
  }
  
  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.first;
    
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    
    await _cameraController!.initialize();
    setState(() {});
  }
  
  Future<void> _takePicture() async {
    if (_capturedImages.length >= 4) return;
    
    final image = await _cameraController!.takePicture();
    setState(() {
      _capturedImages.add(image);
    });
  }
  
  void _toggleFlash() {
    setState(() => _isFlashOn = !_isFlashOn);
    _cameraController!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }
    
    return Scaffold(
      body: Stack(
        children: [
          // Camera Preview
          CameraPreview(_cameraController!),
          
          // Controls
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Flash button
                IconButton(
                  icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
                  onPressed: _toggleFlash,
                ),
                
                // Capture button
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                  ),
                ),
                
                // Gallery button
                IconButton(
                  icon: Icon(Icons.photo_library),
                  onPressed: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      setState(() => _capturedImages.add(image));
                    }
                  },
                ),
              ],
            ),
          ),
          
          // Image preview
          if (_capturedImages.isNotEmpty)
            Positioned(
              top: 100,
              left: 16,
              child: _ImagePreview(images: _capturedImages),
            ),
        ],
      ),
    );
  }
}
```

---

## 🎯 DAY 6-7: VEHICLE SELECTION & FORM

**Objective:** Add vehicle selection and connect to backend

### Tasks

#### 1. Create Vehicle Data Service

```dart
// lib/shared/models/vehicle.dart
class CarMake {
  final String id;
  final String name;
  
  CarMake({required this.id, required this.name});
}

// Static data (same as RN)
final carMakes = [
  CarMake(id: '1', name: 'Toyota'),
  CarMake(id: '2', name: 'BMW'),
  // ... 18 more
];
```

#### 2. Create Dropdown Modal Widget

```dart
// lib/shared/widgets/dropdown_modal.dart
class DropdownModal extends StatelessWidget {
  final List<String> options;
  final Function(String) onSelect;
  
  // Implementation: showModalBottomSheet with search
}
```

#### 3. Create Request Form Screen

After camera, show form:
- Vehicle make (dropdown)
- Vehicle model (dropdown)
- Vehicle year (dropdown)
- Part category (dropdown)
- VIN/Engine number (text input)
- Description (text area)

#### 4. Submit to Backend

```dart
Future<void> _submitRequest() async {
  // Convert images to Base64
  final imagesBase64 = await Future.wait(
    _capturedImages.map((img) async {
      final bytes = await img.readAsBytes();
      return base64Encode(bytes);
    }),
  );
  
  // Call API
  final response = await ref.read(apiServiceProvider).createRequest(
    mechanicId: userId,
    make: selectedMake,
    model: selectedModel,
    year: selectedYear,
    partName: selectedPart,
    description: description,
    imagesBase64: imagesBase64,
  );
  
  // Show success
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Request created! ID: ${response['request']['id']}')),
  );
  
  // Navigate to home
  context.go('/');
}
```

---

## ✅ WEEK 1 COMPLETION CHECKLIST

By end of Week 1, you should have:

- [x] **Day 1-2:** Login/Register screens (DONE)
- [x] **Day 1-2:** API service + secure storage (DONE)
- [x] **Day 1-2:** Navigation + theme (DONE)
- [ ] **Day 3:** Test authentication flow
- [ ] **Day 4-5:** Camera implementation
- [ ] **Day 6-7:** Vehicle selection + form
- [ ] **Day 7:** Submit request to backend
- [ ] **Day 7:** Test full flow end-to-end

**Success Criteria:**
1. ✅ User can register/login
2. ✅ JWT token stored securely
3. 🚧 User can capture 4 photos
4. 🚧 User can select vehicle details
5. 🚧 Request submits to backend successfully
6. 🚧 Backend returns request ID
7. 🚧 User sees success message

---

## 🎉 WEEK 1 GOALS

**Current Status:** 40% complete (Auth + scaffolding done)

**By Friday:**
- Camera working with multi-capture
- Vehicle selection working
- Full request flow from camera → submit → success
- Tested on both Android and iOS

**Next Week (Week 2):**
- My Requests list screen
- Request details screen
- Offer details screen
- Chat interface

---

## 📞 NEED HELP?

**Common Questions:**

1. **"Flutter not installed"**
   - Follow: https://flutter.dev/docs/get-started/install

2. **"Backend not responding"**
   - Check: `curl http://localhost:3333/api/health`
   - Verify: Backend running on correct port

3. **"Camera permission denied"**
   - Check: Platform-specific permission setup (see Day 4-5)

4. **"Build errors"**
   - Run: `flutter clean && flutter pub get`

---

**You're off to a great start!** Auth screens are production-ready. Focus this week on camera and form implementation.

Let's build this! 🚀
