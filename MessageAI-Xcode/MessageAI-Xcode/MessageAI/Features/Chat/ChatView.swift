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
    @FocusState private var isTextFieldFocused: Bool

    init(conversationId: String) {
        self.conversationId = conversationId
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversationId: conversationId))
    }
    
    // MARK: - Messages Scroll View
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(
                            message: message,
                            isFromCurrentUser: message.senderId == viewModel.currentUserId,
                            senderDetails: viewModel.senderDetails[message.senderId],
                            totalParticipants: viewModel.participantIds.count,
                            viewModel: viewModel
                        )
                        .id(message.id)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding()
                .padding(.bottom, 32) // Extra padding so typing indicator doesn't cover last message
            }
            .defaultScrollAnchor(.bottom)
            .onAppear {
                viewModel.markMessagesAsRead()
            }
            .onChange(of: viewModel.messages.count) {
                handleScrollForNewMessage(proxy: proxy)
            }
            .onChange(of: viewModel.translations) {
                handleScrollForTranslation(proxy: proxy)
            }
            .onChange(of: isTextFieldFocused) { _, isFocused in
                handleScrollForKeyboard(proxy: proxy, isFocused: isFocused)
            }
            .onChange(of: viewModel.autoTranslateEnabled) {
                handleScrollForAutoTranslate(proxy: proxy)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages List with Typing Indicator Overlay
            ZStack(alignment: .bottom) {
                messagesScrollView
                    .background(Color.messageBackground)
                
                // Typing Indicator (overlaid at bottom, doesn't affect ScrollView frame)
                if viewModel.isTyping {
                    VStack {
                        Spacer()
                        HStack {
                            Text("Typing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(.horizontal, 16)
                            Spacer()
                        }
                        .frame(height: 28)
                        .background(
                            Color(.systemBackground)
                                .opacity(0.95)
                                .shadow(color: .black.opacity(0.1), radius: 4, y: -2)
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Input Bar
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Message", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($isTextFieldFocused)
                    .lineLimit(1...4)
                    .padding(10)
                    .frame(minHeight: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                    )
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.autoTranslateEnabled.toggle()
                    viewModel.saveAutoTranslateSetting() // Persist the setting
                } label: {
                    Image(systemName: "globe")
                        .foregroundColor(viewModel.autoTranslateEnabled ? .blue : .gray)
                        .symbolVariant(viewModel.autoTranslateEnabled ? .fill : .none)
                        .font(.system(size: 20, weight: viewModel.autoTranslateEnabled ? .bold : .regular))
                }
            }
        }
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
    
    // MARK: - Scroll Helpers
    private func handleScrollForNewMessage(proxy: ScrollViewProxy) {
        guard !viewModel.messages.isEmpty else { return }
        if let lastMessage = viewModel.messages.last {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
    
    private func handleScrollForTranslation(proxy: ScrollViewProxy) {
        // When a translation appears, the message bubble expands
        // Scroll to keep the translated message visible
        // Find the most recently translated message (highest index with translation)
        if let lastTranslatedMessage = viewModel.messages.last(where: { viewModel.translations[$0.id] != nil }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(lastTranslatedMessage.id, anchor: .center)
                }
            }
        }
    }
    
    private func handleScrollForKeyboard(proxy: ScrollViewProxy, isFocused: Bool) {
        if isFocused, let lastMessage = viewModel.messages.last {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
    
    private func handleScrollForAutoTranslate(proxy: ScrollViewProxy) {
        // When auto-translate is toggled, translations appear/disappear
        // Only scroll to bottom if we're already near the bottom
        // This prevents jarring scroll jumps when user is reading older messages
        guard let lastMessage = viewModel.messages.last else { return }
        
        // Small delay to let the view update with new translation visibility
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    let senderDetails: (name: String, initials: String, color: String, photoURL: String?)?
    let totalParticipants: Int
    @ObservedObject var viewModel: ChatViewModel
    
    @State private var showTranslation = false

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
                    // Try to display profile photo, fall back to colored circle
                    // Validate URL: must be http(s) and not a color hex
                    if let photoURL = details.photoURL, 
                       !photoURL.isEmpty,
                       !photoURL.hasPrefix("#"),
                       photoURL.hasPrefix("http") {
                        AsyncImage(url: URL(string: photoURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                            case .failure, .empty:
                                defaultAvatarCircle(details: details)
                            @unknown default:
                                defaultAvatarCircle(details: details)
                            }
                        }
                    } else {
                        defaultAvatarCircle(details: details)
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
                    VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 8) {
                        // Original message text
                        Text(text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(isFromCurrentUser ? Color.messagePrimary : Color.messageReceived)
                            .foregroundColor(isFromCurrentUser ? .white : .primary)
                            .cornerRadius(18)
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        
                        // Translation badge and content (PR #2)
                        // Only show translate button if message is in non-fluent language
                        if !isFromCurrentUser && viewModel.shouldShowTranslateButton(for: message) {
                            Button(action: {
                                showTranslation.toggle()
                                if showTranslation && viewModel.translations[message.id] == nil {
                                    // Use first fluent language, fallback to English
                                    let targetLang = viewModel.userFluentLanguages.first ?? "en"
                                    viewModel.toggleTranslation(messageId: message.id, targetLanguage: targetLang)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "globe")
                                        .font(.caption2)
                                    Text(showTranslation ? "Hide translation" : "Tap to translate")
                                        .font(.caption2)
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            // Show translation if toggled on OR auto-translated
                            if showTranslation || (viewModel.translations[message.id] != nil && viewModel.autoTranslateEnabled) {
                                if viewModel.isTranslating[message.id] == true {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Translating...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(8)
                                } else if let translation = viewModel.translations[message.id] {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(translation.translatedText)
                                            .font(.body)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(12)
                                        
                                        Text("Translated from \(languageName(translation.originalLanguage))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 4)
                                    }
                                } else if viewModel.translationErrors[message.id] != nil {
                                    Text("Translation failed")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding(8)
                                }
                            }
                            
                            // Cultural Context Hint (PR #3)
                            if let culturalContext = viewModel.culturalContexts[message.id],
                               viewModel.culturalHintsEnabled, // Check if user has cultural hints enabled
                               (showTranslation || (viewModel.translations[message.id] != nil && viewModel.autoTranslateEnabled)), // Only show when translation is visible
                               culturalContext.hasContext,
                               !viewModel.dismissedHints.contains(message.id) {
                                CulturalContextCard(
                                    context: culturalContext,
                                    onDismiss: {
                                        viewModel.dismissCulturalHint(messageId: message.id)
                                    }
                                )
                            }
                        }
                    }
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
    
    // Helper to convert language code to readable name (PR #2)
    private func languageName(_ code: String) -> String {
        let locale = Locale.current
        return locale.localizedString(forLanguageCode: code) ?? code.uppercased()
    }
    
    // Helper to create default colored circle avatar with initials
    private func defaultAvatarCircle(details: (name: String, initials: String, color: String, photoURL: String?)) -> some View {
        Circle()
            .fill(Color(hex: details.color))
            .frame(width: 32, height: 32)
            .overlay {
                Text(details.initials)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
    }
}

// MARK: - Cultural Context Card (PR #3)

struct CulturalContextCard: View {
    let context: CulturalContext
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                
                Text("Cultural Context")
                    .font(.caption.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let explanation = context.explanation {
                Text(explanation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        ChatView(conversationId: "preview-conversation")
    }
}
