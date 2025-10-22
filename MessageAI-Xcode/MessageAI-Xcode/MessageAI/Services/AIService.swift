/**
 * AIService - Interface to AI Cloud Functions
 * Handles all communication with Firebase Functions for AI features
 */

import Foundation
import FirebaseFunctions

@MainActor
class AIService: ObservableObject {
    static let shared = AIService()
    
    private let functions = Functions.functions()
    
    // Track loading states
    @Published var isTranslating = false
    @Published var isDetectingLanguage = false
    
    private init() {}
    
    // MARK: - Translation
    
    /**
     * Translate a message to target language
     * Returns cached translation if available
     */
    func translateMessage(
        messageId: String,
        targetLanguage: String
    ) async throws -> Translation {
        isTranslating = true
        defer { isTranslating = false }
        
        let data: [String: Any] = [
            "messageId": messageId,
            "targetLanguage": targetLanguage
        ]
        
        do {
            let result = try await functions.httpsCallable("translateMessage").call(data)
            
            guard let response = result.data as? [String: Any],
                  let originalText = response["originalText"] as? String,
                  let translatedText = response["translatedText"] as? String,
                  let originalLanguage = response["originalLanguage"] as? String,
                  let targetLang = response["targetLanguage"] as? String else {
                throw AIError.invalidResponse
            }
            
            let cached = response["cached"] as? Bool ?? false
            
            return Translation(
                originalText: originalText,
                translatedText: translatedText,
                originalLanguage: originalLanguage,
                targetLanguage: targetLang,
                cached: cached
            )
        } catch {
            print("❌ Translation error: \(error.localizedDescription)")
            throw mapError(error)
        }
    }
    
    // MARK: - Language Detection
    
    /**
     * Detect the language of text
     * Returns ISO 639-1 language code and confidence
     */
    func detectLanguage(text: String) async throws -> LanguageDetection {
        isDetectingLanguage = true
        defer { isDetectingLanguage = false }
        
        let data: [String: Any] = [
            "text": text
        ]
        
        do {
            let result = try await functions.httpsCallable("detectLanguage").call(data)
            
            guard let response = result.data as? [String: Any],
                  let language = response["language"] as? String,
                  let confidence = response["confidence"] as? Double else {
                throw AIError.invalidResponse
            }
            
            return LanguageDetection(
                language: language,
                confidence: confidence
            )
        } catch {
            print("❌ Language detection error: \(error.localizedDescription)")
            throw mapError(error)
        }
    }
    
    // MARK: - Cultural Context (PR #3)
    
    /**
     * Analyze cultural context of a message
     * Returns explanation if culturally significant
     */
    func analyzeCulturalContext(
        text: String,
        language: String,
        targetLanguage: String
    ) async throws -> CulturalContext? {
        // Will be implemented in PR #3
        throw AIError.notImplemented
    }
    
    // MARK: - Formality (PR #4)
    
    /**
     * Analyze formality level of text
     */
    func analyzeFormality(
        text: String,
        language: String
    ) async throws -> FormalityAnalysis {
        // Will be implemented in PR #4
        throw AIError.notImplemented
    }
    
    /**
     * Adjust text to target formality level
     */
    func adjustFormality(
        text: String,
        targetFormality: FormalityLevel,
        language: String
    ) async throws -> String {
        // Will be implemented in PR #4
        throw AIError.notImplemented
    }
    
    // MARK: - Slang & Idioms (PR #5)
    
    /**
     * Detect slang and idioms in text
     */
    func detectSlangIdioms(
        text: String,
        language: String
    ) async throws -> [DetectedPhrase] {
        // Will be implemented in PR #5
        throw AIError.notImplemented
    }
    
    /**
     * Explain a specific phrase
     */
    func explainPhrase(
        phrase: String,
        language: String,
        context: String
    ) async throws -> PhraseExplanation {
        // Will be implemented in PR #5
        throw AIError.notImplemented
    }
    
    // MARK: - Smart Replies (PR #7)
    
    /**
     * Generate smart reply suggestions
     */
    func generateSmartReplies(
        conversationId: String,
        incomingMessageId: String,
        userId: String
    ) async throws -> [SmartReply] {
        // Will be implemented in PR #7
        throw AIError.notImplemented
    }
    
    // MARK: - Semantic Search (PR #6)
    
    /**
     * Perform semantic search across messages
     */
    func semanticSearch(
        query: String,
        userId: String,
        conversationId: String? = nil,
        limit: Int = 10
    ) async throws -> [SearchResult] {
        // Will be implemented in PR #6
        throw AIError.notImplemented
    }
    
    // MARK: - AI Assistant (PR #8)
    
    /**
     * Query the AI assistant
     */
    func queryAIAssistant(
        query: String,
        userId: String
    ) async throws -> String {
        // Will be implemented in PR #8
        throw AIError.notImplemented
    }
    
    // MARK: - Structured Data (PR #9)
    
    /**
     * Extract structured data from message
     */
    func extractStructuredData(
        messageId: String,
        text: String,
        language: String,
        conversationId: String
    ) async throws -> StructuredData? {
        // Will be implemented in PR #9
        throw AIError.notImplemented
    }
    
    // MARK: - Error Handling
    
    private func mapError(_ error: Error) -> AIError {
        if let functionsError = error as? FunctionsErrorCode {
            switch functionsError {
            case .unauthenticated:
                return .unauthenticated
            case .permissionDenied:
                return .permissionDenied
            case .notFound:
                return .notFound
            case .invalidArgument:
                return .invalidArgument
            case .deadlineExceeded:
                return .timeout
            default:
                return .unknown(error.localizedDescription)
            }
        }
        return .unknown(error.localizedDescription)
    }
}

// MARK: - AI Errors

enum AIError: LocalizedError {
    case invalidResponse
    case unauthenticated
    case permissionDenied
    case notFound
    case invalidArgument
    case timeout
    case notImplemented
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from AI service"
        case .unauthenticated:
            return "Please sign in to use AI features"
        case .permissionDenied:
            return "You don't have permission to access this"
        case .notFound:
            return "Content not found"
        case .invalidArgument:
            return "Invalid request"
        case .timeout:
            return "Request timed out. Please try again"
        case .notImplemented:
            return "This feature is coming soon"
        case .unknown(let message):
            return message
        }
    }
}

