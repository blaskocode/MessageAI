/**
 * MessageAI Cloud Functions
 * 
 * Exports:
 * - MVP: Push notification functions
 * - Phase 2: AI-powered features (translation, smart replies, etc.)
 */

import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();

// ============================================================================
// MVP Functions - Push Notifications
// ============================================================================

/**
 * Cloud Function that sends push notifications when a new message is created
 * Triggers on: /conversations/{conversationId}/messages/{messageId}
 */
export const sendMessageNotification = functions.firestore.onDocumentCreated(
  'conversations/{conversationId}/messages/{messageId}',
  async (event) => {
    try {
      const messageData = event.data?.data();
      const conversationId = event.params.conversationId;
      const messageId = event.params.messageId;

      if (!messageData) {
        console.log('No message data found');
        return;
      }

      // Extract message details
      const senderId = messageData.senderId as string;
      const text = messageData.text as string;

      console.log(`New message from ${senderId} in conversation ${conversationId}`);

      // Get conversation to find participants
      const conversationDoc = await admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .get();

      if (!conversationDoc.exists) {
        console.log('Conversation not found');
        return;
      }

      const conversationData = conversationDoc.data();
      if (!conversationData) {
        console.log('No conversation data');
        return;
      }

      const participantIds = conversationData.participantIds as string[];
      const groupName = conversationData.groupName as string | undefined;
      const conversationType = conversationData.type as string;

      // Get sender's display name
      const senderDoc = await admin.firestore()
        .collection('users')
        .doc(senderId)
        .get();

      const senderName = senderDoc.exists 
        ? (senderDoc.data()?.displayName as string) 
        : 'Someone';

      // Get FCM tokens for all participants except sender
      const recipientIds = participantIds.filter(id => id !== senderId);
      
      const tokensPromises = recipientIds.map(async (userId) => {
        const userDoc = await admin.firestore()
          .collection('users')
          .doc(userId)
          .get();
        
        const fcmToken = userDoc.exists ? userDoc.data()?.fcmToken : null;
        return { userId, fcmToken };
      });

      const tokensData = await Promise.all(tokensPromises);
      const validTokens = tokensData
        .filter(data => data.fcmToken)
        .map(data => data.fcmToken as string);

      if (validTokens.length === 0) {
        console.log('No valid FCM tokens found for recipients');
        return;
      }

      // Create notification title based on conversation type
      const notificationTitle = conversationType === 'group' && groupName
        ? `${senderName} in ${groupName}`
        : senderName;

      // Create notification payload
      const payload: admin.messaging.MulticastMessage = {
        tokens: validTokens,
        notification: {
          title: notificationTitle,
          body: text || 'Sent a message',
        },
        data: {
          conversationId: conversationId,
          messageId: messageId,
          senderId: senderId,
          type: 'new_message'
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            }
          }
        },
        android: {
          notification: {
            sound: 'default',
            channelId: 'messages'
          }
        }
      };

      // Send notification
      const response = await admin.messaging().sendEachForMulticast(payload);

      console.log(`Successfully sent ${response.successCount} notifications`);
      if (response.failureCount > 0) {
        console.log(`Failed to send ${response.failureCount} notifications`);
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`Failed to send to token ${validTokens[idx]}:`, resp.error);
          }
        });
      }

    } catch (error) {
      console.error('Error sending notification:', error);
      // Don't throw - we don't want to retry failed notifications
    }
  }
);

// ============================================================================
// Phase 2 AI Functions
// ============================================================================

// Translation & Language Detection (PR #2)
export { translateMessage } from './ai/translation';
export { detectLanguage } from './ai/languageDetection';

// Cultural Context (PR #3)
export { analyzeCulturalContext } from './ai/cultural';

// ============================================================================
// Firestore Triggers
// ============================================================================

// User Profile Updates - Propagate name/photo changes to all conversations
export { onUserProfileUpdated } from './triggers/userProfileUpdated';

// Formality (PR #4)
export { analyzeMessageFormality, adjustMessageFormality } from './ai/formality';

// Slang & Idioms (PR #5)
export { detectSlangIdioms, explainPhrase } from './ai/slang';

// Embeddings & Search (PR #6)
export { onMessageCreated, generateMessageEmbedding } from './ai/embeddings';
export { semanticSearch, getConversationContext } from './ai/semanticSearch';

// Smart Replies (PR #7)
export { generateSmartReplies } from './ai/smartReplies';

// AI Assistant (PR #8)
export { queryAIAssistant, summarizeConversation } from './ai/assistant';

// Structured Data (PR #9)
export { extractStructuredData, onMessageCreatedExtractData } from './ai/structuredData';

// Admin Functions
export { backfillEmbeddings } from './admin/backfillEmbeddings';

