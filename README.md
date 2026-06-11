# BioTime Web Dashboard (حضوري)

Flutter web dashboard for BioTime HR — deployed to GitHub Pages.

**Live site:** https://ibrahim-atef.github.io/biotime_web_dashboard/

## Local development

```bash
flutter pub get
flutter run -d chrome
```

## Deploy to GitHub Pages

1. Push to `main` — workflow builds Flutter web into the **`docs/`** folder on `main`
2. **Enable Pages (required once):**
   - Open https://github.com/ibrahim-atef/biotime_web_dashboard/settings/pages
   - **Build and deployment → Source:** `Deploy from a branch`
   - **Branch:** `main` → folder **`/docs`** → **Save**
3. Wait 1–2 minutes, then open https://ibrahim-atef.github.io/biotime_web_dashboard/
4. Optional: repo secret `BIOTIME_API_URL` = your ngrok/public backend URL

### If you see README instead of the app

Pages is serving **`/(root)`** (README) instead of **`/docs`** (built app). Change the folder to **`/docs`** in Pages settings and save.

## Backend on your PC (for external testers)

The website is public; the **API runs on your machine**.

### 1. Start backend (port 3000, all interfaces)

```bash
cd ../biotime_backend
npm run dev
```

Backend listens on `0.0.0.0:3000` — verify: http://localhost:3000/api/health

### 2. Expose port to the internet (ngrok example)

```bash
ngrok http 3000
```

Copy the HTTPS URL (e.g. `https://abc123.ngrok-free.app`).

### 3. CORS

In `biotime_backend/.env` add GitHub Pages origin:

```
CORS_ORIGINS=http://localhost:3000,https://ibrahim-atef.github.io
```

In `NODE_ENV=development` all origins are allowed automatically.

### 4. Windows firewall

Allow inbound TCP **3000** (or use ngrok only — no port forward needed).

### 5. Tester login

Open the deployed site → on login enter your **ngrok URL** as «رابط الباك اند» → sign in with app user credentials.

## Build web manually

```bash
flutter build web --release \
  --base-href "/biotime_web_dashboard/" \
  --dart-define=BIOTIME_API_URL=https://your-ngrok-url.ngrok-free.app
```

Output: `build/web/`
