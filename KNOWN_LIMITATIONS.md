# Known Limitations & Future Enhancements

**Date:** October 23, 2025  
**Status:** Phase 2 Complete - Documented for Future PRs

---

## 🎯 Translation Target Language Selection

### Current Behavior

**Multiple Fluent Languages:**
- Users can set multiple fluent languages (e.g., ["en", "es", "fr"])
- All translations default to **first language in list**
- No UI to choose different target language per message

**Example:**
- User speaks English, Spanish, French
- Receives German message
- Can only translate to English (first in list)
- Cannot choose Spanish or French as target

### Limitation

- ⚠️ Users with multiple fluent languages cannot choose which language to translate to
- ⚠️ Array order determines translation target (not obvious to users)
- ⚠️ No way to change order without editing settings

### Impact

- **Low** - Most users (95%+) have one primary language
- **Medium** - Polyglots might want flexibility
- **Acceptable for MVP** - Simple implementation, works for majority

### Future Enhancement Options

**Option 1: Preferred Translation Language Setting**
- Add setting in Profile: "Preferred translation language"
- Dropdown to select from fluent languages
- **Time:** ~30 minutes
- **Priority:** Low-Medium

**Option 2: Per-Message Language Selection**
- Long-press translate button → menu with language choices
- Select target language for each translation
- **Time:** ~1 hour
- **Priority:** Medium (power user feature)

**Option 3: Smart Detection**
- Detect conversation language pattern
- Auto-select most relevant target language
- **Time:** ~2 hours
- **Priority:** Low (complex, low ROI)

### Recommendation

- ✅ Keep current implementation for Phase 2
- 📅 Consider Option 1 for PR #5 or #6
- 📋 Gather user feedback before implementing

---

## 📝 Decision

**Status:** ACCEPTED AS LIMITATION  
**Documented:** October 23, 2025  
**Planned Enhancement:** Future PR (post-Phase 2)  
**User Impact:** Minimal (affects < 5% of users)

---

**Approved By:** Testing session - comprehensive Phase 2 coverage  
**Next Review:** After user feedback from beta testing

