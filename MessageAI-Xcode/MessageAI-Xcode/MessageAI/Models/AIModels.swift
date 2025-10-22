/**
 * AI Models - Data structures for AI features
 * Includes models for translation, language detection, and other AI capabilities
 */

import Foundation

// MARK: - Translation

struct Translation: Codable, Identifiable {
    let id = UUID()
    let originalText: String
    let translatedText: String
    let originalLanguage: String
    let targetLanguage: String
    let cached: Bool
    
    enum CodingKeys: String, CodingKey {
        case originalText, translatedText, originalLanguage, targetLanguage, cached
    }
}

// MARK: - Language Detection

struct LanguageDetection: Codable {
    let language: String  // ISO 639-1 code
    let confidence: Double  // 0-1
}

// MARK: - Cultural Context (PR #3)

struct CulturalContext: Codable {
    let hasContext: Bool
    let explanation: String?
    let confidence: Double
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
    /// User's fluent languages (ISO 639-1 codes)
    var fluentLanguages: [String] {
        // Will be stored in Firestore user document
        // Default to empty array for now, will be implemented in PR #2
        return []
    }
    
    /// User's primary language
    var primaryLanguage: String {
        // Default to English, will be configurable
        return "en"
    }
    
    /// Auto-translate enabled flag
    var autoTranslateEnabled: Bool {
        // Will be implemented in PR #3
        return false
    }
    
    /// Cultural hints enabled flag
    var culturalHintsEnabled: Bool {
        // Will be implemented in PR #3
        return true
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

