/**
 * Semantic Search using Message Embeddings
 * Finds relevant messages using cosine similarity
 * PR #6: RAG Pipeline
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { getOpenAIClient, getEmbeddingModel } from '../helpers/llm';
import { requireAuth, handleError } from '../helpers/validation';

interface SearchRequest {
  query: string;
  userId: string;
  conversationId?: string;
  limit?: number;
}

interface SearchResult {
  id: string;  // messageId renamed to 'id' to match iOS Identifiable protocol
  conversationId: string;
  text: string;
  similarity: number;
  language: string;
}

/**
 * Calculate cosine similarity between two vectors
 */
function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length !== b.length) {
    throw new Error('Vectors must have same length');
  }
  
  let dotProduct = 0;
  let magnitudeA = 0;
  let magnitudeB = 0;
  
  for (let i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    magnitudeA += a[i] * a[i];
    magnitudeB += b[i] * b[i];
  }
  
  magnitudeA = Math.sqrt(magnitudeA);
  magnitudeB = Math.sqrt(magnitudeB);
  
  if (magnitudeA === 0 || magnitudeB === 0) {
    return 0;
  }
  
  return dotProduct / (magnitudeA * magnitudeB);
}

/**
 * Generate embedding for query
 */
async function generateQueryEmbedding(query: string): Promise<number[]> {
  const client = getOpenAIClient();
  const model = getEmbeddingModel();
  
  try {
    const response = await client.embeddings.create({
      model: model,
      input: query,
    });
    
    return response.data[0].embedding;
  } catch (error) {
    console.error('Query embedding generation failed:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to generate query embedding'
    );
  }
}

/**
 * Semantic search across user's messages
 * Returns top K most similar messages
 */
export const semanticSearch = functions.https.onCall(
  async (
    data: SearchRequest,
    context: functions.https.CallableContext
  ): Promise<{ results: SearchResult[] }> => {
    try {
      // Authenticate user
      const userId = requireAuth(context);
      
      // Validate input
      if (!data.query || data.query.trim().length === 0) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Query is required'
        );
      }
      
      const limit = data.limit || 10;
      
      console.log(`Semantic search request from ${userId}: "${data.query}"`);
      
      // Generate embedding for query
      const queryEmbedding = await generateQueryEmbedding(data.query);
      
      // Get user's conversations to filter messages
      const conversationsSnapshot = await admin.firestore()
        .collection('conversations')
        .where('participantIds', 'array-contains', userId)
        .get();
      
      const conversationIds = conversationsSnapshot.docs.map(doc => doc.id);
      
      if (conversationIds.length === 0) {
        return { results: [] };
      }
      
      // Get embeddings (filter by conversation if specified)
      let embeddingsQuery = admin.firestore()
        .collection('message_embeddings');
      
      if (data.conversationId) {
        embeddingsQuery = embeddingsQuery.where('conversationId', '==', data.conversationId) as any;
      } else {
        // Filter by user's conversations
        embeddingsQuery = embeddingsQuery.where('conversationId', 'in', conversationIds.slice(0, 10)) as any;
      }
      
      const embeddingsSnapshot = await embeddingsQuery.get();
      
      // Calculate similarities
      const similarities: SearchResult[] = [];
      
      for (const doc of embeddingsSnapshot.docs) {
        const data = doc.data();
        const similarity = cosineSimilarity(queryEmbedding, data.embedding);
        
        similarities.push({
          id: data.messageId,  // iOS expects 'id' not 'messageId'
          conversationId: data.conversationId,
          text: data.text,
          similarity: similarity,
          language: data.language,
        });
      }
      
      // Sort by similarity (highest first) and return top K
      const results = similarities
        .sort((a, b) => b.similarity - a.similarity)
        .slice(0, limit);
      
      console.log(`Semantic search complete: ${results.length} results found`);
      
      return { results };
    } catch (error) {
      return handleError(error, 'semanticSearch');
    }
  }
);

/**
 * Get conversation context for RAG
 * Returns recent messages and relevant messages from history
 */
export const getConversationContext = functions.https.onCall(
  async (
    data: {
      conversationId: string;
      query: string;
      recentCount?: number;
      relevantCount?: number;
    },
    context: functions.https.CallableContext
  ) => {
    try {
      // Authenticate user
      const userId = requireAuth(context);
      
      const recentCount = data.recentCount || 10;
      const relevantCount = data.relevantCount || 5;
      
      // Get recent messages
      const recentMessages = await admin.firestore()
        .collection('conversations')
        .doc(data.conversationId)
        .collection('messages')
        .orderBy('timestamp', 'desc')
        .limit(recentCount)
        .get();
      
      const recentDocs = recentMessages.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
        source: 'recent'
      }));
      
      // If query provided, also get semantically similar messages
      let relevantDocs: any[] = [];
      if (data.query) {
        const searchResults = await semanticSearch.run({
          query: data.query,
          userId: userId,
          conversationId: data.conversationId,
          limit: relevantCount,
        }, context);
        
        relevantDocs = searchResults.map((result: SearchResult) => ({
          id: result.id,
          text: result.text,
          similarity: result.similarity,
          source: 'relevant'
        }));
      }
      
      return {
        recent: recentDocs,
        relevant: relevantDocs,
      };
    } catch (error) {
      return handleError(error, 'getConversationContext');
    }
  }
);

