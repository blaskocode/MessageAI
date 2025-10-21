# Product Context

## Why This Exists
MessageAI is being built to create a modern messaging platform that will eventually leverage AI to enhance communication. The MVP phase validates that we can build a reliable, real-time messaging foundation before adding intelligent features.

## Current Development Stage
**MVP Complete:** All core features implemented and tested  
**Status:** Fully functional on physical devices and simulator  
**Next:** Optional APNs configuration or begin Phase 2 (AI features)

## Problems It Solves
1. **Reliable Communication** - Messages must never get lost, even under poor network conditions
2. **Real-Time Sync** - Users expect instant message delivery (< 1 second latency)
3. **Offline Resilience** - Users need to access message history and queue messages when offline
4. **Foundation for AI** - Establishes the infrastructure needed for future AI features like thread summarization, action item extraction, and smart search

## Target Users
**Primary User:** Any messaging user (persona selection comes in Phase 2)

The MVP serves all users equally - we're validating infrastructure, not targeting specific personas yet.

## How It Works

### Core User Flows Implemented

#### Authentication Flow
1. User opens app → sees auth screen
2. Can sign up with email, password, display name
3. Can sign in with existing credentials
4. Profile created automatically with:
   - Initials from display name
   - Random color from predefined palette
   - Default online status
5. Session persists across app restarts

#### Sending a Message
1. User types message in chat view
2. Message appears instantly in UI (optimistic update)
3. Message sent to Firebase in background
4. Status updates: sending → sent → delivered → read
5. If offline, message queues and sends on reconnection
6. Typing indicator shown to other participants

#### Receiving a Message
1. Firebase real-time listener receives new message
2. Message appears in UI (< 1 second)
3. Saved to local SwiftData cache
4. Push notification shown if app in foreground
5. Read receipt sent automatically when conversation viewed
6. If offline, messages sync when reconnected

#### Conversation Management
1. View list of all conversations
2. Each shows: participants, last message, timestamp
3. Real-time updates as new messages arrive
4. Tap to open chat view
5. Create new conversation (UI placeholder ready)

### Quality Standards
- **Performance:** Message delivery < 1 second under normal conditions
- **Reliability:** Zero message loss, even during crashes or poor network
- **Resilience:** Graceful degradation under bad network conditions
- **Persistence:** All data survives app lifecycle events

## What's Been Built

### ✅ Implemented Features
1. **Authentication System**
   - Email/password signup and signin
   - Profile creation with initials and color
   - Session persistence
   - Online status tracking

2. **Messaging Infrastructure**
   - Real-time message sending and receiving
   - Optimistic UI updates
   - Message delivery states
   - Typing indicators
   - Firebase listeners with proper cleanup

3. **Offline Support**
   - SwiftData local persistence
   - Network monitoring
   - Message queue for offline sends
   - Auto-sync on reconnection

4. **Services Layer**
   - Centralized FirebaseService
   - NetworkMonitor for connectivity
   - NotificationService for push notifications
   - All with proper lifecycle management

5. **Security**
   - Firestore rules: participants-only access
   - Storage rules: authenticated users, 10MB limit
   - User data isolation

### ✅ Completed in This Session
1. User search for creating new conversations - **DONE**
2. Group chat creation UI - **DONE**
3. Typing indicators with auto-scroll - **DONE**
4. Real-time messaging tested on multiple devices - **DONE**
5. All UI/UX bugs fixed - **DONE**

### ⏸️ Post-MVP / Optional
1. Read receipt display UI
2. Media upload (images/GIFs)
3. Profile picture upload
4. Message pagination
5. APNs configuration for background notifications

## What Makes This Different
- **Code-first approach** - Built entire structure before Xcode project
- **Offline-first architecture** - Not an afterthought, baked into design
- **Real-device validation** - Designed for testing on physical devices
- **AI-ready architecture** - Clean separation for future AI features
- **Security-first** - Rules written before any data created

## User Experience Goals
1. **Instant Feedback** - Messages appear immediately when sent
2. **Clear Status** - Users always know message delivery state
3. **Presence Awareness** - Know when contacts are online and typing
4. **Seamless Offline** - No jarring errors when offline
5. **Persistent History** - All messages survive app restarts

## Success Metrics (Not Yet Measured)
Will be validated once Xcode project is running:
- Message latency < 1 second
- Zero message loss in testing
- Offline queue working correctly
- App handles 20+ rapid messages
- Poor network doesn't break app
