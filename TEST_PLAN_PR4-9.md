# Testing Plan: PRs #4-9 (Phase 2 AI Features)

**Date:** October 23, 2025  
**Status:** Backend deployed ✅, iOS UI pending 🔸

---

## Overview

All Cloud Functions for PRs #4-9 are deployed to production. However, iOS UI integration is incomplete. This guide covers:
1. **Backend testing** - Verify Cloud Functions work correctly
2. **Partial iOS testing** - Test with existing code where possible
3. **Full testing checklist** - Complete after UI implementation

---

## PR #4: Formality Analysis & Adjustment

### Backend Status: ✅ DEPLOYED
- `analyzeMessageFormality` - Live in us-central1
- `adjustMessageFormality` - Live in us-central1

### iOS Status: 🔸 PARTIAL
- ✅ Models exist (`FormalityLevel`, `FormalityAnalysis`, `FormalityAdjustment`)
- ✅ Service methods exist (`analyzeFormalityAnalysis()`, `adjustFormality()`)
- ✅ ViewModel extension exists (`ChatViewModel+Formality.swift`)
- 🔸 UI missing (badges, context menu, settings)

---

### Test 1: Backend - Formality Analysis (Spanish)

**Goal:** Verify formality detection works for Spanish (tú vs usted)

**Method:** Direct Cloud Function call from iOS

**Test Code (Add to ChatViewModel temporarily):**

```swift
// Add this test function to ChatViewModel.swift temporarily
func testFormalityAnalysis() async {
    print("🧪 Testing Formality Analysis...")
    
    // Test Case 1: Formal Spanish (usted)
    do {
        let analysis1 = try await aiService.analyzeFormalityAnalysis(
            messageId: "test_formal_spanish",
            text: "¿Cómo está usted? Me gustaría hablar con el gerente.",
            language: "es"
        )
        print("✅ Formal Spanish: \(analysis1.level.rawValue) (confidence: \(analysis1.confidence))")
        print("   Markers: \(analysis1.markers.count)")
        print("   Explanation: \(analysis1.explanation)")
    } catch {
        print("❌ Formal Spanish failed: \(error)")
    }
    
    // Test Case 2: Casual Spanish (tú)
    do {
        let analysis2 = try await aiService.analyzeFormalityAnalysis(
            messageId: "test_casual_spanish",
            text: "¿Cómo estás? ¿Vamos al cine esta noche?",
            language: "es"
        )
        print("✅ Casual Spanish: \(analysis2.level.rawValue) (confidence: \(analysis2.confidence))")
    } catch {
        print("❌ Casual Spanish failed: \(error)")
    }
    
    // Test Case 3: German formal (Sie)
    do {
        let analysis3 = try await aiService.analyzeFormalityAnalysis(
            messageId: "test_formal_german",
            text: "Guten Tag, könnten Sie mir bitte helfen?",
            language: "de"
        )
        print("✅ Formal German: \(analysis3.level.rawValue) (confidence: \(analysis3.confidence))")
    } catch {
        print("❌ Formal German failed: \(error)")
    }
    
    // Test Case 4: German casual (du)
    do {
        let analysis4 = try await aiService.analyzeFormalityAnalysis(
            messageId: "test_casual_german",
            text: "Hey, kommst du heute Abend mit?",
            language: "de"
        )
        print("✅ Casual German: \(analysis4.level.rawValue) (confidence: \(analysis4.confidence))")
    } catch {
        print("❌ Casual German failed: \(error)")
    }
    
    print("🧪 Formality Analysis tests complete")
}
```

**How to Run:**
1. Add the test function to `ChatViewModel.swift`
2. Call it from `ChatView` in `onAppear`:
   ```swift
   .onAppear {
       Task {
           await viewModel.testFormalityAnalysis()
       }
   }
   ```
3. Run the app and check Xcode console

**Expected Results:**
- Formal Spanish → `formal` or `very_formal`
- Casual Spanish → `casual` or `very_casual`
- Formal German → `formal` or `very_formal`
- Casual German → `casual` or `very_casual`
- Confidence scores > 0.7
- Markers array contains relevant words (usted, Sie, du, tú)

---

### Test 2: Backend - Formality Adjustment

**Goal:** Verify formality adjustment preserves meaning

**Test Code:**

```swift
func testFormalityAdjustment() async {
    print("🧪 Testing Formality Adjustment...")
    
    // Test: Adjust casual to formal
    do {
        let adjustment = try await aiService.adjustFormality(
            text: "Hey, what's up? Wanna grab lunch?",
            currentLevel: .casual,
            targetLevel: .formal,
            language: "en"
        )
        print("✅ Casual → Formal:")
        print("   Original: \(adjustment.originalText)")
        print("   Adjusted: \(adjustment.adjustedText)")
        print("   Changes: \(adjustment.changesExplanation)")
    } catch {
        print("❌ Adjustment failed: \(error)")
    }
    
    // Test: Spanish formal to casual
    do {
        let adjustment = try await aiService.adjustFormality(
            text: "Buenos días. ¿Podría usted ayudarme con este problema?",
            currentLevel: .formal,
            targetLevel: .casual,
            language: "es"
        )
        print("✅ Spanish Formal → Casual:")
        print("   Adjusted: \(adjustment.adjustedText)")
    } catch {
        print("❌ Spanish adjustment failed: \(error)")
    }
    
    print("🧪 Formality Adjustment tests complete")
}
```

**Expected Results:**
- English: "Hey, what's up?" → "Good morning, how are you?" or similar
- Spanish: "¿Podría usted..." → "¿Podrías..." (usted → tú)
- Meaning preserved, tone adjusted
- `changesExplanation` describes what changed

---

### Test 3: Caching Verification

**Goal:** Verify Firestore caching works

**Method:**
1. Run Test 1 twice with same messageId
2. Check Firestore console for `formality_cache` collection
3. Second call should be instant (< 100ms)

**How to Verify:**
```swift
let start = Date()
let analysis = try await aiService.analyzeFormalityAnalysis(...)
let duration = Date().timeIntervalSince(start)
print("Duration: \(duration)s")
```

**Expected:**
- First call: 2-5 seconds (GPT-4 API call)
- Second call: < 0.5 seconds (Firestore cache hit)
- Firestore shows document in `formality_cache` collection

---

### Full Testing Checklist (After UI Implementation)

- [ ] Formality badge appears below received messages
- [ ] Badge shows correct icon and formality level
- [ ] Long-press menu shows "View Formality" option
- [ ] Formality detail sheet displays:
  - [ ] Formality level with explanation
  - [ ] Markers highlighted in text
  - [ ] Options to view adjusted versions
- [ ] Settings toggle for auto-analyze works
- [ ] Badge visibility respects settings
- [ ] Draft message rephrase (before sending):
  - [ ] Context menu shows "Rephrase (Formal)" and "Rephrase (Casual)"
  - [ ] Draft text updates after rephrase
  - [ ] Works for multiple languages
- [ ] Offline gracefully degrades (shows cached analysis)

---

## PR #5: Slang & Idiom Explanations

### Backend Status: ✅ DEPLOYED
- `detectSlangIdioms` - Live
- `explainPhrase` - Live

### iOS Status: 🔸 PENDING (No service methods yet)

---

### Test 1: Backend - Slang Detection

**Need to Add:** Service methods to `AIService.swift` first

**Test Code (after adding service methods):**

```swift
func testSlangDetection() async {
    print("🧪 Testing Slang Detection...")
    
    // Test Case 1: English slang
    do {
        let result = try await aiService.detectSlangIdioms(
            text: "That's sick! Let's bounce and grab some grub.",
            language: "en"
        )
        print("✅ English slang detected: \(result.count) phrases")
        for phrase in result {
            print("   - \(phrase.phrase) (\(phrase.type)): \(phrase.meaning)")
        }
    } catch {
        print("❌ English slang detection failed: \(error)")
    }
    
    // Test Case 2: Spanish idioms
    do {
        let result = try await aiService.detectSlangIdioms(
            text: "No hay que darle vueltas al asunto.",
            language: "es"
        )
        print("✅ Spanish idioms detected: \(result.count) phrases")
    } catch {
        print("❌ Spanish detection failed: \(error)")
    }
    
    print("🧪 Slang detection tests complete")
}
```

**Expected Results:**
- "sick" detected as slang (meaning: "cool/awesome")
- "bounce" detected as slang (meaning: "leave")
- "grab some grub" detected as idiom
- Spanish "darle vueltas" detected as idiom
- Each includes meaning, origin, examples

---

### Test 2: Phrase Explanation

```swift
func testPhraseExplanation() async {
    print("🧪 Testing Phrase Explanation...")
    
    do {
        let explanation = try await aiService.explainPhrase(
            phrase: "piece of cake",
            language: "en",
            context: "Don't worry, the test will be a piece of cake."
        )
        print("✅ Phrase: \(explanation.phrase)")
        print("   Meaning: \(explanation.meaning)")
        print("   Origin: \(explanation.origin)")
        print("   Examples: \(explanation.examples.count)")
    } catch {
        print("❌ Phrase explanation failed: \(error)")
    }
}
```

---

## PR #6: Message Embeddings & RAG Pipeline

### Backend Status: ✅ DEPLOYED
- `onMessageCreated` - Firestore trigger (auto-generates embeddings)
- `generateMessageEmbedding` - Manual generation
- `semanticSearch` - Semantic search
- `getConversationContext` - RAG context retrieval

### iOS Status: 🔸 PENDING (No service methods yet)

---

### Test 1: Automatic Embedding Generation

**Goal:** Verify embeddings are auto-generated for new messages

**Method:**
1. Send a message in the app
2. Check Firestore console → `message_embeddings` collection
3. Verify document created with:
   - `messageId` matching your message
   - `embedding` array with 1536 numbers
   - `text` matching your message
   - `language` detected

**Test Messages:**
```
"Hello, how are you today?"
"I love traveling to new places"
"Let's meet at the coffee shop tomorrow"
```

**Expected:**
- Each message creates a document in `message_embeddings`
- Embedding generation happens within 5 seconds
- Array has exactly 1536 float values

---

### Test 2: Semantic Search

**Test Code (after adding service method):**

```swift
func testSemanticSearch() async {
    print("🧪 Testing Semantic Search...")
    
    guard let userId = firebaseService.currentUserId else {
        print("❌ Not authenticated")
        return
    }
    
    do {
        // Search for messages about meetings
        let results = try await aiService.semanticSearch(
            query: "meeting schedule appointment",
            userId: userId,
            conversationId: nil, // Search across all conversations
            limit: 5
        )
        
        print("✅ Semantic search found \(results.count) results")
        for result in results {
            print("   - \(result.text) (similarity: \(result.similarity))")
        }
    } catch {
        print("❌ Semantic search failed: \(error)")
    }
}
```

**Expected Results:**
- Finds messages about meetings even if exact words don't match
- Similarity scores > 0.7 for relevant matches
- Results sorted by similarity (highest first)

---

## PR #7: Smart Replies

### Backend Status: ✅ DEPLOYED
- `generateSmartReplies` - Live

### iOS Status: 🔸 PENDING

---

### Test 1: Smart Reply Generation

**Test Code:**

```swift
func testSmartReplies() async {
    print("🧪 Testing Smart Replies...")
    
    guard let userId = firebaseService.currentUserId else {
        print("❌ Not authenticated")
        return
    }
    
    do {
        // Get the last message in current conversation
        let lastMessage = messages.last
        guard let lastMessage = lastMessage else {
            print("❌ No messages in conversation")
            return
        }
        
        let replies = try await aiService.generateSmartReplies(
            conversationId: conversationId,
            incomingMessageId: lastMessage.id,
            userId: userId
        )
        
        print("✅ Generated \(replies.count) smart replies:")
        for reply in replies {
            print("   - \(reply.text) [\(reply.formality ?? "neutral")]")
        }
    } catch {
        print("❌ Smart replies failed: \(error)")
    }
}
```

**Expected Results:**
- 3-5 reply suggestions
- Vary in length (brief to detailed)
- Match conversation context
- Appropriate formality level

**Test Cases:**
1. Message: "How are you?" → Replies: "Good, thanks!", "I'm doing well, how about you?", etc.
2. Message: "Want to grab lunch?" → Replies: "Sure!", "I'd love to", "What time works?"
3. Message: "Can you help me with the project?" → Work-appropriate suggestions

---

## PR #8: AI Assistant with RAG

### Backend Status: ✅ DEPLOYED
- `queryAIAssistant` - Live
- `summarizeConversation` - Live

### iOS Status: 🔸 PENDING (New UI needed)

---

### Test 1: AI Assistant Query

**Test Code:**

```swift
func testAIAssistant() async {
    print("🧪 Testing AI Assistant...")
    
    guard let userId = firebaseService.currentUserId else {
        print("❌ Not authenticated")
        return
    }
    
    do {
        // Ask about the conversation
        let response = try await aiService.queryAIAssistant(
            query: "What did we discuss about the meeting?",
            userId: userId,
            conversationId: conversationId
        )
        
        print("✅ AI Assistant response:")
        print("   \(response.response)")
        if let sources = response.sources {
            print("   Sources used: \(sources.count) messages")
        }
    } catch {
        print("❌ AI Assistant failed: \(error)")
    }
}
```

**Expected Results:**
- Relevant answer based on conversation history
- Cites specific messages when applicable
- Helpful and conversational tone

---

### Test 2: Conversation Summarization

```swift
func testConversationSummary() async {
    print("🧪 Testing Conversation Summary...")
    
    do {
        let summary = try await aiService.summarizeConversation(
            conversationId: conversationId
        )
        
        print("✅ Conversation Summary:")
        print("   \(summary.summary)")
    } catch {
        print("❌ Summary failed: \(error)")
    }
}
```

**Expected Results:**
- Concise summary of conversation
- Highlights key topics and decisions
- Mentions action items if any

---

## PR #9: Structured Data Extraction

### Backend Status: ✅ DEPLOYED
- `extractStructuredData` - Live
- `onMessageCreatedExtractData` - Firestore trigger (auto)

### iOS Status: 🔸 PENDING

---

### Test 1: Automatic Extraction

**Goal:** Verify events/tasks are auto-extracted

**Method:**
1. Send messages with dates/locations in the app:
   ```
   "Let's meet tomorrow at 3pm"
   "Dinner at Starbucks on Main Street Friday evening"
   "Remind me to call the doctor next week"
   "¿Vamos al cine esta noche a las 8?"
   ```

2. Check Firestore console → `extracted_data` collection

**Expected:**
- Documents created for messages with events/tasks
- `type`: "event", "task", or "location"
- `datetime`: ISO 8601 format
- `location`: { name, address }
- `confidence`: ≥ 0.7

---

### Test 2: Manual Extraction

**Test Code:**

```swift
func testStructuredDataExtraction() async {
    print("🧪 Testing Structured Data Extraction...")
    
    do {
        let data = try await aiService.extractStructuredData(
            messageId: "test_event",
            text: "Let's meet at Starbucks on 5th Avenue tomorrow at 3pm",
            language: "en",
            conversationId: conversationId
        )
        
        print("✅ Extracted Data:")
        print("   Type: \(data.type ?? "none")")
        print("   Datetime: \(data.datetime ?? "none")")
        print("   Location: \(data.location?.name ?? "none")")
        print("   Confidence: \(data.confidence)")
    } catch {
        print("❌ Extraction failed: \(error)")
    }
}
```

**Expected:**
- Type: "event"
- Datetime: Tomorrow's date + 3pm in ISO 8601
- Location: { name: "Starbucks", address: "5th Avenue" }
- Confidence: > 0.8

---

## Complete Test Suite Runner

**Create a test runner to run all tests:**

```swift
// Add to ChatViewModel.swift
func runAllPhase2Tests() async {
    print("🧪🧪🧪 RUNNING ALL PHASE 2 TESTS 🧪🧪🧪")
    print("")
    
    // PR #4
    await testFormalityAnalysis()
    await testFormalityAdjustment()
    
    // PR #5
    await testSlangDetection()
    await testPhraseExplanation()
    
    // PR #6
    await testSemanticSearch()
    
    // PR #7
    await testSmartReplies()
    
    // PR #8
    await testAIAssistant()
    await testConversationSummary()
    
    // PR #9
    await testStructuredDataExtraction()
    
    print("")
    print("🧪🧪🧪 ALL TESTS COMPLETE 🧪🧪🧪")
}
```

**Run from ChatView:**

```swift
.onAppear {
    Task {
        await viewModel.runAllPhase2Tests()
    }
}
```

---

## Testing Checklist Summary

### Backend Tests (Can do NOW)
- [ ] PR #4: Formality analysis (Spanish, German, French, Japanese)
- [ ] PR #4: Formality adjustment preserves meaning
- [ ] PR #4: Caching works (Firestore verification)
- [ ] PR #5: Slang detection (English, Spanish)
- [ ] PR #5: Phrase explanation provides details
- [ ] PR #6: Embeddings auto-generate for new messages
- [ ] PR #6: Semantic search returns relevant results
- [ ] PR #7: Smart replies match conversation context
- [ ] PR #7: Style analysis affects reply tone
- [ ] PR #8: AI Assistant answers questions accurately
- [ ] PR #8: Conversation summary is concise
- [ ] PR #9: Structured data extraction works
- [ ] PR #9: Auto-extraction creates Firestore documents

### iOS Tests (After UI implementation)
- [ ] PR #4: Formality badges display
- [ ] PR #4: Long-press menu options work
- [ ] PR #4: Formality detail sheet
- [ ] PR #4: Draft rephrase updates text field
- [ ] PR #5: Tap-to-explain phrases
- [ ] PR #6: Search UI finds messages
- [ ] PR #7: Quick reply buttons appear
- [ ] PR #7: Tapping reply inserts text
- [ ] PR #8: AI Assistant chat interface
- [ ] PR #9: Event cards with "Add to Calendar"

---

## Performance Benchmarks

**Target Response Times:**
- Formality analysis: < 3 seconds
- Formality adjustment: < 4 seconds
- Slang detection: < 2 seconds
- Semantic search: < 1 second (after embeddings exist)
- Smart replies: < 5 seconds
- AI Assistant: < 3 seconds
- Structured extraction: < 2 seconds

**All cached responses:** < 500ms

---

## Error Scenarios to Test

- [ ] Network offline (graceful degradation)
- [ ] API rate limiting (proper error messages)
- [ ] Invalid language codes
- [ ] Empty text input
- [ ] Very long messages (>1000 words)
- [ ] Emoji-only messages
- [ ] Mixed language messages
- [ ] User not authenticated
- [ ] Conversation not found
- [ ] Message not found

---

## Next Steps

1. **Add missing iOS service methods** for PRs #5-9
2. **Run backend tests** to verify all functions work
3. **Check Firestore** for proper data storage
4. **Implement iOS UI** for each feature
5. **Run full integration tests** end-to-end
6. **Performance profiling** with real data
7. **Update memory bank** with test results

