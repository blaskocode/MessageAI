//
//  NewConversationView.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import SwiftUI

struct NewConversationView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            List {
                // TODO: Show list of users to start conversation with
                Text("User list coming soon...")
                    .foregroundColor(.gray)
            }
            .searchable(text: $searchText, prompt: "Search users")
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NewConversationView()
}

