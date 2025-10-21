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
        
        var conversationData: [String: Any] = [
            "conversationId": conversationRef.documentID,
            "type": type,
            "participantIds": participantIds,
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
                "text": text,
                "senderId": senderId,
                "timestamp": FieldValue.serverTimestamp()
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

