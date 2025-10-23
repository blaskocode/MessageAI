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
    @Published var senderDetails: [String: (name: String, initials: String, color: String, photoURL: String?)] = [:]
    
    // User's fluent languages for translation filtering (PR #2)
    @Published var userFluentLanguages: [String] = ["en"] // Default to English
    
    // User's cultural hints preference (PR #3)
    @Published var culturalHintsEnabled: Bool = true // Default to enabled

    let conversationId: String
    var currentUserId: String? {
        firebaseService.currentUserId
    }

    let firebaseService = FirebaseService.shared
    let notificationService = NotificationService.shared
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
        loadUserFluentLanguages()
        loadAutoTranslateSetting() // Load persisted auto-translate setting
        markMessagesAsRead()
    }

    // MARK: - Auto-Translate Persistence
    
    private func loadAutoTranslateSetting() {
        // Load per-conversation auto-translate setting from UserDefaults
        let key = "autoTranslate_\(conversationId)"
        autoTranslateEnabled = UserDefaults.standard.bool(forKey: key)
        print("🔄 [Auto-Translate] Loaded setting for conversation \(conversationId): \(autoTranslateEnabled)")
    }
    
    func saveAutoTranslateSetting() {
        // Save per-conversation auto-translate setting to UserDefaults
        let key = "autoTranslate_\(conversationId)"
        UserDefaults.standard.set(autoTranslateEnabled, forKey: key)
        print("💾 [Auto-Translate] Saved setting for conversation \(conversationId): \(autoTranslateEnabled)")
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
                let photoURL = userProfile["profilePictureURL"] as? String
                senderDetails[userId] = (name: name, initials: initials.uppercased(), color: color, photoURL: photoURL)
            } catch {
                print("❌ Failed to load sender details for \(userId): \(error)")
            }
        }
    }
    
    // MARK: - Load User Fluent Languages
    
    private func loadUserFluentLanguages() {
        guard let userId = currentUserId else { return }
        
        Task {
            do {
                let userDoc = try await firebaseService.fetchUserProfile(userId: userId)
                if let languages = userDoc["fluentLanguages"] as? [String], !languages.isEmpty {
                    self.userFluentLanguages = languages
                    print("✅ Loaded fluent languages for user: \(languages)")
                } else {
                    // Default to English if not set
                    self.userFluentLanguages = ["en"]
                    print("⚠️ No fluent languages set, defaulting to English")
                }
                
                // Load cultural hints preference (PR #3)
                if let hintsEnabled = userDoc["culturalHintsEnabled"] as? Bool {
                    self.culturalHintsEnabled = hintsEnabled
                    print("✅ Loaded cultural hints preference: \(hintsEnabled)")
                } else {
                    // Default to enabled if not set
                    self.culturalHintsEnabled = true
                    print("⚠️ No cultural hints preference set, defaulting to enabled")
                }
            } catch {
                print("❌ Failed to load user preferences: \(error)")
                self.userFluentLanguages = ["en"] // Fallback
                self.culturalHintsEnabled = true // Fallback
            }
        }
    }
    
    /**
     * Check if translate button should be shown for a message
     * Only show if message is in a language the user is NOT fluent in
     */
    func shouldShowTranslateButton(for message: Message) -> Bool {
        // Need detected language to make decision
        guard let detectedLanguage = message.detectedLanguage else {
            return false // Don't show button until language is detected
        }
        
        // Check if message language is in user's fluent languages
        // Show button only if NOT a fluent language
        return !userFluentLanguages.contains(detectedLanguage.lowercased())
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
        guard let currentUserId = currentUserId else { return }
        
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
            let detectedLanguage = data?["detectedLanguage"] as? String // PR #2: Language detection

            let message = Message(
                id: id,
                senderId: senderId,
                text: text,
                mediaURL: mediaURL,
                mediaType: mediaType,
                timestamp: timestamp,
                status: status,
                deliveredTo: deliveredTo,
                readBy: readBy,
                detectedLanguage: detectedLanguage
            )

            // Check if this is a new message (not in previous set)
            let isNewMessage = !previousMessageIds.contains(id)
            let isFromOtherUser = senderId != currentUserId
            let hasText = text != nil && !text!.isEmpty
            let shouldNotify = !isInitialLoad && isNewMessage && isFromOtherUser && hasText
            
            // Trigger language detection for new messages if not already detected (PR #2)
            if isNewMessage && hasText && detectedLanguage == nil {
                Task {
                    await self.detectAndUpdateLanguage(messageId: id, text: text!)
                }
            }
            
            // Check auto-translate for new incoming messages (PR #3)
            if !isInitialLoad && isNewMessage && isFromOtherUser && hasText {
                Task {
                    await self.checkAutoTranslate(for: message)
                }
            }

            // Trigger notification for new messages from other users (but not on initial load)
            if shouldNotify {
                triggerNotificationForMessage(message: message, senderId: senderId)
            }
            
            // Automatically mark new incoming messages as read (since user is viewing the chat)
            if !isInitialLoad && isNewMessage && isFromOtherUser && !readBy.contains(currentUserId) {
                markMessageAsRead(messageId: id)
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
            
            // Detect language in background (PR #2)
            Task {
                await detectAndUpdateLanguage(messageId: messageId, text: text)
            }

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
                
                // Clear any lingering notifications for this conversation
                NotificationService.shared.clearNotificationsForConversation(conversationId: conversationId)
            } catch {
                print("⚠️ Failed to mark as read: \(error)")
            }
        }
    }
    
    private func markMessageAsRead(messageId: String) {
        guard let userId = currentUserId else { return }
        
        Task {
            do {
                try await firebaseService.markMessageAsRead(
                    conversationId: conversationId,
                    messageId: messageId,
                    userId: userId
                )
                print("✅ Marked message \(messageId) as read")
            } catch {
                print("⚠️ Failed to mark message as read: \(error)")
            }
        }
    }

    // MARK: - Translation (PR #2 & PR #3)
    
    @Published var translations: [String: Translation] = [:]
    @Published var isTranslating: [String: Bool] = [:]
    @Published var translationErrors: [String: String] = [:]
    
    // Auto-translate mode (PR #3)
    @Published var autoTranslateEnabled: Bool = false
    @Published var culturalContexts: [String: CulturalContext] = [:]
    @Published var dismissedHints: Set<String> = []
    
    let aiService = AIService.shared
    
    // Translation methods moved to ChatViewModel+Translation.swift extension

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
