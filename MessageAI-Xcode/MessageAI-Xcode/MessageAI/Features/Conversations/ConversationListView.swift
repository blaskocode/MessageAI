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
                    Button(action: { viewModel.showNewConversation = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showNewConversation) {
                NewConversationView()
            }
            .onAppear {
                viewModel.loadConversations()
            }
        }
    }
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

