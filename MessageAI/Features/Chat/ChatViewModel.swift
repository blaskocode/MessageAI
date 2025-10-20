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
    
    let conversationId: String
    var currentUserId: String? {
        firebaseService.currentUserId
    }
    
    private let firebaseService = FirebaseService.shared
    private nonisolated(unsafe) var messageListener: ListenerRegistration?
    private nonisolated(unsafe) var typingListener: ListenerRegistration?
    
    init(conversationId: String) {
        self.conversationId = conversationId
    }
    
    // MARK: - Load Messages
    
    func loadMessages() {
        guard let userId = currentUserId else { return }
        
        isLoading = true
        
        messageListener = firebaseService.fetchMessages(conversationId: conversationId) { [weak self] documents in
            self?.isLoading = false
            self?.parseMessages(documents)
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
            
            return Message(
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
        }
        .sorted { $0.timestamp < $1.timestamp }
        
        print("✅ Loaded \(messages.count) messages")
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
            try? await firebaseService.updateTypingStatus(
                conversationId: conversationId,
                userId: userId,
                isTyping: isTyping
            )
        }
    }
    
    // MARK: - Read Receipts
    
    private func markMessagesAsRead(userId: String) async throws {
        // TODO: Implement bulk read receipt update
        // For now, this is a placeholder
        print("📖 Marking messages as read for user: \(userId)")
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

