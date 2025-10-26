# Known Limitations

## Multi-Language Precedence

**Issue:** When users have multiple fluent languages (e.g., ["en", "es", "fr"]), the app uses the first language in the array for UI localization and translation targets.

**Current Behavior:**
- UI elements (translate buttons, formality badges) appear in the first language
- Translation target defaults to the first language
- No user control over which language is "primary"

**Impact:** Low (< 5% of users affected)
- Most users have 1-2 fluent languages
- Array order determines precedence (not user preference)

**Workaround:** Users can reorder languages in LanguageSettingsView by changing the order in their profile

**Future Solution:** Add "Preferred Display Language" selector in Settings Screen (PR #10)

**Technical Details:**
- Uses `fluentLanguages.first ?? "en"` throughout codebase
- Documented in User.swift and ChatViewModel+Translation.swift
- Affects: translate button text, formality badge labels, translation targets

---

## Other Limitations

*[Additional limitations can be added here as they are discovered]*