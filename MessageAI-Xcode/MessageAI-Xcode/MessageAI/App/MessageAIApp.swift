//
//  MessageAIApp.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

@main
struct MessageAIApp: App {
    
    init() {
        configureFirebase()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(FirebaseService.shared)
        }
    }
    
    // MARK: - Firebase Configuration
    
    private func configureFirebase() {
        FirebaseApp.configure()
        
        // CRITICAL: Enable offline persistence
        // This must be done immediately after Firebase initialization
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        Firestore.firestore().settings = settings
        
        print("✅ Firebase configured with offline persistence enabled")
    }
}

