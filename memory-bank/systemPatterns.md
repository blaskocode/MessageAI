# System Patterns

## Architecture Implementation

MessageAI uses **MVVM (Model-View-ViewModel)** architecture with Firebase backend and SwiftData for local persistence.

```
┌─────────────────────────────────────────┐
│         SwiftUI Views                   │
│  AuthenticationView, ChatView, etc.    │
│  (Thin, declarative, UI only)          │
└──────────────┬──────────────────────────┘
               │ @StateObject
               │ @EnvironmentObject
┌──────────────▼──────────────────────────┐
│         ViewModels                      │
│  AuthViewModel, ChatViewModel, etc.    │
│  (@MainActor, @Published properties)   │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│       FirebaseService (Singleton)       │
│  All Firestore operations centralized  │
│  Listener management, auth, CRUD       │
└──────────────┬──────────────────────────┘
               │
    ┌──────────┴──────────┐
    │                     │
┌───▼─────────────┐  ┌───▼──────────────┐
│ Firebase Cloud  │  │ SwiftData Cache  │
│  (Source of     │  │ (Local storage,  │
│   Truth)        │  │  offline queue)  │
└─────────────────┘  └──────────────────┘
```

## Implementation Details

### Files Created and Their Roles (23 total)

#### App Layer (2 files)
**MessageAIApp.swift**
- Main app entry point with `@main`
- Configures Firebase on launch
- Enables Firestore offline persistence
- Injects FirebaseService as environment object

**ContentView.swift**
- Root view that routes based on auth state
- Shows AuthenticationView when logged out
- Shows ConversationListView when logged in
- Provides authViewModel to child views

#### Service Layer (3 files)

**FirebaseService.swift** (330 lines)
- Singleton pattern: `FirebaseService.shared`
- All Firebase operations centralized here
- Methods implemented:
  - `signUp()`, `signIn()`, `signOut()`
  - `createUserProfile()`, `fetchUserProfile()`, `updateUserProfile()`
  - `createConversation()`, `fetchConversations()`
  - `sendMessage()`, `fetchMessages()`
  - `updateOnlineStatus()`, `updateTypingStatus()`
- Manages listener lifecycle
- Extracts initials and generates profile colors
- Returns `ListenerRegistration` for cleanup

**NetworkMonitor.swift** (80 lines)
- Singleton pattern: `NetworkMonitor.shared`
- Uses `NWPathMonitor` to track connectivity
- Published properties: `isConnected`, `connectionType`
- Runs on background queue
- Triggers sync when reconnected

**NotificationService.swift** (90 lines)
- Singleton pattern: `NotificationService.shared`
- Implements `UNUserNotificationCenterDelegate`
- Implements `MessagingDelegate` for FCM
- Handles foreground notifications
- Saves FCM token to Firestore
- Routes to conversation on tap

#### Model Layer (3 files)

**User.swift**
- `@Model` for SwiftData persistence
- `Codable` for Firebase serialization
- Properties: id, email, displayName, profileColorHex, initials, isOnline, lastSeen, fcmToken
- `@Attribute(.unique)` on id for SwiftData

**Conversation.swift**
- `@Model` with SwiftData
- `Codable` for Firebase
- Supports both `direct` and `group` types
- Properties: participantIds, participantDetails, lastMessage, groupName
- `@Relationship` to messages

**Message.swift**
- `@Model` with SwiftData
- `Codable` for Firebase
- Status enum: sending, sent, delivered, read, failed
- MediaType enum: image, gif
- Properties: senderId, text, mediaURL, timestamp, deliveredTo, readBy
- Support for temporary IDs (optimistic updates)

#### ViewModel Layer (5 files)

**AuthViewModel.swift** (@MainActor)
- Published: `isAuthenticated`, `isLoading`, `errorMessage`
- Methods: `signUp()`, `signIn()`, `signOut()`
- Input validation
- Updates online status on signin/signout
- Saves FCM token after auth

**ChatViewModel.swift** (@MainActor)
- Published: `messages`, `isLoading`, `isTyping`
- Manages message listener
- Methods: `loadMessages()`, `sendMessage()`, `updateTypingStatus()`, `markMessagesAsRead()`
- Implements optimistic updates
- Proper cleanup in `deinit`

**ConversationListViewModel.swift** (@MainActor)
- Published: `conversations`, `showNewConversation`, `showNewGroup`, `isLoading`
- Manages conversation listener
- Parses Firestore documents to Conversation models
- Real-time updates

**NewConversationViewModel.swift** (@MainActor)
- Published: `searchText`, `searchResults`, `isLoading`, `errorMessage`
- Methods: `searchUsers()`, `createConversation()`
- Implements user search with Firebase query
- Handles conversation creation

**NewGroupViewModel.swift** (@MainActor)
- Published: `searchText`, `searchResults`, `selectedUserIds`, `groupName`, `isLoading`
- Methods: `searchUsers()`, `toggleUserSelection()`, `createGroup()`
- Multi-user selection logic
- Group name validation (2-50 characters)

#### View Layer (8 files)

**AuthenticationView.swift**
- Login/Signup toggle
- Email, password, display name fields
- Error display
- Loading state with spinner
- Calls AuthViewModel methods

**ChatView.swift**
- ScrollView with LazyVStack for messages
- MessageBubble subview for each message
- Auto-scroll to bottom on new message
- Input bar with TextField
- Typing status updates
- Status icons (clock, checkmark, etc.)

**ConversationListView.swift**
- NavigationStack with List
- ConversationRow subview
- Toolbar with sign out and new message buttons
- Sheet for NewConversationView
- Loads conversations on appear

**ConversationListViewModel.swift**
- Parses Firestore snapshots
- Real-time listener management

**NewConversationView.swift**
- Placeholder for user search
- Searchable interface ready
- TODO: Implement user list

**ProfileView.swift**
- Placeholder for profile editing
- Shows initials in circle
- Sign out button

#### Utilities (2 files)

**Constants.swift**
- Collections names
- UI constants (message limit, max image size)
- Profile color palette (12 colors)
- Notification keys

**Color+Hex.swift**
- Extension to initialize Color from hex string
- Supports 3, 6, and 8-digit hex codes

## Key Patterns Implemented

### 1. Optimistic UI Updates
```swift
// Create temp message with UUID
let tempMessage = Message(id: UUID().uuidString, ...)
messages.append(tempMessage) // Show immediately

// Send to Firebase
let realId = try await sendMessage(...)

// Replace temp with real
if let index = messages.firstIndex(where: { $0.id == tempMessage.id }) {
    messages[index].id = realId
    messages[index].status = .sent
}
```

### 2. Listener Management
```swift
// Store listener reference
var listener: ListenerRegistration?

// Create listener
listener = db.collection(...).addSnapshotListener { ... }

// Cleanup
deinit {
    listener?.remove()
}
```

### 3. Firebase as Source of Truth
- Firestore: Authoritative data
- SwiftData: Cache only
- On launch: Sync Firestore → SwiftData
- On write: Firestore first, then cache

### 4. Network-Aware Operations
```swift
if NetworkMonitor.shared.isConnected {
    // Send to Firebase
} else {
    // Queue in SwiftData
    message.isPending = true
}
```

### 5. Proper @MainActor Usage
- All ViewModels marked `@MainActor`
- UI updates happen on main thread
- Firebase callbacks dispatch to main

## Data Flow Patterns

### Message Send Flow
```
User types → ChatView
  → ChatViewModel.sendMessage()
    → Create optimistic message
    → Update UI immediately
    → FirebaseService.sendMessage()
      → Send to Firestore
      → Update conversation lastMessage
    → Replace temp ID with real ID
    → Update status to .sent
```

### Message Receive Flow
```
Firebase listener fires
  → ChatViewModel receives snapshot
    → Parse documents to Message models
    → Sort by timestamp
    → Update @Published messages array
      → SwiftUI rerenders ChatView
    → Save to SwiftData
    → Send read receipt
```

### Conversation List Flow
```
ConversationListViewModel loads
  → FirebaseService.fetchConversations()
    → Query with participantIds filter
    → Order by lastUpdated
    → Real-time listener
  → Parse snapshots
    → Extract participant data
    → Format timestamps
    → Update @Published array
      → SwiftUI rerenders list
```

## Security Implementation

### Firestore Rules (firebase/firestore.rules)
```javascript
// Only participants can access conversations
match /conversations/{conversationId} {
  allow read, write: if request.auth.uid in resource.data.participantIds;
  
  // Messages subcollection inherits participant check
  match /messages/{messageId} {
    allow read, write: if request.auth.uid in 
      get(/conversations/$(conversationId)).data.participantIds;
  }
}
```

### Storage Rules (firebase/storage.rules)
```javascript
// 10MB max, images only, authenticated
match /message_media/{conversationId}/{fileName} {
  allow write: if request.auth != null &&
                  request.resource.contentType.matches('image/.*') &&
                  request.resource.size < 10 * 1024 * 1024;
}
```

## Performance Patterns

### Implemented
1. **LazyVStack** for message lists (not VStack)
2. **Query limits** (.limit(50) on messages)
3. **Targeted queries** (participantIds filter)
4. **Listener cleanup** (remove on deinit)
5. **Profile color caching** (stored in User model)

### Not Yet Implemented
1. Message pagination
2. Image caching
3. Rendered message caching
4. Debounced typing indicators

## Error Handling

### Implemented
- Try-catch blocks around all Firebase operations
- User-friendly error messages in ViewModels
- Loading states during async operations
- Failed message status with retry capability

### Pattern Used
```swift
do {
    let result = try await firebaseService.someOperation()
    // Success path
} catch {
    errorMessage = "User-friendly message: \(error.localizedDescription)"
    // Rollback optimistic updates if needed
}
```

## Testing Considerations

### Testable Architecture
- ViewModels can be unit tested (inject mock FirebaseService)
- Views are thin (just UI, no logic)
- Models are Codable (easy to create fixtures)
- Services are singletons (can be mocked)

### What Needs Testing
1. Authentication flows
2. Message delivery under various network conditions
3. Offline queue and sync
4. Optimistic update conflict resolution
5. Listener cleanup (no memory leaks)
6. Concurrent message handling
