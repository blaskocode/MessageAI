//
//  NewConversationView.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import SwiftUI

struct NewConversationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = NewConversationViewModel()
    let onConversationCreated: (String) -> Void

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("New Message")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                .alert("Error", isPresented: showErrorAlert) {
                    Button("OK") {
                        viewModel.errorMessage = nil
                    }
                } message: {
                    if let error = viewModel.errorMessage {
                        Text(error)
                    }
                }
        }
    }

    private var contentView: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if viewModel.searchText.isEmpty {
                Text("Search for users by name or email")
                    .foregroundColor(.gray)
                    .font(.subheadline)
            } else if viewModel.searchResults.isEmpty {
                Text("No users found")
                    .foregroundColor(.gray)
                    .font(.subheadline)
            } else {
                userList
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search users")
        .onChange(of: viewModel.searchText) {
            Task {
                // Debounce search
                try? await Task.sleep(nanoseconds: 300_000_000)
                await viewModel.searchUsers()
            }
        }
    }

    private var userList: some View {
        ForEach(Array(viewModel.searchResults.enumerated()), id: \.offset) { _, userData in
            UserRow(userData: userData) {
                Task {
                    await createAndNavigate(withUserId: userData["userId"] as? String ?? "")
                }
            }
        }
    }

    private var showErrorAlert: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func createAndNavigate(withUserId userId: String) async {
        if let conversationId = await viewModel.createConversation(withUserId: userId) {
            // Dismiss sheet and navigate to conversation in parent view
            dismiss()
            onConversationCreated(conversationId)
        }
    }
}

// MARK: - User Row

struct UserRow: View {
    let userData: [String: Any]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile circle
                Circle()
                    .fill(Color(hex: userData["profileColor"] as? String ?? "#4ECDC4"))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(displayName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private var displayName: String {
        userData["displayName"] as? String ?? "Unknown"
    }

    private var email: String {
        userData["email"] as? String ?? ""
    }
}

#Preview {
    NewConversationView { _ in }
}
