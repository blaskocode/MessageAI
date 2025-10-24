/**
 * SmartReplyView - Quick reply chips above keyboard
 * PR #7: Smart Replies with Style Learning
 */

import SwiftUI

struct SmartReplyView: View {
    let replies: [SmartReply]
    let onSelect: (SmartReply) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            // Compact header with dismiss button
            HStack {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(.purple)
                
                Text("Quick Replies")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            
            // Reply chips - more compact
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(replies) { reply in
                        Button(action: { onSelect(reply) }) {
                            Text(reply.text)
                                .font(.caption)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 32) // Fixed height to prevent layout issues
            .padding(.bottom, 6)
        }
        .background(.bar)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// Preview
#Preview {
    VStack {
        Spacer()
        
        SmartReplyView(
            replies: [
                SmartReply(text: "Yeah, sounds great! ☕", translation: nil, formality: "casual"),
                SmartReply(text: "What time works for you?", translation: nil, formality: "neutral"),
                SmartReply(text: "Love to! Morning or afternoon?", translation: nil, formality: "casual"),
                SmartReply(text: "Perfect, let's do it 😊", translation: nil, formality: "casual")
            ],
            onSelect: { reply in
                print("Selected: \(reply.text)")
            },
            onDismiss: {
                print("Dismissed")
            }
        )
    }
}

