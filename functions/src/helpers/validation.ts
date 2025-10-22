/**
 * Validation Helper - Input validation and authentication
 * Provides utilities for validating requests and checking permissions
 */

import * as functions from 'firebase-functions';

// ============================================================================
// Authentication Validation
// ============================================================================

/**
 * Ensure user is authenticated
 */
export function requireAuth(context: functions.https.CallableContext): string {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be authenticated to call this function'
    );
  }

  return context.auth.uid;
}

/**
 * Ensure user is authenticated and matches userId
 */
export function requireAuthMatch(
  context: functions.https.CallableContext,
  userId: string
): void {
  const authUid = requireAuth(context);
  
  if (authUid !== userId) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Not authorized to perform this action'
    );
  }
}

// ============================================================================
// Input Validation
// ============================================================================

/**
 * Validate text input
 */
export function validateText(
  text: string,
  fieldName: string,
  options: {
    minLength?: number;
    maxLength?: number;
    required?: boolean;
  } = {}
): void {
  const { minLength = 1, maxLength = 10000, required = true } = options;

  if (required && (!text || typeof text !== 'string')) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${fieldName} is required and must be a string`
    );
  }

  if (!text) return; // If not required and empty, skip other checks

  if (text.length < minLength) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${fieldName} must be at least ${minLength} characters`
    );
  }

  if (text.length > maxLength) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${fieldName} must be at most ${maxLength} characters`
    );
  }
}

/**
 * Validate language code (ISO 639-1)
 */
export function validateLanguageCode(code: string, fieldName: string): void {
  if (!code || typeof code !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${fieldName} must be a valid language code`
    );
  }

  // Basic check: 2-3 letter code
  if (!/^[a-z]{2,3}$/i.test(code)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${fieldName} must be a valid ISO 639-1 language code (e.g., 'en', 'es')`
    );
  }
}

/**
 * Validate message ID
 */
export function validateMessageId(messageId: string): void {
  if (!messageId || typeof messageId !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'messageId is required and must be a string'
    );
  }

  if (messageId.length < 10 || messageId.length > 100) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid messageId format'
    );
  }
}

/**
 * Validate conversation ID
 */
export function validateConversationId(conversationId: string): void {
  if (!conversationId || typeof conversationId !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'conversationId is required and must be a string'
    );
  }

  if (conversationId.length < 10 || conversationId.length > 100) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid conversationId format'
    );
  }
}

/**
 * Validate user ID
 */
export function validateUserId(userId: string): void {
  if (!userId || typeof userId !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'userId is required and must be a string'
    );
  }

  if (userId.length < 10 || userId.length > 100) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid userId format'
    );
  }
}

/**
 * Validate formality level
 */
export function validateFormalityLevel(formality: string): void {
  const validLevels = ['very_formal', 'formal', 'neutral', 'casual', 'very_casual'];
  
  if (!validLevels.includes(formality)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `formality must be one of: ${validLevels.join(', ')}`
    );
  }
}

/**
 * Validate number within range
 */
export function validateNumber(
  value: any,
  fieldName: string,
  options: {
    min?: number;
    max?: number;
    required?: boolean;
  } = {}
): void {
  const { min, max, required = true } = options;

  if (required && (value === null || value === undefined)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${fieldName} is required`
    );
  }

  if (value === null || value === undefined) return;

  if (typeof value !== 'number' || isNaN(value)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${fieldName} must be a valid number`
    );
  }

  if (min !== undefined && value < min) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${fieldName} must be at least ${min}`
    );
  }

  if (max !== undefined && value > max) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${fieldName} must be at most ${max}`
    );
  }
}

// ============================================================================
// Error Response Helpers
// ============================================================================

/**
 * Create a standardized error response
 */
export function createErrorResponse(
  code: functions.https.FunctionsErrorCode,
  message: string,
  details?: any
): never {
  throw new functions.https.HttpsError(code, message, details);
}

/**
 * Handle unknown errors and convert to HttpsError
 */
export function handleError(error: any, defaultMessage: string): never {
  console.error('Function error:', error);

  if (error instanceof functions.https.HttpsError) {
    throw error;
  }

  throw new functions.https.HttpsError(
    'internal',
    defaultMessage
  );
}

/**
 * Validate request has required fields
 */
export function validateRequiredFields(
  data: any,
  requiredFields: string[]
): void {
  for (const field of requiredFields) {
    if (data[field] === undefined || data[field] === null) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Missing required field: ${field}`
      );
    }
  }
}

