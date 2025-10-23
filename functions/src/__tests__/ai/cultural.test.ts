/**
 * Unit Tests for Cultural Context Analysis Cloud Function (PR #3)
 * Tests cultural context detection with mocked OpenAI responses
 */

import { analyzeCulturalContext } from '../../ai/cultural';
import testModule from 'firebase-functions-test';
import * as admin from 'firebase-admin';
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
    FieldValue: {
      serverTimestamp: jest.fn(() => new Date()),
    },
  })),
}));

// Mock OpenAI
jest.mock('openai');

describe('analyzeCulturalContext Cloud Function', () => {
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

  test('should detect indirect communication (Japanese "maybe" = "no")', async () => {
    const text = 'Maybe we can meet tomorrow...';
    const sourceLanguage = 'ja';
    const targetLanguage = 'en';
    
    // Mock OpenAI response
    mockOpenAI.chat.completions.create.mockResolvedValue({
      choices: [{
        message: {
          content: JSON.stringify({
            hasContext: true,
            explanation: 'In Japanese culture, "maybe" or indirect responses often mean "no" to avoid direct confrontation. This is a polite way of declining.',
            category: 'indirect_communication',
            confidence: 0.92,
          }),
        },
      }],
    });

    // Mock cache miss
    mockFirestore.collection.mockReturnValue({
      doc: () => ({
        get: jest.fn().mockResolvedValue({ exists: false }),
        set: jest.fn().mockResolvedValue(undefined),
      }),
    });

    // Call the function
    const wrapped = testEnv.wrap(analyzeCulturalContext);
    const result = await wrapped({
      data: { text, sourceLanguage, targetLanguage },
      auth: { uid: 'user-123' },
    });

    // Assertions
    expect(result.hasContext).toBe(true);
    expect(result.category).toBe('indirect_communication');
    expect(result.confidence).toBeGreaterThan(0.8);
    expect(result.explanation).toContain('indirect');
  });

  test('should detect cultural idiom', async () => {
    const text = 'Break a leg!';
    const sourceLanguage = 'en';
    const targetLanguage = 'es';
    
    // Mock OpenAI response
    mockOpenAI.chat.completions.create.mockResolvedValue({
      choices: [{
        message: {
          content: JSON.stringify({
            hasContext: true,
            explanation: 'This is an English idiom meaning "good luck", commonly used in theater. It may not translate literally to Spanish.',
            category: 'idiom',
            confidence: 0.95,
          }),
        },
      }],
    });

    // Mock cache miss
    mockFirestore.collection.mockReturnValue({
      doc: () => ({
        get: jest.fn().mockResolvedValue({ exists: false }),
        set: jest.fn().mockResolvedValue(undefined),
      }),
    });

    // Call the function
    const wrapped = testEnv.wrap(analyzeCulturalContext);
    const result = await wrapped({
      data: { text, sourceLanguage, targetLanguage },
      auth: { uid: 'user-123' },
    });

    // Assertions
    expect(result.hasContext).toBe(true);
    expect(result.category).toBe('idiom');
    expect(result.confidence).toBeGreaterThan(0.9);
  });

  test('should detect formality custom', async () => {
    const text = 'Could you please send me the report at your earliest convenience?';
    const sourceLanguage = 'en';
    const targetLanguage = 'fr';
    
    // Mock OpenAI response
    mockOpenAI.chat.completions.create.mockResolvedValue({
      choices: [{
        message: {
          content: JSON.stringify({
            hasContext: true,
            explanation: 'This is a very formal request in English. French business communication has different formality conventions, particularly with the use of "vous" vs "tu".',
            category: 'formality',
            confidence: 0.85,
          }),
        },
      }],
    });

    // Mock cache miss
    mockFirestore.collection.mockReturnValue({
      doc: () => ({
        get: jest.fn().mockResolvedValue({ exists: false }),
        set: jest.fn().mockResolvedValue(undefined),
      }),
    });

    // Call the function
    const wrapped = testEnv.wrap(analyzeCulturalContext);
    const result = await wrapped({
      data: { text, sourceLanguage, targetLanguage },
      auth: { uid: 'user-123' },
    });

    // Assertions
    expect(result.hasContext).toBe(true);
    expect(result.category).toBe('formality');
  });

  test('should NOT detect context for simple messages', async () => {
    const text = 'Hello! How are you?';
    const sourceLanguage = 'en';
    const targetLanguage = 'es';
    
    // Mock OpenAI response - no significant context
    mockOpenAI.chat.completions.create.mockResolvedValue({
      choices: [{
        message: {
          content: JSON.stringify({
            hasContext: false,
            confidence: 1.0,
          }),
        },
      }],
    });

    // Mock cache miss
    mockFirestore.collection.mockReturnValue({
      doc: () => ({
        get: jest.fn().mockResolvedValue({ exists: false }),
        set: jest.fn().mockResolvedValue(undefined),
      }),
    });

    // Call the function
    const wrapped = testEnv.wrap(analyzeCulturalContext);
    const result = await wrapped({
      data: { text, sourceLanguage, targetLanguage },
      auth: { uid: 'user-123' },
    });

    // Assertions
    expect(result.hasContext).toBe(false);
  });

  test('should return cached analysis if available', async () => {
    const text = 'Let me think about it...';
    const sourceLanguage = 'ja';
    const targetLanguage = 'en';

    const cachedAnalysis = {
      hasContext: true,
      explanation: 'Cached explanation about indirect communication',
      category: 'indirect_communication',
      confidence: 0.9,
      sourceLanguage: 'ja',
      targetLanguage: 'en',
      cachedAt: {
        toMillis: () => Date.now() - 1000, // 1 second ago
      },
    };

    // Mock cached analysis exists
    mockFirestore.collection.mockReturnValue({
      doc: () => ({
        get: jest.fn().mockResolvedValue({
          exists: true,
          data: () => cachedAnalysis,
        }),
      }),
    });

    // Call the function
    const wrapped = testEnv.wrap(analyzeCulturalContext);
    const result = await wrapped({
      data: { text, sourceLanguage, targetLanguage },
      auth: { uid: 'user-123' },
    });

    // Assertions
    expect(result.hasContext).toBe(true);
    expect(result.explanation).toBe(cachedAnalysis.explanation);
    expect(mockOpenAI.chat.completions.create).not.toHaveBeenCalled();
  });

  test('should handle missing text', async () => {
    const sourceLanguage = 'en';
    const targetLanguage = 'es';

    // Call the function without text
    const wrapped = testEnv.wrap(analyzeCulturalContext);
    
    await expect(
      wrapped({
        data: { sourceLanguage, targetLanguage },
        auth: { uid: 'user-123' },
      })
    ).rejects.toThrow('Text is required');
  });

  test('should handle missing languages', async () => {
    const text = 'Hello';

    // Call the function without languages
    const wrapped = testEnv.wrap(analyzeCulturalContext);
    
    await expect(
      wrapped({
        data: { text },
        auth: { uid: 'user-123' },
      })
    ).rejects.toThrow('Source and target languages are required');
  });

  test('should handle unauthenticated request', async () => {
    const text = 'Hello';
    const sourceLanguage = 'en';
    const targetLanguage = 'es';

    // Call the function without auth
    const wrapped = testEnv.wrap(analyzeCulturalContext);
    
    await expect(
      wrapped({
        data: { text, sourceLanguage, targetLanguage },
        auth: null,
      })
    ).rejects.toThrow('Unauthenticated');
  });

  test('should detect time concept differences', async () => {
    const text = 'I will reply to you soon';
    const sourceLanguage = 'es';
    const targetLanguage = 'en';
    
    // Mock OpenAI response
    mockOpenAI.chat.completions.create.mockResolvedValue({
      choices: [{
        message: {
          content: JSON.stringify({
            hasContext: true,
            explanation: 'Spanish and English cultures have different concepts of "soon". In Spanish-speaking cultures, "pronto" can mean anywhere from minutes to days.',
            category: 'time_concept',
            confidence: 0.82,
          }),
        },
      }],
    });

    // Mock cache miss
    mockFirestore.collection.mockReturnValue({
      doc: () => ({
        get: jest.fn().mockResolvedValue({ exists: false }),
        set: jest.fn().mockResolvedValue(undefined),
      }),
    });

    // Call the function
    const wrapped = testEnv.wrap(analyzeCulturalContext);
    const result = await wrapped({
      data: { text, sourceLanguage, targetLanguage },
      auth: { uid: 'user-123' },
    });

    // Assertions
    expect(result.hasContext).toBe(true);
    expect(result.category).toBe('time_concept');
  });
});

