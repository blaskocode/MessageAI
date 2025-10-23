/**
 * Unit Tests for Translation Cloud Function (PR #2)
 * Tests translation functionality with mocked OpenAI responses
 */

import { translateMessage } from '../../ai/translation';
import * as admin from 'firebase-admin';
import testModule from 'firebase-functions-test';
import { OpenAI } from 'openai';

// Initialize Firebase Functions test environment
const testEnv = testModule();

// Mock Firestore
jest.mock('firebase-admin', () => ({
  initializeApp: jest.fn(),
  firestore: jest.fn(() => ({
    collection: jest.fn(() => ({
      doc: jest.fn(() => ({
        get: jest.fn(),
        set: jest.fn(),
      })),
    })),
  })),
}));

// Mock OpenAI
jest.mock('openai');

describe('translateMessage Cloud Function', () => {
  let mockFirestore: any;
  let mockOpenAI: any;

  beforeEach(() => {
    jest.clearAllMocks();
    
    // Setup Firestore mocks
    mockFirestore = {
      collection: jest.fn(() => ({
        doc: jest.fn(() => ({
          get: jest.fn(),
          set: jest.fn(),
        })),
      })),
    };
    
    (admin.firestore as any).mockReturnValue(mockFirestore);
    
    // Setup OpenAI mocks
    mockOpenAI = {
      chat: {
        completions: {
          create: jest.fn(),
        },
      },
    };
    
    (OpenAI as any).mockImplementation(() => mockOpenAI);
  });

  afterAll(() => {
    testEnv.cleanup();
  });

  test('should translate message successfully', async () => {
    const messageId = 'test-message-123';
    const targetLanguage = 'es';
    const originalText = 'Hello, how are you?';
    const translatedText = '¡Hola! ¿Cómo estás?';

    // Mock message document
    const mockMessageDoc = {
      exists: true,
      data: () => ({
        text: originalText,
        senderId: 'user-123',
      }),
    };

    // Mock OpenAI response
    mockOpenAI.chat.completions.create.mockResolvedValue({
      choices: [{
        message: {
          content: JSON.stringify({
            translatedText,
            sourceLanguage: 'en',
            targetLanguage: 'es',
            preservedTone: true,
          }),
        },
      }],
    });

    // Mock Firestore calls
    const mockMessageGet = jest.fn().mockResolvedValue(mockMessageDoc);
    const mockTranslationSet = jest.fn().mockResolvedValue(undefined);
    const mockTranslationGet = jest.fn().mockResolvedValue({ exists: false });

    mockFirestore.collection.mockImplementation((collectionName: string) => {
      if (collectionName === 'messages') {
        return {
          doc: () => ({
            get: mockMessageGet,
          }),
        };
      }
      if (collectionName === 'translations') {
        return {
          doc: () => ({
            get: mockTranslationGet,
            set: mockTranslationSet,
          }),
        };
      }
      return {
        doc: () => ({
          get: jest.fn().mockResolvedValue({ exists: false }),
        }),
      };
    });

    // Call the function
    const wrapped = testEnv.wrap(translateMessage);
    const result = await wrapped({
      data: { messageId, targetLanguage },
      auth: { uid: 'user-123' },
    });

    // Assertions
    expect(result.translatedText).toBe(translatedText);
    expect(result.sourceLanguage).toBe('en');
    expect(result.targetLanguage).toBe('es');
    expect(result.cached).toBe(false);
    expect(mockOpenAI.chat.completions.create).toHaveBeenCalledTimes(1);
  });

  test('should return cached translation if available', async () => {
    const messageId = 'test-message-456';
    const targetLanguage = 'fr';
    const cachedTranslation = {
      translatedText: 'Bonjour, comment allez-vous?',
      sourceLanguage: 'en',
      targetLanguage: 'fr',
      originalText: 'Hello, how are you?',
      generatedAt: new Date(),
    };

    // Mock cached translation exists
    const mockTranslationDoc = {
      exists: true,
      data: () => cachedTranslation,
    };

    const mockTranslationGet = jest.fn().mockResolvedValue(mockTranslationDoc);

    mockFirestore.collection.mockReturnValue({
      doc: () => ({
        get: mockTranslationGet,
      }),
    });

    // Call the function
    const wrapped = testEnv.wrap(translateMessage);
    const result = await wrapped({
      data: { messageId, targetLanguage },
      auth: { uid: 'user-123' },
    });

    // Assertions
    expect(result.translatedText).toBe(cachedTranslation.translatedText);
    expect(result.cached).toBe(true);
    expect(mockOpenAI.chat.completions.create).not.toHaveBeenCalled();
  });

  test('should handle missing message', async () => {
    const messageId = 'nonexistent-message';
    const targetLanguage = 'de';

    // Mock message doesn't exist
    const mockMessageDoc = {
      exists: false,
    };

    const mockMessageGet = jest.fn().mockResolvedValue(mockMessageDoc);

    mockFirestore.collection.mockReturnValue({
      doc: () => ({
        get: mockMessageGet,
      }),
    });

    // Call the function
    const wrapped = testEnv.wrap(translateMessage);
    
    await expect(
      wrapped({
        data: { messageId, targetLanguage },
        auth: { uid: 'user-123' },
      })
    ).rejects.toThrow('Message not found');
  });

  test('should handle OpenAI API error', async () => {
    const messageId = 'test-message-789';
    const targetLanguage = 'it';

    // Mock message exists
    const mockMessageDoc = {
      exists: true,
      data: () => ({
        text: 'Hello',
        senderId: 'user-123',
      }),
    };

    const mockMessageGet = jest.fn().mockResolvedValue(mockMessageDoc);
    const mockTranslationGet = jest.fn().mockResolvedValue({ exists: false });

    mockFirestore.collection.mockImplementation((collectionName: string) => {
      if (collectionName === 'messages') {
        return { doc: () => ({ get: mockMessageGet }) };
      }
      return { doc: () => ({ get: mockTranslationGet }) };
    });

    // Mock OpenAI error
    mockOpenAI.chat.completions.create.mockRejectedValue(
      new Error('OpenAI API rate limit exceeded')
    );

    // Call the function
    const wrapped = testEnv.wrap(translateMessage);
    
    await expect(
      wrapped({
        data: { messageId, targetLanguage },
        auth: { uid: 'user-123' },
      })
    ).rejects.toThrow();
  });

  test('should validate target language', async () => {
    const messageId = 'test-message-101';
    const invalidLanguage = 'invalid';

    // Call the function with invalid language
    const wrapped = testEnv.wrap(translateMessage);
    
    await expect(
      wrapped({
        data: { messageId, targetLanguage: invalidLanguage },
        auth: { uid: 'user-123' },
      })
    ).rejects.toThrow('Invalid language code');
  });

  test('should handle unauthenticated request', async () => {
    const messageId = 'test-message-102';
    const targetLanguage = 'es';

    // Call the function without auth
    const wrapped = testEnv.wrap(translateMessage);
    
    await expect(
      wrapped({
        data: { messageId, targetLanguage },
        auth: null,
      })
    ).rejects.toThrow('Unauthenticated');
  });
});

