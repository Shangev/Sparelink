# 🚀 Enable Android Emulator Hardware Acceleration

## Problem
Your Android Emulator failed to start with this error:
```
ERROR | x86_64 emulation currently requires hardware acceleration!
CPU acceleration status: Android Emulator hypervisor driver is not installed
```

## Solution: Enable Windows Hypervisor Platform (WHPX)

### Step 1: Enable Windows Features (Requires Admin)

**Option A: Using Windows Settings GUI (EASIEST)**
1. Press `Windows Key` and search for **"Turn Windows features on or off"**
2. Click on it (you'll need admin privileges)
3. In the window that opens, scroll down and CHECK these boxes:
   - ☑ **Windows Hypervisor Platform**
   - ☑ **Virtual Machine Platform** (if available)
4. Click **OK**
5. **Restart your computer** when prompted

**Option B: Using PowerShell (Run as Administrator)**
```powershell
# Open PowerShell as Administrator and run:
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Hypervisor -All
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All
```
Then **restart your computer**.

---

### Step 2: Verify It's Working

After restarting, open PowerShell and run:
```powershell
flutter emulators --launch Medium_Phone_API_36.1
```

The emulator window should appear within 30-60 seconds!

---

### Step 3: Run Your Flutter App on the Emulator

Once the emulator is running, you'll see it in the devices list:
```powershell
flutter devices
```

Then run your app:
```powershell
cd sparelink-flutter
flutter run -d emulator-5554
```

Or simply:
```powershell
cd sparelink-flutter
flutter run
```
(Flutter will automatically pick the running emulator)

---

## Alternative: Use Chrome Web Preview (NO RESTART NEEDED)

If you don't want to restart right now, you can continue testing on **Chrome** which is already working:

```powershell
cd sparelink-flutter
flutter run -d chrome
```

---

## Troubleshooting

### Issue: "Hyper-V conflicts with other software"
Some VirtualBox or VMware installations conflict with Hyper-V. You may need to choose one or the other.

### Issue: "I don't see Windows Hypervisor Platform option"
- Make sure you have **Windows 10 Pro/Enterprise** or **Windows 11**
- Windows 10 Home users: Upgrade to Pro or use **Intel HAXM** instead
- Check your Windows version: Press `Win + R`, type `winver`, press Enter

### Issue: Still not working after enabling WHPX
Try installing the Android Emulator Hypervisor Driver:
1. Open Android Studio
2. Go to **Tools → SDK Manager → SDK Tools**
3. Check **Android Emulator Hypervisor Driver for AMD Processors (installer)**
4. Click **Apply**

---

## Quick Reference Commands

```powershell
# List available emulators
flutter emulators

# Launch emulator
flutter emulators --launch Medium_Phone_API_36.1

# Check connected devices
flutter devices

# Run app on emulator
cd sparelink-flutter
flutter run
```

---

**Next Steps:**
1. ✅ Enable Windows Hypervisor Platform (see Step 1 above)
2. ✅ Restart your computer
3. ✅ Launch the emulator
4. ✅ Run your Flutter app!
