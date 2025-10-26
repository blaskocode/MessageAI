//
//  ProfileViewModel.swift
//  MessageAI
//
//  Profile management and user preferences
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var displayName: String = ""
    @Published var email: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let db = Firestore.firestore()
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    init() {
        loadUserData()
    }
    
    // MARK: - Load User Data
    
    func loadUserData() {
        guard let userId = userId else {
            // Silently return - user not authenticated (normal during sign out)
            return
        }
        
        isLoading = true
        errorMessage = nil
        print("📥 [Profile] Loading user data for: \(userId)")
        
        Task {
            do {
                let document = try await db.collection("users").document(userId).getDocument()
                
                guard document.exists,
                      let data = document.data() else {
                    throw NSError(domain: "ProfileViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
                }
                
                // Parse user data
                let user = try Firestore.Decoder().decode(User.self, from: data)
                self.currentUser = user
                
                // Update UI fields
                self.displayName = user.displayName
                self.email = user.email
                
                isLoading = false
                print("✅ [Profile] Loaded user profile: \(user.displayName)")
                print("  📸 profilePictureURL: \(user.profilePictureURL ?? "nil")")
                print("  🎨 profileColorHex: \(user.profileColorHex)")
                print("  ✏️ initials: \(user.initials)")
                print("  🌍 languages: \(user.fluentLanguages)")
            } catch {
                isLoading = false
                errorMessage = "Failed to load profile: \(error.localizedDescription)"
                print("❌ [Profile] Error loading profile: \(error)")
            }
        }
    }
    
    // MARK: - Save Profile Changes
    
    func saveProfile() async {
        guard let userId = userId else {
            errorMessage = "Not signed in"
            return
        }
        
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Name cannot be empty"
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            // Update Firestore
            try await db.collection("users").document(userId).updateData([
                "displayName": displayName.trimmingCharacters(in: .whitespaces)
            ])
            
            // Update local user object
            if let user = currentUser {
                user.displayName = displayName.trimmingCharacters(in: .whitespaces)
            }
            
            isLoading = false
            successMessage = "Profile updated successfully"
            print("✅ Profile saved")
            
            // Clear success message after 2 seconds
            try? await Task.sleep(for: .seconds(2))
            successMessage = nil
            
        } catch {
            isLoading = false
            errorMessage = "Failed to save: \(error.localizedDescription)"
            print("❌ Error saving profile: \(error)")
        }
    }
    
    // MARK: - Update Languages (called by SettingsViewModel)
    
    func updateLanguages(_ languages: Set<String>) {
        Task {
            guard let userId = userId else { return }
            
            do {
                try await db.collection("users").document(userId).updateData([
                    "fluentLanguages": Array(languages)
                ])
                
                if let user = currentUser {
                    user.fluentLanguages = Array(languages)
                }
                
                print("✅ Languages updated: \(languages)")
            } catch {
                print("❌ Error updating languages: \(error)")
            }
        }
    }
    
    // MARK: - Update Cultural Hints Setting (called by SettingsViewModel)
    
    func updateCulturalHints(_ enabled: Bool) {
        Task {
            guard let userId = userId else { return }
            
            do {
                try await db.collection("users").document(userId).updateData([
                    "culturalHintsEnabled": enabled
                ])
                
                if let user = currentUser {
                    user.culturalHintsEnabled = enabled
                }
                
                print("✅ Cultural hints setting updated: \(enabled)")
            } catch {
                print("❌ Error updating cultural hints: \(error)")
            }
        }
    }
    
    // MARK: - Profile Photo Upload
    
    func uploadProfilePhoto(_ imageData: Data) async {
        guard let userId = userId else {
            errorMessage = "Not signed in"
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            // Create storage reference
            let storageRef = Storage.storage().reference()
            let profilePhotoRef = storageRef.child("profile_photos/\(userId).jpg")
            
            // Compress image if needed
            let maxSize: Int = 2 * 1024 * 1024 // 2MB
            var uploadData = imageData
            
            if imageData.count > maxSize {
                // If image is too large, try to compress it
                if let uiImage = UIImage(data: imageData),
                   let compressedData = uiImage.jpegData(compressionQuality: 0.7) {
                    uploadData = compressedData
                }
            }
            
            // Upload to Firebase Storage
            print("📤 Uploading profile photo (\(uploadData.count / 1024) KB)...")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            _ = try await profilePhotoRef.putDataAsync(uploadData, metadata: metadata)
            
            // Get download URL
            let downloadURL = try await profilePhotoRef.downloadURL()
            let photoURL = downloadURL.absoluteString
            
            print("✅ [Upload] Photo uploaded: \(photoURL)")
            
            // Update Firestore user document
            print("🔄 [Firestore] Updating users/\(userId) with new profilePictureURL...")
            try await db.collection("users").document(userId).updateData([
                "profilePictureURL": photoURL
            ])
            
            print("✅ [Firestore] Profile photo updated in Firestore - Cloud Function should trigger now!")
            
            // Update local user object
            if let user = currentUser {
                user.profilePictureURL = photoURL
                print("📱 [Local] Updated local user object with new photo URL")
            }
            
            isLoading = false
            successMessage = "Profile photo updated!"
            print("🎉 [Complete] Profile photo update complete - check Cloud Functions logs")
            
            // Clear success message after 2 seconds
            try? await Task.sleep(for: .seconds(2))
            successMessage = nil
            
        } catch {
            isLoading = false
            errorMessage = "Failed to upload photo: \(error.localizedDescription)"
            print("❌ Error uploading profile photo: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}

