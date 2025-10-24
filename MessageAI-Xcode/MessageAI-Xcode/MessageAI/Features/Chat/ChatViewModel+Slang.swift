/**
 * ChatViewModel+Slang - Extension for Slang & Idiom Detection
 * PR #5: Slang & Idiom Explanations
 * 
 * Handles:
 * - Automatic slang/idiom detection in messages
 * - Caching detection results
 * - Fetching detailed explanations on demand
 */

import Foundation
import SwiftUI

extension ChatViewModel {
    
    // MARK: - Slang Detection
    
    /// Detect slang and idioms in a message if needed
    @MainActor
    func detectSlangIfNeeded(for message: Message) async {
        // Skip if auto-detect is disabled
        guard autoDetectSlang else { return }
        
        // Skip if already detected
        guard slangDetections[message.id] == nil else { return }
        
        // Skip if no text
        guard let text = message.text, !text.isEmpty else { return }
        
        // Skip if from current user (only detect in received messages)
        guard message.senderId != currentUserId else { return }
        
        // Use detected language from message, or try to detect it
        let language: String
        if let detectedLang = message.detectedLanguage {
            language = detectedLang
        } else {
            // Try to detect language first
            do {
                let detection = try await AIService.shared.detectLanguage(text: text)
                language = detection.language
            } catch {
                print("⚠️ Language detection failed for slang detection: \(error)")
                return
            }
        }
        
        // Detect slang/idioms
        do {
            let phrases = try await AIService.shared.detectSlangIdioms(
                text: text,
                language: language,
                userFluentLanguage: userFluentLanguages.first
            )
            
            // Cache the result (even if empty)
            slangDetections[message.id] = phrases
            
            // Only trigger scroll adjustment for new real-time messages
            // Don't trigger for paginated messages to prevent scroll jumps
            if !isProcessingPagination {
                contentVersion += 1
            }
            
            if !phrases.isEmpty {
                print("✅ Detected \(phrases.count) slang/idiom(s) in message \(message.id)")
            }
        } catch {
            print("❌ Slang detection failed for message \(message.id): \(error.localizedDescription)")
        }
    }
    
    /// Detect slang for all undetected messages in the current conversation
    @MainActor
    func detectSlang(for messages: [Message]) async {
        for message in messages {
            await detectSlangIfNeeded(for: message)
        }
    }
    
    // MARK: - Phrase Explanation
    
    /// Get detailed explanation for a specific phrase
    @MainActor
    func explainPhrase(_ phrase: DetectedPhrase, context: String?) async {
        // Set loading state
        loadingExplanation = true
        selectedPhraseForExplanation = phrase
        showingPhraseExplanationSheet = true
        
        // Check if we already have a full explanation cached
        if let cached = phraseExplanations[phrase.phrase] {
            currentExplanation = cached
            loadingExplanation = false
            return
        }
        
        // Use detected language from the phrase or default to English
        let language = context?.components(separatedBy: " ").count ?? 0 > 5 ? "auto" : "en"
        
        do {
            let explanation = try await AIService.shared.explainPhrase(
                phrase: phrase.phrase,
                language: language,
                context: context,
                userFluentLanguage: userFluentLanguages.first
            )
            
            // Cache the explanation
            phraseExplanations[phrase.phrase] = explanation
            currentExplanation = explanation
            
            print("✅ Got detailed explanation for \"\(phrase.phrase)\"")
        } catch {
            print("❌ Failed to explain phrase: \(error.localizedDescription)")
            currentExplanation = nil
        }
        
        loadingExplanation = false
    }
    
    /// Quick explain a phrase (called from badge tap)
    @MainActor
    func showPhraseExplanation(phrase: DetectedPhrase, messageText: String?) {
        Task {
            await explainPhrase(phrase, context: messageText)
        }
    }
    
    // MARK: - Batch Detection
    
    /// Detect slang for recent messages (called when messages load)
    @MainActor
    func detectSlangForRecentMessages() {
        Task {
            // Detect only recent messages (last 10) to avoid overwhelming the backend
            let recentMessages = messages.suffix(10)
            
            for message in recentMessages {
                await detectSlangIfNeeded(for: message)
            }
        }
    }
}

