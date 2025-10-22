/**
 * Cache Helper - Firestore caching utilities
 * Provides generic caching functions for AI responses
 */

import * as admin from 'firebase-admin';
import { CacheOptions, CachedData } from './types';

/**
 * Get Firestore instance
 */
function getFirestore(): FirebaseFirestore.Firestore {
  return admin.firestore();
}

/**
 * Generate cache key from multiple parts
 */
export function generateCacheKey(...parts: string[]): string {
  return parts.map(part => 
    part.toLowerCase().replace(/[^a-z0-9]/g, '_')
  ).join('_');
}

/**
 * Check if cached data exists and is not expired
 */
export async function cacheExists(
  collection: string,
  documentId: string
): Promise<boolean> {
  try {
    const doc = await getFirestore()
      .collection(collection)
      .doc(documentId)
      .get();

    if (!doc.exists) {
      return false;
    }

    const data = doc.data();
    
    // Check expiration if exists
    if (data?.expiresAt) {
      const now = admin.firestore.Timestamp.now();
      if (data.expiresAt.toMillis() < now.toMillis()) {
        // Expired, delete it
        await doc.ref.delete();
        return false;
      }
    }

    return true;
  } catch (error) {
    console.error('Error checking cache:', error);
    return false;
  }
}

/**
 * Get cached data
 */
export async function getCached<T>(
  collection: string,
  documentId: string
): Promise<T | null> {
  try {
    const doc = await getFirestore()
      .collection(collection)
      .doc(documentId)
      .get();

    if (!doc.exists) {
      return null;
    }

    const cachedData = doc.data() as CachedData<T>;
    
    // Check expiration
    if (cachedData.expiresAt) {
      const now = admin.firestore.Timestamp.now();
      if (cachedData.expiresAt.toMillis() < now.toMillis()) {
        // Expired, delete and return null
        await doc.ref.delete();
        return null;
      }
    }

    return cachedData.data;
  } catch (error) {
    console.error('Error getting cached data:', error);
    return null;
  }
}

/**
 * Set cached data
 */
export async function setCached<T>(
  collection: string,
  documentId: string,
  data: T,
  ttl?: number
): Promise<void> {
  try {
    const cachedData: CachedData<T> = {
      data,
      cachedAt: admin.firestore.Timestamp.now(),
    };

    // Add expiration if TTL provided
    if (ttl) {
      const expiresAt = new Date();
      expiresAt.setSeconds(expiresAt.getSeconds() + ttl);
      cachedData.expiresAt = admin.firestore.Timestamp.fromDate(expiresAt);
    }

    await getFirestore()
      .collection(collection)
      .doc(documentId)
      .set(cachedData);
  } catch (error) {
    console.error('Error setting cached data:', error);
    // Don't throw - caching failure shouldn't break the function
  }
}

/**
 * Delete cached data
 */
export async function deleteCached(
  collection: string,
  documentId: string
): Promise<void> {
  try {
    await getFirestore()
      .collection(collection)
      .doc(documentId)
      .delete();
  } catch (error) {
    console.error('Error deleting cached data:', error);
  }
}

/**
 * Get or compute with caching
 * If cache exists, return it; otherwise compute, cache, and return
 */
export async function getOrCompute<T>(
  options: CacheOptions,
  computeFn: () => Promise<T>
): Promise<{ data: T; cached: boolean }> {
  // Try to get from cache first
  const cached = await getCached<T>(options.collection, options.documentId);
  
  if (cached !== null) {
    return { data: cached, cached: true };
  }

  // Not in cache, compute
  const data = await computeFn();

  // Cache the result
  await setCached(
    options.collection,
    options.documentId,
    data,
    options.ttl
  );

  return { data, cached: false };
}

/**
 * Clean up expired cache entries (can be called periodically)
 */
export async function cleanExpiredCache(collection: string): Promise<number> {
  try {
    const now = admin.firestore.Timestamp.now();
    const snapshot = await getFirestore()
      .collection(collection)
      .where('expiresAt', '<', now)
      .limit(500) // Process in batches
      .get();

    const batch = getFirestore().batch();
    let count = 0;

    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
      count++;
    });

    if (count > 0) {
      await batch.commit();
      console.log(`Cleaned ${count} expired cache entries from ${collection}`);
    }

    return count;
  } catch (error) {
    console.error('Error cleaning expired cache:', error);
    return 0;
  }
}

