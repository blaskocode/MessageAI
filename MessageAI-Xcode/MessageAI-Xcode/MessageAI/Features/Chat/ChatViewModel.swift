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
    
    // Sticky-bottom scroll tracking
    @Published var contentVersion: Int = 0
    @Published var isAtBottom: Bool = true // Track if user is at bottom
    
    // User's fluent languages for translation filtering (PR #2)
    @Published var userFluentLanguages: [String] = ["en"] // Default to English
    
    // User's cultural hints preference (PR #3)
    @Published var culturalHintsEnabled: Bool = true // Default to enabled
    
    // Formality analysis cache (PR #4)
    @Published var formalityAnalyses: [String: FormalityAnalysis] = [:]
    @Published var adjustedVersions: [String: [FormalityLevel: String]] = [:]
    @Published var showingFormalitySheet: Bool = false
    @Published var selectedMessageForFormality: Message?
    
    // Auto-analyze formality setting (reads from UserDefaults, set in ProfileView)
    var autoAnalyzeFormality: Bool {
        UserDefaults.standard.bool(forKey: "autoAnalyzeFormality")
    }
    
    // Slang & idiom detection cache (PR #5)
    @Published var slangDetections: [String: [DetectedPhrase]] = [:]
    @Published var phraseExplanations: [String: PhraseExplanation] = [:]
    @Published var showingPhraseExplanationSheet: Bool = false
    @Published var selectedPhraseForExplanation: DetectedPhrase?
    @Published var currentExplanation: PhraseExplanation?
    @Published var loadingExplanation: Bool = false
    
    // Auto-detect slang setting (reads from UserDefaults, set in ProfileView)
    var autoDetectSlang: Bool {
        UserDefaults.standard.bool(forKey: "autoDetectSlang")
    }
    
    // Smart replies (PR #7)
    @Published var smartReplies: [SmartReply] = []
    @Published var showSmartReplies: Bool = false
    @Published var isGeneratingReplies: Bool = false
    @Published var lastIncomingMessageId: String?
    
    // Auto-generate smart replies setting (default to true for new users)
    var autoGenerateSmartReplies: Bool {
        // Check if key exists
        if UserDefaults.standard.object(forKey: "autoGenerateSmartReplies") == nil {
            // First time - default to true
            return true
        }
        return UserDefaults.standard.bool(forKey: "autoGenerateSmartReplies")
    }

    let conversationId: String
    var currentUserId: String? {
        firebaseService.currentUserId
    }

    let firebaseService = FirebaseService.shared
    let notificationService = NotificationService.shared
    let aiService = AIService.shared
    private nonisolated(unsafe) var messageListener: ListenerRegistration?
    private nonisolated(unsafe) var typingListener: ListenerRegistration?
    private nonisolated(unsafe) var newMessageListener: ListenerRegistration?

    // Track previously seen message IDs to detect new messages
    private var previousMessageIds: Set<String> = []

    // Track if this is the initial load (don't notify on first load)
    @Published var isInitialLoad = true
    
    // Pagination
    private var lastLoadedMessage: DocumentSnapshot?
    private let pageSize = 50
    @Published var canLoadMore = true
    @Published var isLoadingMore = false
    @Published var paginationError: String?
    @Published var isPaginationTriggered = false
    private var paginationRetryCount = 0
    
    // Track if we're currently processing paginated messages (to prevent scroll jumps)
    @Published var isProcessingPagination = false
    
    // Separate array for paginated messages to avoid triggering scroll anchor
    @Published var paginatedMessages: [Message] = []

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
        
        // Load most recent 50 messages with real-time listener
        messageListener = firebaseService.fetchRecentMessages(
            conversationId: conversationId,
            limit: pageSize
        ) { [weak self] documents in
            guard let self = self else { return }
            self.lastLoadedMessage = documents.first // For pagination cursor
            self.parseMessages(documents, isPagination: false)
            self.canLoadMore = documents.count == self.pageSize
            self.isLoading = false
        }
        
        // Listen for typing status (unchanged)
        typingListener = firebaseService.observeTypingStatus(
            conversationId: conversationId,
            currentUserId: userId
        ) { [weak self] isTyping in
            Task { @MainActor in
                self?.isTyping = isTyping
            }
        }
        
        // Mark messages as read
        Task {
            try? await markMessagesAsRead(userId: userId)
        }
    }

    func loadMoreMessages() async {
        guard !isLoadingMore, canLoadMore else { return }
        guard let lastMessage = lastLoadedMessage else { return }
        
        isLoadingMore = true
        isProcessingPagination = true
        paginationError = nil
        
        do {
            let olderMessages = try await firebaseService.fetchMessagesBefore(
                conversationId: conversationId,
                before: lastMessage,
                limit: pageSize
            )
            
            lastLoadedMessage = olderMessages.first
            canLoadMore = olderMessages.count == pageSize
            
            // Parse with pagination flag (enables AI but skips Smart Replies)
            parseMessages(olderMessages, isPagination: true)
            
            paginationRetryCount = 0 // Reset on success
            print("✅ Loaded \(olderMessages.count) older messages")
            
        } catch {
            paginationRetryCount += 1
            
            if paginationRetryCount < 2 {
                // Auto-retry once
                print("⚠️ Pagination failed, retrying... (attempt \(paginationRetryCount + 1))")
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
                await loadMoreMessages()
                return
            } else {
                // After 2 failures, show inline error
                paginationError = "Couldn't load messages. Tap to retry"
                print("❌ Pagination failed after 2 retries")
            }
        }
        
        isLoadingMore = false
        isProcessingPagination = false
    }

    private func parseMessages(_ documents: [DocumentSnapshot], isPagination: Bool = false) {
        guard let currentUserId = currentUserId else { return }
        
        let newMessages = documents.compactMap { doc -> Message? in
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

            // AI Features: Always allow (check cache first), but skip Smart Replies for old messages
            if !isPagination || !isInitialLoad {
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
                
                // Analyze formality for new incoming messages (PR #4)
                if isNewMessage && isFromOtherUser && hasText {
                    Task {
                        await self.analyzeFormalityIfNeeded(for: message)
                    }
                }
                
                // Detect slang/idioms for new incoming messages (PR #5)
                if isNewMessage && isFromOtherUser && hasText {
                    Task {
                        await self.detectSlangIfNeeded(for: message)
                    }
                }
                
                // Smart Replies ONLY for new incoming messages (not paginated)
                if isNewMessage && !isPagination && isFromOtherUser && hasText {
                    Task {
                        await self.generateSmartRepliesIfNeeded(for: message)
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
            }

            return message
        }
        
        if isPagination {
            // Insert older messages at the beginning (preserves scroll position)
            messages.insert(contentsOf: newMessages, at: 0)
        } else {
            // Normal real-time updates
            messages = newMessages.sorted { $0.timestamp < $1.timestamp }
            previousMessageIds = Set(messages.map { $0.id })
            
            if isInitialLoad {
                isInitialLoad = false
            }
            
            contentVersion += 1 // Trigger sticky-bottom scroll
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
                
                // Decrement badge count
                NotificationService.shared.decrementBadgeCount()
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
    
    // MARK: - Smart Replies (PR #7)
    
    /// Generate smart replies for the latest incoming message
    func generateSmartRepliesIfNeeded(for message: Message) async {
        print("🔍 [Smart Replies] Checking if should generate for message: \(message.id)")
        
        // Skip if auto-generate is disabled
        guard autoGenerateSmartReplies else {
            print("⏭️ [Smart Replies] Auto-generate disabled in settings")
            return
        }
        
        // Skip if message is from current user
        guard message.senderId != currentUserId else {
            print("⏭️ [Smart Replies] Message from current user, skipping")
            return
        }
        
        // Skip if we already generated for this message
        guard lastIncomingMessageId != message.id else {
            print("⏭️ [Smart Replies] Already generated for this message")
            return
        }
        
        // Skip if already generating
        guard !isGeneratingReplies else {
            print("⏭️ [Smart Replies] Already generating replies")
            return
        }
        
        print("🚀 [Smart Replies] Generating smart replies...")
        lastIncomingMessageId = message.id
        isGeneratingReplies = true
        
        do {
            let replies = try await aiService.generateSmartReplies(
                conversationId: conversationId,
                incomingMessageId: message.id
            )
            
            if !replies.isEmpty {
                smartReplies = replies
                showSmartReplies = true
                print("✨ [Smart Replies] Generated \(replies.count) smart replies - SHOWING UI")
            } else {
                print("⚠️ [Smart Replies] Backend returned empty array")
            }
            
        } catch {
            print("❌ [Smart Replies] Failed to generate: \(error.localizedDescription)")
        }
        
        isGeneratingReplies = false
    }
    
    /// Insert selected smart reply into draft
    func selectSmartReply(_ reply: SmartReply, into draftText: inout String) {
        draftText = reply.text
        showSmartReplies = false
        print("📝 Inserted smart reply: \(reply.text)")
    }
    
    /// Dismiss smart replies
    func dismissSmartReplies() {
        showSmartReplies = false
        smartReplies = []
    }
}
