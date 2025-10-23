/**
 * Unit Tests for Language Detection Cloud Function (PR #2)
 * Tests language detection with mocked OpenAI responses
 */

import { detectLanguage } from '../../ai/languageDetection';
import testModule from 'firebase-functions-test';
import { OpenAI } from 'openai';

// Initialize Firebase Functions test environment
const testEnv = testModule();

// Mock OpenAI
jest.mock('openai');

describe('detectLanguage Cloud Function', () => {
  let mockOpenAI: any;

  beforeEach(() => {
    jest.clearAllMocks();
    
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

  test('should detect English correctly', async () => {
    const text = 'Hello, how are you today?';
    
    // Mock OpenAI response
    mockOpenAI.chat.completions.create.mockResolvedValue({
      choices: [{
        message: {
          content: JSON.stringify({
            language: 'en',
            confidence: 0.98,
            languageName: 'English',
          }),
        },
      }],
    });

    // Call the function
    const wrapped = testEnv.wrap(detectLanguage);
    const result = await wrapped({
      data: { text },
      auth: { uid: 'user-123' },
    });

    // Assertions
    expect(result.language).toBe('en');
    expect(result.confidence).toBeGreaterThan(0.9);
    expect(result.languageName).toBe('English');
    expect(mockOpenAI.chat.completions.create).toHaveBeenCalledTimes(1);
  });

  test('should detect Spanish correctly', async () => {
    const text = '¡Hola! ¿Cómo estás?';
    
    // Mock OpenAI response
    mockOpenAI.chat.completions.create.mockResolvedValue({
      choices: [{
        message: {
          content: JSON.stringify({
            language: 'es',
            confidence: 0.99,
            languageName: 'Spanish',
          }),
        },
      }],
    });

    // Call the function
    const wrapped = testEnv.wrap(detectLanguage);
    const result = await wrapped({
      data: { text },
      auth: { uid: 'user-123' },
    });

    // Assertions
    expect(result.language).toBe('es');
    expect(result.confidence).toBeGreaterThan(0.95);
  });

  test('should detect Japanese correctly', async () => {
    const text = 'こんにちは、元気ですか？';
    
    // Mock OpenAI response
    mockOpenAI.chat.completions.create.mockResolvedValue({
      choices: [{
        message: {
          content: JSON.stringify({
            language: 'ja',
            confidence: 0.97,
            languageName: 'Japanese',
          }),
        },
      }],
    });

    // Call the function
    const wrapped = testEnv.wrap(detectLanguage);
    const result = await wrapped({
      data: { text },
      auth: { uid: 'user-123' },
    });

    // Assertions
    expect(result.language).toBe('ja');
    expect(result.confidence).toBeGreaterThan(0.9);
  });

  test('should handle mixed language text', async () => {
    const text = 'Hello, je suis tired aujourd\'hui';
    
    // Mock OpenAI response - detects primary language
    mockOpenAI.chat.completions.create.mockResolvedValue({
      choices: [{
        message: {
          content: JSON.stringify({
            language: 'en',
            confidence: 0.65,
            languageName: 'English',
            note: 'Mixed language detected: English, French',
          }),
        },
      }],
    });

    // Call the function
    const wrapped = testEnv.wrap(detectLanguage);
    const result = await wrapped({
      data: { text },
      auth: { uid: 'user-123' },
    });

    // Assertions
    expect(result.language).toBe('en');
    expect(result.confidence).toBeLessThan(0.8); // Lower confidence for mixed
  });

  test('should handle empty text', async () => {
    const text = '';

    // Call the function
    const wrapped = testEnv.wrap(detectLanguage);
    
    await expect(
      wrapped({
        data: { text },
        auth: { uid: 'user-123' },
      })
    ).rejects.toThrow('Text is required');
  });

  test('should handle very short text', async () => {
    const text = 'Hi';
    
    // Mock OpenAI response
    mockOpenAI.chat.completions.create.mockResolvedValue({
      choices: [{
        message: {
          content: JSON.stringify({
            language: 'en',
            confidence: 0.75,
            languageName: 'English',
          }),
        },
      }],
    });

    // Call the function
    const wrapped = testEnv.wrap(detectLanguage);
    const result = await wrapped({
      data: { text },
      auth: { uid: 'user-123' },
    });

    // Assertions
    expect(result.language).toBe('en');
    // Short text may have lower confidence
    expect(result.confidence).toBeGreaterThan(0.5);
  });

  test('should handle unauthenticated request', async () => {
    const text = 'Hello world';

    // Call the function without auth
    const wrapped = testEnv.wrap(detectLanguage);
    
    await expect(
      wrapped({
        data: { text },
        auth: null,
      })
    ).rejects.toThrow('Unauthenticated');
  });

  test('should handle OpenAI API error', async () => {
    const text = 'Hello world';

    // Mock OpenAI error
    mockOpenAI.chat.completions.create.mockRejectedValue(
      new Error('OpenAI API error')
    );

    // Call the function
    const wrapped = testEnv.wrap(detectLanguage);
    
    await expect(
      wrapped({
        data: { text },
        auth: { uid: 'user-123' },
      })
    ).rejects.toThrow();
  });

  test('should handle text that is too long', async () => {
    const text = 'a'.repeat(10001); // Max length exceeded

    // Call the function
    const wrapped = testEnv.wrap(detectLanguage);
    
    await expect(
      wrapped({
        data: { text },
        auth: { uid: 'user-123' },
      })
    ).rejects.toThrow('Text too long');
  });

  test('should detect Arabic correctly', async () => {
    const text = 'مرحبا، كيف حالك؟';
    
    // Mock OpenAI response
    mockOpenAI.chat.completions.create.mockResolvedValue({
      choices: [{
        message: {
          content: JSON.stringify({
            language: 'ar',
            confidence: 0.96,
            languageName: 'Arabic',
          }),
        },
      }],
    });

    // Call the function
    const wrapped = testEnv.wrap(detectLanguage);
    const result = await wrapped({
      data: { text },
      auth: { uid: 'user-123' },
    });

    // Assertions
    expect(result.language).toBe('ar');
    expect(result.confidence).toBeGreaterThan(0.9);
  });
});

