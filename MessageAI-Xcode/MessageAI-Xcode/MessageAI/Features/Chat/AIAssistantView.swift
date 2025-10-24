/**
 * AIAssistantView - Chat interface with AI Assistant
 * PR #8: AI Assistant with RAG
 */

import SwiftUI

struct AIAssistantView: View {
    @StateObject var viewModel: AIAssistantViewModel
    @State private var queryText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    init(conversationId: String? = nil) {
        _viewModel = StateObject(wrappedValue: AIAssistantViewModel(conversationId: conversationId))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.messages) { message in
                            AssistantMessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        // Loading indicator
                        if viewModel.isLoading {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Thinking...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Quick Actions (show after assistant responses, hide while loading)
            if !viewModel.isLoading && (viewModel.messages.isEmpty || viewModel.messages.last?.isUser == false) {
                let actions = viewModel.suggestQuickActions()
                if !actions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(actions, id: \.self) { action in
                                Button(action: {
                                    queryText = action
                                }) {
                                    Text(action)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(.purple.opacity(0.1))
                                        .foregroundStyle(.purple)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 32) // Fixed height to prevent NaN calculations
                    .padding(.vertical, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // Summarize Button (if conversation-specific)
            if viewModel.conversationId != nil {
                Button(action: {
                    Task {
                        await viewModel.summarizeConversation()
                    }
                }) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Summarize Conversation")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.purple)
                    .padding(.vertical, 8)
                }
                .disabled(viewModel.isLoading)
            }
            
            Divider()
            
            // Input Bar
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Ask me anything...", text: $queryText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($isTextFieldFocused)
                    .lineLimit(1...4)
                    .padding(10)
                    .frame(minHeight: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                    )
                
                Button(action: sendQuery) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(queryText.isEmpty ? .gray : .purple)
                }
                .disabled(queryText.isEmpty || viewModel.isLoading)
                .scaleEffect(queryText.isEmpty ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: queryText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
    
    private func sendQuery() {
        let query = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        Task {
            await viewModel.sendQuery(query)
            queryText = ""
        }
    }
}

// MARK: - Message Bubble

struct AssistantMessageBubble: View {
    let message: AssistantMessage
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .padding(12)
                    .background(message.isUser ? Color.purple : Color(.systemGray6))
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Show source count if assistant message with sources
                if !message.isUser && !message.sources.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.caption2)
                        Text("\(message.sources.count) message\(message.sources.count == 1 ? "" : "s") referenced")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 300, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser { Spacer() }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AIAssistantView(conversationId: "preview-123")
    }
}

