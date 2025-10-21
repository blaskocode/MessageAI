# MessageAI MVP - Product Requirements Document

**Project:** MessageAI - WhatsApp Clone with AI Features  
**Timeline:** 24 Hours to MVP  
**Platform:** iOS (Swift + SwiftUI)  
**Backend:** Firebase  
**Last Updated:** October 20, 2025

---

## Executive Summary

MessageAI is a real-time messaging application that provides reliable, WhatsApp-like messaging infrastructure with the foundation for intelligent AI features. The MVP focuses exclusively on proving the core messaging infrastructure works flawlessly before any AI features are added.

**Success Criteria:** Two users can reliably exchange messages in real-time, messages persist across app restarts, and the system gracefully handles offline scenarios.

---

## User Stories

### Primary User: Any Messaging User
*The MVP serves all users equally - persona selection comes in Phase 2*

#### Authentication & Profile
- As a user, I want to create an account so that I can start messaging
- As a user, I want to log in with my credentials so that I can access my messages
- As a user, I want to set a display name and profile picture so that others can identify me

#### One-on-One Messaging
- As a user, I want to send text messages to another user so that we can communicate
- As a user, I want to see messages appear instantly when I send them (optimistic updates)
- As a user, I want to see when my message was sent, delivered, and read
- As a user, I want to see timestamps on all messages so that I know when they were sent
- As a user, I want to see if the other person is online or offline
- As a user, I want to see when the other person is typing
- As a user, I want my messages to persist locally so that I can see history when offline
- As a user, I want messages to sync when I come back online after being disconnected

#### Group Messaging
- As a user, I want to create a group chat with 3+ people
- As a user, I want to see who sent each message in a group chat
- As a user, I want to see read receipts for each group member
- As a user, I want to see which group members are online

#### Notifications
- As a user, I want to receive push notifications when I get a new message (at least in foreground)
- As a user, I want notifications to show who sent the message and a preview of the content

#### Reliability
- As a user, I expect my messages to never get lost, even if the app crashes
- As a user, I expect the app to work on poor network connections
- As a user, I expect messages I send while offline to queue and send when I regain connectivity
- As a user, I expect messages sent to me while offline to appear when I regain connectivity

---

## Key Features for MVP

### 1. User Authentication & Profiles
**Priority:** P0 (Blocking)

- Email/password authentication via Firebase Auth
- User profile with display name and optional profile picture
- Default profile picture: circular view with user's initials and random background color from predefined palette
- Persistent login state
- Basic profile editing

**Acceptance Criteria:**
- User can sign up with email/password
- User can log in and remain logged in across app restarts
- User can set/update display name
- User can upload profile picture (stored in Firebase Storage)
- Default profile picture shows first and last initials in circular view with random background color

### 2. One-on-One Chat
**Priority:** P0 (Blocking)

- Real-time message delivery between two users
- Text message support
- Message timestamps (created, sent, delivered, read)
- Optimistic UI updates (instant message appearance)
- Message delivery states: sending → sent → delivered → read
- Online/offline presence indicators
- Typing indicators
- Message persistence in local storage (SwiftData)

**Acceptance Criteria:**
- Message sent by User A appears instantly on User B's device (< 1 second latency)
- Messages persist locally and survive app restart
- User can see online/offline status of chat partner
- User can see when partner is typing
- Message states update correctly through all stages
- Offline messages queue and send on reconnection

### 3. Group Chat
**Priority:** P0 (Blocking)

- Support for 3+ users in a conversation
- Message attribution (who sent what)
- Per-user read receipts
- Group member list with online status
- Group naming

**Acceptance Criteria:**
- Can create group with 3+ members
- All members receive messages in real-time
- Can see which member sent each message
- Can see read status per member
- Group members can see who's online

### 4. Message Read Receipts
**Priority:** P0 (Blocking)

- Track when messages are delivered to recipient's device
- Track when messages are read (app opened to that conversation)
- Display read status to sender
- In groups, show individual read status per member

**Acceptance Criteria:**
- Sender sees "delivered" when message reaches recipient device
- Sender sees "read" when recipient opens the conversation
- Group messages show count of members who read (e.g., "Read by 3/5")

### 5. Local Notifications (Foreground)
**Priority:** P0 (Blocking)

- **Local notifications** triggered when new messages arrive via Firestore
- Display sender name and message preview (first 100 characters)
- Badge count for unread messages
- Tap notification to open relevant chat
- No notifications for active conversation
- Different format for group vs. direct chats
- Works without APNs (uses UserNotifications framework)

**Acceptance Criteria:**
- User receives notification when new message arrives in non-active conversation
- Notification shows sender name and message content
- Group notifications show: "[Group Name] - [Sender]: [Message]"
- Direct notifications show: "[Sender Name]: [Message]"
- Tapping notification navigates to correct conversation
- Badge count updates correctly
- No notification for self-sent messages
- Background/remote push notifications are post-MVP (requires APNs)

### 6. Offline Support & Sync
**Priority:** P0 (Blocking)

- Local message persistence using SwiftData
- Message queue for offline sends
- Automatic sync on reconnection
- Handle app lifecycle (background, foreground, killed)

**Acceptance Criteria:**
- User can view message history when offline
- Messages sent while offline queue and send on reconnection
- App state persists through background/foreground transitions
- Messages don't duplicate on sync
- Handles force-quit gracefully

### 7. Media Support (Images & GIFs)
**Priority:** P1 (Important)

- Send and receive images (JPEG, PNG, HEIC, WebP)
- Send and receive animated GIFs with animation playback in chat
- GIF picker integration (photo library + built-in GIF search like Giphy)
- Image/GIF thumbnails in chat
- Full-screen image/GIF viewing
- Maximum file size: 10MB
- Images stored in Firebase Storage

**Acceptance Criteria:**
- User can select and send image from photo library
- User can search and send GIFs from built-in picker
- GIFs animate within chat messages
- Images and GIFs appear inline in chat
- Tap image/GIF to view full-screen
- Files over 10MB are rejected with user-friendly error
- Media persists across app restarts

---

## Tech Stack

### Frontend: iOS Native (Swift)
- **SwiftUI** - Modern declarative UI framework
- **SwiftData** - Local persistence (iOS 17+)
- **Combine** - Reactive programming for Firebase listeners
- **URLSession** - Network requests to Cloud Functions

**Why Swift/SwiftUI:**
- Fastest development for iOS
- Native performance
- SwiftUI reduces boilerplate significantly
- SwiftData is simple and powerful
- Excellent Firebase SDK support

### Backend: Firebase
- **Firebase Firestore** - Real-time NoSQL database
- **Firebase Cloud Functions** - Serverless backend (for future AI features)
- **Firebase Authentication** - User auth & management
- **Firebase Cloud Messaging (FCM)** - Push notifications
- **Firebase Storage** - Image/media storage

**Why Firebase:**
- Real-time sync is built-in (critical for messaging)
- Handles offline persistence automatically
- Generous free tier
- Minimal backend code needed
- Proven at scale (used by many chat apps)

### Development Tools
- **Xcode 15+** - IDE
- **CocoaPods or SPM** - Dependency management
- **Git/GitHub** - Version control
- **TestFlight** - Beta distribution

---

## Database Schema

### Firestore Collections

#### `users`
```
{
  userId: string (document ID)
  displayName: string
  email: string
  profilePictureURL: string?
  profileColorHex: string (from predefined palette, assigned at creation)
  initials: string (first + last initial, e.g., "JD")
  isOnline: boolean
  lastSeen: timestamp
  createdAt: timestamp
}
```

#### `conversations`
```
{
  conversationId: string (document ID)
  type: "direct" | "group"
  participantIds: [userId]
  participantDetails: { userId: { name, photoURL } }
  lastMessage: {
    text: string
    senderId: string
    timestamp: timestamp
  }
  lastUpdated: timestamp
  createdAt: timestamp
  
  // Group-specific
  groupName: string?
  createdBy: userId?
}
```

#### `conversations/{conversationId}/messages`
```
{
  messageId: string (document ID)
  senderId: string
  text: string?
  mediaURL: string? (image/GIF URL in Firebase Storage)
  mediaType: "image" | "gif" | null
  timestamp: timestamp
  status: "sending" | "sent" | "delivered" | "read"
  
  // Delivery tracking
  deliveredTo: [userId]
  readBy: [userId]
}
```

#### `conversations/{conversationId}/typing`
```
{
  userId: string (document ID)
  isTyping: boolean
  lastUpdated: timestamp
}
```

---

## Out of Scope for MVP

The following features are explicitly **NOT** included in the 24-hour MVP:

### AI Features (Phase 2)
- Thread summarization
- Action item extraction
- Smart search
- Message translation
- Any AI agent functionality
- RAG pipelines

### Advanced Messaging Features
- Voice messages
- Video messages
- Message editing
- Message deletion
- Message reactions/emojis
- Message forwarding
- Stickers
- Voice/video calls
- Screen sharing
- Location sharing
- Contact sharing
- File attachments (documents, PDFs, etc.)

### Advanced Group Features
- Group admin roles
- Add/remove members
- Group descriptions
- Group profile pictures
- Mute conversations
- Pin conversations

### Polish Features
- Message search within conversation
- Conversation list search
- Custom notification sounds
- Dark mode (use system default)
- Multiple device support
- Web version
- Desktop version
- Backup/restore
- End-to-end encryption

### Account Features
- Phone number verification
- Two-factor authentication
- Block users
- Report users
- Privacy settings
- Status/stories
- Profile bio

---

## Technical Considerations & Pitfalls

### Firebase-Specific Pitfalls

**1. Firestore Listener Management**
- ⚠️ **Problem:** Listeners remain active even when view disappears, causing memory leaks
- ✅ **Solution:** Store listener references and remove them in `onDisappear` or `deinit`
- Use `@StateObject` for view models to ensure proper lifecycle

**2. Offline Persistence Configuration**
- ⚠️ **Problem:** Firestore offline persistence disabled by default
- ✅ **Solution:** Enable immediately after Firebase initialization:
```swift
let settings = FirestoreSettings()
settings.isPersistenceEnabled = true
```

**3. Real-time Updates & Performance**
- ⚠️ **Problem:** Listening to entire collections can be expensive
- ✅ **Solution:** 
  - Use queries with limits (e.g., last 50 messages)
  - Implement pagination for message history
  - Use `.whereField("participantIds", arrayContains: currentUserId)` for conversation list

**4. Optimistic Updates**
- ⚠️ **Problem:** Local updates might conflict with server reality
- ✅ **Solution:** 
  - Generate temporary IDs for pending messages (UUID)
  - Replace temporary ID with server ID on confirmation
  - Handle conflicts by always trusting server state

**5. Security Rules**
- ⚠️ **Problem:** Default rules allow all access (security risk)
- ✅ **Solution:** Write rules immediately:
```
match /conversations/{conversationId} {
  allow read, write: if request.auth.uid in resource.data.participantIds;
}
```

### Swift/SwiftUI Pitfalls

**6. Default Profile Picture Implementation**
- ✅ **Solution:**
  - Define color palette (8-12 colors for variety): blues, greens, purples, oranges, etc.
  - Assign random color at account creation, store hex in Firestore
  - Extract initials from display name (first char of first word + first char of last word)
  - Create SwiftUI view with Circle + Text overlay
  - Fallback: If no last name, use first two letters of first name

**7. GIF Integration**
- ⚠️ **Problem:** Native SwiftUI doesn't support animated GIFs well
- ✅ **Solution:** 
  - Use SDWebImage library (has SwiftUI support via SDWebImageSwiftUI)
  - For GIF picker: Integrate Giphy SDK or use Tenor API
  - Giphy SDK is simpler but requires API key (free tier available)
  - Store GIFs as regular images in Firebase Storage
  - Use `AnimatedImage` view from SDWebImage for playback

**8. SwiftData + Firebase Integration**
- ⚠️ **Problem:** SwiftData and Firebase updates can desync
- ✅ **Solution:** 
  - Use Firestore as source of truth
  - SwiftData only for offline cache
  - On app launch, sync Firestore → SwiftData
  - Don't try to make SwiftData primary persistence

**9. Local Notification Setup**
- ✅ **Solution:** Use UserNotifications framework for local notifications
  - Trigger notifications when Firestore listener detects new messages
  - Track active conversation to avoid duplicate notifications
  - Works immediately without APNs setup
  - Foreground notifications sufficient for MVP
- ⚠️ **Post-MVP:** Remote push notifications require APNs certificates and paid/activated Apple Developer account

**10. Background App Refresh**
- ⚠️ **Problem:** iOS aggressively kills background processes
- ✅ **Solution:** 
  - Don't rely on background execution for message delivery
  - Use Firebase's offline persistence to queue messages
  - Implement proper app state handling (`scenePhase` in SwiftUI)

### Architecture Recommendations

**11. MVVM with ViewModels**
- Use `ObservableObject` ViewModels for each screen
- Keep views thin - logic in ViewModels
- ViewModels manage Firebase listeners

**12. Dependency Injection**
- Create a `FirebaseService` class for all Firestore operations
- Inject into ViewModels (easier to test, cleaner code)
- Singleton pattern for services is acceptable for MVP

**13. Error Handling**
- Firebase operations can fail (network, permissions)
- Always handle errors gracefully
- Show user-friendly error messages
- Implement retry logic for failed sends

### Testing Strategy

**14. Real Device Testing is Critical**
- ⚠️ Simulator doesn't accurately represent:
  - Network conditions
  - Push notifications
  - App lifecycle events
  - Performance
- ✅ Test on at least 2 physical iPhones for MVP validation

**15. Network Condition Testing**
- Test with airplane mode on/off
- Test with throttled connection (Xcode Network Link Conditioner)
- Test rapid message sending (20+ messages in succession)
- Test force-quit during message send

### Performance Optimizations

**16. Image & GIF Handling**
- Compress images before upload (max 1080px, 80% quality)
- Enforce 10MB max file size for all media
- Use thumbnail URLs for chat list
- Lazy load images in message list
- Cache images locally
- For GIFs: Use SDWebImage library for smooth animated playback
- Validate file types before upload (JPEG, PNG, HEIC, WebP, GIF)

**17. Message List Performance**
- Use `LazyVStack` for message list (not `VStack`)
- Implement pagination (load 50 messages at a time)
- Cache rendered messages
- Use `@StateObject` appropriately to prevent unnecessary rerenders

---

## Deployment Plan

### Local Development (First 20 Hours)
- Run on Xcode Simulator
- Test with 2 simulator instances
- Deploy Firebase backend (Firestore, Auth, Storage)

### Device Testing (Last 4 Hours)
- Install on 2 physical iPhones via cable
- Test all MVP requirements end-to-end
- Record demo video

### TestFlight (Stretch Goal)
- Create App Store Connect entry
- Upload build via Xcode
- Add testers
- Distribute link

**Note:** TestFlight is ideal but not required if time is tight. Focus on getting the core working first.

---

## Success Metrics for MVP

The MVP is successful when:

1. ✅ Two users can send text messages that appear instantly (< 1 second)
2. ✅ Messages persist across app force-quit and restart
3. ✅ Offline scenario works: User A offline → User B sends message → User A comes online → message appears
4. ✅ Group chat with 3 users works with proper attribution
5. ✅ Read receipts update correctly in real-time
6. ✅ Online/offline status indicators work
7. ✅ Typing indicators appear/disappear correctly
8. ✅ Push notifications display in foreground
9. ✅ App handles rapid-fire messaging without crashes or lost messages
10. ✅ Poor network conditions don't break the app

**If any of these fail, the MVP fails.**

---

## Build Order (Recommended)

### Hour 0-2: Setup & Auth
1. Create Xcode project
2. Configure Firebase project
3. Add Firebase SDKs
4. Implement auth (signup/login)
5. Basic profile creation

### Hour 2-8: Core Messaging (One-on-One)
6. Create conversation between 2 users
7. Send text message User A → User B
8. Real-time listener on User B's device
9. Local persistence with SwiftData
10. Optimistic updates
11. Message delivery states

### Hour 8-12: Presence & Typing
12. Online/offline status
13. Typing indicators
14. Message timestamps

### Hour 12-16: Group Chat
15. Create group conversation
16. Multi-user message delivery
17. Per-user read receipts
18. Group member list

### Hour 16-20: Notifications & Polish
19. FCM setup
20. Foreground notifications
21. Handle app lifecycle
22. Offline sync testing

### Hour 20-24: Testing & Deployment
23. End-to-end testing on real devices
24. Fix critical bugs
25. Record demo video
26. Deploy to TestFlight (if time allows)

---

## Next Steps

1. Review and approve this PRD
2. Set up Firebase project
3. Create Xcode project with SwiftUI
4. Start with authentication flow
5. Move to core messaging ASAP

**Remember:** A simple, reliable chat app beats a feature-rich app with flaky message delivery. Focus on making messaging bulletproof first.