/**
 * AI Assistant with RAG
 * Conversational AI that can access user's message history
 * PR #8: AI Assistant Chat
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { callOpenAI } from '../helpers/llm';
import { requireAuth, handleError } from '../helpers/validation';
import { semanticSearch } from './semanticSearch';

interface AIAssistantRequest {
  query: string;
  userId: string;
  conversationId?: string;  // Optional - if querying about specific conversation
}

interface AIAssistantResponse {
  response: string;
  sources?: string[];  // Message IDs used for context
}

/**
 * Build system prompt for AI Assistant
 */
function buildSystemPrompt(): string {
  return `You are a helpful multilingual AI assistant integrated into a messaging app. You help users by:
- Translating and explaining messages
- Answering questions about their conversations
- Finding specific information in their message history
- Providing language learning support
- Explaining cultural context and idioms

You have access to the user's message history through semantic search. When answering:
- Be concise but helpful
- Cite specific messages when relevant
- Respect privacy - only access what's needed
- Offer to translate or explain further if needed
- Be friendly and conversational`;
}

/**
 * Get relevant context for query using RAG
 */
async function getRelevantContext(
  query: string,
  userId: string,
  conversationId?: string,
  context?: functions.https.CallableContext
): Promise<{ context: string; sources: string[] }> {
  try {
    // Use semantic search to find relevant messages
    const searchResults = await semanticSearch.run({
      query: query,
      userId: userId,
      conversationId: conversationId,
      limit: 5,
    }, context!);
    
    if (searchResults.length === 0) {
      return { context: '', sources: [] };
    }
    
    // Format context
    const contextText = searchResults
      .map((result: any, index: number) => `[Message ${index + 1}]: "${result.text}" (similarity: ${result.similarity.toFixed(2)})`)
      .join('\n\n');
    
    const sources = searchResults.map((r: any) => r.messageId);
    
    return { context: contextText, sources };
  } catch (error) {
    console.error('Error getting relevant context:', error);
    return { context: '', sources: [] };
  }
}

/**
 * Query AI Assistant
 * Cloud Function: queryAIAssistant
 */
export const queryAIAssistant = functions.https.onCall(
  async (
    data: AIAssistantRequest,
    context: functions.https.CallableContext
  ): Promise<AIAssistantResponse> => {
    try {
      // Authenticate user
      const userId = requireAuth(context);
      
      if (!data.query || data.query.trim().length === 0) {
        throw new functions.https.HttpsError('invalid-argument', 'Query is required');
      }
      
      console.log(`AI Assistant query from ${userId}: "${data.query}"`);
      
      // Get relevant context using RAG
      const { context: ragContext, sources } = await getRelevantContext(
        data.query,
        userId,
        data.conversationId,
        context
      );
      
      // Build prompt with context
      let userPrompt = data.query;
      if (ragContext) {
        userPrompt = `Context from your messages:\n${ragContext}\n\nUser query: ${data.query}`;
      }
      
      // Query GPT-4
      const response = await callOpenAI({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: buildSystemPrompt() },
          { role: 'user', content: userPrompt }
        ],
        temperature: 0.7,
        max_tokens: 800,
      });
      
      console.log(`AI Assistant response generated (${sources.length} sources used)`);
      
      return {
        response: response,
        sources: sources.length > 0 ? sources : undefined,
      };
    } catch (error) {
      return handleError(error, 'queryAIAssistant');
    }
  }
);

/**
 * Summarize conversation
 * Special AI Assistant capability
 */
export const summarizeConversation = functions.https.onCall(
  async (
    data: { conversationId: string },
    context: functions.https.CallableContext
  ): Promise<{ summary: string }> => {
    try {
      // Authenticate user
      const userId = requireAuth(context);
      
      // Verify access to conversation
      const conversationDoc = await admin.firestore()
        .collection('conversations')
        .doc(data.conversationId)
        .get();
      
      if (!conversationDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Conversation not found');
      }
      
      const conversationData = conversationDoc.data();
      const participantIds = conversationData?.participantIds || [];
      
      if (!participantIds.includes(userId)) {
        throw new functions.https.HttpsError('permission-denied', 'Not a participant');
      }
      
      console.log(`Summarizing conversation ${data.conversationId} for ${userId}`);
      
      // Get recent messages (last 50)
      const messagesSnapshot = await admin.firestore()
        .collection('conversations')
        .doc(data.conversationId)
        .collection('messages')
        .orderBy('timestamp', 'desc')
        .limit(50)
        .get();
      
      if (messagesSnapshot.empty) {
        return { summary: 'This conversation has no messages yet.' };
      }
      
      const messages = messagesSnapshot.docs.reverse().map(doc => {
        const data = doc.data();
        return `${data.senderName || 'User'}: ${data.text}`;
      }).join('\n');
      
      // Generate summary
      const prompt = `Summarize this conversation concisely, highlighting key topics, decisions, and action items:\n\n${messages}`;
      
      const response = await callOpenAI({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: 'You are a conversation summarizer. Provide concise, helpful summaries.' },
          { role: 'user', content: prompt }
        ],
        temperature: 0.5,
        max_tokens: 500,
      });
      
      console.log(`Conversation summary generated`);
      
      return { summary: response };
    } catch (error) {
      return handleError(error, 'summarizeConversation');
    }
  }
);

