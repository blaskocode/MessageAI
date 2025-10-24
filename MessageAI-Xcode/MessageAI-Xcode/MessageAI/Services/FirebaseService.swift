//
//  FirebaseService.swift
//  MessageAI
//
//  Created on October 20, 2025
//  Refactored on October 22, 2025 for 500-line compliance
//
//  This is now a facade/coordinator that delegates to specialized services:
//  - FirebaseAuthService: Authentication operations
//  - FirestoreUserService: User profile management
//  - FirestoreConversationService: Conversation operations
//  - FirestoreMessageService: Message operations
//  - RealtimePresenceService: Presence detection (already separate)
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

/// Centralized facade for all Firebase operations
/// Delegates to specialized services while maintaining backward compatibility
@MainActor
class FirebaseService: ObservableObject {
    
    static let shared = FirebaseService()
    
    // MARK: - Service Dependencies
    
    private let authService = FirebaseAuthService.shared
    private let userService = FirestoreUserService.shared
    private let conversationService = FirestoreConversationService.shared
    private let messageService = FirestoreMessageService.shared
    private let presenceService = RealtimePresenceService.shared
    
    // MARK: - Published Properties
    
    @Published private(set) var currentUser: User?
    @Published private(set) var isOnline: Bool = true
    
    // MARK: - Computed Properties
    
    var currentUserId: String? {
        authService.currentUserId
    }
    
    var isAuthenticated: Bool {
        authService.isAuthenticated
    }
    
    // MARK: - Initialization
    
    private init() {
        // Subscribe to auth service's currentUser changes
        authService.$currentUser
            .assign(to: &$currentUser)
    }
    
    // MARK: - Authentication (delegates to FirebaseAuthService)
    
    func signUp(email: String, password: String, displayName: String) async throws -> String {
        try await authService.signUp(email: email, password: password, displayName: displayName)
    }
    
    func signIn(email: String, password: String) async throws -> String {
        try await authService.signIn(email: email, password: password)
    }
    
    func signOut() throws {
        try authService.signOut()
    }
    
    // MARK: - User Profile (delegates to FirestoreUserService)
    
    func fetchUserProfile(userId: String, completion: @escaping ([String: Any]?) -> Void) {
        userService.fetchUserProfile(userId: userId, completion: completion)
    }
    
    func fetchUserProfile(userId: String) async throws -> [String: Any] {
        try await userService.fetchUserProfile(userId: userId)
    }
    
    func updateUserProfile(userId: String, updates: [String: Any]) async throws {
        try await userService.updateUserProfile(userId: userId, updates: updates)
    }
    
    func updateOnlineStatus(userId: String, isOnline: Bool) async throws {
        try await userService.updateOnlineStatus(userId: userId, isOnline: isOnline)
    }
    
    func searchUsers(query: String) async throws -> [[String: Any]] {
        try await userService.searchUsers(query: query)
    }
    
    // MARK: - Conversations (delegates to FirestoreConversationService)
    
    func createConversation(
        participantIds: [String],
        type: String,
        groupName: String? = nil
    ) async throws -> String {
        try await conversationService.createConversation(
            participantIds: participantIds,
            type: type,
            groupName: groupName,
            currentUserId: currentUserId
        )
    }
    
    func fetchConversations(
        userId: String,
        completion: @escaping ([DocumentSnapshot]) -> Void
    ) -> ListenerRegistration {
        conversationService.fetchConversations(userId: userId, completion: completion)
    }
    
    func fetchConversation(conversationId: String) async throws -> [String: Any] {
        try await conversationService.fetchConversation(conversationId: conversationId)
    }
    
    func updateConversationParticipantDetails(
        conversationId: String,
        participantDetails: [String: [String: Any]]
    ) async throws {
        try await conversationService.updateConversationParticipantDetails(
            conversationId: conversationId,
            participantDetails: participantDetails
        )
    }
    
    func markConversationAsRead(conversationId: String, userId: String) async throws {
        try await conversationService.markConversationAsRead(
            conversationId: conversationId,
            userId: userId
        )
    }
    
    func markMessageAsRead(conversationId: String, messageId: String, userId: String) async throws {
        try await conversationService.markMessageAsRead(
            conversationId: conversationId,
            messageId: messageId,
            userId: userId
        )
    }
    
    func findExistingDirectConversation(userId1: String, userId2: String) async throws -> String? {
        try await conversationService.findExistingDirectConversation(
            userId1: userId1,
            userId2: userId2
        )
    }
    
    func cleanupDuplicateConversations(currentUserId: String) async throws {
        try await conversationService.cleanupDuplicateConversations(currentUserId: currentUserId)
    }
    
    func updateTypingStatus(conversationId: String, userId: String, isTyping: Bool) async throws {
        try await conversationService.updateTypingStatus(
            conversationId: conversationId,
            userId: userId,
            isTyping: isTyping
        )
    }
    
    func observeTypingStatus(
        conversationId: String,
        currentUserId: String,
        completion: @escaping (Bool) -> Void
    ) -> ListenerRegistration {
        conversationService.observeTypingStatus(
            conversationId: conversationId,
            currentUserId: currentUserId,
            completion: completion
        )
    }
    
    // MARK: - Messages (delegates to FirestoreMessageService)
    
    func sendMessage(conversationId: String, senderId: String, text: String) async throws -> String {
        try await messageService.sendMessage(
            conversationId: conversationId,
            senderId: senderId,
            text: text
        )
    }
    
    func fetchMessages(
        conversationId: String,
        limit: Int = 50,
        completion: @escaping ([DocumentSnapshot]) -> Void
    ) -> ListenerRegistration {
        messageService.fetchMessages(
            conversationId: conversationId,
            limit: limit,
            completion: completion
        )
    }
    
    func fetchRecentMessages(
        conversationId: String,
        limit: Int,
        completion: @escaping ([DocumentSnapshot]) -> Void
    ) -> ListenerRegistration {
        return messageService.fetchRecentMessages(
            conversationId: conversationId,
            limit: limit,
            completion: completion
        )
    }
    
    func fetchMessagesBefore(
        conversationId: String,
        before: DocumentSnapshot,
        limit: Int
    ) async throws -> [DocumentSnapshot] {
        return try await messageService.fetchMessagesBefore(
            conversationId: conversationId,
            before: before,
            limit: limit
        )
    }
    
    func updateMessage(
        conversationId: String,
        messageId: String,
        updates: [String: Any]
    ) async throws {
        try await messageService.updateMessage(
            conversationId: conversationId,
            messageId: messageId,
            updates: updates
        )
    }
    
    // MARK: - Presence (delegates to RealtimePresenceService)
    
    func observeUserPresence(
        userIds: [String],
        completion: @escaping ([String: Bool]) -> Void
    ) -> [ListenerRegistration] {
        // RTDB-based presence detection with onDisconnect() callbacks
        presenceService.observeMultipleUsers(userIds: userIds, completion: completion)
        
        print("✅ [FirebaseService] Delegating presence observation to RTDB for \(userIds.count) users")
        return []
    }
    
    // MARK: - Cleanup
    
    func removeAllListeners() {
        conversationService.removeAllListeners()
        messageService.removeAllListeners()
    }
}
