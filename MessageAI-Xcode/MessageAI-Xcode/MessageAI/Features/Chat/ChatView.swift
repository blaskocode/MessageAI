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
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message, isFromCurrentUser: message.senderId == viewModel.currentUserId)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) {
                    // Auto-scroll to bottom when new message arrives
                    guard !viewModel.messages.isEmpty else { return }
                    if let lastMessage = viewModel.messages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .onChange(of: viewModel.isTyping) {
                    // Auto-scroll when typing indicator appears
                    if viewModel.isTyping, let lastMessage = viewModel.messages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Typing Indicator (above input bar)
            if viewModel.isTyping {
                HStack {
                    Text("Typing...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .italic()
                        .padding(.horizontal)
                    Spacer()
                }
                .frame(height: 20)
                .background(Color(.systemBackground))
            }
            
            // Input Bar
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Message", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 36, maxHeight: 100)
                    .onChange(of: messageText) {
                        viewModel.updateTypingStatus(isTyping: !messageText.isEmpty)
                    }
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(messageText.isEmpty ? .gray : .blue)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadMessages()
        }
        .onDisappear {
            viewModel.cleanup()
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
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if let text = message.text {
                    Text(text)
                        .padding(12)
                        .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                        .cornerRadius(16)
                }
                
                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    if isFromCurrentUser {
                        Image(systemName: statusIcon)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            if !isFromCurrentUser {
                Spacer()
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

