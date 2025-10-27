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
                // Media Content
                if let mediaURL = message.mediaURL, let mediaType = message.mediaType {
                    MediaMessageView(
                        mediaURL: mediaURL,
                        mediaType: mediaType,
                        isFromCurrentUser: isFromCurrentUser
                    )
                }
                
                // Text Content
                if let text = message.text {
                    VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 8) {
                        // Original message text with enhanced styling
                        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 8) {
                            // Use Text with attributed string to make URLs clickable
                            AttributedText(text: text, textColor: isFromCurrentUser ? .white : .primary)
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
                            
                            // Link Previews
                            if let urls = extractURLs(from: text), !urls.isEmpty {
                                ForEach(urls, id: \.self) { url in
                                    LinkPreviewView(url: url)
                                }
                            }
                        }
                        
                        // AI Badges Container - Only show if there's AI content
                        if hasAnyAIContent {
                            HStack(spacing: 6) {
                                // Formality Badge (PR #4)
                                if hasFormalityData && showFormalityBadge,
                                   let analysis = viewModel.formalityAnalyses[message.id] {
                                    FormalityBadgeView(
                                        analysis: analysis,
                                        onTap: {
                                            viewModel.selectedMessageForFormality = message
                                            viewModel.showingFormalitySheet = true
                                        },
                                        userLanguage: viewModel.userFluentLanguages.first ?? "en"
                                    )
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
                                    Text(showTranslation ? hideTranslationText(for: viewModel.userFluentLanguages.first ?? "en") : translateButtonText(for: viewModel.userFluentLanguages.first ?? "en"))
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
                                        
                                        Text(translatedFromText(for: translation.originalLanguage, targetLang: viewModel.userFluentLanguages.first ?? "en"))
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
                
                // Message Reactions - Show for all messages (received messages only by default for add reaction button)
                // But always show existing reactions
                ReactionView(message: message, viewModel: viewModel)

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
            .messageBubbleAccessibility(
                message: message,
                isFromCurrentUser: isFromCurrentUser,
                senderName: senderDetails?.name
            )

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
    
    // MARK: - Localization Helpers
    
    private func translateButtonText(for targetLanguage: String) -> String {
        switch targetLanguage {
        case "es": return "Tocar para traducir"
        case "fr": return "Appuyez pour traduire"
        case "de": return "Tippen zum Übersetzen"
        case "ja": return "タップして翻訳"
        case "zh": return "点击翻译"
        case "pt": return "Toque para traduzir"
        case "it": return "Tocca per tradurre"
        case "ru": return "Нажмите для перевода"
        default: return "Tap to translate"
        }
    }
    
    private func hideTranslationText(for targetLanguage: String) -> String {
        switch targetLanguage {
        case "es": return "Ocultar traducción"
        case "fr": return "Masquer la traduction"
        case "de": return "Übersetzung ausblenden"
        case "ja": return "翻訳を隠す"
        case "zh": return "隐藏翻译"
        case "pt": return "Ocultar tradução"
        case "it": return "Nascondi traduzione"
        case "ru": return "Скрыть перевод"
        default: return "Hide translation"
        }
    }
    
    private func translatedFromText(for sourceLang: String, targetLang: String) -> String {
        let langName = languageName(sourceLang)
        switch targetLang {
        case "es": return "Traducido desde \(langName)"
        case "fr": return "Traduit de \(langName)"
        case "de": return "Übersetzt von \(langName)"
        case "ja": return "\(langName)から翻訳"
        case "zh": return "从\(langName)翻译"
        case "pt": return "Traduzido de \(langName)"
        case "it": return "Tradotto da \(langName)"
        case "ru": return "Переведено с \(langName)"
        default: return "Translated from \(langName)"
        }
    }
    
    // MARK: - URL Detection
    
    private func extractURLs(from text: String) -> [String]? {
        let urlPattern = #"(https?://[^\s]+)"#
        let regex = try? NSRegularExpression(pattern: urlPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: text.utf16.count)
        
        let matches = regex?.matches(in: text, options: [], range: range) ?? []
        let urls = matches.compactMap { match -> String? in
            if let matchRange = Range(match.range, in: text) {
                return String(text[matchRange])
            }
            return nil
        }
        
        return urls.isEmpty ? nil : urls
    }
}

// MARK: - AttributedText for Clickable URLs

struct AttributedText: View {
    let text: String
    let textColor: Color
    
    var body: some View {
        if let attributedString = createAttributedString(from: text, textColor: textColor) {
            Text(AttributedString(attributedString))
        } else {
            Text(text)
                .foregroundColor(textColor)
        }
    }
    
    private func createAttributedString(from text: String, textColor: Color) -> NSAttributedString? {
        let attributedString = NSMutableAttributedString(string: text)
        let color = UIColor(textColor)
        
        // Set default text color
        attributedString.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: text.count))
        
        // Find URLs and make them clickable
        let urlPattern = #"(https?://[^\s]+)"#
        let regex = try? NSRegularExpression(pattern: urlPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: text.utf16.count)
        
        let matches = regex?.matches(in: text, options: [], range: range) ?? []
        
        for match in matches {
            if let urlRange = Range(match.range, in: text) {
                let urlString = String(text[urlRange])
                if let url = URL(string: urlString) {
                    attributedString.addAttribute(.link, value: url, range: match.range)
                    
                    // Make links underline with appropriate color
                    if textColor == .white {
                        // For dark backgrounds (outgoing messages), use white/light color
                        attributedString.addAttribute(.foregroundColor, value: UIColor.white, range: match.range)
                    } else {
                        // For light backgrounds (incoming messages), use blue
                        attributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: match.range)
                    }
                    attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
                }
            }
        }
        
        return attributedString.length > 0 ? attributedString : nil
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

