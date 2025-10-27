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
    
    func displayName(in language: String) -> String {
        switch (self, language) {
        case (.veryFormal, "es"): return "Muy formal"
        case (.formal, "es"): return "Formal"
        case (.neutral, "es"): return "Neutral"
        case (.casual, "es"): return "Informal"
        case (.veryCasual, "es"): return "Muy informal"
        
        case (.veryFormal, "fr"): return "Très formel"
        case (.formal, "fr"): return "Formel"
        case (.neutral, "fr"): return "Neutre"
        case (.casual, "fr"): return "Décontracté"
        case (.veryCasual, "fr"): return "Très décontracté"
        
        case (.veryFormal, "de"): return "Sehr förmlich"
        case (.formal, "de"): return "Förmlich"
        case (.neutral, "de"): return "Neutral"
        case (.casual, "de"): return "Locker"
        case (.veryCasual, "de"): return "Sehr locker"
        
        case (.veryFormal, "ja"): return "とても丁寧"
        case (.formal, "ja"): return "丁寧"
        case (.neutral, "ja"): return "普通"
        case (.casual, "ja"): return "カジュアル"
        case (.veryCasual, "ja"): return "とてもカジュアル"
        
        case (.veryFormal, "zh"): return "非常正式"
        case (.formal, "zh"): return "正式"
        case (.neutral, "zh"): return "中性"
        case (.casual, "zh"): return "随意"
        case (.veryCasual, "zh"): return "非常随意"
        
        case (.veryFormal, "pt"): return "Muito formal"
        case (.formal, "pt"): return "Formal"
        case (.neutral, "pt"): return "Neutro"
        case (.casual, "pt"): return "Casual"
        case (.veryCasual, "pt"): return "Muito casual"
        
        case (.veryFormal, "it"): return "Molto formale"
        case (.formal, "it"): return "Formale"
        case (.neutral, "it"): return "Neutro"
        case (.casual, "it"): return "Casuale"
        case (.veryCasual, "it"): return "Molto casuale"
        
        case (.veryFormal, "ru"): return "Очень формально"
        case (.formal, "ru"): return "Формально"
        case (.neutral, "ru"): return "Нейтрально"
        case (.casual, "ru"): return "Неформально"
        case (.veryCasual, "ru"): return "Очень неформально"
        
        default: return displayName // English fallback
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
    
    var icon: String {
        switch self {
        case .veryFormal: return "person.2.badge.gearshape"
        case .formal: return "suit.diamond.fill"
        case .neutral: return "bubble.middle.top"
        case .casual: return "figure.wave"
        case .veryCasual: return "hand.wave.fill"
        }
    }
}

enum MarkerType: String, Codable {
    case pronoun = "pronoun"
    case verbForm = "verb_form"
    case honorific = "honorific"
    case vocabulary = "vocabulary"
    case grammar = "grammar"
    case contraction = "contraction"
}

struct FormalityMarker: Codable, Equatable {
    let text: String
    let type: MarkerType
    let position: Int
    let explanation: String
}

struct FormalityAnalysis: Codable, Equatable {
    let level: FormalityLevel
    let confidence: Double
    let markers: [FormalityMarker]
    let explanation: String
    let suggestedLevel: FormalityLevel?
}

struct FormalityAdjustment: Codable {
    let originalText: String
    let adjustedText: String
    let originalLevel: FormalityLevel
    let targetLevel: FormalityLevel
    let language: String
    let changesExplanation: String
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
    let meaning: String
    let origin: String
    let examples: [String]
    let culturalNotes: String
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

// MARK: - Message Reactions

struct MessageReaction: Codable, Identifiable, Equatable {
    let id = UUID()
    let emoji: String
    let userId: String
    let timestamp: Date
    let count: Int
    
    init(emoji: String, userId: String, timestamp: Date, count: Int) {
        self.emoji = emoji
        self.userId = userId
        self.timestamp = timestamp
        self.count = count
    }
    
    enum CodingKeys: String, CodingKey {
        case emoji, userId, timestamp, count
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        emoji = try container.decode(String.self, forKey: .emoji)
        userId = try container.decode(String.self, forKey: .userId)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        count = try container.decode(Int.self, forKey: .count)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(userId, forKey: .userId)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(count, forKey: .count)
    }
    
    static func == (lhs: MessageReaction, rhs: MessageReaction) -> Bool {
        return lhs.id == rhs.id
    }
}

