# 🔧 VERCEL ENVIRONMENT SETUP GUIDE

> **Purpose:** Configure environment variables for the Shop Dashboard  
> **Platform:** Vercel  
> **App:** `shop-dashboard` (Next.js)

---

## REQUIRED ENVIRONMENT VARIABLES

### 1. Go to Vercel Dashboard

1. Log in to [vercel.com](https://vercel.com)
2. Select your project (shop-dashboard)
3. Go to **Settings** → **Environment Variables**

### 2. Add These Variables

| Variable | Value | Environment | Notes |
|----------|-------|-------------|-------|
| `NEXT_PUBLIC_SUPABASE_URL` | `https://your-project.supabase.co` | All | Your Supabase project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | `eyJhbGciOi...` | All | Supabase anon/public key |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJhbGciOi...` | All | ⚠️ Server-side only! |
| `PAYSTACK_SECRET_KEY` | `sk_live_...` or `sk_test_...` | All | Paystack secret key |
| `NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY` | `pk_live_...` or `pk_test_...` | All | Paystack public key |

### 3. Environment-Specific Values

**Production:**
```
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
PAYSTACK_SECRET_KEY=sk_live_xxxxxxxxxxxxxxxxxxxxxxx
NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY=pk_live_xxxxxxxxxxxxxxxxxxxxxxx
```

**Preview/Development:**
```
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
PAYSTACK_SECRET_KEY=sk_test_xxxxxxxxxxxxxxxxxxxxxxx
NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY=pk_test_xxxxxxxxxxxxxxxxxxxxxxx
```

---

## STEP-BY-STEP INSTRUCTIONS

### Step 1: Get Supabase Keys

1. Go to [app.supabase.com](https://app.supabase.com)
2. Select your project
3. Go to **Settings** → **API**
4. Copy:
   - **Project URL** → `NEXT_PUBLIC_SUPABASE_URL`
   - **anon public** key → `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - **service_role** key → `SUPABASE_SERVICE_ROLE_KEY`

⚠️ **SECURITY WARNING:** Never expose `service_role` key in client-side code!

### Step 2: Get Paystack Keys

1. Go to [dashboard.paystack.com](https://dashboard.paystack.com)
2. Go to **Settings** → **API Keys & Webhooks**
3. Copy:
   - **Secret Key** → `PAYSTACK_SECRET_KEY`
   - **Public Key** → `NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY`

For testing, use the **Test** keys. For production, use **Live** keys.

### Step 3: Add Variables in Vercel

1. In Vercel Dashboard, go to your project
2. Click **Settings** → **Environment Variables**
3. For each variable:
   - Enter the **Name** (e.g., `NEXT_PUBLIC_SUPABASE_URL`)
   - Enter the **Value** (your actual key/URL)
   - Select environments: ✅ Production, ✅ Preview, ✅ Development
   - Click **Save**

### Step 4: Redeploy

After adding all variables:
1. Go to **Deployments** tab
2. Find the latest deployment
3. Click the **...** menu → **Redeploy**
4. Wait for deployment to complete

---

## LOCAL DEVELOPMENT

For local development, create `.env.local` in `shop-dashboard/`:

```bash
# shop-dashboard/.env.local

# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Paystack (use test keys for development)
PAYSTACK_SECRET_KEY=sk_test_xxxxxxxxxxxxxxxxxxxxxxx
NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY=pk_test_xxxxxxxxxxxxxxxxxxxxxxx
```

⚠️ **IMPORTANT:** Add `.env.local` to `.gitignore` (already done)

---

## VERIFICATION

### Check Variables Are Set

In your deployed app, open browser console and run:
```javascript
console.log('Supabase URL:', process.env.NEXT_PUBLIC_SUPABASE_URL);
console.log('Paystack Key:', process.env.NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY);
```

Both should show values (not `undefined`).

### Test Supabase Connection

The login page should work. If you see "Invalid API key", check your Supabase keys.

### Test Paystack

Try initiating a payment. If you see "PAYSTACK_PUBLIC_KEY not configured" warning, the key is missing.

---

## TROUBLESHOOTING

| Issue | Cause | Solution |
|-------|-------|----------|
| "Invalid API key" | Wrong Supabase key | Verify key in Supabase dashboard |
| "PAYSTACK_PUBLIC_KEY not configured" | Missing env var | Add `NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY` in Vercel |
| Variables undefined | Not redeployed | Redeploy after adding variables |
| Works locally, fails on Vercel | Variables not added to Vercel | Add all variables in Vercel dashboard |
| "service_role key exposed" error | Using service_role in client | Only use in server-side API routes |

---

## FLUTTER APP CONFIGURATION

The Flutter app uses different configuration:

### Option 1: Environment Variables (Recommended)

Create `.env` file or use `--dart-define`:

```bash
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
```

### Option 2: Update Constants

Edit `lib/core/constants/supabase_constants.dart`:

```dart
class SupabaseConstants {
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOi...';
  // ...
}
```

⚠️ Don't commit real keys to Git!

---

## SECURITY CHECKLIST

- [ ] `SUPABASE_SERVICE_ROLE_KEY` only used in server-side code (API routes)
- [ ] `PAYSTACK_SECRET_KEY` only used in webhook handler
- [ ] `.env.local` is in `.gitignore`
- [ ] No keys hardcoded in source code
- [ ] Production uses live Paystack keys
- [ ] Preview/Dev uses test Paystack keys

---

> **Setup Guide Created:** January 24, 2026  
> **Variables Required:** 5  
> **Security Level:** Production Ready
