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
        conversationId: String,
        targetLanguage: String
    ) async throws -> Translation {
        let data: [String: Any] = [
            "messageId": messageId,
            "conversationId": conversationId,
            "targetLanguage": targetLanguage
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            let callable = functions.httpsCallable("translateMessage")
            callable.call(data) { result, error in
                if let error = error {
                    continuation.resume(throwing: self.mapError(error))
                    return
                }
                
                guard let result = result,
                      let response = result.data as? [String: Any],
                      let originalText = response["originalText"] as? String,
                      let translatedText = response["translatedText"] as? String,
                      let originalLanguage = response["originalLanguage"] as? String,
                      let targetLang = response["targetLanguage"] as? String else {
                    continuation.resume(throwing: AIError.invalidResponse)
                    return
                }
                
                let cached = response["cached"] as? Bool ?? false
                
                let translation = Translation(
                    originalText: originalText,
                    translatedText: translatedText,
                    originalLanguage: originalLanguage,
                    targetLanguage: targetLang,
                    cached: cached
                )
                
                continuation.resume(returning: translation)
            }
        }
    }
    
    // MARK: - Language Detection
    
    /**
     * Detect the language of text
     * Returns ISO 639-1 language code and confidence
     */
    func detectLanguage(text: String) async throws -> LanguageDetection {
        let data: [String: Any] = [
            "text": text
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            let callable = functions.httpsCallable("detectLanguage")
            callable.call(data) { result, error in
                if let error = error {
                    continuation.resume(throwing: self.mapError(error))
                    return
                }
                
                guard let result = result,
                      let response = result.data as? [String: Any],
                      let language = response["language"] as? String,
                      let confidence = response["confidence"] as? Double else {
                    continuation.resume(throwing: AIError.invalidResponse)
                    return
                }
                
                let detection = LanguageDetection(
                    language: language,
                    confidence: confidence
                )
                
                continuation.resume(returning: detection)
            }
        }
    }
    
    // MARK: - Cultural Context (PR #3)
    
    /**
     * Analyze cultural context in a message
     * Detects indirect communication, idioms, formality customs, time concepts
     */
    func analyzeCulturalContext(text: String, sourceLanguage: String, targetLanguage: String) async throws -> CulturalContext {
        return try await withCheckedThrowingContinuation { continuation in
            let function = functions.httpsCallable("analyzeCulturalContext")
            function.call([
                "text": text,
                "sourceLanguage": sourceLanguage,
                "targetLanguage": targetLanguage
            ]) { result, error in
                if let error = error {
                    continuation.resume(throwing: self.mapError(error))
                    return
                }
                
                guard let result = result,
                      let data = result.data as? [String: Any] else {
                    print("❌ [AIService] Cultural context: No data in response")
                    continuation.resume(throwing: AIError.invalidResponse)
                    return
                }
                
                // Log the raw response for debugging
                print("📦 [AIService] Cultural context response: \(data)")
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: data)
                    let context = try JSONDecoder().decode(CulturalContext.self, from: jsonData)
                    continuation.resume(returning: context)
                } catch {
                    print("❌ [AIService] Failed to decode cultural context:")
                    print("   Error: \(error)")
                    print("   Data: \(data)")
                    continuation.resume(throwing: AIError.invalidResponse)
                }
            }
        }
    }
    
    // MARK: - Placeholder Methods (To Be Implemented in Future PRs)
    
    /**
     * Analyze formality of text (PR #4)
     */
    func analyzeFormality(text: String, language: String) async throws -> FormalityAnalysis {
        throw AIError.notImplemented
    }
    
    /**
     * Adjust text to target formality level (PR #4)
     */
    func adjustFormality(
        text: String,
        targetLevel: FormalityLevel,
        language: String
    ) async throws -> String {
        throw AIError.notImplemented
    }
    
    /**
     * Detect slang and idioms in text (PR #5)
     */
    func detectSlangIdioms(text: String, language: String) async throws -> [DetectedPhrase] {
        throw AIError.notImplemented
    }
    
    /**
     * Get detailed explanation of a phrase (PR #5)
     */
    func explainPhrase(
        phrase: String,
        language: String,
        context: String?
    ) async throws -> PhraseExplanation {
        throw AIError.notImplemented
    }
    
    /**
     * Generate smart reply suggestions (PR #7)
     */
    func generateSmartReplies(
        conversationId: String,
        context: [Message],
        incomingLanguage: String
    ) async throws -> [SmartReply] {
        throw AIError.notImplemented
    }
    
    /**
     * Semantic search across messages (PR #6)
     */
    func semanticSearch(
        query: String,
        conversationId: String?,
        limit: Int = 10
    ) async throws -> [SearchResult] {
        throw AIError.notImplemented
    }
    
    /**
     * Query AI Assistant (PR #8)
     */
    func queryAIAssistant(
        query: String,
        userId: String
    ) async throws -> String {
        throw AIError.notImplemented
    }
    
    /**
     * Extract structured data from text (PR #9)
     */
    func extractStructuredData(
        text: String,
        language: String
    ) async throws -> StructuredData? {
        throw AIError.notImplemented
    }
    
    // MARK: - Error Handling
    
    private func mapError(_ error: Error) -> AIError {
        let nsError = error as NSError
        
        // Check if it's a Firebase Functions error
        if nsError.domain == "com.firebase.functions" {
            switch nsError.code {
            case FunctionsErrorCode.unauthenticated.rawValue:
                return .unauthenticated
            case FunctionsErrorCode.permissionDenied.rawValue:
                return .permissionDenied
            case FunctionsErrorCode.notFound.rawValue:
                return .notFound
            case FunctionsErrorCode.invalidArgument.rawValue:
                return .invalidArgument
            case FunctionsErrorCode.deadlineExceeded.rawValue:
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
