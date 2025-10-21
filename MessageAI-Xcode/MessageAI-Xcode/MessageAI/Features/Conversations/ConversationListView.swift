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
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.conversations) { conversation in
                    NavigationLink(destination: ChatView(conversationId: conversation.id)) {
                        ConversationRow(conversation: conversation)
                    }
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { authViewModel.signOut() }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
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
            .sheet(isPresented: $viewModel.showNewConversation) {
                NewConversationView()
            }
            .sheet(isPresented: $viewModel.showNewGroup) {
                NewGroupView()
            }
            .onAppear {
                viewModel.loadConversations()
                // Clear badge count when viewing conversation list
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
        }
    }
}

// Helper to make String identifiable for navigation
extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture Placeholder
            Circle()
                .fill(Color.blue)
                .frame(width: 50, height: 50)
                .overlay {
                    Text("AB")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.groupName ?? "Chat")
                    .font(.headline)
                
                if let lastMessage = conversation.lastMessageText {
                    Text(lastMessage)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if let timestamp = conversation.lastMessageTimestamp {
                Text(timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ConversationListView()
        .environmentObject(AuthViewModel())
}

