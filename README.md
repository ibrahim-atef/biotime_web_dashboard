# BioTime Web Dashboard (حضوري)

Flutter web dashboard for BioTime HR.

**Live site:** https://ibrahim-atef.github.io/biotime_web_dashboard/

## Deploy to GitHub Pages (important)

Use **GitHub Actions** as the Pages source — not "Deploy from a branch".

1. Open https://github.com/ibrahim-atef/biotime_web_dashboard/settings/pages
2. **Build and deployment → Source:** select **`GitHub Actions`** (not "Deploy from a branch")
3. Push to `main` or re-run workflow: https://github.com/ibrahim-atef/biotime_web_dashboard/actions
4. Open https://ibrahim-atef.github.io/biotime_web_dashboard/ — you should see the **login screen**, not this README

### If deploy fails with "in progress deployment"

1. Open **Actions** → cancel any running **pages build and deployment** workflows
2. Wait 2 minutes
3. Re-run **Deploy Flutter Web**

### If you still see README instead of the app

- You are on **Deploy from a branch → main** — switch to **GitHub Actions**
- Hard refresh: `Ctrl + Shift + R`
- Repo homepage (`github.com/.../biotime_web_dashboard`) always shows README — the app is only at the **github.io** link above

## Local development

```bash
flutter pub get
flutter run -d chrome
```

## Backend on your PC (for external testers)

The website is public; the **API runs on your machine**.

### 1. Start backend

```bash
cd ../biotime_backend
npm run dev
```

Verify: http://localhost:3000/api/health

### 2. Expose with ngrok

```bash
ngrok config add-authtoken YOUR_TOKEN
ngrok http 3000
```

### 3. Tester login

Open the live site → enter ngrok URL in **رابط الباك اند** → sign in.

Optional repo secret: `BIOTIME_API_URL` = your ngrok URL (default build uses localhost).
