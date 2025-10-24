/**
 * Smart Replies with Writing Style Learning
 * Generates contextual reply suggestions that match user's style
 * PR #7: Smart Replies
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { callOpenAI } from '../helpers/llm';
import { requireAuth, handleError } from '../helpers/validation';

interface SmartRepliesRequest {
  conversationId: string;
  incomingMessageId: string;
  userId: string;
}

interface SmartReply {
  text: string;
  translation?: string;
  formality?: string;
}

interface WritingStyle {
  formality: string;
  averageLength: number;
  emojiFrequency: number;
  commonPhrases: string[];
  signatureStyle?: string;
}

/**
 * Analyze user's writing style from conversation history
 */
async function analyzeWritingStyle(
  conversationId: string,
  userId: string
): Promise<WritingStyle> {
  // Get user's recent messages in this conversation
  // Note: Fetch without orderBy to avoid needing a composite index
  const messagesSnapshot = await admin.firestore()
    .collection('conversations')
    .doc(conversationId)
    .collection('messages')
    .where('senderId', '==', userId)
    .limit(50)  // Fetch more, then sort and limit in memory
    .get();
  
  if (messagesSnapshot.empty) {
    // Default style
    return {
      formality: 'neutral',
      averageLength: 20,
      emojiFrequency: 0.1,
      commonPhrases: [],
    };
  }
  
  const messages = messagesSnapshot.docs
    .map(doc => doc.data())
    .filter(msg => msg.text && msg.text.trim().length > 0) // Filter out media-only messages
    .sort((a, b) => b.timestamp.seconds - a.timestamp.seconds) // Sort by timestamp desc
    .slice(0, 20); // Take most recent 20
  
  if (messages.length === 0) {
    // No text messages found
    return {
      formality: 'neutral',
      averageLength: 20,
      emojiFrequency: 0.1,
      commonPhrases: [],
    };
  }
  
  // Calculate style metrics
  const totalLength = messages.reduce((sum, msg) => sum + (msg.text?.split(' ').length || 0), 0);
  const averageLength = totalLength / messages.length;
  
  const emojiCount = messages.reduce((sum, msg) => {
    const emojiRegex = /[\p{Emoji}]/gu;
    const matches = msg.text?.match(emojiRegex);
    return sum + (matches ? matches.length : 0);
  }, 0);
  const emojiFrequency = emojiCount / messages.length;
  
  return {
    formality: 'neutral',  // Can be enhanced with formality analysis
    averageLength: Math.round(averageLength),
    emojiFrequency: emojiFrequency,
    commonPhrases: [],  // Can be enhanced with phrase extraction
  };
}

/**
 * Build prompt for smart reply generation
 */
function buildSmartReplyPrompt(
  incomingMessage: string,
  context: string[],
  style: WritingStyle,
  language: string
): string {
  const styleDescription = `
Writing Style:
- Formality: ${style.formality}
- Average message length: ${style.averageLength} words
- Emoji frequency: ${style.emojiFrequency.toFixed(2)} per message
  `.trim();
  
  const contextText = context.length > 0
    ? `\n\nRecent conversation:\n${context.join('\n')}`
    : '';
  
  return `You are generating contextual reply suggestions for a messaging app.

${styleDescription}

Incoming message: "${incomingMessage}"${contextText}

Generate 3-5 reply suggestions in ${language} that:
1. Are contextually relevant
2. Match the user's writing style (length, tone, emoji usage)
3. Range from brief acknowledgments to more detailed responses
4. Are natural and conversational

Return as JSON:
{
  "replies": [
    {
      "text": "reply text",
      "formality": "casual|neutral|formal"
    }
  ]
}

Return ONLY the JSON object, no additional text.`;
}

/**
 * Generate smart reply suggestions
 * Cloud Function: generateSmartReplies
 */
export const generateSmartReplies = functions.https.onCall(
  async (
    data: SmartRepliesRequest,
    context: functions.https.CallableContext
  ): Promise<{ replies: SmartReply[] }> => {
    try {
      // Authenticate user
      const userId = requireAuth(context);
      
      // Verify user is participant
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
      
      console.log(`Smart replies request from ${userId} for conversation ${data.conversationId}`);
      
      // Get incoming message
      const messageDoc = await admin.firestore()
        .collection('conversations')
        .doc(data.conversationId)
        .collection('messages')
        .doc(data.incomingMessageId)
        .get();
      
      if (!messageDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Message not found');
      }
      
      const messageData = messageDoc.data();
      
      if (!messageData) {
        throw new functions.https.HttpsError('not-found', 'Message data not found');
      }
      
      const incomingText = messageData.text || '';
      
      if (!incomingText || incomingText.trim().length === 0) {
        console.log('Cannot generate smart replies for message without text');
        return { replies: [] };
      }
      
      // Get user's fluent language preference (default to English)
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .get();
      
      const userData = userDoc.data();
      const userFluentLanguages = userData?.fluentLanguages || ['en'];
      const language = userFluentLanguages[0] || 'en'; // Use first fluent language
      
      console.log(`Generating smart replies for message: "${incomingText.substring(0, 50)}..." (user fluent language: ${language})`);
      
      // Analyze user's writing style
      console.log('Step 1: Analyzing writing style...');
      const style = await analyzeWritingStyle(data.conversationId, userId);
      console.log(`Writing style analyzed: ${JSON.stringify(style)}`);
      
      // Get recent context (last 5 messages)
      console.log('Step 2: Fetching conversation context...');
      const contextMessages = await admin.firestore()
        .collection('conversations')
        .doc(data.conversationId)
        .collection('messages')
        .orderBy('timestamp', 'desc')
        .limit(5)
        .get();
      
      const messageContext = contextMessages.docs
        .reverse()
        .map(doc => doc.data().text)
        .filter(text => text && text.trim().length > 0); // Filter out media-only messages
      
      console.log(`Context messages retrieved: ${messageContext.length}`);
      
      // Generate replies
      console.log('Step 3: Building prompt...');
      const prompt = buildSmartReplyPrompt(incomingText, messageContext, style, language);
      console.log(`Prompt built, length: ${prompt.length} characters`);
      
      console.log('Step 4: Calling OpenAI...');
      const response = await callOpenAI({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'user', content: prompt }
        ],
        temperature: 0.7,  // Higher for creative variety
        max_tokens: 500,
        response_format: { type: 'json_object' }
      });
      console.log('OpenAI response received');
      
      // Parse response
      let result: { replies: SmartReply[] };
      try {
        result = JSON.parse(response);
      } catch (parseError) {
        console.error('Failed to parse smart replies response:', response);
        throw new functions.https.HttpsError('internal', 'Failed to parse response');
      }
      
      console.log(`✅ Generated ${result.replies.length} smart replies`);
      
      return result;
    } catch (error) {
      console.error('❌ Smart replies error:', error);
      console.error('Error stack:', error instanceof Error ? error.stack : 'No stack');
      return handleError(error, 'generateSmartReplies');
    }
  }
);

