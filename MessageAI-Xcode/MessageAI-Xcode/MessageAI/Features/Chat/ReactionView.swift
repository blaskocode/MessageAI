/**
 * ReactionView - Message reactions with emoji picker
 * Allows users to react to messages with emojis
 */

import SwiftUI

struct ReactionView: View {
    let message: Message
    @ObservedObject var viewModel: ChatViewModel
    @State private var showEmojiPicker = false
    @State private var reactions: [MessageReaction] = []
    
    private let commonEmojis = ["👍", "👎", "❤️", "😂", "😮", "😢", "😡", "🎉"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Reaction buttons
            if !reactions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(reactions, id: \.emoji) { reaction in
                        ReactionButton(
                            reaction: reaction,
                            isFromCurrentUser: viewModel.isReactionFromCurrentUser(reaction),
                            onTap: {
                                viewModel.toggleReaction(messageId: message.id, emoji: reaction.emoji)
                            }
                        )
                    }
                    
                    // Add reaction button
                    Button(action: {
                        showEmojiPicker = true
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accessibilitySupport(
                        label: "Add reaction",
                        hint: "Double tap to add an emoji reaction"
                    )
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(16)
            } else {
                // Show add reaction button when no reactions exist
                Button(action: {
                    showEmojiPicker = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                        Text("Add reaction")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .accessibilitySupport(
                    label: "Add reaction",
                    hint: "Double tap to add an emoji reaction"
                )
            }
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView { emoji in
                viewModel.addReaction(messageId: message.id, emoji: emoji)
                showEmojiPicker = false
            }
        }
        .onAppear {
            loadReactions()
        }
        .onChange(of: viewModel.messageReactions[message.id]) { _, newReactions in
            reactions = newReactions ?? []
        }
    }
    
    private func loadReactions() {
        reactions = viewModel.messageReactions[message.id] ?? []
    }
}

struct ReactionButton: View {
    let reaction: MessageReaction
    let isFromCurrentUser: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(reaction.emoji)
                    .font(.caption)
                
                if reaction.count > 1 {
                    Text("\(reaction.count)")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isFromCurrentUser ? Color.blue.opacity(0.2) : Color.clear)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFromCurrentUser ? Color.blue : Color.clear, lineWidth: 1)
            )
        }
        .accessibilitySupport(
            label: "\(reaction.emoji) reaction, \(reaction.count) people",
            hint: isFromCurrentUser ? "Double tap to remove your reaction" : "Double tap to add your reaction"
        )
    }
}

struct EmojiPickerView: View {
    let onEmojiSelected: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    private let emojiCategories = [
        ("Faces", ["😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "😊", "😇", "🙂", "🙃", "😉", "😌", "😍", "🥰", "😘", "😗", "😙", "😚", "😋", "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🤩", "🥳", "😏", "😒", "😞", "😔", "😟", "😕", "🙁", "☹️", "😣", "😖", "😫", "😩", "🥺", "😢", "😭", "😤", "😠", "😡", "🤬", "🤯", "😳", "🥵", "🥶", "😱", "😨", "😰", "😥", "😓", "🤗", "🤔", "🤭", "🤫", "🤥", "😶", "😐", "😑", "😬", "🙄", "😯", "😦", "😧", "😮", "😲", "🥱", "😴", "🤤", "😪", "😵", "🤐", "🥴", "🤢", "🤮", "🤧", "😷", "🤒", "🤕", "🤑", "🤠", "😈", "👿", "👹", "👺", "🤡", "💩", "👻", "💀", "☠️", "👽", "👾", "🤖", "🎃", "😺", "😸", "😹", "😻", "😼", "😽", "🙀", "😿", "😾"]),
        ("Gestures", ["👋", "🤚", "🖐", "✋", "🖖", "👌", "🤏", "✌️", "🤞", "🤟", "🤘", "🤙", "👈", "👉", "👆", "🖕", "👇", "☝️", "👍", "👎", "👊", "✊", "🤛", "🤜", "👏", "🙌", "👐", "🤲", "🤝", "🙏", "✍️", "💅", "🤳", "💪", "🦾", "🦿", "🦵", "🦶", "👂", "🦻", "👃", "🧠", "🦷", "🦴", "👀", "👁", "👅", "👄"]),
        ("Hearts", ["💋", "👣", "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟"]),
        ("Celebration", ["🎉", "🎊", "🎈", "🎁", "🎀", "🎂", "🍰", "🧁", "🍭", "🍬", "🍫", "🍩", "🍪", "🍯", "🍮", "🍨", "🍧", "🍦", "🍰", "🎂", "🧁", "🍭", "🍬", "🍫", "🍩", "🍪", "🍯", "🍮", "🍨", "🍧", "🍦"]),
        ("Objects", ["📱", "💻", "⌨️", "🖥", "🖨", "🖱", "🖲", "💽", "💾", "💿", "📀", "📼", "📷", "📸", "📹", "🎥", "📽", "🎞", "📞", "☎️", "📟", "📠", "📺", "📻", "🎙", "🎚", "🎛", "🧭", "⏱", "⏲", "⏰", "🕰", "⌛", "⏳", "📡", "🔋", "🔌", "💡", "🔦", "🕯", "🪔", "🧯", "🛢", "💸", "💵", "💴", "💶", "💷", "💰", "💳", "💎", "⚖️", "🧰", "🔧", "🔨", "⚒", "🛠", "⛏", "🔩", "⚙️", "🧱", "⛓", "🧲", "🔫", "💣", "🧨", "🪓", "🔪", "🗡", "⚔️", "🛡", "🚬", "⚰️", "🪦", "⚱️", "🏺", "🔮", "📿", "🧿", "💈", "⚗️", "🔭", "🔬", "🕳", "🩹", "🩺", "💊", "💉", "🧬", "🦠", "🧫", "🧪", "🌡", "🧹", "🧺", "🧻", "🚽", "🚰", "🚿", "🛁", "🛀", "🧴", "🧷", "🧸", "🧵", "🧶", "🪢", "🪣", "🧽", "🧯", "🛒", "🚬", "⚰️", "🪦", "⚱️", "🏺"])
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 16) {
                    ForEach(emojiCategories, id: \.0) { category in
                        Section(header: Text(category.0).font(.headline).padding(.top)) {
                            ForEach(category.1, id: \.self) { emoji in
                                Button(action: {
                                    onEmojiSelected(emoji)
                                }) {
                                    Text(emoji)
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                                .accessibilitySupport(
                                    label: "\(emoji) emoji",
                                    hint: "Double tap to react with this emoji"
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Add Reaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ReactionView(
        message: Message(
            id: "1",
            senderId: "user1",
            text: "Hello world!",
            timestamp: Date(),
            status: .sent
        ),
        viewModel: ChatViewModel(conversationId: "preview")
    )
}
