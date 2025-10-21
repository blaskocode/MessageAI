//
//  NewGroupView.swift
//  MessageAI
//
//  Created on October 21, 2025
//

import SwiftUI

struct NewGroupView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = NewGroupViewModel()
    let onGroupCreated: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Navigation Bar
                customNavigationBar

                // Group Name Input
                groupNameSection

                Divider()

                // User Selection List
                userSelectionList
            }
            .navigationBarHidden(true)
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

    private var customNavigationBar: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }

            Spacer()

            Text("New Group")
                .font(.headline)

            Spacer()

            Button("Create") {
                Task {
                    await createAndNavigate()
                }
            }
            .disabled(!viewModel.canCreateGroup || viewModel.isLoading)
            .opacity(viewModel.canCreateGroup && !viewModel.isLoading ? 1.0 : 0.5)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Divider(),
            alignment: .bottom
        )
    }

    private var groupNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GROUP NAME")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 12)

            TextField("Enter group name", text: $viewModel.groupName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Text("SEARCH USERS")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)

            TextField("Search for users", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .onChange(of: viewModel.searchText) {
                    Task {
                        // Debounce search
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        await viewModel.searchUsers()
                    }
                }

            // Selected users count
            if viewModel.selectedUserIds.count > 0 {
                Text("\(viewModel.selectedUserIds.count) user\(viewModel.selectedUserIds.count == 1 ? "" : "s") selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }

            Spacer()
                .frame(height: 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var userSelectionList: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if viewModel.searchText.isEmpty {
                Text("Search for users to add to the group")
                    .foregroundColor(.gray)
                    .font(.subheadline)
            } else if viewModel.searchResults.isEmpty {
                Text("No users found")
                    .foregroundColor(.gray)
                    .font(.subheadline)
            } else {
                ForEach(Array(viewModel.searchResults.enumerated()), id: \.offset) { _, userData in
                    SelectableUserRow(
                        userData: userData,
                        isSelected: viewModel.isUserSelected(userId: userData["userId"] as? String ?? "")
                    ) {
                        if let userId = userData["userId"] as? String {
                            viewModel.toggleUserSelection(userId: userId)
                        }
                    }
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

    private func createAndNavigate() async {
        if let conversationId = await viewModel.createGroup() {
            // Dismiss sheet and navigate to group conversation in parent view
            dismiss()
            onGroupCreated(conversationId)
        }
    }
}

// MARK: - Selectable User Row

struct SelectableUserRow: View {
    let userData: [String: Any]
    let isSelected: Bool
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

                // Checkmark
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
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
    NewGroupView { _ in }
}
