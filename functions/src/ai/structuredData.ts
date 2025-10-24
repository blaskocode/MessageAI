/**
 * Structured Data Extraction
 * Extracts dates, times, locations, and events from messages
 * PR #9: Structured Data & N8N Integration
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { callOpenAI } from '../helpers/llm';
import { requireAuth, handleError } from '../helpers/validation';

interface StructuredDataRequest {
  messageId: string;
  text: string;
  language: string;
  conversationId: string;
}

interface LocationData {
  name: string;
  address?: string;
  coordinates?: {
    lat: number;
    lng: number;
  };
}

interface StructuredData {
  type: 'event' | 'task' | 'location' | null;
  datetime?: string;  // ISO 8601
  location?: LocationData;
  participants?: string[];
  description?: string;
  confidence: number;
}

/**
 * Build prompt for structured data extraction
 */
function buildExtractionPrompt(text: string, language: string): string {
  return `Extract structured information from this ${language} message.

Message: "${text}"

Extract:
- Type: event, task, location, or null
- Date/time (convert to ISO 8601 format, use current year if not specified)
- Location (name, address if mentioned)
- Event/task description
- Confidence score (0-1)

Common patterns to recognize:
- "Let's meet at..." → event with location
- "Tomorrow at 3pm" → event with datetime
- "Remind me to..." → task
- "See you at Starbucks" → event with location
- "¿Vamos al cine esta noche?" → event (cinema, tonight)
- "Nos vemos el martes a las 3pm" → event (Tuesday, 3pm)
- "On se retrouve demain à 18h" → event (tomorrow, 6pm)
- "来週の金曜日に会議" → event (next Friday, meeting)

Return as JSON:
{
  "type": "event" | "task" | "location" | null,
  "datetime": "ISO 8601 string or null",
  "location": {
    "name": "location name",
    "address": "address if mentioned"
  } or null,
  "description": "brief description",
  "confidence": 0.85,
  "participants": []
}

If no structured data found, return: {"type": null, "confidence": 0}

Return ONLY the JSON object, no additional text.`;
}

/**
 * Extract structured data from message
 * Cloud Function: extractStructuredData
 */
export const extractStructuredData = functions.https.onCall(
  async (
    data: StructuredDataRequest,
    context: functions.https.CallableContext
  ): Promise<StructuredData> => {
    try {
      // Authenticate user
      const userId = requireAuth(context);
      
      if (!data.text || data.text.trim().length === 0) {
        throw new functions.https.HttpsError('invalid-argument', 'Text is required');
      }
      
      console.log(`Structured data extraction from ${userId}: "${data.text}"`);
      
      // Build prompt and call GPT-4
      const prompt = buildExtractionPrompt(data.text, data.language);
      const response = await callOpenAI({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'user', content: prompt }
        ],
        temperature: 0.2,  // Low temperature for consistent extraction
        max_tokens: 400,
        response_format: { type: 'json_object' }
      });
      
      // Parse response
      let result: StructuredData;
      try {
        result = JSON.parse(response);
      } catch (parseError) {
        console.error('Failed to parse structured data response:', response);
        throw new functions.https.HttpsError('internal', 'Failed to parse response');
      }
      
      // Only store if confidence is high
      if (result.type && result.confidence >= 0.6) {
        // Store extracted data
        await admin.firestore()
          .collection('extracted_data')
          .add({
            messageId: data.messageId,
            conversationId: data.conversationId,
            type: result.type,
            datetime: result.datetime || null,
            location: result.location || null,
            description: result.description || null,
            confidence: result.confidence,
            language: data.language,
            extractedAt: admin.firestore.Timestamp.now(),
            userId: userId,
            actionTaken: 'none',
          });
        
        console.log(`Structured data extracted and stored: ${result.type} (confidence: ${result.confidence})`);
      } else {
        console.log(`No structured data found (confidence: ${result.confidence})`);
      }
      
      return result;
    } catch (error) {
      return handleError(error, 'extractStructuredData');
    }
  }
);

/**
 * Firestore trigger: Automatically extract structured data from new messages
 * Runs in background without blocking message creation
 */
export const onMessageCreatedExtractData = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    try {
      const messageData = snapshot.data();
      const messageId = context.params.messageId;
      const conversationId = context.params.conversationId;
      
      // Skip if no text
      if (!messageData.text || messageData.text.trim().length === 0) {
        return;
      }
      
      // Skip if message is very short (< 10 chars)
      if (messageData.text.length < 10) {
        return;
      }
      
      console.log(`Auto-extracting structured data from message ${messageId}`);
      
      const language = messageData.detectedLanguage || 'en';
      
      // Build prompt and call GPT-4
      const prompt = buildExtractionPrompt(messageData.text, language);
      const response = await callOpenAI({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'user', content: prompt }
        ],
        temperature: 0.2,
        max_tokens: 400,
        response_format: { type: 'json_object' }
      });
      
      const result: StructuredData = JSON.parse(response);
      
      // Only store if confidence is high enough
      if (result.type && result.confidence >= 0.7) {
        await admin.firestore()
          .collection('extracted_data')
          .add({
            messageId: messageId,
            conversationId: conversationId,
            type: result.type,
            datetime: result.datetime || null,
            location: result.location || null,
            description: result.description || null,
            confidence: result.confidence,
            language: language,
            extractedAt: admin.firestore.Timestamp.now(),
            userId: messageData.senderId,
            actionTaken: 'none',
          });
        
        console.log(`Auto-extracted: ${result.type} (confidence: ${result.confidence})`);
      }
    } catch (error) {
      console.error('Error in auto-extraction:', error);
      // Don't throw - we don't want to fail message creation
    }
  });

