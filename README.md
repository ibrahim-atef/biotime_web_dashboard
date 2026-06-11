# BioTime Web Dashboard (حضوري)

**Live site:** https://ibrahim-atef.github.io/biotime_web_dashboard/

## Public API for any mobile network (best setup)

The website is on GitHub. The API runs on **your PC**. Mobile data / other Wi‑Fi needs an **HTTPS tunnel**.

### On your PC (one command)

```bash
cd ../biotime_backend
npm run public
```

This starts:
- Backend on port **3000**
- **Cloudflare HTTPS tunnel** (works from any phone, any network)

Copy the printed URL, then update the live site default:

```bash
npm run public:deploy
```

Or manually push after `npm run public` updates `web/tunnel-url.json`.

### Tester flow

1. Open https://ibrahim-atef.github.io/biotime_web_dashboard/
2. Login page auto-fills **رابط الباك اند** from `tunnel-url.json`
3. Sign in with app credentials

**Keep `npm run public` running** while testers use the app.

### Same Wi‑Fi only (no tunnel)

Use `http://YOUR_PC_IP:3000` on login (e.g. `http://192.168.10.32:3000`).

---

## Deploy to GitHub Pages

1. Pages **Source:** `GitHub Actions`
2. Push to `main` → auto deploy

## Local development

```bash
flutter pub get
flutter run -d chrome
```
