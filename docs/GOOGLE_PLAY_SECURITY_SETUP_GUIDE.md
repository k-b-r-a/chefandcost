# Google Play Security & Integrity Activation Guide

This guide provides the exact step-by-step checklist to activate all previously disabled security services in **Google Play Console** and **Google Cloud Console** now that the client-side (`StandardIntegrityManager`, `BillingFlowParams` obfuscated IDs) and backend verification have been implemented.

---

## 1. Google Cloud Console: Enable Play Integrity API & Service Account

1. Open [Google Cloud Console](https://console.cloud.google.com/) with the project `chefycost` (Project Number: `194514517992`).
2. Navigate to **APIs & Services > Library**.
3. Search for **Google Play Integrity API** and click **Enable**.
4. Navigate to **IAM & Admin > Service Accounts**.
5. Click **Create Service Account**:
   - Name: `play-integrity-verifier`
   - Role: **Service Account Token Creator** / **Viewer**
6. Click into the newly created service account, go to **Keys > Add Key > Create new key > JSON**, and save the file safely (e.g. `service-account.json`).
7. In Google Play Console:
   - Go to **API Access** (in Developer account settings).
   - Find the linked service account `play-integrity-verifier@chefycost.iam.gserviceaccount.com` and grant permissions:
     - Check: **View app information and download bulk reports (read-only)**.

---

## 2. Play Integrity API Configuration (0/7 -> 7/7 Active)

Navigate to **Google Play Console > Your App (`Chef&Cost`) > Release > App Integrity**:

### A. Link Google Cloud Project
1. Under **Play Integrity API**, click **Settings** or **Link Cloud Project**.
2. Select your Google Cloud Project: `chefycost` (`194514517992`).
3. Click **Link**.

### B. Response Configuration (Enable all 7 verdicts)
In **App Integrity > Play Integrity API**:
1. Click **Settings** or **Edit response**.
2. Toggle / Check the following 7 signals:
   - [x] **Play licensing checks**: Detect unauthorized access and unlicensed downloads.
   - [x] **App integrity checks**: Detect app tampering, cracking, or modified APKs (`PLAY_RECOGNIZED`).
   - [x] **Device integrity checks**: Detect risky, rooted, or uncertified devices (`MEETS_DEVICE_INTEGRITY`).
   - [x] **Virtual integrity checks**: Detect Play Games for PC and emulators (`MEETS_VIRTUAL_INTEGRITY`).
   - [x] **Recent device activity**: Detect hyperactive devices and automated token farms (`LEVEL_1` to `LEVEL_4`).
   - [x] **Play Protect status**: Detect known malicious software installed on the device (`NO_ISSUES`, `WARNING`, `DANGEROUS`).
   - [x] **App access risk**: Detect apps with risky permissions or active overlays drawing over the screen (tapjacking defense).
3. Click **Save changes**.

---

## 3. Play Store Protection: Store Listing Device Checks (6/7 -> 7/7 Active)

This setting prevents risky or non-certified devices from installing or seeing your app in Google Play Store.

1. Navigate to **Release > App Integrity**.
2. Scroll to **Play Store Protection** or click **Device catalog** in the left menu.
3. Locate **Store listing device checks**:
   - Toggle **Turn ON store listing device checks**.
   - Select the integrity tier requirement: **Meets device integrity** (`MEETS_DEVICE_INTEGRITY`).
4. Click **Save**.
5. Devices that fail basic device certification or have compromised system integrity will no longer be offered app downloads from Google Play.

---

## 4. Play Billing Protection (0/4 -> 4/4 Active)

Now that the app passes `obfuscatedAccountId` and `obfuscatedProfileId` in `BillingFlowParams` through `InAppPurchaseAndroidPlatform`, Google Play automatically activates all 4 billing fraud protections.

1. Navigate to **Monetize > In-app products / Subscriptions > Settings** (or **Monetization setup**).
2. Under **Fraud and risk settings** / **Play Billing Protection**:
   - [x] **Fraud and abuse monitoring**: Automatically monitor and block high-risk purchase attempts and card testing attacks.
   - [x] **Gift card protection**: Prevent fraudulent redemption and draining of Google Play gift cards across cloned accounts.
   - [x] **Location spoofing protection**: Block region-spoofed purchases where device geolocation conflicts with billing territory.
   - [x] **Offer usage limits**: Restrict introductory offers and free trials to 1 per unique user account regardless of reinstallations.
3. Click **Save changes**.

---

## 5. Deployment & Verification Checklist

- [x] Build app release bundle:
  ```bash
  flutter build appbundle --release
  ```
- [x] Upload the `.aab` to Google Play Console Internal Testing or Closed Track.
- [x] Deploy the backend integrity verification function:
  ```bash
  # Via Firebase Cloud Functions:
  firebase deploy --only functions

  # Or standalone Node.js server:
  cd backend && npm start
  ```
- [x] Check Play Console dashboards after the first test purchase and login:
  - **App integrity dashboard**: Inspect token request volume, pass rates, and breakdown.
  - **Monetize dashboard**: Verify fraud prevention indicators are green.
