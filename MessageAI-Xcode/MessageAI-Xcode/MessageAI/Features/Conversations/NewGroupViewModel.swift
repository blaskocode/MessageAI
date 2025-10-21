//
//  NewGroupViewModel.swift
//  MessageAI
//
//  Created on October 21, 2025
//

import Foundation
import FirebaseFirestore

@MainActor
class NewGroupViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [[String: Any]] = []
    @Published var selectedUserIds: Set<String> = []
    @Published var groupName: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let firebaseService = FirebaseService.shared
    private var currentUserId: String? {
        firebaseService.currentUserId
    }
    
    func searchUsers() async {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let users = try await firebaseService.searchUsers(query: searchText)
            // Filter out the current user from search results
            searchResults = users.filter { ($0["userId"] as? String) != currentUserId }
            isLoading = false
        } catch {
            errorMessage = "Failed to search users: \(error.localizedDescription)"
            isLoading = false
            print("❌ Search users error: \(error)")
        }
    }
    
    func toggleUserSelection(userId: String) {
        if selectedUserIds.contains(userId) {
            selectedUserIds.remove(userId)
        } else {
            selectedUserIds.insert(userId)
        }
    }
    
    func isUserSelected(userId: String) -> Bool {
        selectedUserIds.contains(userId)
    }
    
    func createGroup() async -> String? {
        guard let currentUserId = currentUserId else {
            errorMessage = "User not authenticated."
            return nil
        }
        
        guard selectedUserIds.count >= 2 else {
            errorMessage = "Please select at least 2 other users for a group."
            return nil
        }
        
        let trimmedGroupName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGroupName.isEmpty else {
            errorMessage = "Please enter a group name."
            return nil
        }
        
        guard trimmedGroupName.count >= 2 && trimmedGroupName.count <= 50 else {
            errorMessage = "Group name must be between 2 and 50 characters."
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var participantIds = Array(selectedUserIds)
            participantIds.append(currentUserId)
            participantIds.sort()
            
            let conversationId = try await firebaseService.createConversation(
                participantIds: participantIds,
                type: "group",
                groupName: trimmedGroupName
            )
            isLoading = false
            return conversationId
        } catch {
            errorMessage = "Failed to create group: \(error.localizedDescription)"
            isLoading = false
            print("❌ Create group error: \(error)")
            return nil
        }
    }
    
    var canCreateGroup: Bool {
        selectedUserIds.count >= 2 && !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

