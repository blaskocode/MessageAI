/**
 * Cloud Function Trigger: Update all conversations when user profile changes
 * 
 * When a user updates their displayName or profilePictureURL, this function
 * automatically propagates those changes to all conversations they participate in.
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

export const onUserProfileUpdated = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const userId = context.params.userId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    console.log(`🔵 [Trigger] User ${userId} document updated`);
    console.log(`📋 [Before Fields] ${JSON.stringify(Object.keys(beforeData))}`);
    console.log(`📋 [After Fields] ${JSON.stringify(Object.keys(afterData))}`);
    console.log(`🔍 [Before] displayName: "${beforeData.displayName}", profilePictureURL: "${beforeData.profilePictureURL}"`);
    console.log(`🔍 [After] displayName: "${afterData.displayName}", profilePictureURL: "${afterData.profilePictureURL}"`);

    // Check if relevant fields changed
    const nameChanged = beforeData.displayName !== afterData.displayName;
    const photoChanged = beforeData.profilePictureURL !== afterData.profilePictureURL;
    const colorChanged = beforeData.profileColorHex !== afterData.profileColorHex;
    const initialsChanged = beforeData.initials !== afterData.initials;

    console.log(`📊 [Changes] name: ${nameChanged}, photo: ${photoChanged}, color: ${colorChanged}, initials: ${initialsChanged}`);

    if (!nameChanged && !photoChanged && !colorChanged && !initialsChanged) {
      console.log(`⚠️ [Skip] No relevant profile changes for user ${userId}`);
      return null;
    }

    console.log(`✅ [Start] Propagating changes for user ${userId}`);

    // Find all conversations where this user is a participant
    console.log(`🔍 [Query] Searching for conversations with participantIds containing ${userId}`);
    const conversationsSnapshot = await db.collection('conversations')
      .where('participantIds', 'array-contains', userId)
      .get();

    if (conversationsSnapshot.empty) {
      console.log(`⚠️ [Empty] No conversations found for user ${userId}`);
      return null;
    }

    console.log(`📦 [Found] ${conversationsSnapshot.docs.length} conversations to update`);

    // Batch update all conversations
    const batch = db.batch();
    let updateCount = 0;

    for (const doc of conversationsSnapshot.docs) {
      const conversationRef = doc.ref;
      const conversationId = doc.id;

      console.log(`🔄 [Processing] Conversation ${conversationId}`);

      // Update the participant details for this user
      const updatedDetails: any = {};

      if (nameChanged) {
        updatedDetails[`participantDetails.${userId}.name`] = afterData.displayName;
        console.log(`  ✏️ [Update] name → "${afterData.displayName}"`);
      }

      if (photoChanged) {
        updatedDetails[`participantDetails.${userId}.photoURL`] = afterData.profilePictureURL || null;
        console.log(`  📸 [Update] photoURL → "${afterData.profilePictureURL}"`);
      }

      // Add color and initials if they changed (for consistency)
      if (colorChanged || initialsChanged || nameChanged) {
        updatedDetails[`participantDetails.${userId}.profileColorHex`] = afterData.profileColorHex;
        updatedDetails[`participantDetails.${userId}.initials`] = afterData.initials;
        console.log(`  🎨 [Update] color → "${afterData.profileColorHex}", initials → "${afterData.initials}"`);
      }

      console.log(`  📝 [Batch] Adding update for conversation ${conversationId}`);
      batch.update(conversationRef, updatedDetails);
      updateCount++;

      // Firestore batch limit is 500 operations
      if (updateCount >= 500) {
        console.log(`💾 [Commit] Committing batch of ${updateCount} updates...`);
        await batch.commit();
        console.log(`✅ [Committed] Batch of ${updateCount} updates`);
        updateCount = 0;
      }
    }

    // Commit remaining updates
    if (updateCount > 0) {
      console.log(`💾 [Commit] Committing final batch of ${updateCount} updates...`);
      await batch.commit();
      console.log(`✅ [Committed] Final batch of ${updateCount} updates`);
    }

    console.log(`🎉 [Complete] Successfully updated ${conversationsSnapshot.docs.length} conversations for user ${userId}`);
    return null;
  });

