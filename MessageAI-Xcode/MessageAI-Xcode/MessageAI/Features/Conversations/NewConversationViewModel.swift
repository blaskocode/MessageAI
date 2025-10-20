//
//  NewConversationViewModel.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import Foundation
import SwiftUI

@MainActor
class NewConversationViewModel: ObservableObject {
    
    @Published var searchText = ""
    @Published var searchResults: [[String: Any]] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let firebaseService = FirebaseService.shared
    
    // MARK: - Search Users
    
    func searchUsers() async {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let results = try await firebaseService.searchUsers(query: searchText)
            
            // Filter out current user
            searchResults = results.filter { userData in
                guard let userId = userData["userId"] as? String else { return false }
                return userId != firebaseService.currentUserId
            }
            
            isLoading = false
            print("✅ Found \(searchResults.count) matching users")
            
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            isLoading = false
            print("❌ Search error: \(error)")
        }
    }
    
    // MARK: - Create Conversation
    
    func createConversation(withUserId otherUserId: String) async -> String? {
        guard let currentUserId = firebaseService.currentUserId else {
            errorMessage = "Not authenticated"
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let conversationId = try await firebaseService.createConversation(
                participantIds: [currentUserId, otherUserId],
                type: "direct"
            )
            
            isLoading = false
            print("✅ Created conversation: \(conversationId)")
            return conversationId
            
        } catch {
            errorMessage = "Failed to create conversation: \(error.localizedDescription)"
            isLoading = false
            print("❌ Create conversation error: \(error)")
            return nil
        }
    }
}

