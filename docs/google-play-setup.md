# Google Play Store Setup Guide

## Prerequisites

- [ ] Google Play Developer account ($25 one-time fee)
- [ ] App signed with release keystore
- [ ] Privacy policy URL (hosted externally)
- [ ] App icon (512x512 PNG)
- [ ] Feature graphic (1024x500 PNG)
- [ ] Screenshots for phone and tablet

## Step 1: Create Google Play Developer Account

1. Go to [Google Play Console](https://play.google.com/console)
2. Sign in with your Google account
3. Pay the $25 one-time registration fee
4. Complete developer profile

## Step 2: Create New App

1. Click "Create app" in Play Console
2. Fill in app details:
   - **App name:** Trackwise
   - **Default language:** English (US)
   - **App or game:** App
   - **Free or paid:** Free
3. Accept Developer Program Policies
4. Click "Create app"

## Step 3: Set Up Store Listing

### Main Store Listing

Navigate to **Grow > Store presence > Main store listing**

**App Details:**
- **App name:** Trackwise
- **Short description (80 chars):**
  ```
  Track habits with physical ESP32 buttons. Real-time sync, charts & GDPR export.
  ```
- **Full description (4000 chars):**
  ```
  Trackwise - Habit Tracker with ESP32 Integration

  Track your daily habits with physical buttons! Trackwise connects to ESP32 hardware, letting you log events with a simple button press.

  FEATURES:
  - Create unlimited items to track
  - Real-time sync with ESP32 hardware via Bluetooth
  - Beautiful charts and statistics
  - Data export as JSON (GDPR compliant)
  - Account deletion option (GDPR compliant)
  - Clean, intuitive interface

  HOW IT WORKS:
  1. Create items to track (e.g., "Coffee", "Exercise", "Reading")
  2. Send item list to your ESP32 device via Bluetooth
  3. Press physical buttons to log events
  4. View real-time charts and statistics in the app
  5. Export your data anytime

  PRIVACY FIRST:
  Your data is stored securely in Firebase and never shared with third parties. Full GDPR compliance with data export and account deletion available directly in the app.

  Perfect for habit tracking, productivity, and IoT enthusiasts!
  ```

### Graphics

**App icon:**
- Size: 512 x 512 pixels
- Format: 32-bit PNG
- No transparency

**Feature graphic:**
- Size: 1024 x 500 pixels
- Format: PNG or JPEG
- Used in Play Store featured sections

**Screenshots:**
- Phone: 2-8 images, 16:9 or 9:16 aspect ratio
  - Recommended: 1080 x 1920 pixels
- 7-inch tablet: 2-8 images (optional)
- 10-inch tablet: 2-8 images (optional)

**Screenshot suggestions:**
1. Home screen with items list
2. Item detail with chart
3. Bluetooth device connection
4. Profile/Settings page
5. Data export confirmation
6. Add new item dialog

## Step 4: App Content

Navigate to **Policy > App content**

### Privacy Policy
- Add your privacy policy URL
- URL must be publicly accessible
- Recommended: Host on GitHub Pages

### App Access
- Select "All functionality is available without special access"

### Ads
- Select "No, my app does not contain ads"

### Content Rating
Complete the questionnaire:
1. Start new rating
2. Select app category: Utility
3. Answer questions honestly
4. Expected rating: PEGI 3 / Everyone

### Target Audience
- Select: 18 and over
- Confirm app is not designed for children

### News App
- Select: This is not a news app

### COVID-19 Apps
- Select: This is not a COVID-19 app

### Data Safety
Complete the data safety form:

**Data collection:**
- [ ] Email address - Collected for account functionality
- [ ] User-generated content - Items and events created by user

**Data sharing:**
- No data is shared with third parties

**Security practices:**
- [x] Data is encrypted in transit
- [x] Users can request data deletion

## Step 5: Release Setup

### Create Internal Testing Track

1. Navigate to **Release > Testing > Internal testing**
2. Click "Create new release"
3. Upload your AAB file
4. Add release notes:
   ```
   Initial release of Trackwise
   - Create and track items
   - ESP32 Bluetooth connectivity
   - Real-time charts and statistics
   - GDPR data export
   - Account management
   ```
5. Save and review release
6. Start rollout to internal testing

### Internal Testing Tips
- Add up to 100 internal testers
- No app review required
- Updates available within minutes
- Test all features before production

## Step 6: Production Release

After internal testing is complete:

1. Navigate to **Release > Production**
2. Click "Create new release"
3. Select the AAB from internal testing
4. Add release notes
5. Review and start rollout

### Review Timeline
- First submission: 3-7 days
- Updates: Usually 1-3 days
- May take longer if policy issues found

## Build Commands

### Generate Release AAB

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build release AAB
flutter build appbundle --release

# Output location: build/app/outputs/bundle/release/app-release.aab
```

### Generate Release APK (for testing)

```bash
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

## Signing Setup

### Create Keystore (one-time)

```bash
keytool -genkey -v -keystore trackwise-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias trackwise
```

### Configure Signing in android/key.properties

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=trackwise
storeFile=../trackwise-release.jks
```

### Update android/app/build.gradle

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

## Checklist Before Submission

- [ ] App builds without errors
- [ ] All features work correctly
- [ ] Privacy policy URL is accessible
- [ ] App icon meets requirements
- [ ] Screenshots are high quality
- [ ] Store listing is complete
- [ ] Data safety form is complete
- [ ] Content rating questionnaire is complete
- [ ] Internal testing passed
- [ ] No policy violations

## Common Issues

### App Rejected for Policy Violation
- Review the rejection email carefully
- Common issues: misleading descriptions, missing privacy policy
- Fix issues and resubmit

### AAB Upload Fails
- Ensure you're uploading AAB, not APK
- Check version code is higher than previous
- Verify signing configuration

### Screenshots Rejected
- Ensure no device frames in screenshots
- Remove any promotional text overlays
- Use actual app screenshots, not mockups

## Support Resources

- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [Android Developers](https://developer.android.com/distribute)
- [Play Console Policy Center](https://play.google.com/console/about/policy-center)
