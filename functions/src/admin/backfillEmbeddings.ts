/**
 * Admin Function: Backfill embeddings for existing messages
 * PR #6: Message Embeddings
 * 
 * Call this once after deploying to generate embeddings for all existing messages
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import OpenAI from 'openai';

/**
 * Backfill embeddings for all existing messages
 * Cloud Function: backfillEmbeddings
 * 
 * IMPORTANT: This is an admin function - should be protected in production
 */
export const backfillEmbeddings = functions.https.onCall(
  async (data, context) => {
    // Authenticate user (in production, check for admin role)
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const userId = context.auth.uid;
    console.log(`Backfill embeddings requested by user: ${userId}`);

    const db = admin.firestore();
    let processed = 0;
    let generated = 0;
    let skipped = 0;
    let errors = 0;

    try {
      // Get all conversations for this user
      const conversationsSnapshot = await db
        .collection('conversations')
        .where('participantIds', 'array-contains', userId)
        .get();

      console.log(`Found ${conversationsSnapshot.size} conversations`);

      for (const conversationDoc of conversationsSnapshot.docs) {
        const conversationId = conversationDoc.id;

        // Get all messages in this conversation
        const messagesSnapshot = await db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get();

        for (const messageDoc of messagesSnapshot.docs) {
          const messageId = messageDoc.id;
          const messageData = messageDoc.data();
          processed++;

          // Check if embedding already exists
          const embeddingDoc = await db
            .collection('message_embeddings')
            .doc(messageId)
            .get();

          if (embeddingDoc.exists) {
            skipped++;
            continue;
          }

          // Skip messages without text
          if (!messageData.text || messageData.text.trim().length === 0) {
            skipped++;
            continue;
          }

          try {
            // Generate embedding using OpenAI
            const openai = new OpenAI({
              apiKey: process.env.OPENAI_API_KEY || functions.config().openai?.api_key,
            });

            const response = await openai.embeddings.create({
              model: 'text-embedding-ada-002',
              input: messageData.text,
            });

            const embedding = response.data[0].embedding;

            // Store in Firestore
            await db.collection('message_embeddings').doc(messageId).set({
              messageId: messageId,
              conversationId: conversationId,
              embedding: embedding,
              text: messageData.text,
              language: messageData.detectedLanguage || 'unknown',
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              userId: messageData.senderId,
            });

            generated++;
            console.log(`Generated embedding for message ${messageId}`);

          } catch (error) {
            errors++;
            console.error(`Error generating embedding for ${messageId}:`, error);
          }
        }
      }

      return {
        success: true,
        processed,
        generated,
        skipped,
        errors,
      };

    } catch (error) {
      console.error('Backfill error:', error);
      throw new functions.https.HttpsError(
        'internal',
        'Failed to backfill embeddings',
        error
      );
    }
  }
);

