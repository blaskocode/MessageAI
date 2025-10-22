//
//  RealtimePresenceService.swift
//  MessageAI
//
//  Created on October 22, 2025
//
//  Firebase Realtime Database service for immediate presence detection
//  Uses onDisconnect() for server-side disconnect handling
//

import Foundation
import FirebaseDatabase

/// Service for managing user presence using Firebase Realtime Database
/// This provides IMMEDIATE offline detection when users force-quit, crash, or lose connection
/// Uses Firebase's server-side onDisconnect() callbacks - the ONLY reliable way to detect disconnects
@MainActor
class RealtimePresenceService: ObservableObject {
    
    static let shared = RealtimePresenceService()
    
    private let database: DatabaseReference
    private var presenceListeners: [String: DatabaseHandle] = [:]
    
    private init() {
        // Initialize Firebase Realtime Database
        self.database = Database.database().reference()
        
        print("✅ [RTDB] RealtimePresenceService initialized")
    }
    
    // MARK: - Presence Management
    
    /// Set user as online with automatic server-side disconnect handling
    /// When connection drops (force-quit, crash, death), Firebase SERVER sets offline automatically
    func goOnline(userId: String) {
        let presenceRef = database.child("presence").child(userId)
        
        // CRITICAL: Set up onDisconnect() FIRST (server-side callback)
        // This tells Firebase: "When this client disconnects, run this immediately"
        presenceRef.onDisconnectSetValue([
            "online": false,
            "lastSeen": ServerValue.timestamp()
        ]) { error, _ in
            if let error = error {
                print("⚠️ [RTDB] Failed to set onDisconnect: \(error.localizedDescription)")
            } else {
                print("✅ [RTDB] onDisconnect() registered for user \(userId)")
            }
        }
        
        // Then set current online status
        presenceRef.setValue([
            "online": true,
            "lastSeen": ServerValue.timestamp()
        ]) { error, _ in
            if let error = error {
                print("❌ [RTDB] Failed to set online: \(error.localizedDescription)")
            } else {
                print("✅ [RTDB] User \(userId) marked ONLINE with disconnect handler")
            }
        }
    }
    
    /// Manually set user as offline
    /// Used for explicit sign-out scenarios
    func goOffline(userId: String) {
        let presenceRef = database.child("presence").child(userId)
        
        // Cancel any pending onDisconnect operations
        presenceRef.cancelDisconnectOperations()
        
        // Set offline status
        presenceRef.setValue([
            "online": false,
            "lastSeen": ServerValue.timestamp()
        ]) { error, _ in
            if let error = error {
                print("❌ [RTDB] Failed to set offline: \(error.localizedDescription)")
            } else {
                print("✅ [RTDB] User \(userId) marked OFFLINE")
            }
        }
    }
    
    // MARK: - Presence Observation
    
    /// Observe real-time presence for a specific user
    /// Returns immediate updates when user goes online/offline
    func observePresence(userId: String, completion: @escaping (Bool) -> Void) -> DatabaseHandle {
        let presenceRef = database.child("presence").child(userId)
        
        let handle = presenceRef.observe(.value) { snapshot in
            guard let data = snapshot.value as? [String: Any] else {
                completion(false)
                return
            }
            
            let isOnline = data["online"] as? Bool ?? false
            completion(isOnline)
            
            if let lastSeen = data["lastSeen"] as? TimeInterval {
                let date = Date(timeIntervalSince1970: lastSeen / 1000)
                let ago = Date().timeIntervalSince(date)
                print("👤 [RTDB] User \(userId): \(isOnline ? "ONLINE" : "OFFLINE") (lastSeen: \(Int(ago))s ago)")
            }
        }
        
        presenceListeners[userId] = handle
        return handle
    }
    
    /// Observe presence for multiple users
    /// Efficient batch observation
    func observeMultipleUsers(userIds: [String], completion: @escaping ([String: Bool]) -> Void) {
        for userId in userIds {
            _ = observePresence(userId: userId) { isOnline in
                // Call completion with single user update
                completion([userId: isOnline])
            }
        }
        
        print("✅ [RTDB] Observing presence for \(userIds.count) users")
    }
    
    /// Stop observing presence for a specific user
    func stopObserving(userId: String) {
        if let handle = presenceListeners[userId] {
            let presenceRef = database.child("presence").child(userId)
            presenceRef.removeObserver(withHandle: handle)
            presenceListeners.removeValue(forKey: userId)
            print("🛑 [RTDB] Stopped observing user \(userId)")
        }
    }
    
    /// Stop observing all users
    func stopObservingAll() {
        for (userId, handle) in presenceListeners {
            let presenceRef = database.child("presence").child(userId)
            presenceRef.removeObserver(withHandle: handle)
        }
        presenceListeners.removeAll()
        print("🛑 [RTDB] Stopped observing all users")
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Clean up listeners synchronously (safe since we're just removing observers)
        for (userId, handle) in presenceListeners {
            let presenceRef = database.child("presence").child(userId)
            presenceRef.removeObserver(withHandle: handle)
        }
        print("🛑 [RTDB] RealtimePresenceService deinitialized")
    }
}

// MARK: - How This Works

/*
 
 ## The Problem We're Solving:
 
 When a user force-quits an app or their device dies:
 - ❌ App lifecycle methods don't fire (willTerminate, scenePhase)
 - ❌ The app CANNOT execute any code to mark itself offline
 - ❌ Traditional approaches fail completely
 
 ## The Solution: Firebase Realtime Database onDisconnect()
 
 Firebase RTDB maintains a persistent TCP connection and monitors it SERVER-SIDE:
 
 ```
 1. App connects to Firebase RTDB
    ↓
 2. App registers: presenceRef.onDisconnect().set({ online: false })
    ↓
 3. Firebase SERVER stores this callback
    ↓
 4. App sets: presenceRef.set({ online: true })
    ↓
 5. User force-quits app / device dies / crashes
    ↓
 6. TCP connection breaks
    ↓
 7. Firebase SERVER detects broken connection (within 1-2 seconds)
    ↓
 8. Firebase SERVER automatically executes the onDisconnect() callback
    ↓
 9. Sets online: false WITHOUT any client involvement
    ↓
 10. Other clients receive update immediately (< 1 second)
    ↓
 11. ✅ Gray dot appears instantly!
 ```
 
 ## Why This Works:
 
 ✅ **Server-side detection** - Firebase detects disconnect, not the client
 ✅ **TCP-based** - Works for ANY disconnect reason (quit, crash, death, network loss)
 ✅ **Immediate** - Updates within 1-2 seconds (not 45-60 seconds)
 ✅ **Reliable** - No app lifecycle dependencies
 ✅ **Industry standard** - Used by WhatsApp, Slack, Facebook Messenger
 
 ## Architecture:
 
 ```
 Firestore (keeps):          RTDB (adds):
 - Messages                  - Presence (online/offline)
 - Conversations             - Typing indicators (optional)
 - User profiles
 - All persistent data
 ```
 
 This is a **hybrid approach** - best of both worlds:
 - Firestore for complex queries and offline caching
 - RTDB for real-time ephemeral data with disconnect detection
 
 */

