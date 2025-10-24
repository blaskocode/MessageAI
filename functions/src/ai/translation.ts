/**
 * Translation Cloud Function
 * Translates messages using OpenAI GPT-4 with caching
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import {
  TranslationRequest,
  TranslationResponse,
  TranslationDocument,
} from '../helpers/types';
import {
  callOpenAI,
  buildTranslationPrompt,
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

/**
 * Translate a message to target language
 * Caches translations to avoid duplicate API calls
 */
export const translateMessage = functions.https.onCall(
  async (
    data: TranslationRequest,
    context: functions.https.CallableContext
  ): Promise<TranslationResponse> => {
    try {
      // Authenticate user
      const userId = requireAuth(context);

      // Validate input
      validateMessageId(data.messageId);
      validateMessageId(data.conversationId); // Reuse validation for conversationId
      validateLanguageCode(data.targetLanguage, 'targetLanguage');

      console.log(`Translation request from ${userId}: message ${data.messageId} in conversation ${data.conversationId} to ${data.targetLanguage}`);

      // Check if user has access to this conversation
      await verifyMessageAccess(userId, data.conversationId);

      // Get message from Firestore (now we know the conversation)
      const message = await getMessage(data.messageId, data.conversationId);

      if (!message) {
        throw new functions.https.HttpsError(
          'not-found',
          'Message not found'
        );
      }

      const originalText = message.text;
      let originalLanguage = message.detectedLanguage;

      console.log(`📝 Message text: "${originalText.substring(0, 50)}..."`);
      console.log(`🔍 detectedLanguage from Firestore: "${originalLanguage || 'NULL'}"`);

      // If language not detected yet, detect it now
      if (!originalLanguage) {
        console.log(`⚠️ Language not detected yet for message ${data.messageId}, detecting now...`);
        try {
          originalLanguage = await detectMessageLanguage(originalText);
          console.log(`✅ Inline detection successful: ${originalLanguage}`);
          
          // Update message with detected language for future use
          try {
            await admin.firestore()
              .collection('conversations')
              .doc(data.conversationId)
              .collection('messages')
              .doc(data.messageId)
              .update({
                detectedLanguage: originalLanguage,
              });
            console.log(`💾 Updated Firestore with detected language: ${originalLanguage}`);
          } catch (error) {
            console.error(`❌ Failed to update message with detected language:`, error);
            // Continue anyway - we have the language for this translation
          }
        } catch (detectionError) {
          console.error(`❌ Language detection failed:`, detectionError);
          throw new functions.https.HttpsError(
            'internal',
            'Failed to detect language: ' + (detectionError as Error).message
          );
        }
      } else {
        console.log(`✅ Language already detected: ${originalLanguage}`);
      }

      // Skip translation if already in target language
      if (originalLanguage.toLowerCase() === data.targetLanguage.toLowerCase()) {
        return {
          originalText,
          translatedText: originalText,
          originalLanguage,
          targetLanguage: data.targetLanguage,
          cached: false,
        };
      }

      // Generate cache key
      const cacheKey = generateCacheKey(
        data.messageId,
        data.targetLanguage
      );

      // Check cache first
      const cached = await getCached<TranslationDocument>(
        'translations',
        cacheKey
      );

      if (cached) {
        console.log(`✅ Cache hit for translation: ${cacheKey}`);
        const result = {
          originalText: cached.originalText,
          translatedText: cached.translatedText,
          originalLanguage: cached.originalLanguage,
          targetLanguage: cached.targetLanguage,
          cached: true,
        };
        console.log(`📤 Returning cached result to client`);
        return result;
      }

      // Not in cache, translate with OpenAI
      console.log(`🔄 Translating: "${originalText.substring(0, 50)}..." from ${originalLanguage} to ${data.targetLanguage}`);

      const translatedText = await translateWithOpenAI(
        originalText,
        originalLanguage,
        data.targetLanguage
      );

      console.log(`✅ OpenAI translation received: "${translatedText.substring(0, 50)}..."`);

      // Cache the translation
      const translationDoc: TranslationDocument = {
        messageId: data.messageId,
        conversationId: data.conversationId,
        originalText,
        originalLanguage,
        translatedText,
        targetLanguage: data.targetLanguage,
        translatedAt: admin.firestore.Timestamp.now(),
        translationProvider: 'openai',
      };

      await setCached('translations', cacheKey, translationDoc);
      console.log(`💾 Translation cached successfully`);

      // Update message with translation flag
      await admin.firestore()
        .collection('conversations')
        .doc(data.conversationId)
        .collection('messages')
        .doc(data.messageId)
        .update({
          hasTranslation: true,
        });

      console.log(`✅ Translation complete, preparing response`);

      const result = {
        originalText,
        translatedText,
        originalLanguage,
        targetLanguage: data.targetLanguage,
        cached: false,
      };
      
      console.log(`📤 Returning NEW translation to client (length: ${JSON.stringify(result).length} bytes)`);
      
      return result;
    } catch (error: any) {
      console.error('❌ Translation function error:', {
        error: error.message || error,
        stack: error.stack,
        code: error.code,
        type: typeof error,
      });
      return handleError(error, 'Failed to translate message');
    }
  }
);

/**
 * Get message from Firestore using conversationId for efficient lookup
 */
async function getMessage(
  messageId: string,
  conversationId: string
): Promise<{ text: string; detectedLanguage?: string } | null> {
  try {
    // Direct lookup with known conversationId
    const messageDoc = await admin.firestore()
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .doc(messageId)
      .get();

    if (messageDoc.exists) {
      const data = messageDoc.data();
      return {
        text: data?.text || '',
        detectedLanguage: data?.detectedLanguage,
      };
    }

    return null;
  } catch (error) {
    console.error('Error getting message:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to retrieve message'
    );
  }
}

/**
 * Verify user has access to message's conversation
 */
async function verifyMessageAccess(
  userId: string,
  conversationId: string
): Promise<void> {
  const convDoc = await admin.firestore()
    .collection('conversations')
    .doc(conversationId)
    .get();

  if (!convDoc.exists) {
    throw new functions.https.HttpsError(
      'not-found',
      'Conversation not found'
    );
  }

  const participantIds = convDoc.data()?.participantIds || [];

  if (!participantIds.includes(userId)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Not authorized to access this message'
    );
  }
}

/**
 * Detect the language of a message using OpenAI
 * Returns ISO 639-1 language code (e.g., "en", "es", "fr")
 */
async function detectMessageLanguage(text: string): Promise<string> {
  const systemPrompt = `You are a language detection expert. Detect the language of the following text and respond with ONLY the ISO 639-1 two-letter language code (e.g., "en" for English, "es" for Spanish, "fr" for French, "ja" for Japanese).

If the text contains multiple languages, return the PRIMARY language code.
Return ONLY the two-letter code, nothing else.`;

  try {
    const languageCode = await callOpenAI({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: text },
      ],
      temperature: 0.1, // Very low temperature for consistent detection
      max_tokens: 10,
    });

    // Trim and lowercase the response
    const detectedLanguage = languageCode.trim().toLowerCase();
    console.log(`Detected language for "${text.substring(0, 30)}...": ${detectedLanguage}`);
    
    return detectedLanguage;
  } catch (error) {
    console.error('Language detection failed:', error);
    // Default to 'en' if detection fails
    return 'en';
  }
}

/**
 * Translate text using OpenAI
 */
async function translateWithOpenAI(
  text: string,
  sourceLanguage: string,
  targetLanguage: string
): Promise<string> {
  const systemPrompt = buildTranslationPrompt(sourceLanguage, targetLanguage);

  const translatedText = await callOpenAI({
    model: 'gpt-4o-mini',
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: text },
    ],
    temperature: 0.3, // Lower temperature for consistent translations
    max_tokens: 1000,
  });

  return translatedText.trim();
}

