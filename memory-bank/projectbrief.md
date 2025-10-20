# Project Brief: MessageAI

## Overview
MessageAI is a real-time messaging application for iOS that provides reliable, WhatsApp-like messaging infrastructure. The MVP focuses exclusively on proving the core messaging infrastructure works flawlessly before any AI features are added.

## Current Status
**Phase:** Project Structure Complete  
**Code Base:** 21 Swift files created (~2,000 lines)  
**Next Step:** Xcode project creation and Firebase configuration

## Timeline
24 Hours to MVP (started October 20, 2025)

## Primary Goal
Build a bulletproof messaging system where two users can reliably exchange messages in real-time, messages persist across app restarts, and the system gracefully handles offline scenarios.

## Success Definition
The MVP succeeds when:
1. Two users can send text messages that appear instantly (< 1 second)
2. Messages persist across app force-quit and restart
3. Offline scenario works: User A offline → User B sends message → User A comes online → message appears
4. Group chat with 3 users works with proper attribution
5. Read receipts update correctly in real-time
6. Online/offline status indicators work
7. Typing indicators appear/disappear correctly
8. Push notifications display in foreground
9. App handles rapid-fire messaging without crashes or lost messages
10. Poor network conditions don't break the app

**If any of these fail, the MVP fails.**

## Project Structure Created

### Application Code (MessageAI/)
- **App/**: Entry point with Firebase configuration
- **Features/**: Auth, Chat, Conversations, Profile modules
- **Services/**: FirebaseService, NetworkMonitor, NotificationService
- **Models/**: User, Conversation, Message (SwiftData)
- **Utilities/**: Constants, Extensions

### Infrastructure
- **firebase/**: Security rules for Firestore and Storage
- **memory-bank/**: Project documentation
- **Docs**: README, SETUP guide, structure documentation

### Total Files Created
- 21 Swift source files
- 6 configuration files
- 6 memory bank documents
- ~3,500 total lines

## Core Principles
1. **Reliability First** - A simple, reliable chat app beats a feature-rich app with flaky message delivery
2. **Infrastructure Over Features** - Prove the foundation works before adding AI capabilities
3. **Real-World Testing** - Must work on physical devices under real network conditions
4. **Offline-First** - Handle disconnections gracefully with local persistence and sync

## Scope Boundaries

### In Scope (MVP)
- User authentication & profiles ✅ Built
- One-on-one text messaging ✅ Built (needs testing)
- Group chat (3+ users) ✅ Built (needs testing)
- Message read receipts ✅ Built (needs UI)
- Push notifications (foreground minimum) ✅ Built (needs testing)
- Offline support & sync ✅ Built (needs testing)
- Images & GIFs (P1) - Not yet built

### Explicitly Out of Scope
- AI features (Phase 2)
- Voice/video messages
- Message editing/deletion
- Reactions, stickers
- Voice/video calls
- Advanced group management
- End-to-end encryption
- Multi-device support

## Platform
iOS Native (Swift + SwiftUI + SwiftData)  
Minimum: iOS 17.0+

## Backend
Firebase (Firestore, Auth, Storage, FCM)

## Next Critical Steps
1. Create Xcode project from existing source files
2. Set up Firebase project and enable services
3. Add Swift package dependencies
4. Build and test on physical devices
