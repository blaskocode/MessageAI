//
//  ChatViewModel+Translation.swift
//  MessageAI
//
//  Created on October 23, 2025
//  Extension for translation and language detection features (PR #2)
//

import Foundation

// MARK: - Translation & Language Detection (PR #2)

extension ChatViewModel {
    
    // MARK: - Translation
    
    /**
     * Translate a message to the target language
     * Results are cached locally and in Firestore
     */
    func translateMessage(messageId: String, targetLanguage: String) async {
        // Check if already translated
        if translations[messageId] != nil {
            return
        }
        
        // Set loading state
        isTranslating[messageId] = true
        translationErrors[messageId] = nil
        
        do {
            let translation = try await aiService.translateMessage(
                messageId: messageId,
                conversationId: conversationId,
                targetLanguage: targetLanguage
            )
            
            // Store translation
            translations[messageId] = translation
            isTranslating[messageId] = false
            
            // Trigger cultural context analysis after successful translation
            if let message = messages.first(where: { $0.id == messageId }),
               let text = message.text,
               let sourceLanguage = message.detectedLanguage {
                print("🔍 [Translation] Triggering cultural analysis after manual translation")
                await analyzeCulturalContext(messageId: messageId, text: text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
            }
        } catch {
            isTranslating[messageId] = false
            translationErrors[messageId] = error.localizedDescription
            print("❌ Translation failed: \(error.localizedDescription)")
        }
    }
    
    /**
     * Detect the language of a message
     * Used for auto-translate feature (PR #3)
     */
    func detectLanguage(text: String) async -> String? {
        do {
            let detection = try await aiService.detectLanguage(text: text)
            return detection.language
        } catch {
            print("❌ Language detection failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /**
     * Detect language and update message in Firestore (PR #2)
     * Called after sending a message to populate detectedLanguage field
     */
    func detectAndUpdateLanguage(messageId: String, text: String) async {
        // Detect language
        guard let language = await detectLanguage(text: text) else {
            return
        }
        
        // Update message in Firestore with detected language
        do {
            try await firebaseService.updateMessage(
                conversationId: conversationId,
                messageId: messageId,
                updates: ["detectedLanguage": language]
            )
        } catch {
            print("❌ Language detection update failed: \(error)")
        }
    }
    
    /**
     * Toggle translation visibility for a message
     */
    func toggleTranslation(messageId: String, targetLanguage: String = "en") {
        if translations[messageId] != nil {
            // Already have translation, just toggle visibility in UI
            // UI will handle showing/hiding
            return
        }
        
        // Fetch translation
        Task {
            await translateMessage(messageId: messageId, targetLanguage: targetLanguage)
        }
    }
    
    // MARK: - Auto-Translate (PR #3)
    
    /**
     * Check if message should be auto-translated based on user's fluent languages
     * Called automatically when new messages arrive
     */
    func checkAutoTranslate(for message: Message) async {
        guard autoTranslateEnabled else { return }
        guard message.senderId != currentUserId else { return }
        guard let text = message.text else { return }
        
        // Use detected language from message (already set by detectAndUpdateLanguage)
        // If not detected yet, wait a moment and try again
        var language = message.detectedLanguage
        if language == nil {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
            language = await detectLanguage(text: text)
        }
        
        guard let detectedLang = language else {
            return
        }
        
        // Check if message is in non-fluent language
        let fluentLanguages = userFluentLanguages
        let targetLanguage = fluentLanguages.first ?? "en" // Primary language (first in array)
        
        if !fluentLanguages.contains(detectedLang.lowercased()) {
            await translateMessage(messageId: message.id, targetLanguage: targetLanguage)
            await analyzeCulturalContext(messageId: message.id, text: text, sourceLanguage: detectedLang, targetLanguage: targetLanguage)
        }
    }
    
    /**
     * Analyze cultural context for a translated message
     */
    private func analyzeCulturalContext(messageId: String, text: String, sourceLanguage: String, targetLanguage: String) async {
        // Check if already analyzed or hint dismissed
        if culturalContexts[messageId] != nil || dismissedHints.contains(messageId) {
            print("⏭️ [Cultural] Skipping analysis - already analyzed or dismissed")
            return
        }

        print("🔍 [Cultural] Analyzing cultural context for message \(messageId)")
        print("   Text: \(text)")
        print("   Source: \(sourceLanguage) → Target: \(targetLanguage)")

        do {
            let context = try await aiService.analyzeCulturalContext(
                text: text,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                userFluentLanguage: userFluentLanguages.first
            )

            print("✅ [Cultural] Analysis complete:")
            print("   hasContext: \(context.hasContext)")
            print("   confidence: \(context.confidence)")
            if let explanation = context.explanation {
                print("   explanation: \(explanation)")
            }

            // Only store if has meaningful context
            if context.hasContext {
                culturalContexts[messageId] = context
                print("💡 [Cultural] Cultural context stored for message \(messageId)")
            } else {
                print("ℹ️ [Cultural] No significant cultural context found (hasContext=false)")
            }
        } catch {
            print("❌ [Cultural] Cultural context analysis failed:")
            print("   Error: \(error)")
            print("   Localized: \(error.localizedDescription)")
        }
    }
    
    /**
     * Dismiss a cultural hint so it doesn't show again
     */
    func dismissCulturalHint(messageId: String) {
        dismissedHints.insert(messageId)
        culturalContexts.removeValue(forKey: messageId)
        
        // TODO: Persist dismissed hints to Firestore
        print("🚫 Dismissed cultural hint for message \(messageId)")
    }
}

