//
//  FirestoreUserService.swift
//  MessageAI
//
//  Created on October 22, 2025
//  Split from FirebaseService.swift for 500-line compliance
//

import Foundation
import FirebaseFirestore

/// Handles user profile operations in Firestore
/// Part of the refactored Firebase service layer
@MainActor
class FirestoreUserService: ObservableObject {
    
    static let shared = FirestoreUserService()
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - User Profile Methods
    
    func fetchUserProfile(userId: String, completion: @escaping ([String: Any]?) -> Void) {
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("⚠️ [FirestoreUserService] Error fetching user profile: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = snapshot?.data() else {
                print("⚠️ [FirestoreUserService] No user data found for \(userId)")
                completion(nil)
                return
            }
            
            completion(data)
        }
    }
    
    func fetchUserProfile(userId: String) async throws -> [String: Any] {
        let doc = try await db.collection("users").document(userId).getDocument()
        
        guard let data = doc.data() else {
            throw NSError(
                domain: "FirestoreUserService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "User not found"]
            )
        }
        
        return data
    }
    
    func updateUserProfile(userId: String, updates: [String: Any]) async throws {
        try await db.collection("users").document(userId).updateData(updates)
    }
    
    func updateOnlineStatus(userId: String, isOnline: Bool) async throws {
        try await db.collection("users").document(userId).updateData([
            "isOnline": isOnline,
            "lastSeen": FieldValue.serverTimestamp()
        ])
    }
    
    // MARK: - User Search
    
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
}

