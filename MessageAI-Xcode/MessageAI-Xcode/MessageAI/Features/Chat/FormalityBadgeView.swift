/**
 * FormalityBadgeView - Visual indicator for message formality level
 * PR #4: Formality Analysis & Adjustment
 */

import SwiftUI

struct FormalityBadgeView: View {
    let analysis: FormalityAnalysis
    let onTap: () -> Void
    let userLanguage: String
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(analysis.level.emoji)
                    .font(.caption)
                
                Text(analysis.level.displayName(in: userLanguage))
                    .font(.caption)
                    .fontWeight(.medium)
                
                if analysis.confidence >= 0.9 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct FormalityDetailSheet: View {
    let message: Message
    let analysis: FormalityAnalysis
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ChatViewModel
    let userLanguage: String
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Message Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Message")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        
                        Text(message.text ?? "")
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Formality Level
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Formality Level")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        
                        HStack {
                            Text(analysis.level.emoji)
                                .font(.title)
                            VStack(alignment: .leading) {
                                Text(analysis.level.displayName(in: userLanguage))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Text("\(Int(analysis.confidence * 100))% confident")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Explanation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Analysis")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        
                        Text(analysis.explanation)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Markers
                    if !analysis.markers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Formality Indicators")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(analysis.markers.prefix(5), id: \.text) { marker in
                                    HStack {
                                        Image(systemName: markerIcon(for: marker.type))
                                            .foregroundStyle(.blue)
                                            .frame(width: 20)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\"\(marker.text)\"")
                                                .font(.callout)
                                                .fontWeight(.medium)
                                            Text(marker.explanation)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Formality Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func markerIcon(for type: MarkerType) -> String {
        switch type {
        case .pronoun: return "person.fill"
        case .verbForm: return "text.word.spacing"
        case .honorific: return "star.fill"
        case .vocabulary: return "book.fill"
        case .grammar: return "text.alignleft"
        case .contraction: return "text.quote"
        }
    }
}

#Preview {
    FormalityBadgeView(
        analysis: FormalityAnalysis(
            level: .formal,
            confidence: 0.95,
            markers: [],
            explanation: "This message uses formal language.",
            suggestedLevel: nil
        ),
        onTap: {},
        userLanguage: "en"
    )
}

