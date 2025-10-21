//
//  MessageAIApp.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

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

@main
struct MessageAIApp: App {

    @Environment(\.scenePhase) private var scenePhase
    
    // Force Firebase configuration before accessing FirebaseService
    private let firebaseConfigurator = FirebaseConfigurator.shared
    private let firebaseService = FirebaseService.shared

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

        Task {
            switch newPhase {
            case .active:
                // App came to foreground - user is online
                try? await firebaseService.updateOnlineStatus(userId: userId, isOnline: true)
                print("✅ User status: online")

            case .background, .inactive:
                // App went to background or became inactive - user is offline
                try? await firebaseService.updateOnlineStatus(userId: userId, isOnline: false)
                print("✅ User status: offline")

            @unknown default:
                break
            }
        }
    }
}
