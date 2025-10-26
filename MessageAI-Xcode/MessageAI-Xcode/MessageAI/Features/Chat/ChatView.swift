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
    @State private var showingAIAssistant = false

    init(conversationId: String) {
        self.conversationId = conversationId
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversationId: conversationId))
    }
    
    // MARK: - Messages Scroll View
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Pagination loading indicator at top
                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.vertical, 8)
                            Spacer()
                        }
                    } else if let error = viewModel.paginationError {
                        Button(action: {
                            Task { await viewModel.loadMoreMessages() }
                        }) {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        }
                    }
                    
                    ForEach(viewModel.messages) { message in
                        MessageBubble(
                            message: message,
                            isFromCurrentUser: message.senderId == viewModel.currentUserId,
                            senderDetails: viewModel.senderDetails[message.senderId],
                            totalParticipants: viewModel.participantIds.count,
                            viewModel: viewModel
                        )
                        .id(message.id)
                        .transition(.opacity) // Simpler transition for better performance
                        .onAppear {
                            // Trigger pagination when approaching top
                            if viewModel.messages.firstIndex(where: { $0.id == message.id }) ?? 0 < 5 {
                                if !viewModel.isPaginationTriggered {
                                    viewModel.isPaginationTriggered = true
                                    Task { 
                                        await viewModel.loadMoreMessages()
                                        viewModel.isPaginationTriggered = false
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .scrollBounceBehavior(.basedOnSize)
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                // Throttle scroll position updates for better performance
                let isAtBottom = offset > -100
                if viewModel.isAtBottom != isAtBottom {
                    // Use a small delay to throttle rapid updates
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.isAtBottom = isAtBottom
                    }
                }
            }
            .defaultScrollAnchor(viewModel.isProcessingPagination ? nil : .bottom)
            .onAppear {
                viewModel.markMessagesAsRead()
            }
            .onChange(of: viewModel.contentVersion) { _, _ in
                handleStickyBottomScroll(proxy: proxy)
            }
            .onChange(of: isTextFieldFocused) { _, isFocused in
                if isFocused {
                    handleStickyBottomScroll(proxy: proxy)
                }
            }
            .onChange(of: viewModel.showSmartReplies) { _, _ in
                // Trigger sticky-bottom scroll when Smart Replies appear/disappear
                handleStickyBottomScroll(proxy: proxy)
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

            // Smart Replies (PR #7) - Now properly positioned above input bar
            if viewModel.showSmartReplies {
                SmartReplyView(
                    replies: viewModel.smartReplies,
                    onSelect: { reply in
                        viewModel.selectSmartReply(reply, into: &messageText)
                    },
                    onDismiss: {
                        viewModel.dismissSmartReplies()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showSmartReplies)
            }
            
            // Input Bar
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Message", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($isTextFieldFocused)
                    .lineLimit(1...4)
                    .padding(10)
                    .frame(minHeight: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .strokeBorder(Color.messagePrimary.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .onChange(of: messageText) {
                        viewModel.updateTypingStatus(isTyping: !messageText.isEmpty)
                    }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            messageText.isEmpty ? 
                            Color.gray : 
                            Color.messagePrimary
                        )
                }
                .disabled(messageText.isEmpty)
                .scaleEffect(messageText.isEmpty ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: messageText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color(.systemBackground)
                    .shadow(color: Color.messagePrimary.opacity(0.05), radius: 8, x: 0, y: -2)
            )
        }
        .navigationTitle(viewModel.conversationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // AI Assistant Button (PR #8) - Moved to header
                    Button(action: {
                        showingAIAssistant = true
                    }) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.messageGradient)
                            .symbolVariant(.fill)
                            .font(.system(size: 20, weight: .semibold))
                    }
                    
                    // Auto-translate Toggle
                    Button {
                        viewModel.autoTranslateEnabled.toggle()
                        viewModel.saveAutoTranslateSetting() // Persist the setting
                    } label: {
                        Image(systemName: "globe")
                            .foregroundColor(viewModel.autoTranslateEnabled ? Color.messagePrimary : .gray)
                            .symbolVariant(viewModel.autoTranslateEnabled ? .fill : .none)
                            .font(.system(size: 20, weight: viewModel.autoTranslateEnabled ? .bold : .regular))
                    }
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
        .sheet(isPresented: $viewModel.showingFormalitySheet) {
            if let message = viewModel.selectedMessageForFormality,
               let analysis = viewModel.formalityAnalyses[message.id] {
                FormalityDetailSheet(
                    message: message,
                    analysis: analysis,
                    viewModel: viewModel,
                    userLanguage: viewModel.userFluentLanguages.first ?? "en"
                )
            }
        }
        .sheet(isPresented: $viewModel.showingPhraseExplanationSheet) {
            if let phrase = viewModel.selectedPhraseForExplanation {
                PhraseExplanationSheet(
                    phrase: phrase,
                    fullExplanation: viewModel.currentExplanation,
                    isLoading: viewModel.loadingExplanation
                )
            }
        }
        .sheet(isPresented: $showingAIAssistant) {
            NavigationStack {
                AIAssistantView(conversationId: conversationId)
            }
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
    private func handleStickyBottomScroll(proxy: ScrollViewProxy) {
        // Only scroll if user is at/near bottom
        guard viewModel.isAtBottom else { return }
        guard !viewModel.messages.isEmpty else { return }
        guard let lastMessage = viewModel.messages.last else { return }
        
        // Delay to allow view to update with new content
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

// Add preference key for scroll tracking
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MessageBubble and CulturalContextCard extracted to MessageBubbleView.swift

#Preview {
    NavigationStack {
        ChatView(conversationId: "preview-conversation")
    }
}
