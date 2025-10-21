//
//  ChatViewModel.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import Foundation
import FirebaseFirestore

@MainActor
class ChatViewModel: ObservableObject {

    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isTyping = false
    @Published var conversationTitle: String = "Chat"
    @Published var senderDetails: [String: (name: String, initials: String, color: String)] = [:]

    let conversationId: String
    var currentUserId: String? {
        firebaseService.currentUserId
    }

    private let firebaseService = FirebaseService.shared
    private let notificationService = NotificationService.shared
    private nonisolated(unsafe) var messageListener: ListenerRegistration?
    private nonisolated(unsafe) var typingListener: ListenerRegistration?

    // Track previously seen message IDs to detect new messages
    private var previousMessageIds: Set<String> = []

    // Track if this is the initial load (don't notify on first load)
    private var isInitialLoad = true

    // Cache conversation details for notifications
    private var conversationType: String?
    private var groupName: String?
    @Published var participantIds: [String] = []
    private var participantDetails: [String: [String: Any]] = [:]

    init(conversationId: String) {
        self.conversationId = conversationId
        loadConversationDetails()
        markMessagesAsRead()
    }

    // MARK: - Load Conversation Details

    private func loadConversationDetails() {
        Task {
            do {
                let conversation = try await firebaseService.fetchConversation(conversationId: conversationId)
                self.conversationType = conversation["type"] as? String
                self.groupName = conversation["groupName"] as? String
                self.participantIds = conversation["participantIds"] as? [String] ?? []
                self.participantDetails = conversation["participantDetails"] as? [String: [String: Any]] ?? [:]

                // Set conversation title
                if conversationType == "group" {
                    conversationTitle = groupName ?? "Group Chat"
                } else {
                    // For direct chats, show the other participant's name
                    let otherParticipantIds = participantIds.filter { $0 != currentUserId }
                    if let otherUserId = otherParticipantIds.first,
                       let details = participantDetails[otherUserId],
                       let name = details["name"] as? String {
                        conversationTitle = name
                    }
                }

                // Load sender details for all participants
                await loadSenderDetails()
            } catch {
                print("❌ Failed to load conversation details: \(error)")
            }
        }
    }

    private func loadSenderDetails() async {
        for userId in participantIds {
            do {
                let userProfile = try await firebaseService.fetchUserProfile(userId: userId)
                let name = userProfile["displayName"] as? String ?? "Unknown"
                let initials = userProfile["initials"] as? String ?? "?"
                let color = userProfile["profileColorHex"] as? String ?? "#4169E1"
                senderDetails[userId] = (name: name, initials: initials.uppercased(), color: color)
            } catch {
                print("❌ Failed to load sender details for \(userId): \(error)")
            }
        }
    }

    // MARK: - Load Messages

    func loadMessages() {
        guard let userId = currentUserId else { return }

        isLoading = true

        messageListener = firebaseService.fetchMessages(conversationId: conversationId) { [weak self] documents in
            self?.isLoading = false
            self?.parseMessages(documents)
        }

        // Listen for typing status
        typingListener = firebaseService.observeTypingStatus(conversationId: conversationId, currentUserId: userId) { [weak self] isTyping in
            Task { @MainActor in
                self?.isTyping = isTyping
            }
        }

        // Mark messages as read
        Task {
            try? await markMessagesAsRead(userId: userId)
        }
    }

    private func parseMessages(_ documents: [DocumentSnapshot]) {
        messages = documents.compactMap { doc -> Message? in
            let data = doc.data()

            guard let id = data?["messageId"] as? String,
                  let senderId = data?["senderId"] as? String,
                  let timestamp = (data?["timestamp"] as? Timestamp)?.dateValue(),
                  let statusString = data?["status"] as? String,
                  let status = MessageStatus(rawValue: statusString) else {
                return nil
            }

            let text = data?["text"] as? String
            let mediaURL = data?["mediaURL"] as? String
            let mediaTypeString = data?["mediaType"] as? String
            let mediaType = mediaTypeString.flatMap { MediaType(rawValue: $0) }
            let deliveredTo = data?["deliveredTo"] as? [String] ?? []
            let readBy = data?["readBy"] as? [String] ?? []

            let message = Message(
                id: id,
                senderId: senderId,
                text: text,
                mediaURL: mediaURL,
                mediaType: mediaType,
                timestamp: timestamp,
                status: status,
                deliveredTo: deliveredTo,
                readBy: readBy
            )

            // Check if this is a new message (not in previous set)
            let isNewMessage = !previousMessageIds.contains(id)
            let isFromOtherUser = senderId != currentUserId
            let hasText = text != nil && !text!.isEmpty
            let shouldNotify = !isInitialLoad && isNewMessage && isFromOtherUser && hasText

            // Trigger notification for new messages from other users (but not on initial load)
            if shouldNotify {
                triggerNotificationForMessage(message: message, senderId: senderId)
            }

            return message
        }
        .sorted { $0.timestamp < $1.timestamp }

        // Update previous message IDs for next comparison
        previousMessageIds = Set(messages.map { $0.id })

        // Mark initial load as complete
        if isInitialLoad {
            isInitialLoad = false
        }
    }

    // MARK: - Notifications

    private func triggerNotificationForMessage(message: Message, senderId: String) {
        guard let text = message.text else { return }

        // Fetch sender's display name
        Task {
            do {
                let senderData = try await firebaseService.fetchUserProfile(userId: senderId)
                let senderName = senderData["displayName"] as? String ?? "Someone"

                // Trigger local notification
                notificationService.triggerLocalNotification(
                    senderName: senderName,
                    messageText: text,
                    conversationId: conversationId,
                    conversationType: conversationType ?? "direct",
                    groupName: groupName
                )
            } catch {
                print("❌ Failed to fetch sender for notification: \(error)")
            }
        }
    }

    // MARK: - Send Message

    func sendMessage(text: String) async {
        guard let senderId = currentUserId else { return }

        // Create optimistic message
        let tempMessage = Message(
            id: UUID().uuidString,
            senderId: senderId,
            text: text,
            timestamp: Date(),
            status: .sending,
            isPending: true
        )

        // Add to UI immediately (optimistic update)
        messages.append(tempMessage)

        do {
            // Send to Firebase
            let messageId = try await firebaseService.sendMessage(
                conversationId: conversationId,
                senderId: senderId,
                text: text
            )

            // Update optimistic message with real ID and status
            if let index = messages.firstIndex(where: { $0.id == tempMessage.id }) {
                messages[index].id = messageId
                messages[index].status = .sent
                messages[index].isPending = false
            }

            print("✅ Message sent: \(messageId)")

        } catch {
            // Mark message as failed
            if let index = messages.firstIndex(where: { $0.id == tempMessage.id }) {
                messages[index].status = .failed
            }

            print("❌ Failed to send message: \(error)")
        }
    }

    // MARK: - Typing Indicator

    func updateTypingStatus(isTyping: Bool) {
        guard let userId = currentUserId else { return }

        Task {
            do {
                try await firebaseService.updateTypingStatus(
                    conversationId: conversationId,
                    userId: userId,
                    isTyping: isTyping
                )
            } catch {
                print("❌ Failed to update typing status: \(error)")
            }
        }
    }

    // MARK: - Read Receipts

    private func markMessagesAsRead(userId: String) async throws {
        // TODO: Implement bulk read receipt update
        // For now, this is a placeholder
        print("📖 Marking messages as read for user: \(userId)")
    }

    // MARK: - Mark Messages as Read

    func markMessagesAsRead() {
        guard let userId = currentUserId else { return }

        Task {
            do {
                try await firebaseService.markConversationAsRead(
                    conversationId: conversationId,
                    userId: userId
                )
                print("✅ Marked conversation \(conversationId) as read")
            } catch {
                print("⚠️ Failed to mark as read: \(error)")
            }
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        messageListener?.remove()
        typingListener?.remove()

        // Clear typing indicator on exit
        if let userId = currentUserId {
            Task { @MainActor in
                try? await firebaseService.updateTypingStatus(
                    conversationId: conversationId,
                    userId: userId,
                    isTyping: false
                )
            }
        }
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.cleanup()
        }
    }
}
