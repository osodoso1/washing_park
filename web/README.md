# PicklePark Web & Android Progressive Web App (PWA)

This directory contains the mobile-first Progressive Web App (PWA) for **PicklePark: Washington Park**.

---

## 🚀 1-Click Free Hosting Deployments

### **Option A: Cloudflare Pages (Recommended - 100% Free Forever)**
1. Install Wrangler CLI (if not already installed):
   ```bash
   npm install -g wrangler
   ```
2. Deploy the `web` folder:
   ```bash
   npx wrangler pages deploy web --project-name=picklepark
   ```
   *Your app is instantly live at `https://picklepark.pages.dev` with free SSL and global CDN!*

---

### **Option B: Vercel (Free)**
1. Deploy with Vercel CLI:
   ```bash
   npx vercel web --prod
   ```

---

### **Option C: GitHub Pages (Free)**
1. Push this repository to GitHub.
2. In Repository Settings ➔ **Pages**, set source to the `web/` folder.

---

## 📱 Android User Experience
When Android users open the URL in Chrome:
1. Chrome displays an automatic prompt: **"Add PicklePark to Home screen"**.
2. It installs with its own app icon and runs full-screen like a native Android app!
