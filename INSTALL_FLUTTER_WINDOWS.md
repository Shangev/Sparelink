# 🚀 Install Flutter on Windows - Step by Step

**Time Required:** 15-20 minutes

---

## METHOD 1: Direct Download (RECOMMENDED)

### Step 1: Download Flutter SDK

1. **Go to:** https://docs.flutter.dev/get-started/install/windows
2. **Click:** "Download Flutter SDK" button
3. **File:** `flutter_windows_3.x.x-stable.zip` (~1GB)
4. **Save to:** `C:\src\flutter` (create folder if needed)

---

### Step 2: Extract Flutter

1. **Right-click** the downloaded zip file
2. **Select:** "Extract All..."
3. **Extract to:** `C:\src\`
4. **Result:** You should have `C:\src\flutter\bin\flutter.bat`

---

### Step 3: Add Flutter to PATH

**Option A: Using PowerShell (Easiest)**

Open PowerShell **as Administrator** and run:

```powershell
# Add Flutter to PATH permanently
$flutterPath = "C:\src\flutter\bin"
[Environment]::SetEnvironmentVariable("Path", "$env:Path;$flutterPath", "User")

Write-Output "✅ Flutter added to PATH"
Write-Output "⚠️  Close and reopen PowerShell for changes to take effect"
```

**Option B: Using Windows Settings**

1. Press `Windows Key` + type "environment"
2. Click **"Edit the system environment variables"**
3. Click **"Environment Variables"** button
4. Under **"User variables"**, select **"Path"**
5. Click **"Edit"**
6. Click **"New"**
7. Add: `C:\src\flutter\bin`
8. Click **"OK"** on all windows

---

### Step 4: Verify Installation

Close and reopen PowerShell, then run:

```powershell
flutter --version
```

**Expected output:**
```
Flutter 3.x.x • channel stable
Tools • Dart 3.x.x
```

---

### Step 5: Run Flutter Doctor

```powershell
flutter doctor
```

**Expected output:**
```
[✓] Flutter (Channel stable, 3.x.x)
[!] Android toolchain - Missing or needs setup
[!] Visual Studio - Missing or needs setup
[✓] VS Code (version 1.x.x)
[✓] Connected device (none detected)
```

**Don't worry about the warnings!** We just need Flutter SDK installed for now.

---

## METHOD 2: Using Chocolatey (Alternative)

If you have Chocolatey package manager:

```powershell
# Run as Administrator
choco install flutter

# Verify
flutter --version
```

---

## AFTER INSTALLATION

### 1. Verify Flutter Works

```powershell
cd C:\Users\ntmve\OneDrive\Documents\GitHub\SparesLinks\sparelink-flutter
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

## TROUBLESHOOTING

### Issue 1: "flutter: command not found" after adding to PATH

**Solution:** Close and reopen PowerShell/Terminal

```powershell
# Check if PATH updated
$env:Path -split ';' | Select-String flutter
```

---

### Issue 2: Download too slow

**Solution:** Use a download manager or try different mirror:
- GitHub mirror: https://github.com/flutter/flutter/releases

---

### Issue 3: Antivirus blocking

**Solution:** Temporarily disable antivirus during extraction

---

## QUICK CHECK

Run this to verify everything:

```powershell
# Check Flutter
flutter --version

# Check if in correct directory
cd C:\Users\ntmve\OneDrive\Documents\GitHub\SparesLinks\sparelink-flutter
Get-Location

# Try getting dependencies
flutter pub get
```

---

## NEXT STEPS AFTER FLUTTER INSTALLS

Once `flutter pub get` succeeds, you're ready to run the app!

```powershell
# Start Android emulator or connect device
flutter devices

# Run the app
flutter run
```

---

**Need help?** Let me know where you get stuck!
