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

        // Clean up any duplicate conversations on first load
        if isInitialLoad {
            Task {
                do {
                    try await firebaseService.cleanupDuplicateConversations(currentUserId: userId)
                    print("✅ Cleanup check complete")
                } catch {
                    print("⚠️ Cleanup error: \(error)")
                }
            }
        }

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

            // Filter out conversations with no messages
            guard lastMessageText != nil && !lastMessageText!.isEmpty else {
                return nil
            }

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

            // Parse participant details
            let participantDetailsData = data?["participantDetails"] as? [String: [String: Any]] ?? [:]
            var participantDetails: [String: ParticipantInfo] = [:]
            for (userId, details) in participantDetailsData {
                if let name = details["name"] as? String {
                    let photoURL = details["photoURL"] as? String
                    let isOnline = details["isOnline"] as? Bool
                    participantDetails[userId] = ParticipantInfo(name: name, photoURL: photoURL, isOnline: isOnline)
                }
            }

            // If participant details are missing, fetch them asynchronously
            if participantDetails.isEmpty && !participantIds.isEmpty {
                Task {
                    await self.fetchAndUpdateParticipantDetails(conversationId: id, participantIds: participantIds)
                }
            }

            // Determine if conversation has unread messages
            let readBy = lastMessageData?["readBy"] as? [String] ?? []
            let hasUnread = lastMessageSenderId != currentUserId &&
                            !readBy.contains(currentUserId) &&
                            lastMessageText != nil

            return Conversation(
                id: id,
                type: type,
                participantIds: participantIds,
                participantDetails: participantDetails,
                lastMessageText: lastMessageText,
                lastMessageSenderId: lastMessageSenderId,
                lastMessageTimestamp: lastMessageTimestamp,
                lastUpdated: lastUpdated,
                createdAt: createdAt,
                hasUnreadMessages: hasUnread,
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

    private func fetchAndUpdateParticipantDetails(conversationId: String, participantIds: [String]) async {
        var participantDetails: [String: [String: Any]] = [:]

        for participantId in participantIds {
            do {
                let userData = try await firebaseService.fetchUserProfile(userId: participantId)
                let displayName = userData["displayName"] as? String ?? "Unknown"
                let profileColorHex = userData["profileColorHex"] as? String
                let isOnline = userData["isOnline"] as? Bool ?? false
                participantDetails[participantId] = [
                    "name": displayName,
                    "photoURL": profileColorHex ?? "#4ECDC4",
                    "isOnline": isOnline
                ]
            } catch {
                print("⚠️ Could not fetch details for participant \(participantId): \(error)")
            }
        }

        // Update Firestore with participant details
        do {
            try await firebaseService.updateConversationParticipantDetails(
                conversationId: conversationId,
                participantDetails: participantDetails
            )
            print("✅ Updated participant details for conversation \(conversationId)")
        } catch {
            print("⚠️ Could not update participant details: \(error)")
        }
    }

    deinit {
        listener?.remove()
    }
}
