/**
 * SlangBadgeView - Visual indicator for detected slang and idioms
 * PR #5: Slang & Idiom Explanations
 */

import SwiftUI

struct SlangBadgeView: View {
    let phrases: [DetectedPhrase]
    let onTap: (DetectedPhrase) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(phrases) { phrase in
                    Button(action: { onTap(phrase) }) {
                        HStack(spacing: 4) {
                            Text(phrase.type.emoji)
                                .font(.caption)
                            
                            Text(phrase.phrase)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
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
        }
    }
}

struct PhraseExplanationSheet: View {
    let phrase: DetectedPhrase
    let fullExplanation: PhraseExplanation?
    let isLoading: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Phrase Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(phrase.type.emoji)
                                .font(.title)
                            VStack(alignment: .leading) {
                                Text(phrase.phrase)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text(phrase.type.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    if isLoading {
                        // Loading State
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("Getting detailed explanation...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else if let explanation = fullExplanation {
                        // Full Explanation
                        
                        // Meaning
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Meaning")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            
                            Text(explanation.meaning)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Origin
                        if !explanation.origin.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Origin")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                
                                Text(explanation.origin)
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        
                        // Examples
                        if !explanation.examples.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Examples")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(explanation.examples, id: \.self) { example in
                                        HStack(alignment: .top, spacing: 8) {
                                            Text("•")
                                                .foregroundStyle(.blue)
                                            Text(example)
                                                .font(.callout)
                                        }
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        
                        // Cultural Notes
                        if !explanation.culturalNotes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(.yellow)
                                    Text("Cultural Context")
                                }
                                .font(.caption)
                                .textCase(.uppercase)
                                
                                Text(explanation.culturalNotes)
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.yellow.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    } else {
                        // Quick Meaning (from detection)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quick Meaning")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            
                            Text(phrase.meaning)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Similar Phrases
                        if !phrase.similar.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Similar Phrases")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(phrase.similar, id: \.self) { similar in
                                        Text(similar)
                                            .font(.callout)
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
                }
                .padding()
            }
            .navigationTitle(phrase.type.displayName)
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
}

#Preview {
    SlangBadgeView(
        phrases: [
            DetectedPhrase(
                phrase: "piece of cake",
                type: .idiom,
                meaning: "Very easy",
                origin: "British English",
                similar: ["walk in the park", "breeze"],
                examples: ["That test was a piece of cake!"]
            )
        ],
        onTap: { _ in }
    )
}

