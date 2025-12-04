# 🚀 SpareLink API Quick Reference

## Base URL
```
http://localhost:3333/api
```

---

## 📋 ENDPOINTS READY TO USE

### 1. Health Check
```bash
GET /api/health
```
**Response:**
```json
{
  "status": "ok",
  "db": "Supabase (Neon) - 100% connected",
  "apis": "8/8 working"
}
```

---

### 2. Register User
```bash
POST /api/auth/register
Content-Type: application/json

{
  "role": "mechanic",  // or "shop"
  "name": "Ahmed Mechanic",
  "phone": "+971501234567",
  "email": "ahmed@example.com",
  "workshopName": "Ahmed's Auto Repair"
}
```
**Response:**
```json
{
  "user": {
    "id": "uuid",
    "role": "mechanic",
    "name": "Ahmed Mechanic",
    "phone": "+971501234567",
    ...
  },
  "token": "eyJhbGci..."
}
```

---

### 3. Login
```bash
POST /api/auth/login
Content-Type: application/json

{
  "phone": "+971501234567"
}
```
**Response:** Same as register

---

### 4. Create Request (with images)
```bash
POST /api/requests
Content-Type: application/json

{
  "mechanicId": "uuid",
  "make": "Toyota",
  "model": "Land Cruiser",
  "year": 2020,
  "partName": "Front Brake Pads",
  "description": "Need OEM brake pads urgently",
  "imagesBase64": ["data:image/jpeg;base64,..."]
}
```
**Response:**
```json
{
  "id": "uuid",
  "mechanicId": "uuid",
  "vehicleMake": "Toyota",
  "partName": "Front Brake Pads",
  "imageUrls": ["https://res.cloudinary.com/..."],
  "status": "pending",
  ...
}
```

---

### 5. Get User Requests
```bash
GET /api/requests/user/{userId}
```
**Response:**
```json
[
  {
    "id": "uuid",
    "partName": "Front Brake Pads",
    "status": "pending",
    ...
  }
]
```

---

### 6. Find Nearby Shops (20km)
```bash
GET /api/shops/nearby?lat=25.276&lng=55.296&radius=20
```
**Response:**
```json
[
  {
    "id": "uuid",
    "name": "Dubai Auto Parts",
    "address": "Al Quoz, Dubai",
    "lat": 25.123,
    "lng": 55.456,
    ...
  }
]
```

---

### 7. Create Offer
```bash
POST /api/offers
Content-Type: application/json

{
  "requestId": "uuid",
  "shopId": "uuid",
  "priceCents": 12500,  // AED 125.00
  "deliveryFeeCents": 500,  // AED 5.00
  "etaMinutes": 30,
  "stockStatus": "in_stock",
  "partImagesBase64": ["data:image/jpeg;base64,..."],
  "message": "We have OEM brake pads in stock!"
}
```
**Response:**
```json
{
  "id": "uuid",
  "priceCents": 12500,
  "deliveryFeeCents": 500,
  "partImages": ["https://res.cloudinary.com/..."],
  ...
}
```

---

### 8. Get Offers for Request
```bash
GET /api/requests/{requestId}/offers
```
**Response:**
```json
[
  {
    "id": "uuid",
    "priceCents": 12500,
    "shop": {
      "id": "uuid",
      "name": "Dubai Auto Parts",
      ...
    },
    "message": "We have it in stock!",
    ...
  }
]
```

---

## 🔐 Authentication

All protected endpoints (coming soon) will require:
```bash
Authorization: Bearer {token}
```

Get token from `/auth/register` or `/auth/login`

---

## 🖼️ Image Upload

Send images as base64 strings:
```javascript
// In your React Native app:
const base64 = `data:image/jpeg;base64,${imageData}`;

// Send in request:
{
  "imagesBase64": [base64]
}
```

Images are automatically uploaded to Cloudinary and URLs are returned.

---

## 📍 PostGIS Geographic Search

The `/shops/nearby` endpoint uses PostGIS for accurate distance calculations:
- Returns shops within specified radius (default: 20km)
- Results sorted by distance (nearest first)
- Efficient spatial indexing

---

## 💰 Price Format

All prices are in **cents** to avoid decimal issues:
- AED 125.00 = 12500 cents
- AED 5.50 = 550 cents

Frontend should divide by 100 for display.

---

## 🧪 Testing

Quick test with curl:
```bash
# Health check
curl http://localhost:3333/api/health

# Register user
curl -X POST http://localhost:3333/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"role":"mechanic","name":"Test","phone":"+971501234567","email":"test@test.com"}'
```

---

## 🚀 Start Backend

```bash
cd sparelink-backend
npm run dev
```

Server runs at: **http://localhost:3333**

---

## 📊 Status Codes

- `200` - Success
- `400` - Bad request (validation error)
- `401` - Unauthorized (invalid token)
- `404` - Not found
- `500` - Server error

---

## 🔄 Next Steps

Ready to integrate with React Native:
1. Install Axios in your RN app
2. Create API client with base URL
3. Add token management
4. Connect all 10 UI screens
5. Test end-to-end flow

**All backend APIs are ready and tested!** 🎉
