# Apple App Store Setup Guide

## Prerequisites

- [ ] Mac computer with Xcode installed
- [ ] Apple Developer account ($99/year)
- [ ] App signed with distribution certificate
- [ ] Privacy policy URL (hosted externally)
- [ ] App icon (1024x1024 PNG, no transparency)
- [ ] Screenshots for required device sizes

## Step 1: Enroll in Apple Developer Program

1. Go to [Apple Developer](https://developer.apple.com/programs/)
2. Click "Enroll"
3. Sign in with Apple ID
4. Complete enrollment ($99/year)
5. Wait for approval (usually 24-48 hours)

## Step 2: Create App ID

1. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers)
2. Click "+" to create new identifier
3. Select "App IDs" and click Continue
4. Select "App" type
5. Fill in details:
   - **Description:** Trackwise
   - **Bundle ID:** Explicit - `com.yourcompany.trackwise`
6. Select Capabilities:
   - [x] Push Notifications (if using)
   - [x] Sign in with Apple (if using)
7. Click Continue and Register

## Step 3: Create Distribution Certificate

1. Go to [Certificates](https://developer.apple.com/account/resources/certificates)
2. Click "+" to create new certificate
3. Select "Apple Distribution"
4. Follow instructions to create CSR from Keychain Access
5. Upload CSR and download certificate
6. Double-click to install in Keychain

## Step 4: Create Provisioning Profile

1. Go to [Profiles](https://developer.apple.com/account/resources/profiles)
2. Click "+" to create new profile
3. Select "App Store" under Distribution
4. Select your App ID (com.yourcompany.trackwise)
5. Select your Distribution Certificate
6. Name the profile: "Trackwise Distribution"
7. Download and double-click to install

## Step 5: Create App in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click "My Apps"
3. Click "+" and select "New App"
4. Fill in details:
   - **Platforms:** iOS
   - **Name:** Trackwise
   - **Primary Language:** English (U.S.)
   - **Bundle ID:** Select your App ID
   - **SKU:** trackwise-001
   - **User Access:** Full Access
5. Click "Create"

## Step 6: App Information

Navigate to **App Store > App Information**

### General
- **Name:** Trackwise
- **Subtitle:** Habit Tracker with ESP32
- **Category:** Productivity
- **Secondary Category:** Utilities

### Content Rights
- Does not contain third-party content requiring rights

### Age Rating
Complete the questionnaire:
- No objectionable content
- Expected rating: 4+ (suitable for all ages)

## Step 7: Pricing and Availability

Navigate to **App Store > Pricing and Availability**

- **Price:** Free
- **Availability:** Available in all territories
- **Pre-Orders:** No

## Step 8: App Privacy

Navigate to **App Store > App Privacy**

### Privacy Policy URL
- Add your privacy policy URL
- Must be publicly accessible

### Data Collection
Click "Get Started" and complete:

**Contact Info:**
- [x] Email Address
  - Used for: App Functionality
  - Linked to User: Yes
  - Used for Tracking: No

**User Content:**
- [x] Other User Content (items, events)
  - Used for: App Functionality
  - Linked to User: Yes
  - Used for Tracking: No

**Identifiers:**
- [x] User ID
  - Used for: App Functionality
  - Linked to User: Yes
  - Used for Tracking: No

## Step 9: Store Listing (Version Information)

Navigate to **App Store > iOS App > (Version)**

### Screenshots

**Required sizes:**
- 6.7" Display (iPhone 14 Pro Max): 1290 x 2796 pixels
- 6.5" Display (iPhone 11 Pro Max): 1242 x 2688 pixels
- 5.5" Display (iPhone 8 Plus): 1242 x 2208 pixels
- 12.9" Display (iPad Pro): 2048 x 2732 pixels (if supporting iPad)

**Screenshot suggestions:**
1. Home screen with items list
2. Item detail with chart
3. Bluetooth device connection
4. Profile/Settings page
5. Data export feature
6. Add new item dialog

### Promotional Text (170 chars, can be updated without review)
```
Track habits with physical ESP32 buttons! Real-time sync, beautiful charts, and full GDPR compliance.
```

### Description (4000 chars)
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

### Keywords (100 chars, comma-separated)
```
habit,tracker,ESP32,IoT,productivity,counter,tally,bluetooth,fitness,goals
```

### Support URL
- Your website or GitHub repository

### Marketing URL (optional)
- Landing page for your app

### App Clip (optional)
- Not applicable

## Step 10: Build and Upload

### Configure Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Runner" in project navigator
3. Under "Signing & Capabilities":
   - Team: Select your team
   - Bundle Identifier: `com.yourcompany.trackwise`
   - Signing Certificate: Apple Distribution
   - Provisioning Profile: Trackwise Distribution

### Build Archive

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build iOS release
flutter build ios --release

# Or build IPA directly
flutter build ipa --release
```

### Upload via Xcode

1. Open Xcode
2. Product > Archive
3. Wait for archive to complete
4. Click "Distribute App"
5. Select "App Store Connect"
6. Select "Upload"
7. Select options (default is fine)
8. Upload

### Upload via Transporter (alternative)

1. Download [Transporter](https://apps.apple.com/app/transporter/id1450874784) from Mac App Store
2. Sign in with Apple ID
3. Drag and drop IPA file
4. Click "Deliver"

## Step 11: Submit for Review

1. Go to App Store Connect
2. Select your app
3. Select the version
4. Under "Build", click "+" and select your uploaded build
5. Fill in:
   - **Version Release:** Manually release this version
   - **Phased Release:** Optional
6. Answer Export Compliance questions
7. Click "Submit for Review"

### Review Notes (for Apple reviewers)
```
Test Account:
Email: test@example.com
Password: TestPassword123

Bluetooth Device:
This app connects to ESP32 hardware via Bluetooth. For testing without hardware, you can:
1. Create items in the app
2. View charts with sample data
3. Test data export feature
4. Test account deletion feature

The Bluetooth features require actual ESP32 hardware to test fully.
```

## Step 12: App Review

### Timeline
- First submission: 24-48 hours (can be longer)
- Updates: Usually 24 hours
- Expedited review: Available for critical fixes

### Common Rejection Reasons

1. **Incomplete Information**
   - Missing privacy policy
   - Incomplete App Privacy details
   - Missing demo account

2. **Guideline 4.2 - Minimum Functionality**
   - App must provide value beyond basic web content
   - Ensure all features work properly

3. **Guideline 5.1.1 - Data Collection**
   - Privacy policy must match App Privacy details
   - Explain all data collection clearly

4. **Guideline 2.1 - App Completeness**
   - App must work without crashes
   - All features must be functional

### If Rejected
1. Read rejection message carefully
2. Fix all mentioned issues
3. Reply to App Review with explanation
4. Resubmit for review

## Build Commands Reference

### Debug Build
```bash
flutter run --debug
```

### Release Build
```bash
flutter build ios --release
```

### Build IPA
```bash
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

### ExportOptions.plist (for CI/CD)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <true/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
```

## Checklist Before Submission

- [ ] App builds and runs without errors
- [ ] All features work correctly
- [ ] Privacy policy URL is accessible
- [ ] App Privacy questionnaire complete
- [ ] App icon meets requirements (1024x1024, no transparency)
- [ ] Screenshots for all required sizes
- [ ] Store listing complete
- [ ] Age rating questionnaire complete
- [ ] Test account provided (if login required)
- [ ] Export compliance questions answered
- [ ] No private API usage
- [ ] No placeholder content

## TestFlight (Beta Testing)

### Internal Testing
1. Go to App Store Connect > TestFlight
2. Add internal testers (up to 100)
3. Builds available immediately after processing

### External Testing
1. Go to TestFlight > External Testing
2. Create test group
3. Add external testers (up to 10,000)
4. Submit build for beta review
5. Review usually takes 24-48 hours

## Support Resources

- [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple Developer Forums](https://developer.apple.com/forums/)
