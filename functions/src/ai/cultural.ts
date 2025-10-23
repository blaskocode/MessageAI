/**
 * Cultural Context Analysis Cloud Function (PR #3)
 * Detects culturally significant phrases and provides explanations
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { callOpenAI } from '../helpers/llm';
import { validateText, requireAuth } from '../helpers/validation';

// Initialize Firestore
const db = admin.firestore();

interface CulturalContextResult {
  hasContext: boolean;
  explanation?: string;
  category?: 'indirect_communication' | 'idiom' | 'formality' | 'time_concept' | 'other';
  confidence: number;
  sourceLanguage: string;
  targetLanguage: string;
}

/**
 * Analyze cultural context in a message
 * Detects indirect communication, idioms, formality customs, time concepts
 */
export const analyzeCulturalContext = functions.https.onCall(
  async (data, context): Promise<CulturalContextResult> => {
    try {
      // Validate authentication
      const userId = requireAuth(context);

      // Validate input
      const { text, sourceLanguage, targetLanguage } = data;
      
      if (!text || typeof text !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', 'Text is required');
      }
      
      validateText(text, 'text', { maxLength: 10000 });
      
      if (!sourceLanguage || !targetLanguage) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Source and target languages are required'
        );
      }

      // Check if analysis already exists in cache
      const cacheKey = generateCacheKey(text, sourceLanguage, targetLanguage);
      const cachedResult = await getCachedAnalysis(cacheKey);
      
      if (cachedResult) {
        console.log(`✅ Cultural context cache hit: ${cacheKey}`);
        return cachedResult;
      }

      console.log(`🔍 Analyzing cultural context: ${sourceLanguage} → ${targetLanguage}`);
      console.log(`📝 Text to analyze: "${text}"`);

      // Construct prompt for cultural analysis
      const systemPrompt = 'You are a cultural linguistics expert who helps people understand cross-cultural communication nuances. Respond ONLY with valid JSON.';
      
      const userPrompt = `Analyze the following text for cultural context that might be missed in translation.
      
Source Language: ${sourceLanguage}
Target Language: ${targetLanguage}
Text: "${text}"

Identify:
1. Indirect communication patterns (e.g., Japanese "maybe" often means "no")
2. Cultural idioms or expressions
3. Formality customs specific to the culture
4. Different concepts of time or urgency
5. Other culturally significant elements

If there IS significant cultural context worth explaining, respond with:
{
  "hasContext": true,
  "explanation": "A concise 2-3 sentence explanation of the cultural nuance",
  "category": "indirect_communication",
  "confidence": 0.95
}

If there is NO significant cultural context, respond with:
{
  "hasContext": false,
  "confidence": 1.0
}

Be selective - only flag truly significant cultural differences that affect meaning or interpretation.`;

      // Call OpenAI using helper (with retry logic and better error handling)
      const resultText = await callOpenAI({
        model: 'gpt-4-turbo-preview',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
        temperature: 0.3,
        max_tokens: 500,
        response_format: { type: 'json_object' },
      });

      console.log(`✅ OpenAI response received: ${resultText.substring(0, 200)}...`);

      let analysis;
      try {
        analysis = JSON.parse(resultText);
      } catch (parseError) {
        console.error('❌ Failed to parse OpenAI response as JSON:', resultText);
        throw new functions.https.HttpsError(
          'internal',
          'OpenAI returned invalid JSON'
        );
      }

      // Validate required fields
      if (typeof analysis.hasContext !== 'boolean') {
        console.error('❌ Invalid OpenAI response - missing or invalid hasContext:', analysis);
        // Default to no context if response is malformed
        analysis.hasContext = false;
        analysis.confidence = 0.0;
      }

      // Validate category is one of the allowed values
      const validCategories = ['indirect_communication', 'idiom', 'formality', 'time_concept', 'other'];
      if (analysis.category && !validCategories.includes(analysis.category)) {
        console.warn(`⚠️ Invalid category received: ${analysis.category}, defaulting to 'other'`);
        analysis.category = 'other';
      }

      const result: CulturalContextResult = {
        hasContext: analysis.hasContext || false,
        explanation: analysis.explanation || undefined,
        category: analysis.category || undefined,
        confidence: typeof analysis.confidence === 'number' ? analysis.confidence : 0.0,
        sourceLanguage,
        targetLanguage,
      };

      // Cache the result if confidence is high
      if (result.confidence > 0.8) {
        await cacheAnalysis(cacheKey, result, userId);
      }

      console.log(`✅ Cultural context analyzed: hasContext=${result.hasContext}`);
      return result;

    } catch (error) {
      console.error('❌ Cultural context analysis failed:', error);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError(
        'internal',
        'Failed to analyze cultural context',
        error
      );
    }
  }
);

/**
 * Generate cache key for cultural analysis
 */
function generateCacheKey(text: string, sourceLanguage: string, targetLanguage: string): string {
  const crypto = require('crypto');
  const hash = crypto
    .createHash('sha256')
    .update(`${text}-${sourceLanguage}-${targetLanguage}`)
    .digest('hex')
    .substring(0, 16);
  return `cultural_${sourceLanguage}_${targetLanguage}_${hash}`;
}

/**
 * Get cached cultural analysis
 */
async function getCachedAnalysis(cacheKey: string): Promise<CulturalContextResult | null> {
  try {
    const doc = await db.collection('cultural_context_cache').doc(cacheKey).get();
    
    if (doc.exists) {
      const data = doc.data();
      if (data) {
        // Check if cache is still valid (30 days)
        const cacheAge = Date.now() - data.cachedAt.toMillis();
        const maxAge = 30 * 24 * 60 * 60 * 1000; // 30 days
        
        if (cacheAge < maxAge) {
          return {
            hasContext: data.hasContext,
            explanation: data.explanation,
            category: data.category,
            confidence: data.confidence,
            sourceLanguage: data.sourceLanguage,
            targetLanguage: data.targetLanguage,
          };
        }
      }
    }
    
    return null;
  } catch (error) {
    console.error('❌ Failed to retrieve cached analysis:', error);
    return null;
  }
}

/**
 * Cache cultural analysis result
 */
async function cacheAnalysis(
  cacheKey: string,
  result: CulturalContextResult,
  userId: string
): Promise<void> {
  try {
    await db.collection('cultural_context_cache').doc(cacheKey).set({
      ...result,
      cachedAt: admin.firestore.FieldValue.serverTimestamp(),
      cachedBy: userId,
    });
    
    console.log(`✅ Cached cultural analysis: ${cacheKey}`);
  } catch (error) {
    console.error('❌ Failed to cache analysis:', error);
    // Don't throw - caching failure shouldn't break the function
  }
}

