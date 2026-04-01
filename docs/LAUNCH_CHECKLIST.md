# Traxelos Launch Checklist

## Code & Build (DONE)
- [x] Rename app ID to `com.traxelos.app` (Android + iOS)
- [x] Configure Android release signing (keystore generated)
- [x] Add ProGuard rules for production
- [x] Enable code obfuscation in release builds
- [x] Bump version to 1.1.0, update CHANGELOG
- [x] Pin all dependencies
- [x] Add iOS export compliance declaration
- [x] Update CI/CD pipeline (signing, obfuscation, iOS build, Firebase config)
- [x] Register `com.traxelos.app` in Firebase Console (Android + iOS)
- [x] Update `GOOGLE_SERVICES_JSON` GitHub secret
- [x] Verify all tests pass (847/847)
- [x] Verify debug, release, and obfuscated builds succeed
- [x] CI green on master

## Accounts
- [ ] Create Google Play Developer account ($25 one-time) — https://play.google.com/console
- [ ] Create Apple Developer account ($99/year) — https://developer.apple.com/programs/

## Signing & Secrets (after accounts)
- [ ] Back up `release-keystore.jks` + password to password manager
- [ ] Add GitHub secrets: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`
- [ ] Add GitHub secret: `GOOGLE_SERVICE_INFO_PLIST` (base64 of iOS Firebase config)
- [ ] Enable Google Play App Signing (during first upload — recommended safety net)
- [ ] Create iOS distribution certificate (Apple Developer portal)
- [ ] Create iOS App Store provisioning profile for `com.traxelos.app`
- [ ] Add iOS signing to CI (certificates + profiles as GitHub secrets)

## Store Listings — Android
- [ ] Create app in Google Play Console
- [ ] App name: Traxelos
- [ ] Short description (80 chars max)
- [ ] Full description (4000 chars max)
- [ ] App icon (512x512 PNG)
- [ ] Feature graphic (1024x500 PNG)
- [ ] Screenshots — phone (min 2, recommended 4-8)
- [ ] Screenshots — tablet (optional but recommended)
- [ ] App category (Tools? Productivity?)
- [ ] Content rating questionnaire
- [ ] Privacy policy URL
- [ ] Target audience and content declarations
- [ ] Pricing & distribution (free/paid, countries)

## Store Listings — iOS
- [ ] Create app in App Store Connect
- [ ] App name: Traxelos
- [ ] Subtitle (30 chars max)
- [ ] Description
- [ ] Keywords (100 chars max, comma-separated)
- [ ] App icon (1024x1024 PNG, no alpha)
- [ ] Screenshots — 6.7" (iPhone 15 Pro Max, required)
- [ ] Screenshots — 6.5" (iPhone 11 Pro Max, required)
- [ ] Screenshots — 5.5" (iPhone 8 Plus, optional)
- [ ] Screenshots — iPad (optional unless supporting iPad)
- [ ] App category
- [ ] Age rating questionnaire
- [ ] Privacy policy URL (same as Android)
- [ ] App privacy details (data collection declarations)

## Privacy Policy
- [ ] Write privacy policy covering: data collected, Firebase usage, BLE data, analytics
- [ ] Host at a public URL (Firebase Hosting, GitHub Pages, or your domain)
- [ ] Add URL to both store listings
- [ ] Verify in-app privacy policy viewer matches hosted version

## Testing
- [ ] Upload first build to Google Play internal testing track
- [ ] Upload first build to TestFlight
- [ ] Test on multiple Android devices (different API levels)
- [ ] Test on multiple iOS devices (different iOS versions)
- [ ] Test fresh install flow (onboarding)
- [ ] Test BLE pairing with physical device
- [ ] Test OTA firmware update flow
- [ ] Verify Crashlytics receives test crash reports
- [ ] Verify Analytics events appear in Firebase Console

## Launch
- [ ] Promote Android from internal → open testing (or production)
- [ ] Submit iOS for App Review
- [ ] Monitor Crashlytics for first 48 hours
- [ ] Monitor store reviews
