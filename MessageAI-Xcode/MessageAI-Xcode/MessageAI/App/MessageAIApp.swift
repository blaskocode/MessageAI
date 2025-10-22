//
//  MessageAIApp.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import UIKit

// MARK: - Firebase Configuration (must run BEFORE App initialization)
private class FirebaseConfigurator {
    static let shared = FirebaseConfigurator()
    
    private init() {
        FirebaseApp.configure()
        
        // CRITICAL: Enable offline persistence
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        Firestore.firestore().settings = settings
        
        print("✅ Firebase configured with offline persistence enabled")
    }
}

// MARK: - Presence Manager (using Firebase Realtime Database)
@MainActor
class PresenceManager: ObservableObject {
    static let shared = PresenceManager()
    
    private let realtimePresence = RealtimePresenceService.shared
    
    private init() {
        print("✅ PresenceManager initialized with RTDB")
    }
    
    func startPresenceMonitoring(userId: String) {
        // Use Firebase Realtime Database with onDisconnect()
        // This provides IMMEDIATE offline detection when app force-quits
        realtimePresence.goOnline(userId: userId)
        print("✅ Presence monitoring started with RTDB onDisconnect()")
    }
    
    func stopPresenceMonitoring(userId: String) {
        // Manually mark offline (for sign-out scenarios)
        realtimePresence.goOffline(userId: userId)
        print("✅ User marked offline via RTDB")
    }
    
    deinit {
        print("🛑 PresenceManager deinitialized")
    }
}

@main
struct MessageAIApp: App {

    @Environment(\.scenePhase) private var scenePhase
    
    // Force Firebase configuration before accessing FirebaseService
    private let firebaseConfigurator = FirebaseConfigurator.shared
    private let firebaseService = FirebaseService.shared
    private let presenceManager = PresenceManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(firebaseService)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
        }
    }

    // MARK: - Scene Phase Handling

    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        guard let userId = firebaseService.currentUserId else { return }

        print("🔄 Scene phase change: \(oldPhase) → \(newPhase)")

        switch newPhase {
        case .active:
            // App came to foreground - start presence monitoring
            presenceManager.startPresenceMonitoring(userId: userId)
            print("✅ User status: online (with heartbeat)")

        case .background:
            // App went to background - mark offline immediately
            print("⚠️ Marking user offline (background)...")
            presenceManager.stopPresenceMonitoring(userId: userId)
            print("✅ User status: offline (background)")
            
        case .inactive:
            // Inactive is transitional - if coming from active, mark offline preemptively
            if oldPhase == .active {
                print("⚠️ Inactive from active - marking offline preemptively...")
                presenceManager.stopPresenceMonitoring(userId: userId)
            } else {
                print("⚠️ User status: inactive (transitioning)")
            }
            
        @unknown default:
            break
        }
    }
}
