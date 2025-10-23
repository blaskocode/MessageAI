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
        text: String
    ) async throws -> String {
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document()
        
        let messageData: [String: Any] = [
            "messageId": messageRef.documentID,
            "senderId": senderId,
            "text": text,
            "timestamp": FieldValue.serverTimestamp(),
            "status": "sent",
            "deliveredTo": [],
            "readBy": [senderId]
        ]
        
        try await messageRef.setData(messageData)
        
        // Update conversation's lastMessage
        try await db.collection("conversations").document(conversationId).updateData([
            "lastMessage": [
                "id": messageRef.documentID,
                "messageId": messageRef.documentID,  // Include both for compatibility
                "text": text,
                "senderId": senderId,
                "timestamp": FieldValue.serverTimestamp(),
                "readBy": [senderId]  // Sender has read their own message
            ],
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
    
    // MARK: - Cleanup
    
    nonisolated func removeAllListeners() {
        listenerRegistrations.forEach { $0.remove() }
        listenerRegistrations.removeAll()
    }
    
    deinit {
        removeAllListeners()
    }
}

