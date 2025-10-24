/**
 * Language Detection Cloud Function
 * Detects the language of text using OpenAI
 */

import * as functions from 'firebase-functions';
import {
  LanguageDetectionRequest,
  LanguageDetectionResponse,
} from '../helpers/types';
import {
  callOpenAI,
  parseJSONResponse,
} from '../helpers/llm';
import {
  requireAuth,
  validateText,
  handleError,
} from '../helpers/validation';
import {
  generateCacheKey,
  getCached,
  setCached,
} from '../helpers/cache';

/**
 * Detect the language of text
 * Returns ISO 639-1 language code with confidence score
 */
export const detectLanguage = functions.https.onCall(
  async (
    data: LanguageDetectionRequest,
    context: functions.https.CallableContext
  ): Promise<LanguageDetectionResponse> => {
    try {
      // Authenticate user
      requireAuth(context);

      // Validate input
      validateText(data.text, 'text', { minLength: 1, maxLength: 5000 });

      console.log(`Language detection request for text: "${data.text.substring(0, 50)}..."`);

      // Generate cache key from text hash
      const cacheKey = generateCacheKey('lang', hashText(data.text));

      // Check cache first
      const cached = await getCached<LanguageDetectionResponse>(
        'language_detections',
        cacheKey
      );

      if (cached) {
        console.log(`Cache hit for language detection: ${cached.language}`);
        return cached;
      }

      // Not in cache, detect with OpenAI
      const result = await detectWithOpenAI(data.text);

      // Cache the result (TTL: 30 days - language of text doesn't change)
      await setCached(
        'language_detections',
        cacheKey,
        result,
        30 * 24 * 60 * 60 // 30 days
      );

      console.log(`Language detected: ${result.language} (confidence: ${result.confidence})`);

      return result;
    } catch (error: any) {
      return handleError(error, 'Failed to detect language');
    }
  }
);

/**
 * Detect language using OpenAI
 */
async function detectWithOpenAI(text: string): Promise<LanguageDetectionResponse> {
  const systemPrompt = `You are a language detection expert. Analyze the given text and determine its language.

IMPORTANT:
1. Return ONLY the ISO 639-1 language code (2 letters, lowercase)
2. If you detect multiple languages, return the primary/dominant one
3. If uncertain, return your best guess with lower confidence
4. Return a JSON object with this exact format: {"language": "en", "confidence": 0.95}

Common codes: en (English), es (Spanish), fr (French), de (German), it (Italian), pt (Portuguese), 
ja (Japanese), zh (Chinese), ko (Korean), ar (Arabic), ru (Russian), hi (Hindi)`;

  const response = await callOpenAI({
    model: 'gpt-4o-mini',
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: `Detect the language of this text:\n\n"${text}"` },
    ],
    temperature: 0.1, // Very low temperature for consistent detection
    max_tokens: 100,
    response_format: { type: 'json_object' },
  });

  const result = parseJSONResponse<{
    language: string;
    confidence: number;
  }>(response);

  // Validate the response
  if (!result.language || typeof result.language !== 'string') {
    throw new Error('Invalid language detection response from OpenAI');
  }

  // Ensure confidence is between 0 and 1
  const confidence = typeof result.confidence === 'number' 
    ? Math.min(1, Math.max(0, result.confidence))
    : 0.9; // Default high confidence if not provided

  return {
    language: result.language.toLowerCase().trim(),
    confidence,
  };
}

/**
 * Simple hash function for text (for cache keys)
 */
function hashText(text: string): string {
  let hash = 0;
  for (let i = 0; i < text.length; i++) {
    const char = text.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32bit integer
  }
  return Math.abs(hash).toString(36);
}

