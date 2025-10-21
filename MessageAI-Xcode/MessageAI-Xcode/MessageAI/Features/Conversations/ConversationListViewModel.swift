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
    @Published var showNewGroup = false
    @Published var isLoading = false
    
    private let firebaseService = FirebaseService.shared
    private let notificationService = NotificationService.shared
    private var listener: ListenerRegistration?
    
    // Track previously seen last messages to detect new ones
    private var previousLastMessages: [String: String] = [:]  // conversationId -> lastMessageId
    private var isInitialLoad = true
    
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
        guard let currentUserId = firebaseService.currentUserId else { return }
        
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
            
            // Check if this is a new message that should trigger a notification
            let messageId = "\(id)_\(lastMessageText ?? "")_\(lastMessageSenderId ?? "")"
            let isNewMessage = previousLastMessages[id] != messageId
            let isFromOtherUser = lastMessageSenderId != currentUserId
            let hasText = lastMessageText != nil && !lastMessageText!.isEmpty
            let isNotActiveConversation = notificationService.activeConversationId != id
            
            // Trigger notification if this is a new message from someone else
            if !isInitialLoad && isNewMessage && isFromOtherUser && hasText && isNotActiveConversation {
                triggerNotification(
                    conversationId: id,
                    senderId: lastMessageSenderId!,
                    messageText: lastMessageText!,
                    conversationType: typeString,
                    groupName: data?["groupName"] as? String
                )
            }
            
            // Update tracked last message
            previousLastMessages[id] = messageId
            
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
        
        // Mark initial load as complete
        if isInitialLoad {
            isInitialLoad = false
        }
        
        print("✅ Loaded \(conversations.count) conversations")
    }
    
    private func triggerNotification(
        conversationId: String,
        senderId: String,
        messageText: String,
        conversationType: String,
        groupName: String?
    ) {
        Task {
            do {
                let senderData = try await firebaseService.fetchUserProfile(userId: senderId)
                let senderName = senderData["displayName"] as? String ?? "Someone"
                
                notificationService.triggerLocalNotification(
                    senderName: senderName,
                    messageText: messageText,
                    conversationId: conversationId,
                    conversationType: conversationType,
                    groupName: groupName
                )
            } catch {
                print("❌ Failed to fetch sender: \(error)")
            }
        }
    }
    
    deinit {
        listener?.remove()
    }
}

