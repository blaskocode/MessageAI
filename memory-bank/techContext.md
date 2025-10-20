# Technical Context

## Current Implementation Status

**Code Written:** 21 Swift files (~2,000 lines)  
**Configuration:** 6 files (rules, Package.swift, .gitignore, docs)  
**Status:** Ready for Xcode project creation  
**Next Step:** Create Xcode project from existing source files

## Tech Stack (Implemented)

### Frontend: iOS Native (Swift)
**Implemented:**
- SwiftUI views and navigation
- SwiftData models with @Model
- Combine for reactive updates (@Published)
- URLSession infrastructure (not yet used)

**Files Created:**
- 6 View files (Auth, Chat, Conversations, Profile)
- 3 ViewModel files (Auth, Chat, ConversationList)
- 3 Model files (User, Conversation, Message)

**Not Yet Added:**
- SDWebImage dependency (for GIFs)
- Actual Xcode project file

### Backend: Firebase (Configured)
**Implemented:**
- FirebaseService with all CRUD operations
- Authentication methods (signUp, signIn, signOut)
- Firestore queries and real-time listeners
- Storage infrastructure (not yet used for uploads)
- FCM notification setup

**Security Rules Written:**
- Firestore: Participant-based access control
- Storage: Authenticated users, 10MB limit, images only

**Not Yet Done:**
- Actual Firebase project creation
- GoogleService-Info.plist download
- APNs certificate upload

### Dependencies Defined

**Package.swift created with:**
```swift
dependencies: [
  .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0"),
  .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI", from: "2.0.0")
]

targets: [
  .target(dependencies: [
    "FirebaseAuth",
    "FirebaseFirestore", 
    "FirebaseStorage",
    "FirebaseMessaging",
    "SDWebImageSwiftUI"
  ])
]
```

**Not Yet Done:**
- Running `swift package resolve`
- Adding packages in Xcode

## File Inventory

### Application Code (MessageAI/)

```
MessageAI/
├── App/ (2 files)
│   ├── MessageAIApp.swift       # 42 lines - Firebase initialization
│   └── ContentView.swift        # 24 lines - Auth routing
│
├── Features/ (9 files)
│   ├── Auth/
│   │   ├── AuthViewModel.swift          # 120 lines - Auth logic
│   │   └── AuthenticationView.swift     # 98 lines - Login/signup UI
│   ├── Chat/
│   │   ├── ChatViewModel.swift          # 145 lines - Message handling
│   │   └── ChatView.swift               # 112 lines - Chat UI
│   ├── Conversations/
│   │   ├── ConversationListViewModel.swift  # 78 lines
│   │   ├── ConversationListView.swift       # 72 lines
│   │   └── NewConversationView.swift        # 28 lines
│   └── Profile/
│       └── ProfileView.swift            # 58 lines
│
├── Services/ (3 files)
│   ├── FirebaseService.swift    # 320 lines - All Firebase ops
│   ├── NetworkMonitor.swift     # 82 lines - Connectivity tracking
│   └── NotificationService.swift # 88 lines - FCM handling
│
├── Models/ (3 files)
│   ├── User.swift               # 85 lines - SwiftData + Codable
│   ├── Conversation.swift       # 92 lines - SwiftData + Codable
│   └── Message.swift            # 96 lines - SwiftData + Codable
│
└── Utilities/ (2 files)
    ├── Constants.swift          # 58 lines - App constants
    └── Extensions/
        └── Color+Hex.swift      # 32 lines - Hex to Color
```

### Configuration Files

```
firebase/
├── firestore.rules              # 52 lines - Database security
└── storage.rules                # 38 lines - Storage security

Root/
├── Package.swift                # 32 lines - SPM dependencies
├── .gitignore                   # 28 lines - Git exclusions
├── README.md                    # 165 lines - Project overview
├── SETUP.md                     # 312 lines - Detailed setup guide
└── PROJECT_STRUCTURE.md         # 285 lines - Architecture doc
```

### Memory Bank (This Directory)

```
memory-bank/
├── projectbrief.md              # Project overview
├── productContext.md            # Product vision
├── systemPatterns.md            # Architecture details
├── techContext.md               # This file
├── activeContext.md             # Current work status
└── progress.md                  # Progress tracking
```

## Database Schema (Defined in Code)

### Firestore Collections

All data models implement Codable for Firebase serialization.

#### users collection
```swift
User {
  id: String                    // Document ID
  email: String
  displayName: String
  profilePictureURL: String?
  profileColorHex: String       // From 12-color palette
  initials: String              // "JD" format
  isOnline: Bool
  lastSeen: Date
  createdAt: Date
  fcmToken: String?
}
```

#### conversations collection
```swift
Conversation {
  id: String                    // Document ID
  type: ConversationType        // .direct or .group
  participantIds: [String]
  participantDetails: [String: ParticipantInfo]
  lastMessageText: String?
  lastMessageSenderId: String?
  lastMessageTimestamp: Date?
  lastUpdated: Date
  createdAt: Date
  groupName: String?            // Group only
  createdBy: String?            // Group only
}
```

#### conversations/{id}/messages subcollection
```swift
Message {
  id: String                    // Document ID
  senderId: String
  text: String?
  mediaURL: String?
  mediaType: MediaType?         // .image or .gif
  timestamp: Date
  status: MessageStatus         // .sending, .sent, .delivered, .read, .failed
  deliveredTo: [String]
  readBy: [String]
  temporaryId: String?          // For optimistic updates
  isPending: Bool               // For offline queue
}
```

#### conversations/{id}/typing subcollection
```swift
TypingIndicator {
  userId: String                // Document ID
  isTyping: Bool
  lastUpdated: Date
}
```

### SwiftData Schema

Same models as Firestore, with SwiftData decorators:
- `@Model` on classes
- `@Attribute(.unique)` on id fields
- `@Relationship(deleteRule: .cascade)` for messages
- All properties support both SwiftData and Codable

## API Methods Implemented

### FirebaseService (All Async)

#### Authentication
- `signUp(email, password, displayName) async throws -> String`
- `signIn(email, password) async throws -> String`
- `signOut() throws`
- `currentUserId: String?` (computed property)

#### User Profile
- `createUserProfile(userId, email, displayName) async throws`
- `fetchUserProfile(userId)` (uses listener)
- `updateUserProfile(userId, updates) async throws`

#### Conversations
- `createConversation(participantIds, type) async throws -> String`
- `fetchConversations(userId, completion) -> ListenerRegistration`

#### Messages
- `sendMessage(conversationId, senderId, text) async throws -> String`
- `fetchMessages(conversationId, limit, completion) -> ListenerRegistration`

#### Presence & Typing
- `updateOnlineStatus(userId, isOnline) async throws`
- `updateTypingStatus(conversationId, userId, isTyping) async throws`

#### Utilities
- `extractInitials(from: String) -> String` (private)
- `generateRandomProfileColor() -> String` (private)
- `removeAllListeners()` (cleanup)

### NetworkMonitor
- `isConnected: Bool` (@Published)
- `connectionType: ConnectionType` (@Published)
- `startMonitoring()`
- `stopMonitoring()`

### NotificationService
- `fcmToken: String?` (@Published)
- `setupNotifications()`
- `requestPermission()`
- `saveFCMToken(for: String) async`
- Implements UNUserNotificationCenterDelegate
- Implements MessagingDelegate

## Configuration Requirements

### Xcode Project Needs
1. **Project Creation**
   - iOS App template
   - SwiftUI + SwiftData
   - Minimum deployment: iOS 17.0
   - Import all source files

2. **Capabilities**
   - Push Notifications
   - Background Modes (Remote notifications)

3. **Bundle Identifier**
   - Must match Firebase registration
   - Example: `com.yourname.messageai`

4. **Signing**
   - Team selection
   - Provisioning profile

### Firebase Project Needs
1. **Create Project** at console.firebase.google.com
2. **Register iOS App** with bundle identifier
3. **Download** GoogleService-Info.plist
4. **Enable Services:**
   - Authentication (Email/Password)
   - Firestore Database
   - Cloud Storage
   - Cloud Messaging
5. **Deploy Rules:**
   - Copy from `firebase/firestore.rules`
   - Copy from `firebase/storage.rules`
6. **Upload APNs Key:**
   - Create in Apple Developer Portal
   - Upload to Firebase Console

### Dependencies to Install
Via Swift Package Manager in Xcode:
1. `https://github.com/firebase/firebase-ios-sdk` (10.0.0+)
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseStorage
   - FirebaseMessaging
2. `https://github.com/SDWebImage/SDWebImageSwiftUI` (2.0.0+)

## Development Environment

### Required Tools
- macOS (25.0.0 or compatible)
- Xcode 15+
- Swift 5.9+
- Physical iPhone for testing (iOS 17+)
- Apple Developer account

### Optional Tools
- Network Link Conditioner (Xcode)
- Firebase Emulator Suite
- Charles Proxy (network debugging)

## Build Process (Not Yet Run)

### Steps to Build
1. Create Xcode project
2. Add all MessageAI/ source files
3. Add GoogleService-Info.plist
4. Add package dependencies
5. Build (Cmd+B)
6. Fix any import/syntax errors
7. Run on device (Cmd+R)

### Expected Build Time
- Initial package resolution: 2-3 minutes
- First build: 1-2 minutes
- Incremental builds: 10-20 seconds

## Testing Strategy

### Unit Testing (Not Yet Implemented)
- Test ViewModels with mock FirebaseService
- Test data model Codable conformance
- Test utility functions (initials, colors)

### Integration Testing (Not Yet Done)
- Test Firebase operations against emulator
- Test listener lifecycle
- Test offline queue

### Device Testing (Critical, Not Yet Done)
**Must test on physical devices:**
1. Authentication flow
2. Message sending/receiving
3. Offline scenarios (airplane mode)
4. Poor network (throttled)
5. Rapid messaging (20+ messages)
6. Force quit and restart
7. Background/foreground transitions
8. Push notifications

### Testing Tools Available
- Xcode Network Link Conditioner
- Airplane mode
- Force quit app
- Monitor Firebase Console

## Known Technical Constraints

### iOS Platform
- Push notifications require physical device
- SwiftData requires iOS 17+
- Background execution is limited
- APNs requires certificate

### Firebase Free Tier
- 50K reads/day, 20K writes/day
- 1GB storage
- 10GB/month bandwidth
- Adequate for MVP

### Code Limitations
- No pagination implemented yet
- No media upload implemented yet
- No group creation UI yet
- No user search implemented yet
- Offline sync not fully tested

## Performance Targets (Not Yet Measured)

Once running:
- Message delivery: < 1 second
- App launch: < 2 seconds
- Message list scroll: 60 FPS
- Image upload: < 5 seconds (2MB)

## Next Technical Steps

1. **Create Xcode Project**
   - Import source files
   - Configure settings
   - Add capabilities

2. **Set Up Firebase**
   - Create project
   - Enable services
   - Deploy rules

3. **Install Dependencies**
   - Add SPM packages
   - Resolve dependencies

4. **First Build**
   - Fix any errors
   - Test on device

5. **Validate Core Features**
   - Auth works
   - Messages send/receive
   - Offline queue works
