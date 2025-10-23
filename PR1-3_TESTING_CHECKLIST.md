# 🧪 Phase 2 PRs #1-3 Comprehensive Testing Checklist

**Date:** October 23, 2025  
**Status:** 🔄 IN PROGRESS  
**Goal:** Verify all AI features work correctly before moving to PR #4

---

## 📋 How to Use This Checklist

1. **Work through each section systematically**
2. **Check the box ☐ when test passes**
3. **Note any issues in the "Issues" column**
4. **Don't skip tests - they build on each other**
5. **Test with fresh data (not cached)**

---

## 🧪 PR #1: Infrastructure Testing

### Cloud Functions Deployment Status

| Test | Status | Issues |
|------|--------|--------|
| ☐ Functions deployed to Firebase (run `firebase functions:list`) | | |
| ☐ `translateMessage` function exists and is callable | | |
| ☐ `detectLanguage` function exists and is callable | | |
| ☐ `analyzeCulturalContext` function exists and is callable | | |
| ☐ `onUserProfileUpdated` trigger exists | | |
| ☐ OpenAI API key configured (check logs don't show "API key not configured") | | |

### Helper Functions Test

| Test | Status | Issues |
|------|--------|--------|
| ☐ Translation caching works (translate same message twice - should be instant 2nd time) | | |
| ☐ Error handling works (disconnect internet during translation) | | |
| ☐ Validation rejects invalid input (try translating empty message) | | |

**Commands to run:**
```bash
cd /Users/courtneyblaskovich/Documents/Projects/MessageAI
firebase functions:list
```

---

## 🌐 PR #2: Translation & Language Detection Testing

### 2.1 Basic Translation Tests

| Language | Test Message | Expected Translation | Status | Issues |
|----------|-------------|---------------------|--------|--------|
| Spanish → English | "Hola, ¿cómo estás?" | "Hello, how are you?" | ☐ | |
| French → English | "Bonjour, comment allez-vous?" | "Hello, how are you?" | ☐ | |
| German → English | "Guten Tag, wie geht es Ihnen?" | "Good day, how are you?" | ☐ | |
| Japanese → English | "こんにちは、元気ですか？" | "Hello, how are you?" | ☐ | |
| Chinese → English | "你好，你好吗？" | "Hello, how are you?" | ☐ | |
| English → Spanish | "The weather is nice today" | "El clima está agradable hoy" | ☐ | |

**How to test:**
1. Open MessageAI on iOS
2. Log in with Account A
3. Send test message in foreign language from Account B
4. On Account A, tap "Tap to translate"
5. **First attempt should work** (not fail!)
6. Verify translation is accurate
7. Check it shows correct source language (not "UNKNOWN")

### 2.2 Language Detection Tests

| Test Message | Expected Language | Status | Issues |
|-------------|-------------------|--------|--------|
| "Hello, how are you?" | en | ☐ | |
| "Hola, ¿cómo estás?" | es | ☐ | |
| "Bonjour, comment ça va?" | fr | ☐ | |
| "Guten Tag" | de | ☐ | |
| "こんにちは" | ja | ☐ | |
| "你好" | zh | ☐ | |

**How to test:**
1. Send message from Account B
2. On Account A, wait 1-2 seconds for language detection
3. Check iOS console logs for: `✅ [Language Detection] Detected 'XX' for message`
4. Verify language code is correct

### 2.3 Conditional Translate Button Tests

| Scenario | Expected Behavior | Status | Issues |
|----------|------------------|--------|--------|
| ☐ English message to English user | NO translate button | | |
| ☐ Spanish message to English user | YES translate button | | |
| ☐ English message to bilingual (en, es) user | NO translate button | | |
| ☐ French message to bilingual (en, es) user | YES translate button | | |
| ☐ Button waits for language detection | Button appears after 1-2s, not immediately | | |

**How to test:**
1. Set your fluent languages in Profile → Language Settings
2. Send messages in different languages from another account
3. Verify translate button only shows for non-fluent languages
4. Check console logs: `🔍 [Translate Button] Message XXX: detected=XX, fluent=[...], show=true/false`

### 2.4 Translation UI Tests

| Feature | Expected Behavior | Status | Issues |
|---------|------------------|--------|--------|
| ☐ "Tap to translate" badge visible | Shows below foreign language messages | | |
| ☐ Tapping badge shows translation | Translation appears inline | | |
| ☐ "Hide translation" works | Tapping again hides translation | | |
| ☐ Loading indicator | Shows while translating | | |
| ☐ Error message | Shows if translation fails | | |
| ☐ "Translated from [language]" label | Shows correct source language | | |
| ☐ Original text always visible | Both original and translation visible | | |

### 2.5 Translation Caching Tests

| Test | Expected Behavior | Status | Issues |
|------|------------------|--------|--------|
| ☐ First translation takes 1-3 seconds | Normal API call time | | |
| ☐ Second translation instant | Retrieved from cache | | |
| ☐ Cache persists across app restart | Close app, reopen, translation still cached | | |
| ☐ Different target languages cached separately | Translate to English, then Spanish - both cached | | |

### 2.6 Translation Edge Cases

| Test | Expected Behavior | Status | Issues |
|------|------------------|--------|--------|
| ☐ Empty message | Should not show translate button | | |
| ☐ Very long message (500+ chars) | Translates successfully | | |
| ☐ Message with emojis | Preserves emojis in translation | | |
| ☐ Message with URLs | Preserves URLs in translation | | |
| ☐ Mixed language message | Detects primary language | | |

### 2.7 Language Settings Tests

| Test | Expected Behavior | Status | Issues |
|------|------------------|--------|--------|
| ☐ Profile → Language Settings exists | Can navigate to language settings | | |
| ☐ Can select multiple fluent languages | Select English + Spanish | | |
| ☐ Can deselect languages | Remove Spanish from fluent languages | | |
| ☐ Settings persist across app restart | Close app, reopen, settings still saved | | |
| ☐ Settings affect translate button | Button visibility updates when settings change | | |

---

## 💡 PR #3: Auto-Translate & Cultural Context Testing

### 3.1 Auto-Translate Mode Tests

| Test | Expected Behavior | Status | Issues |
|------|------------------|--------|--------|
| ☐ Globe icon in chat toolbar | Icon visible in chat view | | |
| ☐ Tapping globe enables auto-translate | Icon highlights/changes | | |
| ☐ Auto-translate translates new messages | Foreign messages auto-translated | | |
| ☐ Auto-translate OFF: manual translate only | Must tap "Tap to translate" | | |
| ☐ Auto-translate ON: immediate translation | Translation appears automatically | | |
| ☐ Setting persists per conversation | Close chat, reopen, setting remembered | | |

**How to test:**
1. Open chat with foreign language contact
2. Tap globe icon in toolbar
3. Have them send a message in their language
4. Translation should appear automatically (no need to tap button)
5. Tap globe again to disable
6. Next message should require manual tap

### 3.2 Cultural Context Detection Tests

| Language | Test Phrase | Expected Hint | Status | Issues |
|----------|------------|---------------|--------|--------|
| Japanese | "Maybe..." (曖昧な返事) | Explains indirect communication | ☐ | |
| Spanish | "Mañana" (in context of delay) | Explains "mañana culture" concept | ☐ | |
| English | "It's interesting..." | May indicate polite disagreement | ☐ | |
| German | Formal "Sie" vs informal "du" | Explains formality distinction | ☐ | |
| French | "Bisous" at end of message | Explains casual sign-off custom | ☐ | |

**How to test:**
1. Enable auto-translate or manually translate messages
2. Send test phrases from Account B
3. Translate on Account A
4. Look for "💡 Cultural Context" card below translation
5. Verify explanation is helpful and accurate
6. Check confidence score is mentioned in logs

### 3.3 Cultural Hints UI Tests

| Feature | Expected Behavior | Status | Issues |
|---------|------------------|--------|--------|
| ☐ 💡 Cultural Context card appears | Shows below translation when detected | | |
| ☐ Card is expandable/collapsible | Can tap to expand/collapse | | |
| ☐ "Don't show again" button works | Dismisses hint, doesn't show again | | |
| ☐ Dismissed hints persist | Close app, reopen, hint still dismissed | | |
| ☐ High confidence only | Only shows when confidence > 0.8 | | |

### 3.4 Cultural Hints Settings Tests

| Test | Expected Behavior | Status | Issues |
|------|------------------|--------|--------|
| ☐ Profile → Cultural Hints toggle exists | Setting visible in profile | | |
| ☐ Disabling hides all cultural cards | No cards appear when disabled | | |
| ☐ Enabling shows cultural cards | Cards appear when enabled | | |
| ☐ Setting persists across app restart | Close app, reopen, setting remembered | | |

---

## 🎁 BONUS: Profile Features Testing

### Profile Photo Upload Tests

| Test | Expected Behavior | Status | Issues |
|------|------------------|--------|--------|
| ☐ Camera overlay appears on profile photo | Tap profile photo shows PhotosPicker | | |
| ☐ Can select photo from library | Photo picker opens | | |
| ☐ Photo uploads successfully | Loading indicator → success message | | |
| ☐ Photo displays immediately in profile | New photo shows in profile view | | |
| ☐ Photo displays in conversation list | New photo shows in conversation row | | |
| ☐ Photo displays in chat bubbles | New photo shows next to messages | | |
| ☐ Large images compressed | 5MB photo uploads (compressed to 2MB) | | |

### Profile Name Propagation Tests

| Test | Expected Behavior | Status | Issues |
|------|------------------|--------|--------|
| ☐ Can edit name in profile | TextField is always editable | | |
| ☐ Pressing Return saves name | Name updates on Enter press | | |
| ☐ Name updates in conversation list | Other users see new name (1-2 seconds) | | |
| ☐ Name updates in chat view | Other users see new name in chat header | | |
| ☐ Name updates in message bubbles | Existing messages show new name | | |
| ☐ Works in group chats | All group members see updated name | | |

**How to test:**
1. Log in as Account A
2. Change name to "Test User 123"
3. On Account B (different device), wait 2-3 seconds
4. Check conversation list - should show "Test User 123"
5. Open chat with Account A - should show "Test User 123"
6. Look at previous messages - should show "Test User 123"

### Profile Photo Propagation Tests

| Test | Expected Behavior | Status | Issues |
|------|------------------|--------|--------|
| ☐ Photo appears on other devices | Other users see photo in conversation list | | |
| ☐ Photo appears in chat view | Other users see photo in chat bubbles | | |
| ☐ Photo updates are real-time | Change photo, other users see update in 1-2s | | |
| ☐ Works in group chats | All group members see updated photo | | |

---

## 🔄 MVP Features Regression Testing

**CRITICAL:** Ensure existing MVP features still work!

| MVP Feature | Expected Behavior | Status | Issues |
|-------------|------------------|--------|--------|
| ☐ Send text message | Message appears on both devices | | |
| ☐ Message latency < 1 second | Message arrives quickly | | |
| ☐ Typing indicators work | "Typing..." appears when other user types | | |
| ☐ Read receipts work | "Read" appears when other user opens chat | | |
| ☐ Conversation list updates | New messages appear in conversation list | | |
| ☐ Unread indicators work | Blue dot appears for unread conversations | | |
| ☐ Group chat works (3+ users) | Can create and message in groups | | |
| ☐ User search works | Can find users by name/email | | |
| ☐ Local notifications work | Foreground notifications appear | | |
| ☐ Offline persistence works | Messages persist after app restart | | |
| ☐ Authentication works | Sign in, sign out, sign up all work | | |

---

## 🐛 Known Issues Fixed (Verify They Stay Fixed)

| Bug | Expected Behavior | Status | Issues |
|-----|------------------|--------|--------|
| ☐ Translation works on FIRST attempt | No more "INTERNAL" error on first try | | |
| ☐ No "Translated from UNKNOWN" | Always shows correct source language | | |
| ☐ Translate button only for foreign languages | No button for fluent languages | | |
| ☐ No race condition | Button appears after language detected | | |
| ☐ Profile photo shows correctly | AsyncImage loads photos in conversation list | | |

---

## 📊 Testing Summary

### PR #1: Infrastructure
- Tests Completed: __ / 9
- Issues Found: __
- Status: ☐ PASS / ☐ FAIL

### PR #2: Translation & Language Detection
- Tests Completed: __ / 40+
- Issues Found: __
- Status: ☐ PASS / ☐ FAIL

### PR #3: Auto-Translate & Cultural Context
- Tests Completed: __ / 18
- Issues Found: __
- Status: ☐ PASS / ☐ FAIL

### BONUS: Profile Features
- Tests Completed: __ / 13
- Issues Found: __
- Status: ☐ PASS / ☐ FAIL

### MVP Regression Tests
- Tests Completed: __ / 11
- Issues Found: __
- Status: ☐ PASS / ☐ FAIL

---

## ✅ Final Sign-Off

**All PRs #1-3 Ready for Production:** ☐ YES / ☐ NO

**Critical Issues to Fix Before PR #4:**
1. 
2. 
3. 

**Notes:**


---

**Next Step:** Once all tests pass, we can proceed to PR #4 (Formality Analysis) with confidence! 🚀

---

*"Test thoroughly, you must. To production without testing, leads to the dark side it does!" - Yoda* 🌟

