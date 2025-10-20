//
//  ConversationListViewModel.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import Foundation
import FirebaseFirestore

@MainActor
class ConversationListViewModel: ObservableObject {
    
    @Published var conversations: [Conversation] = []
    @Published var showNewConversation = false
    @Published var isLoading = false
    
    private let firebaseService = FirebaseService.shared
    private var listener: ListenerRegistration?
    
    func loadConversations() {
        guard let userId = firebaseService.currentUserId else {
            print("❌ No current user")
            return
        }
        
        isLoading = true
        
        listener = firebaseService.fetchConversations(userId: userId) { [weak self] documents in
            self?.isLoading = false
            self?.parseConversations(documents)
        }
    }
    
    private func parseConversations(_ documents: [DocumentSnapshot]) {
        conversations = documents.compactMap { doc -> Conversation? in
            let data = doc.data()
            
            guard let id = data?["conversationId"] as? String,
                  let typeString = data?["type"] as? String,
                  let type = ConversationType(rawValue: typeString),
                  let participantIds = data?["participantIds"] as? [String] else {
                return nil
            }
            
            let lastMessageData = data?["lastMessage"] as? [String: Any]
            let lastMessageText = lastMessageData?["text"] as? String
            let lastMessageSenderId = lastMessageData?["senderId"] as? String
            
            let timestamp = lastMessageData?["timestamp"] as? Timestamp
            let lastMessageTimestamp = timestamp?.dateValue()
            
            let lastUpdatedTimestamp = data?["lastUpdated"] as? Timestamp
            let lastUpdated = lastUpdatedTimestamp?.dateValue() ?? Date()
            
            let createdAtTimestamp = data?["createdAt"] as? Timestamp
            let createdAt = createdAtTimestamp?.dateValue() ?? Date()
            
            let groupName = data?["groupName"] as? String
            let createdBy = data?["createdBy"] as? String
            
            return Conversation(
                id: id,
                type: type,
                participantIds: participantIds,
                lastMessageText: lastMessageText,
                lastMessageSenderId: lastMessageSenderId,
                lastMessageTimestamp: lastMessageTimestamp,
                lastUpdated: lastUpdated,
                createdAt: createdAt,
                groupName: groupName,
                createdBy: createdBy
            )
        }
        
        print("✅ Loaded \(conversations.count) conversations")
    }
    
    deinit {
        listener?.remove()
    }
}

