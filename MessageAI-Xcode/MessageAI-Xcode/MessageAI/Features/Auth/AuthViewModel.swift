//
//  AuthViewModel.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import Foundation
import Combine

@MainActor
class AuthViewModel: ObservableObject {

    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let firebaseService = FirebaseService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Check if user is already signed in
        isAuthenticated = firebaseService.currentUserId != nil
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String, displayName: String) async {
        guard validateInputs(email: email, password: password, displayName: displayName) else {
            return
        }

        isLoading = true
        errorMessage = nil

        // Sanitize inputs
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let userId = try await firebaseService.signUp(
                email: trimmedEmail,
                password: password,
                displayName: trimmedName
            )

            print("✅ User signed up successfully: \(userId)")
            isAuthenticated = true
            isLoading = false

        } catch {
            errorMessage = "Sign up failed: \(error.localizedDescription)"
            isLoading = false
            print("❌ Sign up error: \(error)")
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async {
        guard !email.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter email and password"
            return
        }

        isLoading = true
        errorMessage = nil

        // Sanitize email
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        do {
            let userId = try await firebaseService.signIn(email: trimmedEmail, password: password)

            print("✅ User signed in successfully: \(userId)")
            isAuthenticated = true
            isLoading = false

            // Update online status
            try? await firebaseService.updateOnlineStatus(userId: userId, isOnline: true)

        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            isLoading = false
            print("❌ Sign in error: \(error)")
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            // Update online status before signing out
            if let userId = firebaseService.currentUserId {
                do {
                    try await firebaseService.updateOnlineStatus(userId: userId, isOnline: false)
                    print("✅ User status set to offline before sign out")
                } catch {
                    print("⚠️ Failed to update online status: \(error)")
                }
            }

            try firebaseService.signOut()
            isAuthenticated = false
            errorMessage = nil

            print("✅ User signed out successfully")

        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
            print("❌ Sign out error: \(error)")
        }
    }

    // MARK: - Validation

    private func validateInputs(email: String, password: String, displayName: String) -> Bool {
        // Check for empty fields
        if email.isEmpty || password.isEmpty || displayName.isEmpty {
            errorMessage = "All fields are required"
            return false
        }

        // Validate email format with regex
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        if !emailPredicate.evaluate(with: email) {
            errorMessage = "Please enter a valid email address"
            return false
        }

        // Validate password strength
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters"
            return false
        }

        // Validate display name length
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.count < 2 {
            errorMessage = "Display name must be at least 2 characters"
            return false
        }

        if trimmedName.count > 50 {
            errorMessage = "Display name must be less than 50 characters"
            return false
        }

        return true
    }
}
