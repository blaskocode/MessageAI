// //  ChatView.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import SwiftUI

struct ChatView: View {
    let conversationId: String

    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""

    init(conversationId: String) {
        self.conversationId = conversationId
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversationId: conversationId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(
                                message: message,
                                isFromCurrentUser: message.senderId == viewModel.currentUserId,
                                senderDetails: viewModel.senderDetails[message.senderId],
                                totalParticipants: viewModel.participantIds.count
                            )
                            .id(message.id)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding()
                }
                .onAppear {
                    // Instantly scroll to bottom on load (no animation)
                    if let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                    // Mark messages as read when view appears
                    viewModel.markMessagesAsRead()
                }
                .onChange(of: viewModel.messages.count) {
                    // Animated scroll for new messages arriving
                    guard !viewModel.messages.isEmpty else { return }
                    if let lastMessage = viewModel.messages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .onChange(of: viewModel.isTyping) {
                    // Auto-scroll when typing indicator appears
                    if viewModel.isTyping, let lastMessage = viewModel.messages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.messageBackground)

            // Typing Indicator (above input bar)
            if viewModel.isTyping {
                HStack {
                    Text("Typing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.horizontal, 16)
                    Spacer()
                }
                .frame(height: 24)
                .background(Color(.systemBackground))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Input Bar
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Message", text: $messageText, axis: .vertical)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...4)
                    .frame(minHeight: 40)
                    .onChange(of: messageText) {
                        viewModel.updateTypingStatus(isTyping: !messageText.isEmpty)
                    }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(messageText.isEmpty ? .gray : .messagePrimary)
                }
                .disabled(messageText.isEmpty)
                .scaleEffect(messageText.isEmpty ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: messageText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .navigationTitle(viewModel.conversationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadMessages()
            // Mark this conversation as active (prevents notifications for it)
            NotificationService.shared.activeConversationId = conversationId
        }
        .onDisappear {
            viewModel.cleanup()
            // Clear active conversation when leaving chat
            NotificationService.shared.activeConversationId = nil
        }
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        Task {
            await viewModel.sendMessage(text: text)
            messageText = ""
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    let senderDetails: (name: String, initials: String, color: String)?
    let totalParticipants: Int

    // Check if message has been read by someone OTHER than the sender
    private var isReadByOthers: Bool {
        // For direct chat (2 people): read if readBy contains more than just the sender
        if totalParticipants == 2 {
            return message.readBy.count >= 2
        }
        // For group chat: read if anyone besides sender has read it
        return message.readBy.count > 1
    }

    private var othersReadCount: Int {
        // Exclude the sender from the count
        return max(0, message.readBy.count - 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Avatar for received messages
            if !isFromCurrentUser {
                if let details = senderDetails {
                    Circle()
                        .fill(Color(hex: details.color))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Text(details.initials)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                } else {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Text("?")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                }
            }

            if isFromCurrentUser {
                Spacer(minLength: 50)
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if let text = message.text {
                    Text(text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isFromCurrentUser ? Color.messagePrimary : Color.messageReceived)
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                        .cornerRadius(18)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }

                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if isFromCurrentUser {
                        // Show read receipt information
                        if isReadByOthers {
                            if totalParticipants > 2 {
                                // Group chat: show read count (excluding sender)
                                Text("Read by \(othersReadCount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } else {
                                // Direct chat: show "Read"
                                Text("Read")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            // Show status icon for other states
                            Image(systemName: statusIcon)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
    }

    private var statusIcon: String {
        switch message.status {
        case .sending:
            return "clock"
        case .sent:
            return "checkmark"
        case .delivered:
            return "checkmark.circle"
        case .read:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.circle"
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(conversationId: "preview-conversation")
    }
}
