//
//  ContentView.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                // Show main app
                ConversationListView()
            } else {
                // Show authentication
                AuthenticationView()
            }
        }
        .environmentObject(authViewModel)
        .onAppear {
            // Set user online if already authenticated on app launch
            if let userId = firebaseService.currentUserId {
                Task {
                    try? await firebaseService.updateOnlineStatus(userId: userId, isOnline: true)
                    print("✅ User set to online on app launch")
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FirebaseService.shared)
}
