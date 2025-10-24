/**
 * Slang & Idiom Detection Cloud Function
 * Detects and explains slang, idioms, and cultural phrases using GPT-4
 */

import * as functions from 'firebase-functions';
import {
  callOpenAI,
} from '../helpers/llm';
import {
  requireAuth,
  validateLanguageCode,
  handleError,
} from '../helpers/validation';
import {
  generateCacheKey,
  getCached,
  setCached,
} from '../helpers/cache';

interface SlangDetectionRequest {
  text: string;
  language: string;
  userFluentLanguage?: string;
}

interface DetectedPhrase {
  phrase: string;
  type: 'slang' | 'idiom';
  meaning: string;
  origin: string;
  similar: string[];
  examples: string[];
}

interface PhraseExplanationRequest {
  phrase: string;
  language: string;
  context?: string;
  userFluentLanguage?: string;
}

interface PhraseExplanation {
  phrase: string;
  meaning: string;
  origin: string;
  examples: string[];
  culturalNotes: string;
}

/**
 * Build prompt for slang/idiom detection
 */
function buildDetectionPrompt(text: string, language: string, explanationLanguage: string): string {
  return `You are a linguistic expert specializing in slang and idioms across languages.

Analyze the following ${language} text and identify any slang terms or idiomatic expressions.

Text to analyze:
"${text}"

For each slang term or idiom found, provide:
- The exact phrase
- Type (slang or idiom)
- Meaning in simple terms
- Origin if known
- Similar expressions
- Example sentences

IMPORTANT: Provide all meanings, origins, and examples in ${explanationLanguage}. If you don't know ${explanationLanguage}, provide the explanation in English.

Return a JSON array of detected phrases:
{
  "phrases": [
    {
      "phrase": "the actual phrase from the text",
      "type": "slang" or "idiom",
      "meaning": "what it means (in ${explanationLanguage})",
      "origin": "where it comes from (in ${explanationLanguage}) or 'Unknown'",
      "similar": ["similar phrase 1", "similar phrase 2"],
      "examples": ["example sentence 1 (in ${explanationLanguage})", "example sentence 2 (in ${explanationLanguage})"]
    }
  ]
}

If no slang or idioms are found, return: {"phrases": []}

Return ONLY the JSON object, no additional text.`;
}

/**
 * Build prompt for phrase explanation
 */
function buildExplanationPrompt(phrase: string, language: string, explanationLanguage: string, context?: string): string {
  const contextInfo = context ? `\n\nContext where it was used:\n"${context}"` : '';
  
  return `You are a linguistic expert. Explain the following ${language} phrase in detail.

Phrase: "${phrase}"${contextInfo}

Provide a comprehensive explanation including:
- What it means (literal and figurative if applicable)
- Origin and etymology
- Usage examples in different contexts
- Cultural significance
- Regional variations if any

IMPORTANT: Provide all explanations in ${explanationLanguage}. If you don't know ${explanationLanguage}, provide the explanation in English.

Return your explanation as JSON:
{
  "phrase": "${phrase}",
  "meaning": "detailed meaning explanation (in ${explanationLanguage})",
  "origin": "origin and etymology (in ${explanationLanguage})",
  "examples": ["example 1 (in ${explanationLanguage})", "example 2 (in ${explanationLanguage})", "example 3 (in ${explanationLanguage})"],
  "culturalNotes": "cultural context and significance (in ${explanationLanguage})"
}

Return ONLY the JSON object, no additional text.`;
}

/**
 * Detect slang and idioms in text
 * Cloud Function: detectSlangIdioms
 */
export const detectSlangIdioms = functions.https.onCall(
  async (
    data: SlangDetectionRequest,
    context: functions.https.CallableContext
  ): Promise<{ phrases: DetectedPhrase[] }> => {
    try {
      // Authenticate user
      const userId = requireAuth(context);

      // Validate input
      validateLanguageCode(data.language, 'language');

      if (!data.text || data.text.trim().length === 0) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Text is required'
        );
      }

      console.log(`Slang detection request from ${userId} in ${data.language}`);

      // Use user's fluent language for explanations, default to English
      const explanationLanguage = data.userFluentLanguage || 'en';

      // Check cache first
      const cacheKey = generateCacheKey('slang', data.text, data.language);
      const cached = await getCached<{ phrases: DetectedPhrase[] }>('slang_cache', cacheKey);

      if (cached) {
        console.log(`Returning cached slang detection`);
        return cached;
      }

      // Build prompt and call GPT-4
      const prompt = buildDetectionPrompt(data.text, data.language, explanationLanguage);
      const response = await callOpenAI({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'user', content: prompt }
        ],
        temperature: 0.3,
        max_tokens: 1000,
        response_format: { type: 'json_object' }
      });

      // Parse JSON response
      let result: { phrases: DetectedPhrase[] };
      try {
        result = JSON.parse(response);
      } catch (parseError) {
        console.error('Failed to parse slang detection response:', response);
        throw new functions.https.HttpsError(
          'internal',
          'Failed to parse detection response'
        );
      }

      // Cache the result
      await setCached('slang_cache', cacheKey, result);

      console.log(`Slang detection complete: ${result.phrases.length} phrases found`);

      return result;
    } catch (error) {
      return handleError(error, 'detectSlangIdioms');
    }
  }
);

/**
 * Get detailed explanation of a specific phrase
 * Cloud Function: explainPhrase
 */
export const explainPhrase = functions.https.onCall(
  async (
    data: PhraseExplanationRequest,
    context: functions.https.CallableContext
  ): Promise<PhraseExplanation> => {
    try {
      // Authenticate user
      const userId = requireAuth(context);

      // Validate input
      validateLanguageCode(data.language, 'language');

      if (!data.phrase || data.phrase.trim().length === 0) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Phrase is required'
        );
      }

      console.log(`Phrase explanation request from ${userId}: "${data.phrase}" in ${data.language}`);

      // Use user's fluent language for explanations, default to English
      const explanationLanguage = data.userFluentLanguage || 'en';

      // Check cache first
      const cacheKey = generateCacheKey('phrase-explanation', data.phrase, data.language, data.context || 'none');
      const cached = await getCached<PhraseExplanation>('phrase_explanations', cacheKey);

      if (cached) {
        console.log(`Returning cached phrase explanation`);
        return cached;
      }

      // Build prompt and call GPT-4
      const prompt = buildExplanationPrompt(data.phrase, data.language, explanationLanguage, data.context);
      const response = await callOpenAI({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'user', content: prompt }
        ],
        temperature: 0.4,
        max_tokens: 800,
        response_format: { type: 'json_object' }
      });

      // Parse JSON response
      let explanation: PhraseExplanation;
      try {
        explanation = JSON.parse(response);
      } catch (parseError) {
        console.error('Failed to parse phrase explanation response:', response);
        throw new functions.https.HttpsError(
          'internal',
          'Failed to parse explanation response'
        );
      }

      // Cache the result
      await setCached('phrase_explanations', cacheKey, explanation);

      console.log(`Phrase explanation complete: "${explanation.phrase}"`);

      return explanation;
    } catch (error) {
      return handleError(error, 'explainPhrase');
    }
  }
);

