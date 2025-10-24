/**
 * Message Embeddings for RAG Pipeline
 * Generates and stores OpenAI embeddings for semantic search
 * PR #6: Message Embeddings & RAG
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { getOpenAIClient, getEmbeddingModel } from '../helpers/llm';
import { handleError } from '../helpers/validation';

interface EmbeddingDocument {
  messageId: string;
  conversationId: string;
  text: string;
  language: string;
  embedding: number[];  // 1536-dimensional vector
  generatedAt: FirebaseFirestore.Timestamp;
  userId: string;
}

/**
 * Generate embedding for text
 */
async function generateEmbedding(text: string): Promise<number[]> {
  const client = getOpenAIClient();
  const model = getEmbeddingModel();
  
  try {
    const response = await client.embeddings.create({
      model: model,
      input: text,
    });
    
    return response.data[0].embedding;
  } catch (error) {
    console.error('Embedding generation failed:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to generate embedding'
    );
  }
}

/**
 * Firestore trigger: Generate embedding when message is created
 * Automatically creates embeddings for all new messages
 */
export const onMessageCreated = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    try {
      const messageData = snapshot.data();
      const messageId = context.params.messageId;
      const conversationId = context.params.conversationId;
      
      // Skip if no text
      if (!messageData.text || messageData.text.trim().length === 0) {
        console.log(`Skipping embedding for empty message ${messageId}`);
        return;
      }
      
      console.log(`Generating embedding for message ${messageId}`);
      
      // Generate embedding
      const embedding = await generateEmbedding(messageData.text);
      
      // Store embedding in Firestore
      const embeddingDoc: EmbeddingDocument = {
        messageId: messageId,
        conversationId: conversationId,
        text: messageData.text,
        language: messageData.detectedLanguage || 'unknown',
        embedding: embedding,
        generatedAt: admin.firestore.Timestamp.now(),
        userId: messageData.senderId,
      };
      
      await admin.firestore()
        .collection('message_embeddings')
        .doc(messageId)
        .set(embeddingDoc);
      
      console.log(`Embedding stored for message ${messageId}`);
    } catch (error) {
      console.error('Error generating embedding:', error);
      // Don't throw - we don't want to fail message creation
    }
  });

/**
 * Manually generate embedding for a message
 * Useful for backfilling existing messages
 */
export const generateMessageEmbedding = functions.https.onCall(
  async (
    data: { messageId: string; conversationId: string },
    context: functions.https.CallableContext
  ) => {
    try {
      // Authenticate
      if (!context.auth) {
        throw new functions.https.HttpsError(
          'unauthenticated',
          'Must be authenticated'
        );
      }
      
      const { messageId, conversationId } = data;
      
      // Get message
      const messageDoc = await admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .get();
      
      if (!messageDoc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Message not found'
        );
      }
      
      const messageData = messageDoc.data();
      if (!messageData || !messageData.text) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Message has no text'
        );
      }
      
      // Check if embedding already exists
      const existingEmbedding = await admin.firestore()
        .collection('message_embeddings')
        .doc(messageId)
        .get();
      
      if (existingEmbedding.exists) {
        return { success: true, message: 'Embedding already exists' };
      }
      
      // Generate embedding
      const embedding = await generateEmbedding(messageData.text);
      
      // Store embedding
      const embeddingDoc: EmbeddingDocument = {
        messageId: messageId,
        conversationId: conversationId,
        text: messageData.text,
        language: messageData.detectedLanguage || 'unknown',
        embedding: embedding,
        generatedAt: admin.firestore.Timestamp.now(),
        userId: messageData.senderId,
      };
      
      await admin.firestore()
        .collection('message_embeddings')
        .doc(messageId)
        .set(embeddingDoc);
      
      return { success: true, message: 'Embedding generated' };
    } catch (error) {
      return handleError(error, 'generateMessageEmbedding');
    }
  }
);

