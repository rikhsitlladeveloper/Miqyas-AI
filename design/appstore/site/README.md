# METRX support + privacy site

A small static website for the METRX iPhone app. App Store Connect needs its two links:

| File | What it is | App Store Connect field |
|---|---|---|
| `index.html` | Support page: what the app is, the contact email, FAQ | **Support URL** |
| `privacy.html` | Privacy policy (effective 25 Oct 2026) | **Privacy Policy URL** |
| `.nojekyll` | Tells GitHub Pages to serve the files as they are | — |

Each page has three languages: Uzbek (default), Russian and English. The switch at the top uses the address's ending:
`privacy.html#uz`, `privacy.html#ru`, `privacy.html#en`. Each page carries its own CSS (light and dark follow the phone's setting). There are no scripts, web fonts or trackers, and nothing is loaded from other sites.

## Publish with GitHub Pages (about 5 minutes)

1. On github.com, create a **new public repository**, for example `metrx-app`. Don't add a README.
2. Upload the files from this folder **to the repository's root**: `index.html`, `privacy.html`, `.nojekyll`. This README is optional.
   - In the browser: **Add file → Upload files** and drag them in. The `.nojekyll` file is hidden on Windows; if the upload skips it, use **Add file → Create new file**, name it `.nojekyll`, leave it empty and commit.
   - Or from a terminal inside this folder:
     ```
     git init -b main
     git add index.html privacy.html .nojekyll README.md
     git commit -m "METRX support and privacy site"
     git remote add origin https://github.com/<your-user>/metrx-app.git
     git push -u origin main
     ```
3. In the repository: **Settings → Pages → Build and deployment → Source: Deploy from a branch**, branch **main**, folder **/ (root)**, then **Save**.
4. Wait 1–2 minutes. The site is then at `https://<your-user>.github.io/metrx-app/`.
5. In App Store Connect, enter:
   - Support URL: `https://<your-user>.github.io/metrx-app/`
   - Privacy Policy URL: `https://<your-user>.github.io/metrx-app/privacy.html`
6. Open both links on your phone and check all three languages before you submit.

## Changing the policy later

Edit `privacy.html` in all three language sections, change the effective date in each, and upload again. If the app ever starts sending data off the phone (for example cloud sync), update the policy **before** that version ships, and update the App Privacy answers in App Store Connect too.
