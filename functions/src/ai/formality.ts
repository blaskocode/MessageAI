/**
 * Formality Analysis Cloud Function
 * Detects and adjusts formality levels in messages using GPT-4
 */

import * as functions from 'firebase-functions';
import {
  callOpenAI,
} from '../helpers/llm';
import {
  requireAuth,
  validateMessageId,
  validateLanguageCode,
  handleError,
} from '../helpers/validation';
import {
  generateCacheKey,
  getCached,
  setCached,
} from '../helpers/cache';

// Formality levels enum
export enum FormalityLevel {
  VERY_FORMAL = 'very_formal',
  FORMAL = 'formal',
  NEUTRAL = 'neutral',
  CASUAL = 'casual',
  VERY_CASUAL = 'very_casual'
}

// Marker types for formality indicators
export enum MarkerType {
  PRONOUN = 'pronoun',
  VERB_FORM = 'verb_form',
  HONORIFIC = 'honorific',
  VOCABULARY = 'vocabulary',
  GRAMMAR = 'grammar'
}

interface FormalityMarker {
  text: string;
  type: MarkerType;
  position: number;
  explanation: string;
}

interface FormalityAnalysis {
  level: FormalityLevel;
  confidence: number;
  markers: FormalityMarker[];
  explanation: string;
  suggestedLevel?: FormalityLevel;
}

interface FormalityAnalysisRequest {
  messageId: string;
  text: string;
  language: string;
}

interface FormalityAdjustmentRequest {
  text: string;
  currentLevel?: FormalityLevel;
  targetLevel: FormalityLevel;
  language: string;
}

interface FormalityAdjustment {
  originalText: string;
  adjustedText: string;
  originalLevel: FormalityLevel;
  targetLevel: FormalityLevel;
  language: string;
  changesExplanation: string;
}

/**
 * Build prompt for formality analysis
 */
function buildFormalityAnalysisPrompt(text: string, language: string): string {
  return `You are a linguistic expert specializing in formality analysis across languages.

Analyze the formality level of the following ${language} text and provide a detailed assessment.

Text to analyze:
"${text}"

Formality Levels:
- very_formal: Business, officials, strangers (Sie, vous, usted, keigo)
- formal: Professional colleagues, acquaintances
- neutral: Standard communication
- casual: Friends, peers (du, tu, tú)
- very_casual: Close friends, family (slang, abbreviations)

Provide your analysis in the following JSON format:
{
  "level": "formal|casual|neutral|very_formal|very_casual",
  "confidence": 0.95,
  "markers": [
    {
      "text": "specific word or phrase",
      "type": "pronoun|verb_form|honorific|vocabulary|grammar",
      "position": 0,
      "explanation": "why this indicates formality"
    }
  ],
  "explanation": "2-3 sentence explanation of the formality level",
  "suggestedLevel": "formal|casual|neutral" (optional, only if current level seems inappropriate)
}

Language-specific considerations:
- Spanish: tú vs usted, verb conjugations
- French: tu vs vous, conditional forms
- German: du vs Sie, word order
- Japanese: keigo levels (teineigo, sonkeigo, kenjougo)
- Korean: honorific markers, verb endings
- English: vocabulary choice, contractions, sentence structure

Return ONLY the JSON object, no additional text.`;
}

/**
 * Build prompt for formality adjustment
 */
function buildFormalityAdjustmentPrompt(
  text: string,
  currentLevel: FormalityLevel,
  targetLevel: FormalityLevel,
  language: string
): string {
  return `You are a linguistic expert specializing in formality adjustment across languages.

Rewrite the following ${language} text to match the target formality level while preserving meaning and emotion.

Original text:
"${text}"

Current formality: ${currentLevel}
Target formality: ${targetLevel}

Guidelines:
- Preserve the core meaning and intent
- Maintain the emotional tone (happy, sad, excited, etc.)
- Adjust pronouns, verb forms, and vocabulary appropriately
- Keep cultural context appropriate for the language
- Make the adjustment feel natural, not robotic

Language-specific adjustments:
- Spanish: tú ↔ usted, informal ↔ formal verb forms
- French: tu ↔ vous, conditional tense for politeness
- German: du ↔ Sie, word order for emphasis
- Japanese: plain ↔ keigo forms
- Korean: 반말 ↔ 존댓말
- English: contractions, vocabulary, sentence complexity

Provide your response in the following JSON format:
{
  "adjustedText": "the rewritten text",
  "changesExplanation": "brief explanation of key changes made"
}

Return ONLY the JSON object, no additional text.`;
}

// Note: Access verification is optional for formality analysis
// Messages are analyzed without requiring conversation context

/**
 * Analyze message formality
 * Cloud Function: analyzeMessageFormality
 */
export const analyzeMessageFormality = functions.https.onCall(
  async (
    data: FormalityAnalysisRequest,
    context: functions.https.CallableContext
  ): Promise<FormalityAnalysis> => {
    try {
      // Authenticate user
      const userId = requireAuth(context);

      // Validate input
      validateMessageId(data.messageId);
      validateLanguageCode(data.language, 'language');

      if (!data.text || data.text.trim().length === 0) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Text is required'
        );
      }

      console.log(`Formality analysis request from ${userId}: message ${data.messageId} in ${data.language}`);

      // Check cache first
      const cacheKey = generateCacheKey('formality', data.messageId, data.language);
      const cached = await getCached<FormalityAnalysis>('formality_cache', cacheKey);

      if (cached) {
        console.log(`Returning cached formality analysis for ${data.messageId}`);
        return cached;
      }

      // Build prompt and call GPT-4
      const prompt = buildFormalityAnalysisPrompt(data.text, data.language);
      const response = await callOpenAI({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'user', content: prompt }
        ],
        temperature: 0.3,  // Lower temperature for more consistent analysis
        max_tokens: 500,
        response_format: { type: 'json_object' }
      });

      // Parse JSON response
      let analysis: FormalityAnalysis;
      try {
        analysis = JSON.parse(response);
      } catch (parseError) {
        console.error('Failed to parse formality analysis response:', response);
        throw new functions.https.HttpsError(
          'internal',
          'Failed to parse analysis response'
        );
      }

      // Validate response structure
      if (!analysis.level || !analysis.confidence || !analysis.explanation) {
        throw new functions.https.HttpsError(
          'internal',
          'Invalid analysis response structure'
        );
      }

      // Cache the result
      await setCached('formality_cache', cacheKey, analysis);

      console.log(`Formality analysis complete: ${analysis.level} (confidence: ${analysis.confidence})`);

      return analysis;
    } catch (error) {
      return handleError(error, 'analyzeMessageFormality');
    }
  }
);

/**
 * Adjust message formality
 * Cloud Function: adjustMessageFormality
 */
export const adjustMessageFormality = functions.https.onCall(
  async (
    data: FormalityAdjustmentRequest,
    context: functions.https.CallableContext
  ): Promise<FormalityAdjustment> => {
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

      if (!Object.values(FormalityLevel).includes(data.targetLevel)) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Invalid target formality level'
        );
      }

      console.log(`Formality adjustment request from ${userId}: ${data.currentLevel || 'unknown'} → ${data.targetLevel} in ${data.language}`);

      // Check cache for this specific adjustment
      const cacheKey = generateCacheKey(
        'formality-adjustment',
        data.text,
        `${data.currentLevel || 'auto'}-${data.targetLevel}-${data.language}`
      );
      const cached = await getCached<FormalityAdjustment>('formality_adjustments', cacheKey);

      if (cached) {
        console.log(`Returning cached formality adjustment`);
        return cached;
      }

      // If currentLevel not provided, analyze first
      let currentLevel: FormalityLevel = data.currentLevel || FormalityLevel.NEUTRAL;
      if (!data.currentLevel) {
        const analysisPrompt = buildFormalityAnalysisPrompt(data.text, data.language);
        const analysisResponse = await callOpenAI({
          model: 'gpt-4o-mini',
          messages: [
            { role: 'user', content: analysisPrompt }
          ],
          temperature: 0.3,
          max_tokens: 300,
          response_format: { type: 'json_object' }
        });
        const analysis = JSON.parse(analysisResponse);
        currentLevel = analysis.level;
      }

      // Build prompt and call GPT-4
      const prompt = buildFormalityAdjustmentPrompt(
        data.text,
        currentLevel,
        data.targetLevel,
        data.language
      );
      const response = await callOpenAI({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'user', content: prompt }
        ],
        temperature: 0.5,  // Slightly higher for creative rephrasing
        max_tokens: 800,
        response_format: { type: 'json_object' }
      });

      // Parse JSON response
      let adjustmentData: { adjustedText: string; changesExplanation: string };
      try {
        adjustmentData = JSON.parse(response);
      } catch (parseError) {
        console.error('Failed to parse adjustment response:', response);
        throw new functions.https.HttpsError(
          'internal',
          'Failed to parse adjustment response'
        );
      }

      const adjustment: FormalityAdjustment = {
        originalText: data.text,
        adjustedText: adjustmentData.adjustedText,
        originalLevel: currentLevel,
        targetLevel: data.targetLevel,
        language: data.language,
        changesExplanation: adjustmentData.changesExplanation,
      };

      // Cache the result
      await setCached('formality_adjustments', cacheKey, adjustment);

      console.log(`Formality adjustment complete: ${currentLevel} → ${data.targetLevel}`);

      return adjustment;
    } catch (error) {
      return handleError(error, 'adjustMessageFormality');
    }
  }
);

