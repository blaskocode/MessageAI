/**
 * ChatViewModel+Formality - Extension for Formality Analysis & Adjustment
 * PR #4: Formality Analysis & Adjustment
 * 
 * Handles:
 * - Automatic formality analysis of received messages
 * - Caching formality results
 * - Formality adjustment (rephrase) for both sent and received messages
 */

import Foundation
import SwiftUI

extension ChatViewModel {
    
    // MARK: - Formality Analysis
    
    /// Analyze formality for a message if needed (not already cached, auto-analyze enabled, etc.)
    @MainActor
    func analyzeFormalityIfNeeded(for message: Message) async {
        // Skip if auto-analyze is disabled
        guard autoAnalyzeFormality else { return }
        
        // Skip if already analyzed
        guard formalityAnalyses[message.id] == nil else { return }
        
        // Skip if no text
        guard let text = message.text, !text.isEmpty else { return }
        
        // Skip if from current user (only analyze received messages)
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
                print("⚠️ Language detection failed for formality analysis: \(error)")
                return
            }
        }
        
        // Analyze formality
        do {
            let analysis = try await AIService.shared.analyzeFormalityAnalysis(
                messageId: message.id,
                text: text,
                language: language
            )
            
            // Cache the result
            formalityAnalyses[message.id] = analysis
            
            // Only trigger scroll adjustment for new real-time messages
            // Don't trigger for paginated messages to prevent scroll jumps
            if !isProcessingPagination {
                contentVersion += 1
            }
            
            print("✅ Formality analyzed for message \(message.id): \(analysis.level.displayName) (\(Int(analysis.confidence * 100))%)")
        } catch {
            print("❌ Formality analysis failed for message \(message.id): \(error.localizedDescription)")
        }
    }
    
    /// Analyze formality for all unanalyzed messages in the current conversation
    @MainActor
    func analyzeFormality(for messages: [Message]) async {
        for message in messages {
            await analyzeFormalityIfNeeded(for: message)
        }
    }
    
    // MARK: - Formality Adjustment (Rephrase)
    
    /// Rephrase a message to a specific formality level
    @MainActor
    func rephraseMessageForFormality(
        message: Message,
        targetLevel: FormalityLevel
    ) async -> String? {
        guard let text = message.text, !text.isEmpty else { return nil }
        
        // Use detected language or default to English
        let language = message.detectedLanguage ?? "en"
        
        do {
            let adjustment = try await AIService.shared.adjustFormality(
                text: text,
                currentLevel: formalityAnalyses[message.id]?.level,
                targetLevel: targetLevel,
                language: language
            )
            
            // Cache the adjusted version
            if adjustedVersions[message.id] == nil {
                adjustedVersions[message.id] = [:]
            }
            adjustedVersions[message.id]?[targetLevel] = adjustment.adjustedText
            
            print("✅ Rephrased to \(targetLevel.displayName): \(adjustment.adjustedText.prefix(50))...")
            
            return adjustment.adjustedText
        } catch {
            print("❌ Formality adjustment failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Quick rephrase to formal (for context menu)
    @MainActor
    func rephraseFormal(_ message: Message) async {
        guard let adjusted = await rephraseMessageForFormality(message: message, targetLevel: .formal) else {
            return
        }
        
        // Show result (could be a toast/alert, or update UI state)
        print("Formal version: \(adjusted)")
    }
    
    /// Quick rephrase to casual (for context menu)
    @MainActor
    func rephraseCasual(_ message: Message) async {
        guard let adjusted = await rephraseMessageForFormality(message: message, targetLevel: .casual) else {
            return
        }
        
        // Show result (could be a toast/alert, or update UI state)
        print("Casual version: \(adjusted)")
    }
    
    // MARK: - Batch Analysis
    
    /// Analyze formality for multiple messages at once (called when messages load)
    @MainActor
    func analyzeFormalityForRecentMessages() {
        Task {
            // Analyze only recent messages (last 10) to avoid overwhelming the backend
            let recentMessages = messages.suffix(10)
            
            for message in recentMessages {
                await analyzeFormalityIfNeeded(for: message)
            }
        }
    }
}

