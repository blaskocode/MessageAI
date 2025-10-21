import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';

admin.initializeApp();

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

