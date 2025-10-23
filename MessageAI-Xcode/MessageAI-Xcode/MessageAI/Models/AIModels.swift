/**
 * AI Models - Data structures for AI features
 * Includes models for translation, language detection, and other AI capabilities
 */

import Foundation

// MARK: - Translation

struct Translation: Codable, Identifiable, Equatable {
    let id = UUID()
    let originalText: String
    let translatedText: String
    let originalLanguage: String
    let targetLanguage: String
    let cached: Bool
    
    enum CodingKeys: String, CodingKey {
        case originalText, translatedText, originalLanguage, targetLanguage, cached
    }
    
    // Equatable conformance (auto-synthesized by Swift)
    static func == (lhs: Translation, rhs: Translation) -> Bool {
        return lhs.originalText == rhs.originalText &&
               lhs.translatedText == rhs.translatedText &&
               lhs.originalLanguage == rhs.originalLanguage &&
               lhs.targetLanguage == rhs.targetLanguage &&
               lhs.cached == rhs.cached
    }
}

// MARK: - Language Detection

struct LanguageDetection: Codable {
    let language: String  // ISO 639-1 code
    let confidence: Double  // 0-1
}

// MARK: - Cultural Context (PR #3)

enum CulturalContextCategory: String, Codable {
    case indirectCommunication = "indirect_communication"
    case idiom = "idiom"
    case formality = "formality"
    case timeConcept = "time_concept"
    case other = "other"
}

struct CulturalContext: Codable, Identifiable {
    let id = UUID()
    let hasContext: Bool
    let explanation: String?
    let category: CulturalContextCategory?
    let confidence: Double
    let sourceLanguage: String
    let targetLanguage: String
    
    enum CodingKeys: String, CodingKey {
        case hasContext, explanation, category, confidence, sourceLanguage, targetLanguage
    }
    
    // Custom decoder to handle missing/invalid category gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasContext = try container.decode(Bool.self, forKey: .hasContext)
        explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
        confidence = try container.decode(Double.self, forKey: .confidence)
        sourceLanguage = try container.decode(String.self, forKey: .sourceLanguage)
        targetLanguage = try container.decode(String.self, forKey: .targetLanguage)
        
        // Try to decode category, but default to nil if it fails
        category = try? container.decodeIfPresent(CulturalContextCategory.self, forKey: .category)
    }
}

// MARK: - Formality (PR #4)

enum FormalityLevel: String, Codable {
    case veryFormal = "very_formal"
    case formal = "formal"
    case neutral = "neutral"
    case casual = "casual"
    case veryCasual = "very_casual"
    
    var displayName: String {
        switch self {
        case .veryFormal: return "Very Formal"
        case .formal: return "Formal"
        case .neutral: return "Neutral"
        case .casual: return "Casual"
        case .veryCasual: return "Very Casual"
        }
    }
    
    var emoji: String {
        switch self {
        case .veryFormal: return "🎩"
        case .formal: return "👔"
        case .neutral: return "💬"
        case .casual: return "😊"
        case .veryCasual: return "🤙"
        }
    }
}

struct FormalityAnalysis: Codable {
    let formality: FormalityLevel
    let explanation: String
    let markers: [String]  // Specific words/phrases indicating formality
}

// MARK: - Slang & Idioms (PR #5)

struct DetectedPhrase: Codable, Identifiable {
    let id = UUID()
    let phrase: String
    let type: PhraseType
    let meaning: String
    let origin: String
    let similar: [String]
    let examples: [String]
    
    enum CodingKeys: String, CodingKey {
        case phrase, type, meaning, origin, similar, examples
    }
    
    enum PhraseType: String, Codable {
        case slang
        case idiom
        
        var displayName: String {
            switch self {
            case .slang: return "Slang"
            case .idiom: return "Idiom"
            }
        }
        
        var emoji: String {
            switch self {
            case .slang: return "💬"
            case .idiom: return "📖"
            }
        }
    }
}

struct PhraseExplanation: Codable {
    let phrase: String
    let explanation: String
}

// MARK: - Smart Replies (PR #7)

struct SmartReply: Codable, Identifiable {
    let id = UUID()
    let text: String
    let translation: String?
    let formality: String?
    
    enum CodingKeys: String, CodingKey {
        case text, translation, formality
    }
}

// MARK: - Semantic Search (PR #6)

struct SearchResult: Codable, Identifiable {
    let id: String  // messageId
    let conversationId: String
    let text: String
    let similarity: Double
    let language: String
    
    enum CodingKeys: String, CodingKey {
        case id, conversationId, text, similarity, language
    }
}

// MARK: - Structured Data (PR #9)

struct StructuredData: Codable {
    let type: DataType?
    let datetime: String?
    let location: LocationData?
    let participants: [String]
    let description: String?
    let confidence: Double
    
    enum DataType: String, Codable {
        case event
        case task
        case location
        
        var displayName: String {
            switch self {
            case .event: return "Event"
            case .task: return "Task"
            case .location: return "Location"
            }
        }
        
        var emoji: String {
            switch self {
            case .event: return "📅"
            case .task: return "✓"
            case .location: return "📍"
            }
        }
    }
    
    struct LocationData: Codable {
        let name: String
        let address: String?
        let coordinates: Coordinates?
        
        struct Coordinates: Codable {
            let lat: Double
            let lng: Double
        }
    }
}

// MARK: - User AI Preferences

extension User {
    /// User's primary language (computed from fluentLanguages)
    var primaryLanguage: String {
        return fluentLanguages.first ?? "en"
    }
    
    /// Auto-translate enabled flag (will be implemented in PR #3)
    var autoTranslateEnabled: Bool {
        // TODO: Store this in User model as stored property
        return false
    }
    
    /// Smart replies enabled flag
    var smartRepliesEnabled: Bool {
        // Will be implemented in PR #7
        return true
    }
    
    /// AI assistant enabled flag
    var aiAssistantEnabled: Bool {
        // Will be implemented in PR #8
        return false
    }
}

