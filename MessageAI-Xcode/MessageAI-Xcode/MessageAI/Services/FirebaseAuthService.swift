//
//  FirebaseAuthService.swift
//  MessageAI
//
//  Created on October 22, 2025
//  Split from FirebaseService.swift for 500-line compliance
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Handles Firebase Authentication operations
/// Part of the refactored Firebase service layer
@MainActor
class FirebaseAuthService: ObservableObject {
    
    static let shared = FirebaseAuthService()
    
    // MARK: - Properties
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    @Published private(set) var currentUser: User?
    
    // MARK: - Initialization
    
    private init() {
        // Listen for auth state changes
        _ = auth.addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                Task { @MainActor in
                    await self?.loadCurrentUserProfile(userId: user.uid)
                }
            } else {
                self?.currentUser = nil
            }
        }
    }
    
    // MARK: - Authentication Methods
    
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
    
    var isAuthenticated: Bool {
        auth.currentUser != nil
    }
    
    // MARK: - User Profile Creation
    
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
    
    private func loadCurrentUserProfile(userId: String) async {
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            guard doc.data() != nil else {
                print("⚠️ [FirebaseAuthService] No user data found for \(userId)")
                return
            }
            
            // Parse user data (simplified - you may want to use User model)
            print("✅ [FirebaseAuthService] User profile loaded for user")
        } catch {
            print("⚠️ [FirebaseAuthService] Error loading user profile: \(error.localizedDescription)")
        }
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
}

