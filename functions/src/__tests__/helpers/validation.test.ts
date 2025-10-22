/**
 * Tests for validation helper functions
 */

import { 
  validateText,
  validateLanguageCode,
  validateFormalityLevel,
} from '../../helpers/validation';
import { generateCacheKey } from '../../helpers/cache';

describe('Validation Helpers', () => {
  describe('validateText', () => {
    it('should pass for valid text', () => {
      expect(() => {
        validateText('Hello world', 'message');
      }).not.toThrow();
    });

    it('should throw for empty required text', () => {
      expect(() => {
        validateText('', 'message', { required: true });
      }).toThrow('message is required');
    });

    it('should pass for empty optional text', () => {
      expect(() => {
        validateText('', 'message', { required: false });
      }).not.toThrow();
    });

    it('should throw for text too short', () => {
      expect(() => {
        validateText('Hi', 'message', { minLength: 5 });
      }).toThrow('at least 5 characters');
    });

    it('should throw for text too long', () => {
      const longText = 'a'.repeat(101);
      expect(() => {
        validateText(longText, 'message', { maxLength: 100 });
      }).toThrow('at most 100 characters');
    });
  });

  describe('validateLanguageCode', () => {
    it('should pass for valid 2-letter codes', () => {
      expect(() => validateLanguageCode('en', 'language')).not.toThrow();
      expect(() => validateLanguageCode('es', 'language')).not.toThrow();
      expect(() => validateLanguageCode('fr', 'language')).not.toThrow();
    });

    it('should pass for valid 3-letter codes', () => {
      expect(() => validateLanguageCode('eng', 'language')).not.toThrow();
    });

    it('should throw for invalid codes', () => {
      expect(() => validateLanguageCode('', 'language')).toThrow();
      expect(() => validateLanguageCode('e', 'language')).toThrow();
      expect(() => validateLanguageCode('english', 'language')).toThrow();
      expect(() => validateLanguageCode('12', 'language')).toThrow();
    });
  });

  describe('validateFormalityLevel', () => {
    it('should pass for valid formality levels', () => {
      expect(() => validateFormalityLevel('very_formal')).not.toThrow();
      expect(() => validateFormalityLevel('formal')).not.toThrow();
      expect(() => validateFormalityLevel('neutral')).not.toThrow();
      expect(() => validateFormalityLevel('casual')).not.toThrow();
      expect(() => validateFormalityLevel('very_casual')).not.toThrow();
    });

    it('should throw for invalid formality level', () => {
      expect(() => validateFormalityLevel('super_formal')).toThrow();
      expect(() => validateFormalityLevel('FORMAL')).toThrow();
      expect(() => validateFormalityLevel('')).toThrow();
    });
  });
});

describe('Cache Helpers', () => {
  describe('generateCacheKey', () => {
    it('should generate consistent keys', () => {
      const key1 = generateCacheKey('test', 'key', '123');
      const key2 = generateCacheKey('test', 'key', '123');
      expect(key1).toBe(key2);
    });

    it('should normalize special characters', () => {
      const key = generateCacheKey('Test Key!', 'with-dashes', '123');
      expect(key).toMatch(/^[a-z0-9_]+$/);
    });

    it('should handle empty parts', () => {
      const key = generateCacheKey('test', '', 'key');
      expect(key).toBeTruthy();
    });
  });
});

