//
//  ConversationListView.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import SwiftUI

struct ConversationListView: View {
    @StateObject private var viewModel = ConversationListViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedConversationId: String?
    @State private var showLogoutConfirmation = false
    @State private var navigateToConversationId: String?

    var body: some View {
        let currentUserId = FirebaseService.shared.currentUserId ?? ""

        return NavigationStack {
            List {
                ForEach(viewModel.conversations) { conversation in
                    NavigationLink(destination: ChatView(conversationId: conversation.id)) {
                        ConversationRow(conversation: conversation, currentUserId: currentUserId)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    logoutButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    newMessageMenu
                }
            }
            .confirmationDialog("Are you sure you want to sign out?", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authViewModel.signOut()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $viewModel.showNewConversation) {
                NewConversationView { conversationId in
                    // Navigate to the newly created conversation
                    navigateToConversationId = conversationId
                }
            }
            .sheet(isPresented: $viewModel.showNewGroup) {
                NewGroupView { conversationId in
                    // Navigate to the newly created group
                    navigateToConversationId = conversationId
                }
            }
            .onAppear {
                viewModel.loadConversations()
                NotificationService.shared.clearBadgeCount()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToConversation"))) { notification in
                if let conversationId = notification.userInfo?["conversationId"] as? String {
                    selectedConversationId = conversationId
                }
            }
            .navigationDestination(item: $selectedConversationId) { conversationId in
                ChatView(conversationId: conversationId)
            }
            .onChange(of: navigateToConversationId) { _, newValue in
                if let conversationId = newValue {
                    selectedConversationId = conversationId
                    navigateToConversationId = nil
                }
            }
        }
    }

    private var logoutButton: some View {
        Button(action: { showLogoutConfirmation = true }) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
        }
    }

    private var newMessageMenu: some View {
        Menu {
            Button {
                viewModel.showNewConversation = true
            } label: {
                Label("New Message", systemImage: "message")
            }

            Button {
                viewModel.showNewGroup = true
            } label: {
                Label("New Group", systemImage: "person.3")
            }
        } label: {
            Image(systemName: "square.and.pencil")
        }
    }
}

// Helper to make String identifiable for navigation
extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct ConversationRow: View {
    let conversation: Conversation
    let currentUserId: String

    var body: some View {
        HStack(spacing: 12) {
            // Unread indicator
            if conversation.hasUnreadMessages {
                Circle()
                    .fill(Color.unreadIndicator)
                    .frame(width: 10, height: 10)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 10, height: 10)
            }

            // Profile Picture with color from participant details
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(getProfileColor(for: conversation))
                    .frame(width: 54, height: 54)
                    .overlay {
                        Circle()
                            .strokeBorder(Color(.systemGray5), lineWidth: 0.5)
                    }
                    .overlay {
                        Text(getInitials(for: conversation))
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }

                // Online status indicator (only for direct chats)
                if conversation.type == .direct {
                    let isOnline = getOnlineStatus(for: conversation) ?? false
                    Circle()
                        .fill(isOnline ? Color.green : Color.gray)
                        .frame(width: 14, height: 14)
                        .overlay {
                            Circle()
                                .strokeBorder(Color(.systemBackground), lineWidth: 2)
                        }
                        .offset(x: 2, y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(conversation.displayName(currentUserId: currentUserId))
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)

                if let lastMessage = conversation.lastMessageText {
                    Text(lastMessage)
                        .font(.system(.subheadline, design: .default))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let timestamp = conversation.lastMessageTimestamp {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(timestamp, style: .time)
                        .font(.system(.caption, design: .default))
                        .foregroundColor(.secondary)

                    if conversation.hasUnreadMessages {
                        Circle()
                            .fill(Color.unreadIndicator)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 0)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 1, y: 1)
    }

    private func getInitials(for conversation: Conversation) -> String {
        let displayName = conversation.displayName(currentUserId: currentUserId)
        let words = displayName.split(separator: " ")
        if words.count >= 2 {
            let firstInitial = words[0].prefix(1).uppercased()
            let secondInitial = words[1].prefix(1).uppercased()
            return "\(firstInitial)\(secondInitial)"
        } else if let firstWord = words.first {
            return String(firstWord.prefix(2)).uppercased()
        }
        return "?"
    }

    private func getProfileColor(for conversation: Conversation) -> Color {
        // For direct chats, use the other participant's color if available
        if conversation.type == .direct {
            let otherParticipantIds = conversation.participantIds.filter { $0 != currentUserId }
            if let otherUserId = otherParticipantIds.first,
               let details = conversation.participantDetails[otherUserId],
               let colorHex = details.photoURL {
                // Use color from participant details if available
                return Color(hex: colorHex)
            }
        }
        // Default color for groups or when color not available
        return Color.messagePrimary
    }

    private func getOnlineStatus(for conversation: Conversation) -> Bool? {
        // Get online status for direct chats
        guard conversation.type == .direct else { return nil }

        let otherParticipantIds = conversation.participantIds.filter { $0 != currentUserId }
        if let otherUserId = otherParticipantIds.first,
           let details = conversation.participantDetails[otherUserId] {
            return details.isOnline ?? false // Default to offline if nil
        }
        return false // Default to offline
    }
}

#Preview {
    ConversationListView()
        .environmentObject(AuthViewModel())
}
