/**
 * AIService - Interface to AI Cloud Functions
 * Handles all communication with Firebase Functions for AI features
 */

import Foundation
@preconcurrency import FirebaseFunctions
import FirebaseAuth

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
    
    // MARK: - Formality Analysis (PR #4)
    
    /**
     * Analyze formality level of message
     */
    func analyzeFormalityAnalysis(
        messageId: String,
        text: String,
        language: String
    ) async throws -> FormalityAnalysis {
        let data: [String: Any] = [
            "messageId": messageId,
            "text": text,
            "language": language
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            let callable = functions.httpsCallable("analyzeMessageFormality")
            callable.call(data) { result, error in
                if let error = error {
                    continuation.resume(throwing: self.mapError(error))
                    return
                }
                
                guard let result = result,
                      let response = result.data as? [String: Any] else {
                    continuation.resume(throwing: AIError.invalidResponse)
                    return
                }
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: response)
                    let analysis = try JSONDecoder().decode(FormalityAnalysis.self, from: jsonData)
                    continuation.resume(returning: analysis)
                } catch {
                    print("Failed to decode formality analysis: \(error)")
                    continuation.resume(throwing: AIError.invalidResponse)
                }
            }
        }
    }
    
    /**
     * Adjust message formality to target level
     */
    func adjustFormality(
        text: String,
        currentLevel: FormalityLevel?,
        targetLevel: FormalityLevel,
        language: String
    ) async throws -> FormalityAdjustment {
        var data: [String: Any] = [
            "text": text,
            "targetLevel": targetLevel.rawValue,
            "language": language
        ]
        
        if let currentLevel = currentLevel {
            data["currentLevel"] = currentLevel.rawValue
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let callable = functions.httpsCallable("adjustMessageFormality")
            callable.call(data) { result, error in
                if let error = error {
                    continuation.resume(throwing: self.mapError(error))
                    return
                }
                
                guard let result = result,
                      let response = result.data as? [String: Any] else {
                    continuation.resume(throwing: AIError.invalidResponse)
                    return
                }
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: response)
                    let adjustment = try JSONDecoder().decode(FormalityAdjustment.self, from: jsonData)
                    continuation.resume(returning: adjustment)
                } catch {
                    print("Failed to decode formality adjustment: \(error)")
                    continuation.resume(throwing: AIError.invalidResponse)
                }
            }
        }
    }
    
    /**
     * Detect slang and idioms in text (PR #5)
     */
    func detectSlangIdioms(text: String, language: String) async throws -> [DetectedPhrase] {
        let data: [String: Any] = [
            "text": text,
            "language": language
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            let callable = functions.httpsCallable("detectSlangIdioms")
            callable.call(data) { result, error in
                if let error = error {
                    continuation.resume(throwing: self.mapError(error))
                    return
                }
                
                guard let result = result,
                      let response = result.data as? [String: Any],
                      let phrasesData = response["phrases"] as? [[String: Any]] else {
                    continuation.resume(throwing: AIError.invalidResponse)
                    return
                }
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: phrasesData)
                    let phrases = try JSONDecoder().decode([DetectedPhrase].self, from: jsonData)
                    continuation.resume(returning: phrases)
                } catch {
                    print("Failed to decode detected phrases: \(error)")
                    continuation.resume(throwing: AIError.invalidResponse)
                }
            }
        }
    }
    
    /**
     * Get detailed explanation of a phrase (PR #5)
     */
    func explainPhrase(
        phrase: String,
        language: String,
        context: String?
    ) async throws -> PhraseExplanation {
        var data: [String: Any] = [
            "phrase": phrase,
            "language": language
        ]
        
        if let context = context {
            data["context"] = context
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let callable = functions.httpsCallable("explainPhrase")
            callable.call(data) { result, error in
                if let error = error {
                    continuation.resume(throwing: self.mapError(error))
                    return
                }
                
                guard let result = result,
                      let response = result.data as? [String: Any] else {
                    continuation.resume(throwing: AIError.invalidResponse)
                    return
                }
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: response)
                    let explanation = try JSONDecoder().decode(PhraseExplanation.self, from: jsonData)
                    continuation.resume(returning: explanation)
                } catch {
                    print("Failed to decode phrase explanation: \(error)")
                    continuation.resume(throwing: AIError.invalidResponse)
                }
            }
        }
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
        var data: [String: Any] = [
            "query": query,
            "limit": limit
        ]
        
        if let conversationId = conversationId {
            data["conversationId"] = conversationId
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let callable = functions.httpsCallable("semanticSearch")
            callable.call(data) { result, error in
                if let error = error {
                    continuation.resume(throwing: self.mapError(error))
                    return
                }
                
                guard let result = result,
                      let response = result.data as? [String: Any],
                      let resultsData = response["results"] as? [[String: Any]] else {
                    continuation.resume(throwing: AIError.invalidResponse)
                    return
                }
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: resultsData)
                    let searchResults = try JSONDecoder().decode([SearchResult].self, from: jsonData)
                    continuation.resume(returning: searchResults)
                } catch {
                    print("Failed to decode search results: \(error)")
                    continuation.resume(throwing: AIError.invalidResponse)
                }
            }
        }
    }
    
    /**
     * Query AI Assistant (PR #8)
     */
    func queryAIAssistant(
        query: String,
        conversationId: String? = nil
    ) async throws -> (response: String, sources: [String]) {
        let callable = functions.httpsCallable("queryAIAssistant")
        
        let data: [String: Any] = [
            "query": query,
            "userId": Auth.auth().currentUser?.uid ?? "",
            "conversationId": conversationId as Any
        ]
        
        do {
            let result = try await callable.call(data)
            
            guard let resultData = result.data as? [String: Any],
                  let response = resultData["response"] as? String else {
                throw AIError.invalidResponse
            }
            
            let sources = resultData["sources"] as? [String] ?? []
            
            print("✅ AI Assistant response received (sources: \(sources.count))")
            return (response, sources)
            
        } catch {
            print("❌ AI Assistant query failed: \(error.localizedDescription)")
            throw mapError(error)
        }
    }
    
    /**
     * Summarize conversation (PR #8)
     */
    func summarizeConversation(
        conversationId: String
    ) async throws -> String {
        let callable = functions.httpsCallable("summarizeConversation")
        
        let data: [String: Any] = [
            "conversationId": conversationId,
            "userId": Auth.auth().currentUser?.uid ?? ""
        ]
        
        do {
            let result = try await callable.call(data)
            
            guard let resultData = result.data as? [String: Any],
                  let summary = resultData["summary"] as? String else {
                throw AIError.invalidResponse
            }
            
            print("✅ Conversation summary generated")
            return summary
            
        } catch {
            print("❌ Conversation summary failed: \(error.localizedDescription)")
            throw mapError(error)
        }
    }
    
    /**
     * Generate smart replies for a message (PR #7)
     */
    func generateSmartReplies(
        conversationId: String,
        incomingMessageId: String
    ) async throws -> [SmartReply] {
        let callable = functions.httpsCallable("generateSmartReplies")
        
        let data: [String: Any] = [
            "conversationId": conversationId,
            "incomingMessageId": incomingMessageId,
            "userId": Auth.auth().currentUser?.uid ?? ""
        ]
        
        do {
            let result = try await callable.call(data)
            
            guard let resultData = result.data as? [String: Any],
                  let repliesArray = resultData["replies"] as? [[String: Any]] else {
                throw AIError.invalidResponse
            }
            
            let replies = try repliesArray.map { replyDict -> SmartReply in
                guard let text = replyDict["text"] as? String else {
                    throw AIError.invalidResponse
                }
                
                return SmartReply(
                    text: text,
                    translation: replyDict["translation"] as? String,
                    formality: replyDict["formality"] as? String
                )
            }
            
            print("✅ Generated \(replies.count) smart replies")
            return replies
            
        } catch {
            print("❌ Smart replies generation failed: \(error.localizedDescription)")
            throw mapError(error)
        }
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
