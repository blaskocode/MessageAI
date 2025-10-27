//
//  FirestoreMessageService.swift
//  MessageAI
//
//  Created on October 22, 2025
//  Split from FirebaseService.swift for 500-line compliance
//

import Foundation
import FirebaseFirestore

/// Handles message operations in Firestore
/// Part of the refactored Firebase service layer
@MainActor
class FirestoreMessageService: ObservableObject {
    
    static let shared = FirestoreMessageService()
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    private nonisolated(unsafe) var listenerRegistrations: [ListenerRegistration] = []
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Message Operations
    
    func sendMessage(
        conversationId: String,
        senderId: String,
        text: String? = nil,
        mediaURL: String? = nil,
        mediaType: String? = nil
    ) async throws -> String {
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document()
        
        var messageData: [String: Any] = [
            "messageId": messageRef.documentID,
            "senderId": senderId,
            "timestamp": FieldValue.serverTimestamp(),
            "status": "sent",
            "deliveredTo": [],
            "readBy": [senderId]
        ]
        
        // Add text if provided
        if let text = text, !text.isEmpty {
            messageData["text"] = text
        }
        
        // Add media if provided
        if let mediaURL = mediaURL {
            messageData["mediaURL"] = mediaURL
        }
        
        if let mediaType = mediaType {
            messageData["mediaType"] = mediaType
        }
        
        try await messageRef.setData(messageData)
        
        // Update conversation's lastMessage
        var lastMessageData: [String: Any] = [
            "id": messageRef.documentID,
            "messageId": messageRef.documentID,
            "senderId": senderId,
            "timestamp": FieldValue.serverTimestamp(),
            "readBy": [senderId]
        ]
        
        // Add text or media info to last message
        if let text = text, !text.isEmpty {
            lastMessageData["text"] = text
        } else if let mediaType = mediaType {
            lastMessageData["text"] = "[\(mediaType.capitalized)]"
        }
        
        try await db.collection("conversations").document(conversationId).updateData([
            "lastMessage": lastMessageData,
            "lastUpdated": FieldValue.serverTimestamp()
        ])
        
        return messageRef.documentID
    }
    
    func fetchMessages(
        conversationId: String,
        limit: Int = 50,
        completion: @escaping ([DocumentSnapshot]) -> Void
    ) -> ListenerRegistration {
        let listener = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ [FirestoreMessageService] Error fetching messages: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ [FirestoreMessageService] No message documents found")
                    return
                }
                
                completion(documents)
            }
        
        listenerRegistrations.append(listener)
        return listener
    }
    
    func fetchRecentMessages(
        conversationId: String,
        limit: Int,
        completion: @escaping ([DocumentSnapshot]) -> Void
    ) -> ListenerRegistration {
        return db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                completion(documents.reversed()) // Chronological order
            }
    }
    
    func fetchMessagesBefore(
        conversationId: String,
        before: DocumentSnapshot,
        limit: Int
    ) async throws -> [DocumentSnapshot] {
        let snapshot = try await db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .start(afterDocument: before)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.reversed()
    }
    
    func updateMessage(
        conversationId: String,
        messageId: String,
        updates: [String: Any]
    ) async throws {
        try await db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
            .updateData(updates)
    }
    
    // MARK: - Reactions
    
    func addReaction(
        conversationId: String,
        messageId: String,
        emoji: String,
        userId: String
    ) async throws {
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        // Get current reactions
        let doc = try await messageRef.getDocument()
        var reactions = doc.data()?["reactions"] as? [[String: Any]] ?? []
        
        // Check if this exact reaction already exists
        let reactionExists = reactions.contains { reaction in
            guard let reactionEmoji = reaction["emoji"] as? String,
                  let reactionUserId = reaction["userId"] as? String else {
                return false
            }
            return reactionEmoji == emoji && reactionUserId == userId
        }
        
        // If reaction doesn't exist, add it
        if !reactionExists {
            let reactionData: [String: Any] = [
                "emoji": emoji,
                "userId": userId,
                "timestamp": Date() // Will be converted to Timestamp automatically
            ]
            
            reactions.append(reactionData)
            
            try await messageRef.updateData([
                "reactions": reactions
            ])
        }
    }
    
    func removeReaction(
        conversationId: String,
        messageId: String,
        emoji: String,
        userId: String
    ) async throws {
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        // Get current reactions
        let doc = try await messageRef.getDocument()
        guard let data = doc.data(),
              let reactions = data["reactions"] as? [[String: Any]] else {
            return
        }
        
        // Remove the specific reaction
        let updatedReactions = reactions.filter { reaction in
            guard let reactionUserId = reaction["userId"] as? String,
                  let reactionEmoji = reaction["emoji"] as? String else {
                return true
            }
            return !(reactionUserId == userId && reactionEmoji == emoji)
        }
        
        // Update with filtered reactions
        try await messageRef.updateData([
            "reactions": updatedReactions
        ])
    }
    
    // MARK: - Cleanup
    
    nonisolated func removeAllListeners() {
        listenerRegistrations.forEach { $0.remove() }
        listenerRegistrations.removeAll()
    }
    
    deinit {
        removeAllListeners()
    }
}

