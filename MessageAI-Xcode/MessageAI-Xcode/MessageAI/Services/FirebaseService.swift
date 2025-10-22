//
//  FirebaseService.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Combine

/// Centralized service for all Firebase operations
/// Singleton pattern - single source of truth for Firebase interactions
@MainActor
class FirebaseService: ObservableObject {

    static let shared = FirebaseService()

    // MARK: - Properties

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let storage = Storage.storage()

    @Published private(set) var currentUser: User?
    @Published private(set) var isOnline: Bool = true

    private nonisolated(unsafe) var listenerRegistrations: [ListenerRegistration] = []

    // MARK: - Initialization

    private init() {
        // Listen for auth state changes
        _ = auth.addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                self?.fetchUserProfile(userId: user.uid)
            } else {
                self?.currentUser = nil
            }
        }
    }

    // MARK: - Authentication

    func signUp(email: String, password: String, displayName: String) async throws -> String {
        let result = try await auth.createUser(withEmail: email, password: password)
        let userId = result.user.uid

        // Create user profile in Firestore
        try await createUserProfile(userId: userId, email: email, displayName: displayName)

        return userId
    }

    func signIn(email: String, password: String) async throws -> String {
        let result = try await auth.signIn(withEmail: email, password: password)
        return result.user.uid
    }

    func signOut() throws {
        try auth.signOut()
        currentUser = nil
    }

    var currentUserId: String? {
        auth.currentUser?.uid
    }

    // MARK: - User Profile

    private func createUserProfile(userId: String, email: String, displayName: String) async throws {
        let initials = extractInitials(from: displayName)
        let colorHex = generateRandomProfileColor()

        let userData: [String: Any] = [
            "userId": userId,
            "email": email,
            "displayName": displayName,
            "initials": initials,
            "profileColorHex": colorHex,
            "isOnline": true,
            "createdAt": FieldValue.serverTimestamp(),
            "lastSeen": FieldValue.serverTimestamp()
        ]

        try await db.collection("users").document(userId).setData(userData)
    }

    func fetchUserProfile(userId: String) {
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("⚠️ [FirebaseService] Error fetching user profile: \(error.localizedDescription)")
                return
            }

            guard snapshot?.data() != nil else {
                print("⚠️ [FirebaseService] No user data found for \(userId)")
                return
            }

            // TODO: Parse user data and set currentUser
            print("✅ [FirebaseService] User profile fetched for user")
        }
    }

    func fetchUserProfile(userId: String) async throws -> [String: Any] {
        let doc = try await db.collection("users").document(userId).getDocument()

        guard let data = doc.data() else {
            throw NSError(domain: "FirebaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }

        return data
    }

    func updateUserProfile(userId: String, updates: [String: Any]) async throws {
        try await db.collection("users").document(userId).updateData(updates)
    }

    func searchUsers(query: String) async throws -> [[String: Any]] {
        let lowercaseQuery = query.lowercased()

        // Fetch all users (in production, you'd want pagination)
        let snapshot = try await db.collection("users").getDocuments()

        // Filter users client-side (Firestore doesn't support case-insensitive search)
        let matchingUsers = snapshot.documents.compactMap { doc -> [String: Any]? in
            let data = doc.data()
            guard let displayName = data["displayName"] as? String,
                  let email = data["email"] as? String else {
                return nil
            }

            // Match by display name or email
            if displayName.lowercased().contains(lowercaseQuery) ||
               email.lowercased().contains(lowercaseQuery) {
                var userData = data
                userData["userId"] = doc.documentID
                return userData
            }

            return nil
        }

        return matchingUsers
    }

    // MARK: - Conversations

    func createConversation(participantIds: [String], type: String, groupName: String? = nil) async throws -> String {
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

    func fetchConversations(userId: String, completion: @escaping ([DocumentSnapshot]) -> Void) -> ListenerRegistration {
        let listener = db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastUpdated", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ [FirebaseService] Error fetching conversations: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ [FirebaseService] No conversation documents found")
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
            throw NSError(domain: "FirebaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }

        return data
    }

    func updateConversationParticipantDetails(conversationId: String, participantDetails: [String: [String: Any]]) async throws {
        try await db.collection("conversations").document(conversationId).updateData([
            "participantDetails": participantDetails
        ])
    }

    func markConversationAsRead(conversationId: String, userId: String) async throws {
        // Update the conversation's lastMessage readBy
        try await db.collection("conversations").document(conversationId).updateData([
            "lastMessage.readBy": FieldValue.arrayUnion([userId])
        ])

        // More importantly: Mark all unread messages in the messages subcollection
        let messagesRef = db.collection("conversations").document(conversationId).collection("messages")
        
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
        
        // Always update the conversation's lastMessage.readBy in case this is the most recent message
        // This is safe to do even if it's not the last message - it will just add to the array
        try await db.collection("conversations").document(conversationId).updateData([
            "lastMessage.readBy": FieldValue.arrayUnion([userId])
        ])
    }

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

    // MARK: - Messages

    func sendMessage(conversationId: String, senderId: String, text: String) async throws -> String {
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

    func fetchMessages(conversationId: String, limit: Int = 50, completion: @escaping ([DocumentSnapshot]) -> Void) -> ListenerRegistration {
        let listener = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ [FirebaseService] Error fetching messages: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ [FirebaseService] No message documents found")
                    return
                }

                completion(documents)
            }

        listenerRegistrations.append(listener)
        return listener
    }

    // MARK: - Presence & Typing

    func updateOnlineStatus(userId: String, isOnline: Bool) async throws {
        try await db.collection("users").document(userId).updateData([
            "isOnline": isOnline,
            "lastSeen": FieldValue.serverTimestamp()
        ])
    }

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

    func observeTypingStatus(conversationId: String, currentUserId: String, completion: @escaping (Bool) -> Void) -> ListenerRegistration {
        let listener = db.collection("conversations")
            .document(conversationId)
            .collection("typing")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ [FirebaseService] Error observing typing status: \(error.localizedDescription)")
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

    func observeUserPresence(userIds: [String], completion: @escaping ([String: Bool]) -> Void) -> [ListenerRegistration] {
        // DEPRECATED: This method now uses Firebase Realtime Database (RTDB) instead of Firestore
        // RTDB provides IMMEDIATE offline detection via server-side onDisconnect() callbacks
        
        // Use RealtimePresenceService for real-time presence observation
        let realtimePresence = RealtimePresenceService.shared
        
        realtimePresence.observeMultipleUsers(userIds: userIds) { presenceUpdate in
            completion(presenceUpdate)
        }
        
        // Return empty array since RTDB handles its own listener registration internally
        // The actual listeners are managed by RealtimePresenceService
        print("✅ [FirebaseService] Delegating presence observation to RTDB for \(userIds.count) users")
        return []
    }

    // MARK: - Helper Methods

    private func extractInitials(from name: String) -> String {
        let words = name.components(separatedBy: " ").filter { !$0.isEmpty }
        if words.count >= 2 {
            let first = words.first?.prefix(1).uppercased() ?? ""
            let last = words.last?.prefix(1).uppercased() ?? ""
            return "\(first)\(last)"
        } else if let word = words.first {
            return String(word.prefix(2).uppercased())
        }
        return "?"
    }

    private func generateRandomProfileColor() -> String {
        let colors = [
            "#FF6B6B", // Red
            "#4ECDC4", // Teal
            "#45B7D1", // Blue
            "#FFA07A", // Salmon
            "#98D8C8", // Mint
            "#F7DC6F", // Yellow
            "#BB8FCE", // Purple
            "#85C1E2", // Light Blue
            "#F8B739", // Orange
            "#52B788", // Green
            "#F06292", // Pink
            "#7986CB"  // Indigo
        ]
        return colors.randomElement() ?? "#4ECDC4"
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
