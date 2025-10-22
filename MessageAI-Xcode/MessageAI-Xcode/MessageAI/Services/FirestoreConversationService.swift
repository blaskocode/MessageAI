//
//  FirestoreConversationService.swift
//  MessageAI
//
//  Created on October 22, 2025
//  Split from FirebaseService.swift for 500-line compliance
//

import Foundation
import FirebaseFirestore

/// Handles conversation operations in Firestore
/// Part of the refactored Firebase service layer
@MainActor
class FirestoreConversationService: ObservableObject {
    
    static let shared = FirestoreConversationService()
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    private nonisolated(unsafe) var listenerRegistrations: [ListenerRegistration] = []
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Conversation Management
    
    func createConversation(
        participantIds: [String],
        type: String,
        groupName: String? = nil,
        currentUserId: String? = nil
    ) async throws -> String {
        let conversationRef = db.collection("conversations").document()
        
        // Fetch participant details for all participants
        var participantDetails: [String: [String: Any]] = [:]
        for participantId in participantIds {
            do {
                let userDoc = try await db.collection("users").document(participantId).getDocument()
                if let userData = userDoc.data() {
                    let displayName = userData["displayName"] as? String ?? "Unknown"
                    let profileColorHex = userData["profileColorHex"] as? String
                    let isOnline = userData["isOnline"] as? Bool ?? false
                    participantDetails[participantId] = [
                        "name": displayName,
                        "photoURL": profileColorHex ?? "#4ECDC4",
                        "isOnline": isOnline
                    ]
                }
            } catch {
                print("⚠️ Could not fetch details for participant \(participantId): \(error)")
            }
        }
        
        var conversationData: [String: Any] = [
            "conversationId": conversationRef.documentID,
            "type": type,
            "participantIds": participantIds,
            "participantDetails": participantDetails,
            "createdAt": FieldValue.serverTimestamp(),
            "lastUpdated": FieldValue.serverTimestamp()
        ]
        
        // Add group name if provided
        if let groupName = groupName {
            conversationData["groupName"] = groupName
            conversationData["createdBy"] = currentUserId ?? ""
        }
        
        try await conversationRef.setData(conversationData)
        return conversationRef.documentID
    }
    
    func fetchConversations(
        userId: String,
        completion: @escaping ([DocumentSnapshot]) -> Void
    ) -> ListenerRegistration {
        let listener = db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastUpdated", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ [FirestoreConversationService] Error fetching conversations: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ [FirestoreConversationService] No conversation documents found")
                    return
                }
                
                completion(documents)
            }
        
        listenerRegistrations.append(listener)
        return listener
    }
    
    func fetchConversation(conversationId: String) async throws -> [String: Any] {
        let doc = try await db.collection("conversations").document(conversationId).getDocument()
        
        guard let data = doc.data() else {
            throw NSError(
                domain: "FirestoreConversationService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Conversation not found"]
            )
        }
        
        return data
    }
    
    func updateConversationParticipantDetails(
        conversationId: String,
        participantDetails: [String: [String: Any]]
    ) async throws {
        try await db.collection("conversations").document(conversationId).updateData([
            "participantDetails": participantDetails
        ])
    }
    
    // MARK: - Read Receipts
    
    func markConversationAsRead(conversationId: String, userId: String) async throws {
        // Update the conversation's lastMessage readBy
        try await db.collection("conversations").document(conversationId).updateData([
            "lastMessage.readBy": FieldValue.arrayUnion([userId])
        ])
        
        // More importantly: Mark all unread messages in the messages subcollection
        let messagesRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
        
        // Get all messages where user is NOT in readBy array and sender is NOT the current user
        let unreadMessages = try await messagesRef
            .whereField("senderId", isNotEqualTo: userId)
            .getDocuments()
        
        // Update each unread message
        let batch = db.batch()
        var updateCount = 0
        
        for document in unreadMessages.documents {
            let data = document.data()
            let readBy = data["readBy"] as? [String] ?? []
            
            // Only update if user hasn't already read it
            if !readBy.contains(userId) {
                batch.updateData([
                    "readBy": FieldValue.arrayUnion([userId]),
                    "status": "read"
                ], forDocument: document.reference)
                updateCount += 1
            }
        }
        
        // Commit all updates in a single batch
        if updateCount > 0 {
            try await batch.commit()
            print("✅ Marked \(updateCount) messages as read")
        }
    }
    
    func markMessageAsRead(conversationId: String, messageId: String, userId: String) async throws {
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        // Update the message's readBy array and status
        try await messageRef.updateData([
            "readBy": FieldValue.arrayUnion([userId]),
            "status": "read"
        ])
        
        // Always update the conversation's lastMessage.readBy
        try await db.collection("conversations").document(conversationId).updateData([
            "lastMessage.readBy": FieldValue.arrayUnion([userId])
        ])
    }
    
    // MARK: - Conversation Search & Cleanup
    
    func findExistingDirectConversation(userId1: String, userId2: String) async throws -> String? {
        // Query for conversations where both users are participants and type is "direct"
        let snapshot = try await db.collection("conversations")
            .whereField("type", isEqualTo: "direct")
            .whereField("participantIds", arrayContains: userId1)
            .getDocuments()
        
        // Filter to find conversations that contain BOTH users
        for document in snapshot.documents {
            let data = document.data()
            if let participantIds = data["participantIds"] as? [String],
               participantIds.contains(userId1) && participantIds.contains(userId2) {
                return data["conversationId"] as? String
            }
        }
        
        return nil
    }
    
    func cleanupDuplicateConversations(currentUserId: String) async throws {
        // Fetch all direct conversations for the current user
        let snapshot = try await db.collection("conversations")
            .whereField("type", isEqualTo: "direct")
            .whereField("participantIds", arrayContains: currentUserId)
            .getDocuments()
        
        // Group conversations by the "other" participant
        var conversationsByParticipant: [String: [(id: String, lastUpdated: Date)]] = [:]
        
        for document in snapshot.documents {
            let data = document.data()
            guard let conversationId = data["conversationId"] as? String,
                  let participantIds = data["participantIds"] as? [String],
                  participantIds.count == 2 else { continue }
            
            // Find the other participant
            let otherParticipantId = participantIds.first(where: { $0 != currentUserId }) ?? ""
            
            let lastUpdatedTimestamp = data["lastUpdated"] as? Timestamp
            let lastUpdated = lastUpdatedTimestamp?.dateValue() ?? Date.distantPast
            
            if conversationsByParticipant[otherParticipantId] == nil {
                conversationsByParticipant[otherParticipantId] = []
            }
            conversationsByParticipant[otherParticipantId]?.append((id: conversationId, lastUpdated: lastUpdated))
        }
        
        // For each participant with multiple conversations, keep the most recent one
        for (participantId, conversations) in conversationsByParticipant where conversations.count > 1 {
            print("⚠️ Found \(conversations.count) duplicate conversations with user \(participantId)")
            
            // Sort by lastUpdated, keeping the most recent
            let sorted = conversations.sorted { $0.lastUpdated > $1.lastUpdated }
            let keepConversation = sorted.first!
            let duplicates = sorted.dropFirst()
            
            print("✅ Keeping conversation: \(keepConversation.id)")
            
            // Delete duplicates
            for duplicate in duplicates {
                print("🗑️ Deleting duplicate conversation: \(duplicate.id)")
                try await db.collection("conversations").document(duplicate.id).delete()
            }
        }
    }
    
    // MARK: - Typing Indicators
    
    func updateTypingStatus(conversationId: String, userId: String, isTyping: Bool) async throws {
        try await db.collection("conversations")
            .document(conversationId)
            .collection("typing")
            .document(userId)
            .setData([
                "isTyping": isTyping,
                "lastUpdated": FieldValue.serverTimestamp()
            ])
    }
    
    func observeTypingStatus(
        conversationId: String,
        currentUserId: String,
        completion: @escaping (Bool) -> Void
    ) -> ListenerRegistration {
        let listener = db.collection("conversations")
            .document(conversationId)
            .collection("typing")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ [FirestoreConversationService] Error observing typing: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(false)
                    return
                }
                
                // Check if any other user (not current user) is typing
                let isAnyoneTyping = documents.contains { doc in
                    guard doc.documentID != currentUserId,
                          let isTyping = doc.data()["isTyping"] as? Bool else {
                        return false
                    }
                    return isTyping
                }
                
                completion(isAnyoneTyping)
            }
        
        listenerRegistrations.append(listener)
        return listener
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

