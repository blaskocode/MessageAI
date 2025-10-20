# MessageAI Setup Guide

This guide will walk you through setting up MessageAI from scratch.

## Prerequisites

- macOS with Xcode 15+ installed
- Apple Developer account (for device testing and push notifications)
- Firebase account (free tier is sufficient for MVP)

## Step-by-Step Setup

### 1. Firebase Project Setup

1. **Create Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Click "Add project"
   - Name it "MessageAI" (or your preferred name)
   - Disable Google Analytics (optional for MVP)
   - Click "Create project"

2. **Register iOS App**
   - Click the iOS icon to add an iOS app
   - Bundle ID: `com.yourname.messageai` (customize this)
   - App nickname: "MessageAI iOS"
   - Download `GoogleService-Info.plist`
   - **Important:** Save this file - you'll add it to Xcode later

3. **Enable Authentication**
   - In Firebase Console, go to "Authentication"
   - Click "Get started"
   - Go to "Sign-in method" tab
   - Enable "Email/Password"
   - Save

4. **Create Firestore Database**
   - Go to "Firestore Database"
   - Click "Create database"
   - Start in **test mode** (we'll add security rules later)
   - Choose a location (use default or closest to you)
   - Click "Enable"

5. **Deploy Security Rules**
   - In Firestore, go to "Rules" tab
   - Copy contents from `firebase/firestore.rules` in this project
   - Paste and publish
   - **Critical:** Don't skip this - it secures your data

6. **Set Up Storage**
   - Go to "Storage" in Firebase Console
   - Click "Get started"
   - Start in **test mode**
   - Use same location as Firestore
   - Click "Done"
   - Go to "Rules" tab
   - Copy contents from `firebase/storage.rules` in this project
   - Paste and publish

7. **Set Up Cloud Messaging (FCM)**
   - Go to "Cloud Messaging" in Firebase Console
   - Note: iOS setup requires APNs key (see next section)

### 2. Apple Developer Setup (APNs for Push Notifications)

1. **Create APNs Authentication Key**
   - Go to [Apple Developer Portal](https://developer.apple.com)
   - Go to "Certificates, Identifiers & Profiles"
   - Click "Keys" in sidebar
   - Click "+" to create a new key
   - Name it "MessageAI APNs Key"
   - Check "Apple Push Notifications service (APNs)"
   - Click "Continue" then "Register"
   - Download the `.p8` file - **you can only download this once!**
   - Note the Key ID

2. **Upload APNs Key to Firebase**
   - In Firebase Console, go to Project Settings (gear icon)
   - Go to "Cloud Messaging" tab
   - Under "APNs Authentication Key", click "Upload"
   - Upload your `.p8` file
   - Enter your Team ID (found in Apple Developer Portal)
   - Enter your Key ID
   - Click "Upload"

### 3. Xcode Project Setup

1. **Open Project**
   ```bash
   cd MessageAI
   open MessageAI.xcodeproj
   ```
   
   **Note:** If `.xcodeproj` doesn't exist yet, you'll need to create it:
   - Open Xcode
   - File → New → Project
   - Choose "iOS" → "App"
   - Product Name: `MessageAI`
   - Organization Identifier: `com.yourname`
   - Interface: SwiftUI
   - Language: Swift
   - Storage: SwiftData
   - Save in the `MessageAI` folder

2. **Add GoogleService-Info.plist**
   - Drag `GoogleService-Info.plist` into Xcode project
   - Make sure "Copy items if needed" is checked
   - Add to target "MessageAI"

3. **Configure Bundle Identifier**
   - Select project in Xcode navigator
   - Select "MessageAI" target
   - Go to "Signing & Capabilities"
   - Set Bundle Identifier to match what you used in Firebase
   - Select your Team

4. **Add Capabilities**
   - Click "+ Capability"
   - Add "Push Notifications"
   - Add "Background Modes"
     - Check "Remote notifications"

5. **Add Firebase Dependencies**
   - File → Add Package Dependencies
   - Enter: `https://github.com/firebase/firebase-ios-sdk`
   - Version: "10.0.0" (or latest)
   - Add these products:
     - FirebaseAuth
     - FirebaseFirestore
     - FirebaseStorage
     - FirebaseMessaging
   - Click "Add Package"

6. **Add SDWebImage for GIFs**
   - File → Add Package Dependencies
   - Enter: `https://github.com/SDWebImage/SDWebImageSwiftUI`
   - Version: "2.0.0" (or latest)
   - Add "SDWebImageSwiftUI"
   - Click "Add Package"

7. **Copy Project Files**
   - Copy all files from the `MessageAI/` directory structure into your Xcode project
   - Make sure to preserve the folder structure:
     - App/
     - Features/
     - Services/
     - Models/
     - Utilities/

### 4. Build and Test

1. **Build the Project**
   - Select your physical iOS device (simulator won't work for push notifications)
   - Press Cmd+B to build
   - Fix any build errors (likely missing imports or typos)

2. **Run on Device**
   - Press Cmd+R to run
   - The app should launch on your device
   - You may need to trust your developer certificate in device Settings

3. **Create Test Accounts**
   - Sign up with 2 different email addresses
   - Use separate devices or sign out/in to test

### 5. Verify Everything Works

Test these core features:
- [ ] Sign up creates account
- [ ] Sign in works
- [ ] Can see conversation list
- [ ] Can send message
- [ ] Message appears on other device (< 1 second)
- [ ] Messages persist after force-quit
- [ ] Offline message queuing works
- [ ] Push notification appears

### 6. Troubleshooting

**Build Errors:**
- Ensure all Firebase packages are added correctly
- Check that `GoogleService-Info.plist` is in the project
- Verify bundle identifier matches Firebase

**Can't Sign In:**
- Check Firebase Authentication is enabled
- Check Firestore security rules are deployed
- Look at Firebase Console logs

**No Push Notifications:**
- Must test on physical device (not simulator)
- Verify APNs key is uploaded to Firebase
- Check that "Push Notifications" capability is added
- Look at Xcode console for FCM token

**Messages Not Syncing:**
- Check Firebase Console → Firestore for data
- Verify security rules allow read/write
- Check network connectivity
- Look at Xcode console logs

### 7. Firebase Indexes (Optional)

If you see Firestore index errors in logs:
- The error message will contain a link
- Click the link to auto-create the required index
- Wait a few minutes for index to build

## Next Steps

Once setup is complete:
1. Test all MVP success criteria (see README.md)
2. Test on poor network conditions
3. Test with 3+ users for group chat
4. Record demo video
5. Deploy to TestFlight (optional)

## Support

For issues:
1. Check Firebase Console logs
2. Check Xcode console output
3. Review Firestore security rules
4. Verify all setup steps completed

## Important Files

- `GoogleService-Info.plist` - Firebase config (NEVER commit to git)
- `firebase/firestore.rules` - Database security rules
- `firebase/storage.rules` - Storage security rules
- `.gitignore` - Ensures sensitive files aren't committed

## Security Notes

⚠️ **Never commit these files:**
- `GoogleService-Info.plist`
- APNs `.p8` key file
- Any API keys or secrets

The `.gitignore` is configured to exclude these automatically.

