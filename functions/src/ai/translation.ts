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
      validateLanguageCode(data.targetLanguage, 'targetLanguage');

      console.log(`Translation request from ${userId}: message ${data.messageId} to ${data.targetLanguage}`);

      // Get message from Firestore
      const message = await getMessage(data.messageId);

      if (!message) {
        throw new functions.https.HttpsError(
          'not-found',
          'Message not found'
        );
      }

      // Check if user has access to this message
      await verifyMessageAccess(userId, message.conversationId);

      const originalText = message.text;
      const originalLanguage = message.detectedLanguage || 'unknown';

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
        console.log(`Cache hit for translation: ${cacheKey}`);
        return {
          originalText: cached.originalText,
          translatedText: cached.translatedText,
          originalLanguage: cached.originalLanguage,
          targetLanguage: cached.targetLanguage,
          cached: true,
        };
      }

      // Not in cache, translate with OpenAI
      console.log(`Translating: "${originalText.substring(0, 50)}..." from ${originalLanguage} to ${data.targetLanguage}`);

      const translatedText = await translateWithOpenAI(
        originalText,
        originalLanguage,
        data.targetLanguage
      );

      // Cache the translation
      const translationDoc: TranslationDocument = {
        messageId: data.messageId,
        conversationId: message.conversationId,
        originalText,
        originalLanguage,
        translatedText,
        targetLanguage: data.targetLanguage,
        translatedAt: admin.firestore.Timestamp.now(),
        translationProvider: 'openai',
      };

      await setCached('translations', cacheKey, translationDoc);

      // Update message with translation flag
      await admin.firestore()
        .collection('messages')
        .doc(data.messageId)
        .update({
          hasTranslation: true,
        });

      console.log(`Translation complete and cached: ${cacheKey}`);

      return {
        originalText,
        translatedText,
        originalLanguage,
        targetLanguage: data.targetLanguage,
        cached: false,
      };
    } catch (error: any) {
      return handleError(error, 'Failed to translate message');
    }
  }
);

/**
 * Get message from Firestore
 */
async function getMessage(
  messageId: string
): Promise<{ text: string; conversationId: string; detectedLanguage?: string } | null> {
  try {
    // Try direct message lookup first
    const messageDoc = await admin.firestore()
      .collection('messages')
      .doc(messageId)
      .get();

    if (messageDoc.exists) {
      const data = messageDoc.data();
      return {
        text: data?.text || '',
        conversationId: data?.conversationId || '',
        detectedLanguage: data?.detectedLanguage,
      };
    }

    // If not found, search in conversations subcollections
    const conversationsSnapshot = await admin.firestore()
      .collection('conversations')
      .get();

    for (const convDoc of conversationsSnapshot.docs) {
      const msgDoc = await convDoc.ref
        .collection('messages')
        .doc(messageId)
        .get();

      if (msgDoc.exists) {
        const data = msgDoc.data();
        return {
          text: data?.text || '',
          conversationId: convDoc.id,
          detectedLanguage: data?.detectedLanguage,
        };
      }
    }

    return null;
  } catch (error) {
    console.error('Error getting message:', error);
    return null;
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
 * Translate text using OpenAI
 */
async function translateWithOpenAI(
  text: string,
  sourceLanguage: string,
  targetLanguage: string
): Promise<string> {
  const systemPrompt = buildTranslationPrompt(sourceLanguage, targetLanguage);

  const translatedText = await callOpenAI({
    model: 'gpt-4-turbo-preview',
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: text },
    ],
    temperature: 0.3, // Lower temperature for consistent translations
    max_tokens: 1000,
  });

  return translatedText.trim();
}

