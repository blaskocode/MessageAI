# MessageAI

A real-time messaging application for iOS that provides reliable, WhatsApp-like messaging infrastructure with the foundation for intelligent AI features.

## Overview

MessageAI is built using Swift, SwiftUI, and Firebase. The MVP focuses on proving the core messaging infrastructure works flawlessly:
- Real-time message delivery (< 1 second)
- Offline support with local persistence
- Message read receipts and typing indicators
- Group chat support
- Push notifications

## Tech Stack

### Frontend
- **SwiftUI** - Modern declarative UI
- **SwiftData** - Local persistence (iOS 17+)
- **Combine** - Reactive programming
- **SDWebImage** - GIF support

### Backend
- **Firebase Firestore** - Real-time database
- **Firebase Auth** - User authentication
- **Firebase Storage** - Media storage
- **Firebase Cloud Messaging** - Push notifications

## Project Structure

```
MessageAI/
├── App/                    # Main app entry point
├── Features/               # Feature modules
│   ├── Auth/              # Authentication
│   ├── Chat/              # Messaging
│   ├── Conversations/     # Conversation list
│   └── Profile/           # User profile
├── Services/              # Core services
│   ├── FirebaseService    # Firebase operations
│   ├── NetworkMonitor     # Network connectivity
│   └── NotificationService # Push notifications
├── Models/                # Data models
│   ├── User
│   ├── Conversation
│   └── Message
└── Utilities/             # Helpers and extensions
```

## Setup Instructions

### Prerequisites
- Xcode 15+
- iOS 17.0+ deployment target
- Firebase project (see Firebase Setup below)

### Firebase Setup

1. Create a new Firebase project at [console.firebase.google.com](https://console.firebase.google.com)

2. Register your iOS app with bundle identifier (e.g., `com.yourname.messageai`)

3. Download `GoogleService-Info.plist` and add it to your Xcode project

4. Enable these Firebase services:
   - Authentication (Email/Password provider)
   - Firestore Database
   - Storage
   - Cloud Messaging

5. Configure Firestore Security Rules (see `firestore.rules`)

6. Upload APNs authentication key for push notifications:
   - Go to Apple Developer Portal
   - Create APNs key
   - Upload to Firebase Console (Project Settings → Cloud Messaging)

### Xcode Setup

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd MessageAI
   ```

2. Open in Xcode:
   ```bash
   open MessageAI.xcodeproj
   ```

3. Add `GoogleService-Info.plist` to the project (if not already present)

4. Update bundle identifier in Xcode project settings

5. Add Firebase dependencies via Swift Package Manager:
   - File → Add Package Dependencies
   - Add: `https://github.com/firebase/firebase-ios-sdk`
   - Add: `https://github.com/SDWebImage/SDWebImageSwiftUI`

6. Build and run on a physical device (required for push notifications)

## Running the Application

### Opening the Project

1. Navigate to the project directory:
   ```bash
   cd MessageAI/MessageAI-Xcode
   ```

2. Open the Xcode project:
   ```bash
   open MessageAI-Xcode.xcodeproj
   ```
   
   Alternatively, you can double-click `MessageAI-Xcode.xcodeproj` in Finder.

### Selecting a Simulator

1. In Xcode, locate the scheme selector in the toolbar (top-left area)
   - It displays the current target device/simulator

2. Click on the device selector and choose a simulator:
   - Select **"iPhone 15 Pro"** (or any iPhone model)
   - Ensure the iOS version is **17.0 or newer**
   
   > **Note:** The app requires iOS 17+ due to SwiftData dependencies

3. If you don't see iOS 17+ simulators:
   - Go to **Xcode → Settings → Platforms**
   - Download the iOS 17+ simulator runtime

### Building and Running

1. **Build the project** (⌘B or Product → Build):
   - This compiles the code and checks for errors
   - Wait for the build to complete successfully

2. **Run the application** (⌘R or Product → Run):
   - Xcode will launch the selected simulator
   - The app will automatically install and launch
   - First launch may take 30-60 seconds

3. **Verify the build**:
   - The simulator should display the authentication screen
   - Check the Xcode console for any startup messages

### Running on a Physical Device

For full functionality (especially push notifications):

1. Connect your iPhone via USB
2. Select your iPhone from the device selector
3. If prompted, trust the device and enable Developer Mode:
   - On iPhone: Settings → Privacy & Security → Developer Mode → Enable
4. Ensure your iPhone is running **iOS 17.0 or newer**
5. Build and run (⌘R)

> **Important:** Push notifications only work on physical devices, not simulators.

### Troubleshooting

**Build Errors:**
- Clean build folder: Product → Clean Build Folder (⌘⇧K)
- Delete derived data: Xcode → Settings → Locations → Derived Data → Delete
- Verify Swift Package dependencies are resolved

**Simulator Issues:**
- Reset simulator: Device → Erase All Content and Settings
- Quit and restart Xcode
- Restart your Mac if simulator won't launch

**Code Signing:**
- Go to project settings → Signing & Capabilities
- Select your Apple ID team
- Xcode will automatically handle provisioning

## Testing

### Minimum Requirements
- Test on at least 2 physical iPhones
- Test offline scenarios (airplane mode on/off)
- Test poor network conditions
- Test rapid message sending
- Test force-quit scenarios

### Testing Tools
- Xcode Network Link Conditioner (for throttled connections)
- Firebase Emulator Suite (optional, for local testing)

## MVP Success Criteria

The MVP is successful when:
1. ✅ Two users can send messages instantly (< 1 second)
2. ✅ Messages persist across app force-quit and restart
3. ✅ Offline scenario works correctly
4. ✅ Group chat with 3 users works with proper attribution
5. ✅ Read receipts update in real-time
6. ✅ Online/offline status indicators work
7. ✅ Typing indicators appear/disappear correctly
8. ✅ Push notifications display in foreground
9. ✅ App handles rapid-fire messaging
10. ✅ Poor network doesn't break the app

## Key Features

### P0 (Blocking)
- [x] User authentication & profiles
- [ ] One-on-one messaging
- [ ] Group chat
- [ ] Read receipts
- [ ] Push notifications
- [ ] Offline support & sync

### P1 (Important)
- [ ] Images
- [ ] GIFs with animation

## Out of Scope (Phase 2)
- AI features (summarization, action items, etc.)
- Voice/video messages
- Message editing/deletion
- Voice/video calls
- End-to-end encryption

## License

Copyright © 2025. All rights reserved.

## Contact

For questions or support, please open an issue in the repository.
