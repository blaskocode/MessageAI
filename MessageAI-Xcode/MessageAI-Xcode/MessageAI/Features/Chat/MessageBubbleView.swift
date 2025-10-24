/**
 * MessageBubbleView - Individual message display component
 * Handles message text, avatars, read receipts, translation UI, and formality badges
 */

import SwiftUI

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    let senderDetails: (name: String, initials: String, color: String, photoURL: String?)?
    let totalParticipants: Int
    @ObservedObject var viewModel: ChatViewModel
    
    @State private var showTranslation = false
    @State private var showFormalityBadge = false
    @State private var showSlangBadge = false
    
    // Individual badge state checks
    private var hasFormalityData: Bool {
        !isFromCurrentUser && 
        viewModel.autoAnalyzeFormality && 
        viewModel.formalityAnalyses[message.id] != nil
    }
    
    private var hasSlangData: Bool {
        !isFromCurrentUser && 
        viewModel.autoDetectSlang && 
        viewModel.slangDetections[message.id] != nil && 
        !viewModel.slangDetections[message.id]!.isEmpty
    }
    
    private var hasTranslationData: Bool {
        !isFromCurrentUser && 
        viewModel.shouldShowTranslateButton(for: message)
    }
    
    // Check if message has any AI content that requires reserved space
    private var hasAnyAIContent: Bool {
        return hasFormalityData || hasSlangData || hasTranslationData
    }

    // Check if message has been read by someone OTHER than the sender
    private var isReadByOthers: Bool {
        // For direct chat (2 people): read if readBy contains more than just the sender
        if totalParticipants == 2 {
            return message.readBy.count >= 2
        }
        // For group chat: read if anyone besides sender has read it
        return message.readBy.count > 1
    }

    private var othersReadCount: Int {
        // Exclude the sender from the count
        return max(0, message.readBy.count - 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Avatar for received messages
            if !isFromCurrentUser {
                if let details = senderDetails {
                    // Try to display profile photo, fall back to colored circle
                    // Validate URL: must be http(s) and not a color hex
                    if let photoURL = details.photoURL, 
                       !photoURL.isEmpty,
                       !photoURL.hasPrefix("#"),
                       photoURL.hasPrefix("http") {
                        AsyncImage(url: URL(string: photoURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                            case .failure, .empty:
                                defaultAvatarCircle(details: details)
                            @unknown default:
                                defaultAvatarCircle(details: details)
                            }
                        }
                        .transaction { $0.animation = nil } // Prevent flash on cache hit
                    } else {
                        defaultAvatarCircle(details: details)
                    }
                } else {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Text("?")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                }
            }

            if isFromCurrentUser {
                Spacer(minLength: 50)
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if let text = message.text {
                    VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 8) {
                        // Original message text with enhanced styling
                        Text(text)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                Group {
                                    if isFromCurrentUser {
                                        // Beautiful gradient for sent messages
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color.messageGradient)
                                            .shadow(color: Color.messagePrimary.opacity(0.3), radius: 4, x: 0, y: 2)
                                    } else {
                                        // Enhanced received message styling
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color.messageReceived)
                                            .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
                                    }
                                }
                            )
                            .foregroundColor(isFromCurrentUser ? .white : .primary)
                        
                        // AI Badges Container - Only show if there's AI content
                        if hasAnyAIContent {
                            HStack(spacing: 6) {
                                // Formality Badge (PR #4)
                                if hasFormalityData && showFormalityBadge,
                                   let analysis = viewModel.formalityAnalyses[message.id] {
                                    FormalityBadgeView(analysis: analysis) {
                                        viewModel.selectedMessageForFormality = message
                                        viewModel.showingFormalitySheet = true
                                    }
                                    .opacity(showFormalityBadge ? 1.0 : 0.0)
                                }
                                
                                // Slang & Idiom Badges (PR #5)
                                if hasSlangData && showSlangBadge,
                                   let phrases = viewModel.slangDetections[message.id] {
                                    SlangBadgeView(phrases: phrases) { phrase in
                                        viewModel.showPhraseExplanation(phrase: phrase, messageText: text)
                                    }
                                    .opacity(showSlangBadge ? 1.0 : 0.0)
                                }
                                
                                Spacer() // Push badges to the left
                            }
                            .frame(height: 24) // Reserve fixed height to prevent layout shifts
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: hasAnyAIContent)
                            .onAppear {
                                // Instant fade-in when badges are ready
                                if hasFormalityData {
                                    withAnimation(.easeIn(duration: 0.25)) {
                                        showFormalityBadge = true
                                    }
                                }
                                
                                if hasSlangData {
                                    withAnimation(.easeIn(duration: 0.25)) {
                                        showSlangBadge = true
                                    }
                                }
                            }
                            .onChange(of: hasFormalityData) { _, hasData in
                                if hasData && !showFormalityBadge {
                                    withAnimation(.easeIn(duration: 0.25)) {
                                        showFormalityBadge = true
                                    }
                                }
                            }
                            .onChange(of: hasSlangData) { _, hasData in
                                if hasData && !showSlangBadge {
                                    withAnimation(.easeIn(duration: 0.25)) {
                                        showSlangBadge = true
                                    }
                                }
                            }
                        }
                        
                        // Translation badge and content (PR #2)
                        // Only show translate button if message is in non-fluent language
                        if !isFromCurrentUser && viewModel.shouldShowTranslateButton(for: message) {
                            Button(action: {
                                showTranslation.toggle()
                                if showTranslation && viewModel.translations[message.id] == nil {
                                    // Use first fluent language, fallback to English
                                    let targetLang = viewModel.userFluentLanguages.first ?? "en"
                                    viewModel.toggleTranslation(messageId: message.id, targetLanguage: targetLang)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "globe")
                                        .font(.caption2)
                                    Text(showTranslation ? "Hide translation" : "Tap to translate")
                                        .font(.caption2)
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            // Show translation if toggled on OR auto-translated
                            if showTranslation || (viewModel.translations[message.id] != nil && viewModel.autoTranslateEnabled) {
                                if viewModel.isTranslating[message.id] == true {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Translating...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(8)
                                } else if let translation = viewModel.translations[message.id] {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(translation.translatedText)
                                            .font(.body)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(12)
                                        
                                        Text("Translated from \(languageName(translation.originalLanguage))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 4)
                                    }
                                } else if viewModel.translationErrors[message.id] != nil {
                                    Text("Translation failed")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding(8)
                                }
                            }
                            
                            // Cultural Context Hint (PR #3)
                            if let culturalContext = viewModel.culturalContexts[message.id],
                               viewModel.culturalHintsEnabled, // Check if user has cultural hints enabled
                               (showTranslation || (viewModel.translations[message.id] != nil && viewModel.autoTranslateEnabled)), // Only show when translation is visible
                               culturalContext.hasContext,
                               !viewModel.dismissedHints.contains(message.id) {
                                CulturalContextCard(
                                    context: culturalContext,
                                    onDismiss: {
                                        viewModel.dismissCulturalHint(messageId: message.id)
                                    }
                                )
                            }
                        }
                    }
                }

                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if isFromCurrentUser {
                        // Show read receipt information
                        if isReadByOthers {
                            if totalParticipants > 2 {
                                // Group chat: show read count (excluding sender)
                                Text("Read by \(othersReadCount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } else {
                                // Direct chat: show "Read"
                                Text("Read")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            // Show status icon for other states
                            Image(systemName: statusIcon)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: hasAnyAIContent)

            if !isFromCurrentUser {
                Spacer(minLength: 50)
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
    
    // Helper to convert language code to readable name (PR #2)
    private func languageName(_ code: String) -> String {
        let locale = Locale.current
        return locale.localizedString(forLanguageCode: code) ?? code.uppercased()
    }
    
    // Helper to create default colored circle avatar with initials
    private func defaultAvatarCircle(details: (name: String, initials: String, color: String, photoURL: String?)) -> some View {
        Circle()
            .fill(Color(hex: details.color))
            .frame(width: 32, height: 32)
            .overlay {
                Text(details.initials)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
    }
}

// MARK: - Cultural Context Card (PR #3)

struct CulturalContextCard: View {
    let context: CulturalContext
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                
                Text("Cultural Context")
                    .font(.caption.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let explanation = context.explanation {
                Text(explanation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

