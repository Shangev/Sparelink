# 🚀 How to Run SpareLink App

## ✅ YOU NOW HAVE ONE UNIFIED REACT NATIVE APP!

**Location:** `sparelink-app/`

This is a full React Native app built with Expo that runs on:
- 📱 iOS devices
- 📱 Android devices  
- 🌐 Web browsers
- 💻 iOS Simulator (Mac only)
- 💻 Android Emulator

---

## 🎯 START THE APP

### **Step 1: Navigate to the app**
```bash
cd sparelink-app
```

### **Step 2: Start Expo**
```bash
npm start
```

---

## 📱 VIEW ON YOUR PHONE (Best Experience)

### **iOS (iPhone/iPad):**
1. Download **Expo Go** from App Store
2. Open Expo Go
3. Scan the QR code from your terminal
4. App loads on your phone!

### **Android:**
1. Download **Expo Go** from Google Play
2. Open Expo Go
3. Scan the QR code from your terminal
4. App loads on your phone!

---

## 💻 VIEW IN BROWSER

After running `npm start`, press `w` in the terminal.

This opens the app in your web browser!

**Note:** Some mobile features (camera, notifications) won't work in browser, but the UI will look perfect.

---

## 🖥️ VIEW IN SIMULATOR/EMULATOR

### **iOS Simulator (Mac only):**
- Requires Xcode installed
- Press `i` in the terminal

### **Android Emulator:**
- Requires Android Studio installed
- Press `a` in the terminal

---

## 🎨 WHAT YOU'LL SEE

✅ **Pixel-perfect home screen** matching your design:
- Camera icon in brackets header
- "Find any part. Delivered fast." hero
- 4 glassmorphism cards in 2×2 grid
- Bottom navigation bar

---

## 🔧 BACKEND CONNECTION

Your backend is also ready!

**Start backend:**
```bash
cd sparelink-backend
npm run dev
```

**Backend URL:** http://localhost:3333
**Health Check:** http://localhost:3333/api/health

---

## 📊 PROJECT STRUCTURE

```
SparesLinks/
├── sparelink-app/           # 📱 React Native App (Expo)
│   ├── App.tsx             # Home screen (pixel-perfect!)
│   ├── package.json
│   └── ...
│
└── sparelink-backend/       # 🔧 Backend API
    ├── src/
    │   ├── routes/api.ts   # 8 APIs ready
    │   ├── db/             # Database connection
    │   └── auth.ts         # JWT authentication
    └── ...
```

---

## ⚡ QUICK COMMANDS

```bash
# Start React Native app
cd sparelink-app && npm start

# Start backend
cd sparelink-backend && npm run dev

# View app on phone
# (After npm start, scan QR code with Expo Go)

# View in browser
# (After npm start, press 'w')

# View in Android emulator
# (After npm start, press 'a')

# View in iOS simulator (Mac)
# (After npm start, press 'i')
```

---

## 🔄 RELOAD APP

- **Phone:** Shake device to reload
- **Terminal:** Press `r` to reload
- **Browser:** Refresh page

---

## 🚀 NEXT STEPS

Now that you have the home screen working:

1. **Add more screens** - Camera, Chat, Requests List, etc.
2. **Add navigation** - React Navigation between screens
3. **Connect APIs** - Make buttons call backend
4. **Test features** - Camera, location, notifications
5. **Deploy** - Publish to Expo / App Store / Play Store

---

## 📞 NEED HELP?

**Common Issues:**

**Q: QR code not showing?**
A: Make sure you're on the same WiFi network, or press `w` for web

**Q: App won't load on phone?**
A: Download Expo Go from App Store / Play Store first

**Q: Want to test in browser?**
A: Press `w` after running `npm start`

---

## ✅ STATUS

- ✅ React Native app ready
- ✅ Pixel-perfect home screen
- ✅ Backend with 8 APIs
- ✅ Database connected (Neon PostgreSQL)
- ✅ Authentication ready
- ✅ Image upload configured

**You're ready to build the rest of the screens!** 🎉

---

**Run the app now:**
```bash
cd sparelink-app
npm start
```

Then scan the QR code or press `w` for web! 📱
