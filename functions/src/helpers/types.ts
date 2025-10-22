/**
 * TypeScript types and interfaces for MessageAI AI features
 * Shared across all Cloud Functions
 */

// ============================================================================
// Request/Response Types
// ============================================================================

export interface TranslationRequest {
  messageId: string;
  targetLanguage: string;
}

export interface TranslationResponse {
  originalText: string;
  translatedText: string;
  originalLanguage: string;
  targetLanguage: string;
  cached: boolean;
}

export interface LanguageDetectionRequest {
  text: string;
}

export interface LanguageDetectionResponse {
  language: string; // ISO 639-1 code
  confidence: number; // 0-1
}

export interface CulturalContextRequest {
  text: string;
  language: string;
  targetLanguage: string;
}

export interface CulturalContextResponse {
  hasContext: boolean;
  explanation: string | null;
  confidence: number;
}

export interface FormalityAnalysisRequest {
  text: string;
  language: string;
}

export interface FormalityAnalysisResponse {
  formality: FormalityLevel;
  explanation: string;
  markers: string[]; // Specific words/phrases indicating formality
}

export interface FormalityAdjustmentRequest {
  text: string;
  targetFormality: FormalityLevel;
  language: string;
}

export interface FormalityAdjustmentResponse {
  original: string;
  adjusted: string;
  targetFormality: FormalityLevel;
}

export interface SlangDetectionRequest {
  text: string;
  language: string;
}

export interface SlangDetectionResponse {
  detected: DetectedPhrase[];
}

export interface PhraseExplanationRequest {
  phrase: string;
  language: string;
  messageContext: string;
}

export interface PhraseExplanationResponse {
  phrase: string;
  explanation: string;
}

export interface SmartRepliesRequest {
  conversationId: string;
  incomingMessageId: string;
  userId: string;
}

export interface SmartRepliesResponse {
  replies: SmartReply[];
}

export interface SemanticSearchRequest {
  query: string;
  userId: string;
  conversationId?: string;
  limit?: number;
}

export interface SemanticSearchResponse {
  results: SearchResult[];
}

export interface StructuredDataRequest {
  messageId: string;
  text: string;
  language: string;
  conversationId: string;
}

export interface StructuredDataResponse {
  type: DataType | null;
  datetime: string | null;
  location: LocationData | null;
  participants: string[];
  description: string | null;
  confidence: number;
}

// ============================================================================
// Data Models
// ============================================================================

export type FormalityLevel = 
  | 'very_formal' 
  | 'formal' 
  | 'neutral' 
  | 'casual' 
  | 'very_casual';

export interface DetectedPhrase {
  phrase: string;
  type: 'slang' | 'idiom';
  meaning: string;
  origin: string;
  similar: string[];
  examples: string[];
}

export interface SmartReply {
  text: string;
  translation?: string;
  formality?: string;
}

export interface SearchResult {
  messageId: string;
  conversationId: string;
  text: string;
  similarity: number;
  language: string;
}

export type DataType = 'event' | 'task' | 'location';

export interface LocationData {
  name: string;
  address?: string;
  coordinates?: {
    lat: number;
    lng: number;
  };
}

// ============================================================================
// Firestore Document Schemas
// ============================================================================

export interface TranslationDocument {
  messageId: string;
  conversationId: string;
  originalText: string;
  originalLanguage: string;
  translatedText: string;
  targetLanguage: string;
  translatedAt: FirebaseFirestore.Timestamp;
  translationProvider: 'openai' | 'google';
  detectedFormality?: FormalityLevel;
}

export interface MessageEmbeddingDocument {
  conversationId: string;
  text: string;
  language: string;
  embedding: number[]; // 1536-dimensional vector
  generatedAt: FirebaseFirestore.Timestamp;
  userId: string;
}

export interface DetectedPhraseDocument {
  messageId: string;
  phrase: string;
  language: string;
  type: 'slang' | 'idiom' | 'cultural';
  explanation: string;
  examples: string[];
  shownToUser: boolean;
  detectedAt: FirebaseFirestore.Timestamp;
}

export interface SmartReplyUsageDocument {
  userId: string;
  conversationId: string;
  suggestedReply: string;
  actualReply: string;
  wasUsed: boolean;
  wasEdited: boolean;
  language: string;
  formality: string;
  timestamp: FirebaseFirestore.Timestamp;
}

export interface ExtractedDataDocument {
  messageId: string;
  conversationId: string;
  type: DataType;
  data: {
    datetime?: string;
    location?: LocationData;
    participants: string[];
    description?: string;
  };
  confidence: number;
  language: string;
  extractedAt: FirebaseFirestore.Timestamp;
  actionTaken: 'calendar' | 'reminder' | 'none';
}

export interface AIAssistantMemory {
  preferences: {
    languagePreferences: Record<string, string>; // contactId -> language
    writingStyle: Record<string, WritingStyle>; // contactId -> style
  };
  conversationContext: {
    lastDiscussed: Record<string, string>; // conversationId -> topic
  };
  learnedPatterns: string[];
  dismissedHints: string[];
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
}

export interface WritingStyle {
  formality: FormalityLevel;
  averageLength: number; // words
  emojiFrequency: number; // emojis per message
  commonPhrases: string[];
  signatureStyle?: string;
}

// ============================================================================
// OpenAI Types
// ============================================================================

export interface OpenAIMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface OpenAICompletionOptions {
  model: string;
  messages: OpenAIMessage[];
  temperature?: number;
  max_tokens?: number;
  response_format?: { type: 'json_object' };
}

// ============================================================================
// Cache Types
// ============================================================================

export interface CacheOptions {
  ttl?: number; // Time to live in seconds (default: no expiration)
  collection: string;
  documentId: string;
}

export interface CachedData<T> {
  data: T;
  cachedAt: FirebaseFirestore.Timestamp;
  expiresAt?: FirebaseFirestore.Timestamp;
}

