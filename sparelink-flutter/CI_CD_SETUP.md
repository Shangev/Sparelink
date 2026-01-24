# 🚀 CI/CD SETUP GUIDE

> **Pass 5: Infrastructure, CI/CD & Launch Readiness**  
> **Last Updated:** January 24, 2026

---

## Overview

SpareLink uses GitHub Actions for CI/CD:
- **Flutter App:** Automated testing, APK/AAB builds
- **Shop Dashboard:** Automated deployment to Vercel

---

## Required GitHub Secrets

Go to: **Repository → Settings → Secrets and variables → Actions**

### Supabase Secrets

| Secret Name | Description | Where to Find |
|-------------|-------------|---------------|
| `SUPABASE_URL` | Supabase project URL | Supabase Dashboard → Settings → API |
| `SUPABASE_ANON_KEY` | Supabase anon/public key | Supabase Dashboard → Settings → API |

### Vercel Secrets (for Dashboard deployment)

| Secret Name | Description | Where to Find |
|-------------|-------------|---------------|
| `VERCEL_TOKEN` | Vercel API token | Vercel → Settings → Tokens → Create |
| `VERCEL_ORG_ID` | Your Vercel organization ID | `.vercel/project.json` after `vercel link` |
| `VERCEL_PROJECT_ID` | Your Vercel project ID | `.vercel/project.json` after `vercel link` |

### Optional: Notification Secrets

| Secret Name | Description | Where to Find |
|-------------|-------------|---------------|
| `SLACK_WEBHOOK_URL` | Slack webhook for notifications | Slack → Apps → Incoming Webhooks |
| `DISCORD_WEBHOOK_URL` | Discord webhook for notifications | Discord → Server Settings → Integrations |

---

## Step-by-Step Setup

### 1. Get Supabase Keys

```bash
# From Supabase Dashboard (app.supabase.com):
# 1. Select your project
# 2. Go to Settings → API
# 3. Copy:
#    - Project URL → SUPABASE_URL
#    - anon public key → SUPABASE_ANON_KEY
```

### 2. Get Vercel Credentials

```bash
# Install Vercel CLI
npm install -g vercel

# Login to Vercel
vercel login

# Link your project (run from shop-dashboard directory)
cd shop-dashboard
vercel link

# This creates .vercel/project.json with:
# - orgId → VERCEL_ORG_ID
# - projectId → VERCEL_PROJECT_ID

# Create API token
# Go to: https://vercel.com/account/tokens
# Click "Create" → Copy the token → VERCEL_TOKEN
```

### 3. Add Secrets to GitHub

1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret:

```
Name: SUPABASE_URL
Value: https://your-project.supabase.co

Name: SUPABASE_ANON_KEY
Value: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

Name: VERCEL_TOKEN
Value: your-vercel-api-token

Name: VERCEL_ORG_ID
Value: team_xxxxxxxxxxxxxxxx

Name: VERCEL_PROJECT_ID
Value: prj_xxxxxxxxxxxxxxxx
```

---

## Workflows

### Flutter CI (`flutter-ci.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main`

**Jobs:**
1. **Analyze & Test** - Runs `flutter analyze` and `flutter test`
2. **Build Android** - Creates release APK and AAB (main branch only)
3. **Build Web** - Creates web build (main branch only)
4. **Notify on Failure** - Sends alert if build fails

**Artifacts Generated:**
- `sparelink-release-apk` - Android APK file
- `sparelink-release-aab` - Android App Bundle (for Play Store)
- `sparelink-web` - Web build files

### Dashboard CI (`dashboard-ci.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main`

**Jobs:**
1. **Lint & Type Check** - TypeScript validation
2. **Run Tests** - Jest tests
3. **Deploy to Vercel** - Production deployment (main branch)
4. **Deploy Preview** - Preview deployment (pull requests)

---

## Manual Deployment

### Flutter App (Android)

```bash
# Build release APK
flutter build apk --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

# Build App Bundle (for Play Store)
flutter build appbundle --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

# Output locations:
# APK: build/app/outputs/flutter-apk/app-release.apk
# AAB: build/app/outputs/bundle/release/app-release.aab
```

### Shop Dashboard (Vercel)

```bash
cd shop-dashboard

# Install dependencies
npm install

# Build
npm run build

# Deploy to production
vercel --prod

# Deploy preview
vercel
```

---

## Play Store Deployment

### Prerequisites

1. Google Play Developer Account ($25 one-time fee)
2. App signing key (generated or uploaded)
3. Store listing assets (screenshots, description, icon)

### Steps

1. **Create App in Play Console**
   - Go to [play.google.com/console](https://play.google.com/console)
   - Click "Create app"
   - Fill in app details

2. **Upload AAB**
   - Go to Release → Production
   - Create new release
   - Upload the `.aab` file from CI artifacts

3. **Complete Store Listing**
   - App name: SpareLink
   - Short description: Auto parts marketplace for mechanics
   - Full description: (see marketing materials)
   - Screenshots: Phone and tablet
   - Feature graphic: 1024x500px

4. **Submit for Review**
   - Complete all required sections
   - Submit for review (usually 1-3 days)

### Automated Play Store Deployment (Advanced)

Add to `flutter-ci.yml`:

```yaml
- name: 🚀 Deploy to Play Store
  uses: r0adkll/upload-google-play@v1
  with:
    serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON }}
    packageName: com.sparelink.app
    releaseFiles: build/app/outputs/bundle/release/app-release.aab
    track: internal  # or: alpha, beta, production
    status: completed
```

---

## Monitoring CI/CD

### GitHub Actions Dashboard

View all workflow runs:
- Go to repository → **Actions** tab
- Filter by workflow or branch
- Click on any run to see logs

### Build Status Badges

Add to README.md:

```markdown
![Flutter CI](https://github.com/Shangev/Sparelink/actions/workflows/flutter-ci.yml/badge.svg)
![Dashboard CI](https://github.com/Shangev/Sparelink/actions/workflows/dashboard-ci.yml/badge.svg)
```

### Failure Notifications

To enable Slack notifications, add webhook:

```yaml
# In workflow file
- name: Notify Slack
  if: failure()
  run: |
    curl -X POST -H 'Content-type: application/json' \
      --data '{"text":"🚨 Build failed: ${{ github.workflow }}"}' \
      ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

## Troubleshooting

### "VERCEL_TOKEN is not set"

**Cause:** Missing secret  
**Solution:** Add `VERCEL_TOKEN` to GitHub Secrets

### "Flutter analyze found issues"

**Cause:** Code style or lint errors  
**Solution:** Run `flutter analyze` locally and fix issues

### "Build failed: Java version"

**Cause:** Wrong Java version  
**Solution:** Ensure workflow uses Java 17

### "Vercel deployment failed"

**Cause:** Build errors or missing env vars  
**Solution:** 
1. Check Vercel dashboard for error logs
2. Ensure all env vars are set in Vercel project settings

---

## Security Notes

⚠️ **Never commit secrets to the repository**

- Use GitHub Secrets for all sensitive values
- Use `--dart-define` for Flutter builds
- Use Vercel environment variables for Dashboard
- Rotate keys if accidentally exposed

---

> **CI/CD Setup Complete!**  
> Push to `main` to trigger automated builds and deployments.
