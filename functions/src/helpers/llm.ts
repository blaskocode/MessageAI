/**
 * LLM Helper - OpenAI client initialization and utilities
 * Handles API communication with retry logic and error handling
 */

import OpenAI from 'openai';
import * as functions from 'firebase-functions';
import { OpenAICompletionOptions } from './types';

// Initialize OpenAI client
let openaiClient: OpenAI | null = null;

/**
 * Get or initialize the OpenAI client
 */
export function getOpenAIClient(): OpenAI {
  if (!openaiClient) {
    const apiKey = process.env.OPENAI_API_KEY || functions.config().openai?.api_key;
    
    if (!apiKey) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'OpenAI API key not configured'
      );
    }

    openaiClient = new OpenAI({
      apiKey: apiKey,
    });
  }

  return openaiClient;
}

/**
 * Get the default GPT model from environment or config
 */
export function getDefaultModel(): string {
  return process.env.OPENAI_MODEL || 
         functions.config().openai?.model || 
         'gpt-4-turbo-preview';
}

/**
 * Get the default embedding model
 */
export function getEmbeddingModel(): string {
  return process.env.EMBEDDING_MODEL || 
         functions.config().openai?.embedding_model || 
         'text-embedding-ada-002';
}

/**
 * Call OpenAI with retry logic
 */
export async function callOpenAI(
  options: OpenAICompletionOptions,
  retries = 3
): Promise<string> {
  const client = getOpenAIClient();
  
  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      const response = await client.chat.completions.create({
        model: options.model || getDefaultModel(),
        messages: options.messages,
        temperature: options.temperature ?? 0.7,
        max_tokens: options.max_tokens,
        response_format: options.response_format,
      });

      const content = response.choices[0]?.message?.content;
      
      if (!content) {
        throw new Error('No content in OpenAI response');
      }

      return content;
    } catch (error: any) {
      console.error(`OpenAI API call failed (attempt ${attempt + 1}/${retries}):`, error);
      
      // Don't retry on certain errors
      if (error.status === 401 || error.status === 403) {
        throw new functions.https.HttpsError(
          'unauthenticated',
          'Invalid OpenAI API key'
        );
      }

      if (error.status === 400) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Invalid request to OpenAI API'
        );
      }

      // If this was the last attempt, throw
      if (attempt === retries - 1) {
        throw new functions.https.HttpsError(
          'internal',
          'OpenAI API call failed after retries'
        );
      }

      // Exponential backoff
      await sleep(Math.pow(2, attempt) * 1000);
    }
  }

  throw new functions.https.HttpsError('internal', 'Failed to call OpenAI');
}

/**
 * Generate embeddings for text
 */
export async function generateEmbedding(
  text: string,
  retries = 3
): Promise<number[]> {
  const client = getOpenAIClient();
  
  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      const response = await client.embeddings.create({
        model: getEmbeddingModel(),
        input: text,
      });

      const embedding = response.data[0]?.embedding;
      
      if (!embedding) {
        throw new Error('No embedding in OpenAI response');
      }

      return embedding;
    } catch (error: any) {
      console.error(`OpenAI embedding failed (attempt ${attempt + 1}/${retries}):`, error);
      
      if (attempt === retries - 1) {
        throw new functions.https.HttpsError(
          'internal',
          'Failed to generate embedding'
        );
      }

      await sleep(Math.pow(2, attempt) * 1000);
    }
  }

  throw new functions.https.HttpsError('internal', 'Failed to generate embedding');
}

/**
 * Build system prompt for translation
 */
export function buildTranslationPrompt(
  sourceLanguage: string,
  targetLanguage: string
): string {
  return `You are a professional translator. Translate the following text from ${sourceLanguage} to ${targetLanguage}.

IMPORTANT RULES:
1. Preserve the tone, emotion, and formality level of the original text
2. Keep emojis and formatting exactly as they appear
3. For cultural idioms, translate the meaning, not the words literally
4. Maintain the natural flow of conversation
5. Return ONLY the translated text, nothing else

If you're unsure about the source language, detect it automatically.`;
}

/**
 * Sleep helper for retry backoff
 */
function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Parse JSON response from OpenAI safely
 */
export function parseJSONResponse<T>(content: string): T {
  try {
    return JSON.parse(content) as T;
  } catch (error) {
    throw new functions.https.HttpsError(
      'internal',
      'Failed to parse OpenAI JSON response'
    );
  }
}

