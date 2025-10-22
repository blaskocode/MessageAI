# MessageAI Phase 2 - Product Requirements Document
## International Communicator Persona

**Timeline:** Days 2-7 (5 days remaining)  
**Persona:** International Communicator  
**Platform:** iOS (Swift + SwiftUI) + Firebase Cloud Functions  
**AI Stack:** OpenAI GPT-4 / Anthropic Claude + Google Translate API  
**Status:** MVP Complete ✅ - Building on Solid Foundation

---

## Executive Summary

Phase 2 transforms MessageAI into an intelligent multilingual communication platform. We're building AI features that break down language barriers, provide cultural context, and make international communication effortless.

**Target User:** People with friends, family, or colleagues who speak different languages - anyone communicating across language barriers daily.

---

## Persona Deep Dive: International Communicator

### Who Are They?

**Demographics:**
- Age: 20-50
- Backgrounds:
  - Expatriates living abroad
  - International students
  - Remote workers with global teams
  - People with multilingual families
  - Travelers and digital nomads
  - International business professionals

**Daily Reality:**
- Communicates in 2-4 languages daily
- Switches between formal (work) and casual (friends) contexts
- Encounters slang, idioms, cultural references they don't understand
- Spends time copy-pasting to Google Translate
- Worries about formality levels in professional messages
- Misses cultural nuances that affect communication

### Core Pain Points

#### 1. Language Barriers (Critical)
- "I want to chat with my Spanish host family but my Spanish is limited"
- "My colleague writes in French, I respond in English - feels disconnected"
- Constantly switching between messaging app and translation app
- Translations lose context and emotion

#### 2. Translation Nuances (High)
- Google Translate gives literal translations, misses context
- "How do I know if this is formal or casual?"
- Machine translations sound robotic, not natural
- Can't tell tone or emotion in translated text

#### 3. Copy-Paste Overhead (Medium)
- Copy message → Switch to Google Translate → Paste → Copy translation → Switch back
- Disrupts conversation flow
- Takes 15-30 seconds per message
- Frustrating for rapid back-and-forth

#### 4. Learning Difficulty (Medium)
- Want to improve language skills but translations don't help learning
- Don't understand WHY a phrase means what it means
- Miss opportunities to learn from conversations

#### 5. Cultural Context Missing (High)
- "Why did my Japanese friend say 'maybe' when they meant 'no'?"
- "Is '¡Órale!' positive or negative?"
- Literal translation doesn't convey cultural meaning
- Can accidentally offend due to cultural misunderstanding

### What Success Looks Like

**Seamless Communication:**
- Chat naturally in any language without leaving app
- Translations appear instantly, in context
- Understand cultural nuances automatically
- Never miss the meaning behind words

**Language Learning:**
- Improve language skills through conversations
- Understand idioms and slang in context
- See formality levels clearly
- Learn cultural communication patterns

**Confidence:**
- Write messages in foreign languages without fear
- Understand when to be formal vs casual
- Navigate cultural differences easily
- Respond quickly without translation delays

---

## Required AI Features (All 5)

### 1. Real-Time Translation (Inline)
**Problem:** Users waste time copying/pasting between apps, losing conversation flow.

**Solution:** Instant, contextual translation without leaving the chat.

**User Experience:**

**Inline Translation Mode (Default):**
```
Message arrives in Spanish: "¡Hola! ¿Cómo estás?"
User sees:
┌─────────────────────────────┐
│ ¡Hola! ¿Cómo estás?        │
│ 🌐 Tap to translate        │
└─────────────────────────────┘

User taps → Translation appears:
┌─────────────────────────────┐
│ ¡Hola! ¿Cómo estás?        │
│ ━━━━━━━━━━━━━━━━━━         │
│ 🇬🇧 Hello! How are you?    │
│                             │
│ Spanish → English           │
└─────────────────────────────┘
```

**Auto-Translate Mode (Toggle):**
- User enables: "Auto-translate all non-English messages"
- Messages automatically show translation below original
- Can tap to see original if hidden

**Translation Features:**
- Preserves formatting (emojis, line breaks)
- Shows source → target language
- Cached (same message translated once)
- Works offline with cached translations
- Maintains message bubble design

**Technical Requirements:**
- Cloud Function: `translateMessage(messageId, targetLanguage)`
- Cache translations in Firestore: `conversations/{id}/translations/{messageId}`
- LLM preserves tone, emotion, context
- Fallback to Google Translate API for speed
- Response time: < 2 seconds

**Acceptance Criteria:**
- ✅ Translates 50+ languages accurately
- ✅ Inline translation appears in < 2 seconds
- ✅ Auto-translate mode works for all incoming messages
- ✅ Translations cached and persist
- ✅ Original text always accessible
- ✅ Works for text of any length (up to 2000 chars)

---

### 2. Language Detection & Auto-Translate
**Problem:** Users must manually select languages or paste into external tools.

**Solution:** AI automatically detects language and offers translation based on user preferences.

**User Experience:**

**Setup (Profile Settings):**
```
┌─────────────────────────────────┐
│ Languages You're Fluent In:    │
│                                 │
│ ☑ English                       │
│ ☑ French                        │
│ ☐ Spanish                       │
│ ☐ German                        │
│ ☐ Japanese                      │
│ ...                             │
│                                 │
│ [Save Preferences]              │
└─────────────────────────────────┘
```

**Automatic Behavior:**
- Message arrives in Spanish → Auto-detected as "es"
- User's profile: fluent in [en, fr]
- Spanish NOT in fluent list → Offer translation
- If auto-translate enabled → Translate immediately
- If disabled → Show "🌐 Tap to translate" badge

**Detection Display:**
```
┌─────────────────────────────┐
│ Bonjour, comment ça va?    │
│ 🇫🇷 French (detected)       │
│ ━━━━━━━━━━━━━━━━━━         │
│ No translation needed      │
│ (You're fluent in French)  │
└─────────────────────────────┘

vs.

┌─────────────────────────────┐
│ こんにちは                   │
│ 🇯🇵 Japanese (detected)     │
│ 🌐 Tap to translate        │
└─────────────────────────────┘
```

**Technical Requirements:**
- Cloud Function: `detectLanguage(text)` using OpenAI
- User model extended with `fluentLanguages: [String]`
- Logic: if detected ∉ fluentLanguages → offer translation
- Store detected language in message metadata
- 95%+ accuracy for common languages

**Acceptance Criteria:**
- ✅ Detects 50+ languages accurately (95%+)
- ✅ Respects user's fluent language preferences
- ✅ Only offers translation for non-fluent languages
- ✅ Detection happens in < 1 second
- ✅ Handles mixed-language messages (defaults to primary language)
- ✅ Works for messages as short as 3 words

---

### 3. Cultural Context Hints
**Problem:** Users miss cultural nuances that affect meaning and can cause misunderstandings.

**Solution:** AI proactively provides cultural context when culturally significant phrases are detected.

**User Experience:**

**Proactive Context (Default Behavior):**
```
Message: "彼は多分来ないと思います"
Translation: "I think he probably won't come"

┌─────────────────────────────────────┐
│ 彼は多分来ないと思います           │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━         │
│ 🇬🇧 I think he probably won't come │
│                                     │
│ 💡 Cultural Context:                │
│ In Japanese culture, "probably"    │
│ (多分) often means "definitely     │
│ not" when declining. This is an    │
│ indirect way to say "no" politely. │
│                                     │
│ [Learn More] [Dismiss]              │
└─────────────────────────────────────┘
```

**Context Types:**
- **Indirect Communication:** (Japanese "maybe" = "no")
- **Formality Customs:** (German Sie vs Du)
- **Idioms:** (Spanish "me importa un pepino" = "I don't care")
- **Gestures/Emojis:** (👍 offensive in some cultures)
- **Time Concepts:** (Latin American "ahorita" = maybe later, not "right now")
- **Politeness Levels:** (Korean honorifics)

**Settings Control:**
```
┌─────────────────────────────┐
│ Cultural Context Hints      │
│                             │
│ ☑ Show automatically        │
│ ☐ Only when I ask           │
│ ☐ Never show                │
│                             │
│ Hint Frequency:             │
│ ◯ Always                    │
│ ◉ Once per phrase           │
│ ◯ Rarely                    │
└─────────────────────────────┘
```

**Technical Requirements:**
- Cloud Function: `analyzeCulturalContext(text, language, targetLanguage)`
- LLM identifies culturally significant phrases
- Database of common cultural patterns per language
- Show hint once per unique phrase (track in Firestore)
- Dismissible with "Don't show again" option

**Acceptance Criteria:**
- ✅ Detects 20+ common cultural patterns per language
- ✅ Provides accurate, helpful context
- ✅ Non-intrusive (appears below translation)
- ✅ User can disable per conversation or globally
- ✅ Learns user preferences (dismissed hints don't repeat)
- ✅ Context is concise (2-3 sentences max)

---

### 4. Formality Level Adjustment
**Problem:** Users don't know if their message is appropriately formal/casual for the context.

**Solution:** AI analyzes formality and helps users write at the appropriate level.

**User Experience:**

**Incoming Message Analysis:**
```
Message from colleague (German):
"Könnten Sie mir bitte helfen?"

┌─────────────────────────────────────┐
│ Könnten Sie mir bitte helfen?      │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━         │
│ 🇬🇧 Could you please help me?      │
│                                     │
│ 🎩 Formality: FORMAL (Sie)          │
│ This uses the formal "Sie" rather  │
│ than casual "du". Expected in      │
│ professional German contexts.      │
│                                     │
│ ✏️ Reply formally  💬 Reply casually│
└─────────────────────────────────────┘
```

**Outgoing Message Assistance:**
```
User typing: "Hey, can you send that?"

AI suggestion appears:
┌─────────────────────────────────────┐
│ 💡 Formality Check                  │
│                                     │
│ Your message: "Hey, can you send   │
│ that?"                              │
│                                     │
│ Formality: CASUAL                   │
│                                     │
│ To match recipient's style:        │
│ 🎩 Formal version:                  │
│ "Hello, could you please send that │
│ when you have a moment?"            │
│                                     │
│ [Use Formal] [Keep Casual] [Dismiss]│
└─────────────────────────────────────┘
```

**Formality Spectrum:**
- **Very Formal:** Business, officials, strangers (Sie, vous, usted)
- **Formal:** Professional colleagues, acquaintances
- **Neutral:** Standard communication
- **Casual:** Friends, peers (du, tu, tú)
- **Very Casual:** Close friends, family (slang, abbreviations)

**Technical Requirements:**
- Cloud Function: `analyzeFormality(text, language)`
- Cloud Function: `adjustFormality(text, targetFormality, language)`
- LLM detects formality markers (pronouns, verb forms, honorifics)
- Suggests rewrite at different formality levels
- Works in both directions (analyze incoming, adjust outgoing)

**Acceptance Criteria:**
- ✅ Accurately detects formality level (85%+ accuracy)
- ✅ Provides appropriate formal/casual alternatives
- ✅ Works for 20+ languages with formality distinctions
- ✅ Preserves message meaning when adjusting
- ✅ Explains WHY message is formal/casual
- ✅ Optional (user can dismiss/disable)

---

### 5. Slang/Idiom Explanations
**Problem:** Slang and idioms don't translate literally, causing confusion.

**Solution:** AI detects slang/idioms and provides clear explanations with examples.

**User Experience:**

**Auto-Detection (Proactive):**
```
Message: "That's the bee's knees!"

┌─────────────────────────────────────┐
│ That's the bee's knees! 💬          │
│                                     │
│ 📖 Idiom Detected: "bee's knees"   │
│                                     │
│ Meaning: Something excellent or    │
│ outstanding                         │
│                                     │
│ Origin: 1920s American slang,      │
│ nonsense phrase that became        │
│ popular for expressing approval    │
│                                     │
│ Similar to: "the cat's pajamas",   │
│ "top-notch", "awesome"              │
│                                     │
│ Example: "This new phone is the    │
│ bee's knees!"                       │
│                                     │
│ [Got it] [Learn More]               │
└─────────────────────────────────────┘
```

**On-Request (Highlight + Ask):**
```
User long-presses: "¡Órale!"

Menu appears:
┌─────────────────────────────┐
│ Translate                   │
│ Explain Slang/Idiom ✨      │
│ Copy                        │
│ ...                         │
└─────────────────────────────┘

User taps "Explain":
┌─────────────────────────────────────┐
│ 📖 Slang Explanation                │
│                                     │
│ "¡Órale!" (Mexican Spanish)        │
│                                     │
│ Meanings (context-dependent):      │
│ 1. "Wow!" / "Whoa!" (surprise)     │
│ 2. "Right on!" (approval)          │
│ 3. "Let's go!" (encouragement)     │
│ 4. "Hurry up!" (urgency)           │
│                                     │
│ In this context: Likely expressing │
│ surprise or approval                │
│                                     │
│ Cultural note: Very common in      │
│ Mexican Spanish, less so in Spain  │
└─────────────────────────────────────┘
```

**Detection Indicators:**
- 💬 Small badge on messages with detected slang/idioms
- Subtle highlight on the phrase itself
- Tap to expand explanation
- One explanation per unique phrase (doesn't repeat)

**Technical Requirements:**
- Cloud Function: `detectSlangIdioms(text, language)`
- Cloud Function: `explainPhrase(phrase, language, context)`
- LLM identifies non-literal expressions
- Provides: meaning, origin, examples, similar phrases
- Context-aware (same phrase can have multiple meanings)
- Track shown explanations (don't show same one twice)

**Acceptance Criteria:**
- ✅ Detects 100+ common idioms/slang per major language
- ✅ Provides clear, helpful explanations
- ✅ Shows cultural/regional context
- ✅ Includes usage examples
- ✅ Handles multiple meanings (context-dependent)
- ✅ Works in both auto-detect and on-request modes
- ✅ User can disable auto-detection

---

## Advanced Feature: Context-Aware Smart Replies

**Problem:** Responding in foreign languages is slow and stressful. Need to think, translate, check formality.

**Solution:** AI generates 3-5 reply suggestions that match user's writing style, in the correct language and formality level.

**User Experience:**

**Smart Reply Suggestions:**
```
Incoming message (Spanish, casual):
"¿Vamos al cine esta noche?"
(Translation: "Should we go to the movies tonight?")

Smart replies appear above input:
┌─────────────────────────────────────┐
│ 💡 Quick Replies (Spanish)          │
│                                     │
│ 🎬 "¡Claro! ¿A qué hora?"          │
│    (Sure! What time?)               │
│                                     │
│ 📅 "Me encantaría, pero estoy      │
│     ocupado/a"                      │
│    (I'd love to, but I'm busy)     │
│                                     │
│ 🤔 "¿Qué película quieres ver?"    │
│    (What movie do you want to see?)│
│                                     │
│ ❌ "No puedo esta noche, ¿qué tal  │
│     mañana?"                        │
│    (Can't tonight, how about       │
│     tomorrow?)                      │
│                                     │
│ ✏️ Or write your own...            │
└─────────────────────────────────────┘
```

**Learning User Style:**

**After 10+ messages with a contact:**
```
AI learns:
- User signs messages with "Saludos" (not "Atentamente")
- Uses "tú" form with this person (casual)
- Frequently uses "me parece bien" phrase
- Prefers short responses (1-2 sentences)
- Uses emojis moderately (1-2 per message)

Future replies match this style:
"Me parece bien 👍 Nos vemos a las 7"
(instead of formal: "Está bien. Te veré a las 19:00 horas")
```

**Style Matching Features:**
- **Formality:** Matches recipient's level (tú vs usted, etc.)
- **Length:** Short, medium, or long (learns preference)
- **Emoji Usage:** Matches user's patterns
- **Vocabulary:** Uses phrases user frequently uses
- **Tone:** Matches energy level (enthusiastic vs neutral)
- **Cultural Norms:** Follows regional conventions

**Multilingual Support:**
```
Conversation with contact who speaks French:
- AI generates replies in French
- Matches user's French proficiency level
- Uses phrases user knows
- Suggests corrections if user makes common mistakes

User's French improves over time:
- AI gradually introduces more complex phrases
- Adapts to user's growing vocabulary
- Still provides translations for learning
```

**Context Awareness:**
```
Recent conversation context:
User: "I'm working on the presentation"
Contact: "How's it going?"

Smart replies understand context:
✅ "Almost done! Just polishing it" (context-aware)
✅ "Need 30 more minutes" (relevant)
✅ "Going well, thanks!" (appropriate)

❌ "What presentation?" (context-lost)
❌ "I'm hungry" (irrelevant)
```

**Technical Requirements:**
- Cloud Function: `generateSmartReplies(conversationId, incomingMessage, userId)`
- RAG pipeline retrieves last 20 messages for context
- Analyzes user's writing patterns from message history
- LLM generates 3-5 contextually relevant replies
- Matches detected language of incoming message
- Learns preferences over time (stored in AI memory)
- Response time: < 3 seconds

**Learning & Memory:**
```javascript
// Stored in Firestore
ai_assistant_memory/{userId}
  - writingStyle: {
      "contact_id_maria": {
        formality: "casual",
        averageLength: 15, // words
        emojiFrequency: 0.3, // emojis per message
        commonPhrases: ["me parece bien", "¡genial!"],
        signatureStyle: "Saludos"
      }
  }
```

**Acceptance Criteria:**
- ✅ Generates 3-5 relevant replies in < 3 seconds
- ✅ Replies match incoming message language
- ✅ Formality matches conversation context
- ✅ Style adapts to user's patterns after 10+ messages
- ✅ Context-aware (uses conversation history)
- ✅ Improves accuracy over time (learning)
- ✅ Translations provided for non-fluent languages
- ✅ User can edit before sending
- ✅ Works across 20+ languages

---

## Stretch Goal: Intelligent Processing (Multilingual)

**Problem:** Important information (dates, times, locations) gets buried in multilingual conversations.

**Solution:** AI extracts structured data from messages in any language and creates actionable items.

**User Experience:**

**Automatic Extraction:**
```
Message (Spanish): 
"Nos vemos el martes a las 3pm en Café Central"

AI detects structured data:
┌─────────────────────────────────────┐
│ 📅 Event Detected                   │
│                                     │
│ When: Tuesday, 3:00 PM              │
│ Where: Café Central                 │
│ With: Juan (this conversation)      │
│                                     │
│ [Add to Calendar] [Create Reminder] │
│ [Dismiss]                           │
└─────────────────────────────────────┘
```

**Multilingual Extraction Examples:**

**French:**
```
"On se retrouve demain à 18h devant la gare"
→ Extracted: Tomorrow, 6:00 PM, Train Station (location)
```

**Japanese:**
```
"来週の金曜日に会議があります"
→ Extracted: Next Friday, Meeting (event type)
```

**German:**
```
"Treffpunkt ist der Alexanderplatz um 14 Uhr"
→ Extracted: Alexanderplatz (location), 2:00 PM
```

**N8N Integration (Optional):**

**Workflow Trigger:**
1. Message arrives with structured data
2. Cloud Function extracts: date, time, location, participants
3. Sends to N8N webhook
4. N8N workflow:
   - Creates Google Calendar event
   - Adds location to Google Maps
   - Creates Todoist task reminder
   - Sends confirmation back to Firebase

**N8N Workflow Example:**
```
Webhook (Firebase) 
  → Extract Data Node
  → Google Calendar: Create Event
  → Google Maps: Save Location
  → Todoist: Create Task
  → Firebase: Update Message with "✓ Added to calendar"
```

**Data Types Extracted:**
- **Dates/Times:** "next Tuesday", "el viernes", "明日"
- **Locations:** Addresses, landmarks, meeting points
- **Contacts:** Names, phone numbers, emails
- **Events:** Meetings, appointments, reminders
- **Tasks:** Action items, deadlines, assignments

**Technical Requirements:**
- Cloud Function: `extractStructuredData(messageId, text, language)`
- LLM with structured output (JSON)
- Handles 20+ date/time formats across languages
- Geocodes locations when possible
- Optional N8N webhook integration
- Works offline with best-effort (online for accuracy)

**Extracted Data Schema:**
```javascript
{
  type: "event" | "task" | "contact" | "location",
  datetime: ISO8601 string,
  location: {
    name: string,
    address: string?,
    coordinates: { lat, lng }?
  },
  participants: [userId],
  confidence: 0-1, // how sure AI is
  originalText: string,
  language: string
}
```

**Acceptance Criteria:**
- ✅ Extracts dates/times from 20+ languages
- ✅ Handles relative dates ("tomorrow", "next week")
- ✅ Extracts locations with geocoding
- ✅ Identifies participants from conversation
- ✅ Confidence score for accuracy (>80% = show)
- ✅ Creates calendar events in iOS Calendar
- ✅ Optional: N8N integration for external tools
- ✅ Works across all 5 required translation features

---

## AI Assistant Chat Interface

### Overview
A dedicated AI conversation that acts as a multilingual assistant, accessible from the conversation list.

**UI Location:**
- Pinned at top of conversation list
- Special icon: 🤖 "AI Assistant"
- Gradient background to distinguish from regular chats
- Can't be deleted or archived

### Capabilities

**Translation Queries:**
```
User: "Translate my last message to French"
AI: [Retrieves message via RAG, translates]
    "Your message: 'See you tomorrow!'
     French translation: 'À demain!'"

User: "How do you say 'I miss you' in Japanese?"
AI: "In Japanese: '会いたい' (aitai)
     or more formal: 'あなたが恋しいです' (anata ga koishii desu)"
```

**Conversation Analysis:**
```
User: "Summarize my chat with Maria"
AI: [RAG retrieves Maria conversation]
    "Your conversation with Maria (last 7 days):
     - Discussed weekend plans (dinner on Saturday)
     - She asked about your project deadline (you said Monday)
     - Made jokes about the weather
     - Mostly casual Spanish, some English phrases"

User: "What did Juan say about the meeting?"
AI: [Semantic search across conversations]
    "Juan mentioned the meeting in your chat on Tuesday:
     'La reunión es el viernes a las 10' (The meeting is Friday at 10)
     
     [Jump to message]"
```

**Language Help:**
```
User: "Is this formal or casual: 'Podrías ayudarme?'"
AI: "That's FORMAL Spanish.
     - Uses 'podrías' (conditional, polite)
     - Missing accent on 'Podrias' would be error
     
     Casual version: '¿Me ayudas?'
     Very casual: '¿Me echas una mano?'"

User: "What does 'me importa un pepino' mean?"
AI: "That's a Spanish idiom meaning 'I don't care at all'
     Literal: 'I care a cucumber' (nonsensical)
     Similar English idiom: 'I don't give a hoot'
     
     Used in casual contexts, slightly humorous"
```

**Smart Reply Requests:**
```
User: "Help me respond to this: 'Ça te dit d'aller au resto?'"
AI: "They're asking (in French): 'Do you feel like going to a restaurant?'
     
     Here are some natural replies:
     1. Accepting: 'Oui, avec plaisir! Où?' (Yes, with pleasure! Where?)
     2. Declining: 'Désolé(e), je ne peux pas ce soir' (Sorry, I can't tonight)
     3. Suggesting alternative: 'Demain plutôt?' (Tomorrow instead?)"
```

**Memory & Preferences:**
```
User: "Remember I speak Spanish with Maria"
AI: "Got it! I'll remember:
     - Conversation with Maria is in Spanish
     - Generate Spanish replies for her messages
     - Translate her messages to English if needed
     
     [View AI Memory]"

User: "Show my language preferences"
AI: [Displays table from ai_assistant_memory]
    "Your Language Settings:
     - Fluent in: English, French
     - Learning: Spanish (intermediate)
     
     Per-Contact Preferences:
     - Maria: Spanish (casual)
     - Jean: French (formal)
     - Akiko: English (she's learning)
     
     [Edit Preferences]"
```

### RAG Pipeline Architecture

**How RAG Works:**
1. **User Query:** "What did Maria say about dinner?"
2. **Query Embedding:** Generate embedding for query
3. **Semantic Search:** Find relevant messages in vector DB
4. **Context Retrieval:** Get top 10 most relevant messages
5. **LLM Synthesis:** Send context + query to LLM
6. **Response:** AI answers with citations

**Embedding Generation:**
- Cloud Function trigger on message creation
- Generates OpenAI embedding (1536-dim vector)
- Stores in Firestore with message metadata
- Indexed for fast retrieval

**Vector Search:**
- Compute cosine similarity client-side
- Firestore stores embeddings as arrays
- Find top K closest vectors (K=10 for context)
- Filter by conversation if specified

**Context Window:**
```javascript
// Sent to LLM
{
  systemPrompt: "You are a multilingual AI assistant...",
  context: [
    { sender: "Maria", text: "...", timestamp: "...", language: "es" },
    { sender: "User", text: "...", timestamp: "...", language: "en" },
    // ... top 10 relevant messages
  ],
  userQuery: "What did Maria say about dinner?",
  userPreferences: {
    fluentLanguages: ["en", "fr"],
    aiMemory: { /* learned patterns */ }
  }
}
```

### Technical Requirements
- Dedicated conversation document: `conversations/ai_assistant_{userId}`
- Special type: `"ai_assistant"`
- RAG pipeline with embedding search
- Access to all user's conversations (with disclosure)
- Persistent memory in `ai_assistant_memory/{userId}`
- Response streaming for long outputs
- Cloud Functions for all AI operations

### Privacy & Permissions

**Disclosure on First Use:**
```
┌─────────────────────────────────────┐
│ 🤖 Welcome to AI Assistant          │
│                                     │
│ To help you, AI Assistant needs    │
│ access to your messages for:       │
│                                     │
│ ✓ Translation and language help    │
│ ✓ Finding information across chats │
│ ✓ Learning your writing style      │
│ ✓ Remembering your preferences     │
│                                     │
│ Your data:                          │
│ • Stays in your Firebase account   │
│ • Processed securely via OpenAI    │
│ • Not used to train AI models      │
│                                     │
│ [Enable AI Assistant] [Learn More]  │
│ [No Thanks]                         │
└─────────────────────────────────────┘
```

**Settings:**
- User can disable AI Assistant
- View/edit AI memory
- Control which conversations AI can access
- Delete all AI data

---

## Technical Architecture

### Tech Stack

**Frontend (iOS):**
- Swift + SwiftUI (existing MVP)
- iOS 17.0+ (existing requirement)
- MVVM architecture (existing pattern)

**Backend (Firebase):**
- Cloud Functions (Node.js/TypeScript)
- Firestore (existing database)
- Firebase Auth (existing)
- Cloud Storage (existing)

**AI Services:**
- **Primary LLM:** OpenAI GPT-4 Turbo OR Anthropic Claude Sonnet 3.5
  - Translation (contextual, natural)
  - Language detection
  - Cultural context analysis
  - Formality detection/adjustment
  - Slang/idiom explanation
  - Smart reply generation
- **Embeddings:** OpenAI text-embedding-ada-002
  - Message embeddings for RAG
  - Semantic search
  - 1536-dimensional vectors
- **Fallback:** Google Translate API
  - Fast translations for simple text
  - Cost optimization
  - Offline translation cache

**Vector Storage:**
- Firestore with embedding arrays
- Client-side cosine similarity
- Good for <10k messages per user
- Scalable to Pinecone if needed

### Database Schema Extensions

**New Collections:**

```javascript
// AI-specific user preferences
users/{userId}
  - primaryLanguage: "en"
  - fluentLanguages: ["en", "fr"]
  - autoTranslateEnabled: true
  - culturalHintsEnabled: true
  - smartRepliesEnabled: true
  - aiAssistantEnabled: true

// AI Assistant memory
ai_assistant_memory/{userId}
  - preferences: {
      languagePreferences: {
        "contact_user_id": "es",
        "another_user_id": "fr"
      },
      writingStyle: {
        "contact_user_id": {
          formality: "casual",
          averageLength: 15,
          emojiFrequency: 0.3,
          commonPhrases: ["me parece bien", "¡genial!"],
          signatureStyle: "Saludos"
        }
      }
  }
  - conversationContext: {
      lastDiscussed: {
        "conversation_id_1": "dinner plans",
        "conversation_id_2": "work project"
      }
  }
  - learnedPatterns: [
      "User prefers informal Spanish with Maria",
      "User uses formal French with Jean"
  ]
  - dismissedHints: ["japanese_maybe_no", "spanish_pepino_idiom"]
  - createdAt: timestamp
  - updatedAt: timestamp

// Cached translations
translations/{translationId}
  - messageId: string
  - conversationId: string
  - originalText: string
  - originalLanguage: string
  - translatedText: string
  - targetLanguage: string
  - translatedAt: timestamp
  - translationProvider: "openai" | "google" | "claude"
  - detectedFormality: "formal" | "casual" | "neutral"

// Message embeddings for RAG
message_embeddings/{messageId}
  - conversationId: string
  - text: string
  - language: string
  - embedding: array<float> // 1536-dim
  - generatedAt: timestamp
  - userId: string // message sender

// Detected slang/idioms
detected_phrases/{phraseId}
  - messageId: string
  - phrase: string
  - language: string
  - type: "slang" | "idiom" | "cultural"
  - explanation: string
  - examples: [string]
  - shownToUser: boolean
  - detectedAt: timestamp

// Smart reply history (for learning)
smart_reply_usage/{usageId}
  - userId: string
  - conversationId: string
  - suggestedReply: string
  - actualReply: string // what user sent
  - wasUsed: boolean
  - wasEdited: boolean
  - language: string
  - formality: string
  - timestamp: timestamp

// Structured data extraction
extracted_data/{extractionId}
  - messageId: string
  - conversationId: string
  - type: "event" | "task" | "location" | "contact"
  - data: {
      datetime: ISO8601 string?,
      location: {
        name: string,
        address: string?,
        coordinates: {lat: float, lng: float}?
      }?,
      participants: [string],
      description: string
  }
  - confidence: float // 0-1
  - language: string
  - extractedAt: timestamp
  - actionTaken: "calendar" | "reminder" | "none"
```

**Updates to Existing Collections:**

```javascript
// messages collection - add AI metadata
messages/{messageId}
  // ... existing fields ...
  
  // New AI fields
  - detectedLanguage: "es" | "en" | "fr" | etc.
  - languageConfidence: float // 0-1
  - hasTranslation: boolean
  - detectedFormality: "formal" | "casual" | "neutral"
  - containsSlang: boolean
  - containsIdiom: boolean
  - culturalContextProvided: boolean
  - embeddingGenerated: boolean
  - structuredDataExtracted: boolean

// conversations collection - add AI assistant
conversations/ai_assistant_{userId}
  - id: "ai_assistant_{userId}"
  - type: "ai_assistant"
  - participantIds: [userId]
  - aiAssistant: true
  - lastMessage: { ... }
  - createdAt: timestamp
```

### Cloud Functions Architecture

**Modular Functions (Recommended Approach A):**

```typescript
// functions/src/ai/translation.ts
export const translateMessage = functions.https.onCall(async (data, context) => {
  const { messageId, targetLanguage } = data;
  
  // 1. Authenticate user
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  
  // 2. Fetch message
  const messageDoc = await admin.firestore().doc(`messages/${messageId}`).get();
  
  // 3. Check cache
  const cached = await checkTranslationCache(messageId, targetLanguage);
  if (cached) return cached;
  
  // 4. Translate with OpenAI/Claude
  const translation = await openai.chat.completions.create({
    model: "gpt-4-turbo-preview",
    messages: [
      {
        role: "system",
        content: "You are a professional translator. Translate naturally while preserving tone, emotion, and context. Maintain formality level."
      },
      {
        role: "user",
        content: `Translate this ${sourceLanguage} text to ${targetLanguage}:\n\n${originalText}`
      }
    ]
  });
  
  // 5. Cache result
  await cacheTranslation(messageId, targetLanguage, translation);
  
  // 6. Return
  return {
    originalText,
    translatedText: translation.choices[0].message.content,
    originalLanguage: sourceLanguage,
    targetLanguage
  };
});

// functions/src/ai/languageDetection.ts
export const detectLanguage = functions.https.onCall(async (data, context) => {
  const { text } = data;
  
  // Use OpenAI for detection
  const response = await openai.chat.completions.create({
    model: "gpt-4-turbo-preview",
    messages: [
      {
        role: "system",
        content: "Detect the language of the given text. Return only the ISO 639-1 language code (e.g., 'en', 'es', 'fr')."
      },
      { role: "user", content: text }
    ]
  });
  
  const detectedLanguage = response.choices[0].message.content.trim().toLowerCase();
  
  return {
    language: detectedLanguage,
    confidence: 0.95 // OpenAI is highly accurate
  };
});

// functions/src/ai/smartReplies.ts
export const generateSmartReplies = functions.https.onCall(async (data, context) => {
  const { conversationId, incomingMessageId, userId } = data;
  
  // 1. Retrieve context via RAG
  const context = await retrieveConversationContext(conversationId, 20);
  
  // 2. Get user's writing style
  const userStyle = await getUserWritingStyle(userId, conversationId);
  
  // 3. Get incoming message
  const incomingMessage = await getMessageById(incomingMessageId);
  
  // 4. Generate replies
  const replies = await openai.chat.completions.create({
    model: "gpt-4-turbo-preview",
    messages: [
      {
        role: "system",
        content: `Generate 3-5 smart reply suggestions that:
        1. Match the language of the incoming message (${incomingMessage.language})
        2. Match this formality level: ${userStyle.formality}
        3. Are around ${userStyle.averageLength} words
        4. Use emojis at ${userStyle.emojiFrequency} frequency
        5. Sound natural and contextually relevant
        6. Match the user's writing style
        
        Return as JSON array: [{ text: "reply", translation: "English translation if not English" }]`
      },
      {
        role: "user",
        content: `Conversation context:\n${formatContext(context)}\n\nIncoming message: "${incomingMessage.text}"\n\nGenerate replies:`
      }
    ],
    response_format: { type: "json_object" }
  });
  
  return JSON.parse(replies.choices[0].message.content);
});

// functions/src/ai/culturalContext.ts
export const analyzeCulturalContext = functions.https.onCall(async (data, context) => {
  const { text, language, targetLanguage } = data;
  
  const response = await openai.chat.completions.create({
    model: "gpt-4-turbo-preview",
    messages: [
      {
        role: "system",
        content: `Analyze text for cultural context that a ${targetLanguage} speaker should understand when communicating with ${language} speakers. 
        
        Identify:
        1. Indirect communication patterns
        2. Cultural idioms or references
        3. Formality customs
        4. Politeness levels
        5. Time/scheduling concepts
        
        If culturally significant context exists, provide a 2-3 sentence explanation. Otherwise, return null.
        
        Return JSON: { hasContext: boolean, explanation: string | null }`
      },
      { role: "user", content: text }
    ],
    response_format: { type: "json_object" }
  });
  
  return JSON.parse(response.choices[0].message.content);
});

// functions/src/ai/formalityAnalysis.ts
export const analyzeFormality = functions.https.onCall(async (data, context) => {
  const { text, language } = data;
  
  const response = await openai.chat.completions.create({
    model: "gpt-4-turbo-preview",
    messages: [
      {
        role: "system",
        content: `Analyze the formality level of ${language} text on a scale:
        - very_formal: Official, business, strangers
        - formal: Professional, polite
        - neutral: Standard communication
        - casual: Friends, peers
        - very_casual: Close friends, slang
        
        Explain WHY (pronouns, verb forms, vocabulary).
        
        Return JSON: { 
          formality: "very_formal" | "formal" | "neutral" | "casual" | "very_casual",
          explanation: string,
          markers: [string] // specific words/phrases indicating formality
        }`
      },
      { role: "user", content: text }
    ],
    response_format: { type: "json_object" }
  });
  
  return JSON.parse(response.choices[0].message.content);
});

export const adjustFormality = functions.https.onCall(async (data, context) => {
  const { text, targetFormality, language } = data;
  
  const response = await openai.chat.completions.create({
    model: "gpt-4-turbo-preview",
    messages: [
      {
        role: "system",
        content: `Rewrite the ${language} text to be ${targetFormality}. Preserve meaning and tone while adjusting formality markers (pronouns, verbs, vocabulary).`
      },
      { role: "user", content: text }
    ]
  });
  
  return {
    original: text,
    adjusted: response.choices[0].message.content,
    targetFormality
  };
});

// functions/src/ai/slangIdioms.ts
export const detectSlangIdioms = functions.https.onCall(async (data, context) => {
  const { text, language } = data;
  
  const response = await openai.chat.completions.create({
    model: "gpt-4-turbo-preview",
    messages: [
      {
        role: "system",
        content: `Identify slang terms and idioms in ${language} text. For each:
        1. Exact phrase
        2. Type (slang/idiom)
        3. Meaning
        4. Origin/cultural context
        5. Similar expressions
        6. Usage examples
        
        Return JSON: {
          detected: [
            {
              phrase: string,
              type: "slang" | "idiom",
              meaning: string,
              origin: string,
              similar: [string],
              examples: [string]
            }
          ]
        }`
      },
      { role: "user", content: text }
    ],
    response_format: { type: "json_object" }
  });
  
  return JSON.parse(response.choices[0].message.content);
});

export const explainPhrase = functions.https.onCall(async (data, context) => {
  const { phrase, language, messageContext } = data;
  
  const response = await openai.chat.completions.create({
    model: "gpt-4-turbo-preview",
    messages: [
      {
        role: "system",
        content: `Explain the ${language} phrase "${phrase}" in context. Include:
        1. Literal vs actual meaning
        2. Multiple meanings if context-dependent
        3. Origin/etymology
        4. Cultural significance
        5. Usage examples
        6. Similar expressions in other languages
        
        Be clear, concise, and helpful for language learners.`
      },
      { role: "user", content: `Context: "${messageContext}"\n\nExplain: "${phrase}"` }
    ]
  });
  
  return {
    phrase,
    explanation: response.choices[0].message.content
  };
});

// functions/src/ai/embeddings.ts
export const generateEmbedding = functions.firestore
  .document('messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    
    // Skip if already has embedding
    if (message.embeddingGenerated) return;
    
    // Generate embedding
    const response = await openai.embeddings.create({
      model: "text-embedding-ada-002",
      input: message.text
    });
    
    const embedding = response.data[0].embedding;
    
    // Store in message_embeddings collection
    await admin.firestore().collection('message_embeddings').doc(snap.id).set({
      conversationId: message.conversationId,
      text: message.text,
      language: message.detectedLanguage || 'unknown',
      embedding: embedding,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      userId: message.senderId
    });
    
    // Mark message as having embedding
    await snap.ref.update({ embeddingGenerated: true });
  });

// functions/src/ai/semanticSearch.ts
export const semanticSearch = functions.https.onCall(async (data, context) => {
  const { query, userId, conversationId, limit = 10 } = data;
  
  // 1. Generate query embedding
  const queryEmbedding = await openai.embeddings.create({
    model: "text-embedding-ada-002",
    input: query
  });
  
  // 2. Fetch user's message embeddings
  let embeddingsQuery = admin.firestore()
    .collection('message_embeddings')
    .where('userId', '==', userId);
  
  if (conversationId) {
    embeddingsQuery = embeddingsQuery.where('conversationId', '==', conversationId);
  }
  
  const embeddingsSnapshot = await embeddingsQuery.get();
  
  // 3. Compute cosine similarity (client-side in iOS, but showing logic)
  const results = embeddingsSnapshot.docs.map(doc => {
    const data = doc.data();
    const similarity = cosineSimilarity(queryEmbedding.data[0].embedding, data.embedding);
    
    return {
      messageId: doc.id,
      conversationId: data.conversationId,
      text: data.text,
      similarity,
      language: data.language
    };
  });
  
  // 4. Sort by similarity and return top K
  const topResults = results
    .sort((a, b) => b.similarity - a.similarity)
    .slice(0, limit);
  
  return { results: topResults };
});

// functions/src/ai/structuredExtraction.ts (Stretch Goal)
export const extractStructuredData = functions.https.onCall(async (data, context) => {
  const { messageId, text, language } = data;
  
  const response = await openai.chat.completions.create({
    model: "gpt-4-turbo-preview",
    messages: [
      {
        role: "system",
        content: `Extract structured data from ${language} text:
        - Dates/times (convert to ISO8601)
        - Locations (names, addresses)
        - Participants (names, contacts)
        - Event type (meeting, dinner, etc.)
        
        Handle relative dates ("tomorrow", "next week").
        Return confidence score (0-1).
        
        Return JSON: {
          type: "event" | "task" | "location" | null,
          datetime: string?, // ISO8601
          location: { name: string, address: string? }?,
          participants: [string],
          description: string?,
          confidence: float
        }`
      },
      { role: "user", content: text }
    ],
    response_format: { type: "json_object" }
  });
  
  const extracted = JSON.parse(response.choices[0].message.content);
  
  // Store if confidence > 0.8
  if (extracted.type && extracted.confidence > 0.8) {
    await admin.firestore().collection('extracted_data').add({
      messageId,
      conversationId: data.conversationId,
      ...extracted,
      extractedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }
  
  return extracted;
});

// Helper function
function cosineSimilarity(vecA: number[], vecB: number[]): number {
  const dotProduct = vecA.reduce((sum, a, i) => sum + a * vecB[i], 0);
  const magnitudeA = Math.sqrt(vecA.reduce((sum, a) => sum + a * a, 0));
  const magnitudeB = Math.sqrt(vecB.reduce((sum, b) => sum + b * b, 0));
  return dotProduct / (magnitudeA * magnitudeB);
}
```

### iOS Implementation

**New Files to Create:**

```swift
// Services/AIService.swift
@MainActor
class AIService: ObservableObject {
    static let shared = AIService()
    private let functions = Functions.functions()
    
    // Translation
    func translateMessage(messageId: String, targetLanguage: String) async throws -> Translation {
        let result = try await functions.httpsCallable("translateMessage").call([
            "messageId": messageId,
            "targetLanguage": targetLanguage
        ])
        return try parseTranslation(result.data)
    }
    
    // Language Detection
    func detectLanguage(text: String) async throws -> LanguageDetection {
        let result = try await functions.httpsCallable("detectLanguage").call([
            "text": text
        ])
        return try parseLanguageDetection(result.data)
    }
    
    // Smart Replies
    func generateSmartReplies(conversationId: String, incomingMessageId: String, userId: String) async throws -> [SmartReply] {
        let result = try await functions.httpsCallable("generateSmartReplies").call([
            "conversationId": conversationId,
            "incomingMessageId": incomingMessageId,
            "userId": userId
        ])
        return try parseSmartReplies(result.data)
    }
    
    // Cultural Context
    func analyzeCulturalContext(text: String, language: String, targetLanguage: String) async throws -> CulturalContext? {
        let result = try await functions.httpsCallable("analyzeCulturalContext").call([
            "text": text,
            "language": language,
            "targetLanguage": targetLanguage
        ])
        return try parseCulturalContext(result.data)
    }
    
    // Formality
    func analyzeFormality(text: String, language: String) async throws -> FormalityAnalysis {
        let result = try await functions.httpsCallable("analyzeFormality").call([
            "text": text,
            "language": language
        ])
        return try parseFormalityAnalysis(result.data)
    }
    
    func adjustFormality(text: String, targetFormality: FormalityLevel, language: String) async throws -> String {
        let result = try await functions.httpsCallable("adjustFormality").call([
            "text": text,
            "targetFormality": targetFormality.rawValue,
            "language": language
        ])
        return try parseAdjustedText(result.data)
    }
    
    // Slang/Idioms
    func detectSlangIdioms(text: String, language: String) async throws -> [DetectedPhrase] {
        let result = try await functions.httpsCallable("detectSlangIdioms").call([
            "text": text,
            "language": language
        ])
        return try parseDetectedPhrases(result.data)
    }
    
    func explainPhrase(phrase: String, language: String, messageContext: String) async throws -> PhraseExplanation {
        let result = try await functions.httpsCallable("explainPhrase").call([
            "phrase": phrase,
            "language": language,
            "messageContext": messageContext
        ])
        return try parsePhraseExplanation(result.data)
    }
    
    // Semantic Search
    func semanticSearch(query: String, userId: String, conversationId: String? = nil) async throws -> [SearchResult] {
        let result = try await functions.httpsCallable("semanticSearch").call([
            "query": query,
            "userId": userId,
            "conversationId": conversationId as Any
        ])
        return try parseSearchResults(result.data)
    }
    
    // Structured Extraction (Stretch)
    func extractStructuredData(messageId: String, text: String, language: String, conversationId: String) async throws -> StructuredData? {
        let result = try await functions.httpsCallable("extractStructuredData").call([
            "messageId": messageId,
            "text": text,
            "language": language,
            "conversationId": conversationId
        ])
        return try parseStructuredData(result.data)
    }
}

// Models/AIModels.swift
struct Translation: Codable {
    let originalText: String
    let translatedText: String
    let originalLanguage: String
    let targetLanguage: String
}

struct LanguageDetection: Codable {
    let language: String
    let confidence: Double
}

struct SmartReply: Codable, Identifiable {
    let id = UUID()
    let text: String
    let translation: String?
    let formality: String?
}

struct CulturalContext: Codable {
    let hasContext: Bool
    let explanation: String?
}

enum FormalityLevel: String, Codable {
    case veryFormal = "very_formal"
    case formal = "formal"
    case neutral = "neutral"
    case casual = "casual"
    case veryCasual = "very_casual"
}

struct FormalityAnalysis: Codable {
    let formality: FormalityLevel
    let explanation: String
    let markers: [String]
}

struct DetectedPhrase: Codable, Identifiable {
    let id = UUID()
    let phrase: String
    let type: PhraseType
    let meaning: String
    let origin: String
    let similar: [String]
    let examples: [String]
    
    enum PhraseType: String, Codable {
        case slang, idiom
    }
}

struct PhraseExplanation: Codable {
    let phrase: String
    let explanation: String
}

struct SearchResult: Codable, Identifiable {
    let id: String // messageId
    let conversationId: String
    let text: String
    let similarity: Double
    let language: String
}

struct StructuredData: Codable {
    let type: DataType?
    let datetime: String?
    let location: Location?
    let participants: [String]
    let description: String?
    let confidence: Double
    
    enum DataType: String, Codable {
        case event, task, location
    }
    
    struct Location: Codable {
        let name: String
        let address: String?
    }
}

// Models/User.swift (extend existing)
extension User {
    var primaryLanguage: String { "en" }
    var fluentLanguages: [String] { ["en"] }
    var autoTranslateEnabled: Bool { true }
    var culturalHintsEnabled: Bool { true }
    var smartRepliesEnabled: Bool { true }
    var aiAssistantEnabled: Bool { true }
}
```

---

## Implementation Priorities

### Must-Have (P0) - Required for Passing Grade
1. ✅ Real-time translation (inline)
2. ✅ Language detection & auto-translate
3. ✅ Cultural context hints
4. ✅ Formality level adjustment
5. ✅ Slang/idiom explanations
6. ✅ Context-aware smart replies (advanced feature)
7. ✅ AI Assistant chat interface
8. ✅ RAG pipeline for semantic search

### Should-Have (P1) - For Higher Grade
1. ✅ View AI Memory UI
2. ✅ Translation caching
3. ✅ Auto-translate mode toggle
4. ✅ Smart reply learning over time
5. ✅ Formality matching in replies
6. ✅ Cultural hint personalization

### Nice-to-Have (P2) - Stretch Goals
1. ⭐ Intelligent processing (structured data extraction)
2. ⭐ N8N integration for calendar/tasks
3. ⭐ Offline translation cache
4. ⭐ Multi-turn conversation with AI Assistant
5. ⭐ Language learning progress tracking

---

## Success Metrics

### Quantitative (Rubric-Based)

**AI Features Implementation (30 points total):**
- Required features (15 points): All 5 features working excellently
  - Translation accuracy: 90%+ natural translations
  - Language detection: 95%+ accuracy
  - Cultural hints: 80%+ relevance
  - Formality detection: 85%+ accuracy
  - Slang/idiom: 90%+ helpful explanations

- Advanced feature (10 points): Smart replies
  - Response time: < 3 seconds
  - Quality: 85%+ contextually relevant
  - Style matching: Adapts after 10+ messages
  - Multi-language: Works in 20+ languages

- Persona fit (5 points):
  - Clear mapping to International Communicator pain points
  - Daily usefulness demonstrated
  - Solves real problems for multilingual users

**Technical Excellence (10 points):**
- Clean architecture: Modular Cloud Functions
- Security: API keys never exposed
- RAG pipeline: Working semantic search
- Function calling: Proper implementation
- Rate limiting: Smart caching strategy

### Qualitative

**User Experience:**
- Seamless: AI features don't disrupt conversation flow
- Fast: All features respond in < 3 seconds
- Natural: Translations sound human, not robotic
- Helpful: Cultural hints add genuine value
- Learnable: User improves language skills through use

**Demo Quality:**
- Clear demonstration of all 5 required features
- Impressive advanced feature (smart replies)
- Real-world scenarios (not contrived)
- Smooth, polished UI
- "Wow" factor for reviewers

---

## Out of Scope (Phase 2)

### Not Building
- Voice message transcription/translation
- Real-time voice translation
- Custom ML model training
- Integration with external translation APIs (beyond Google)
- Multi-device sync (already handled by Firebase)
- End-to-end encryption
- Offline AI features (embeddings only online)
- Automated language proficiency assessment
- Gamification / language learning rewards
- Translation history export

---

## Risk Mitigation

### High-Risk Areas

**1. LLM API Costs**
- **Risk:** OpenAI costs could be high with frequent translations
- **Mitigation:** 
  - Aggressive caching (same message translated once)
  - Google Translate fallback for simple text
  - Rate limiting per user
  - Batch processing where possible
- **Backup:** Set spending limits, monitor usage

**2. Translation Quality**
- **Risk:** AI translations might be inaccurate or unnatural
- **Mitigation:**
  - Extensive prompt engineering
  - Test with native speakers
  - Allow user to report bad translations
  - Fallback to Google Translate
- **Backup:** Human review for demo examples

**3. Language Detection Accuracy**
- **Risk:** Mixed-language messages might confuse detection
- **Mitigation:**
  - OpenAI is highly accurate (95%+)
  - Default to user's primary language if unsure
  - Allow manual language selection
- **Backup:** Let user override detected language

**4. RAG Pipeline Performance**
- **Risk:** Semantic search might be slow with many messages
- **Mitigation:**
  - Client-side cosine similarity is fast
  - Limit search to top 100 conversations
  - Cache embeddings aggressively
  - Background generation
- **Backup:** Keyword search fallback

**5. Smart Reply Relevance**
- **Risk:** Suggested replies might be irrelevant or awkward
- **Mitigation:**
  - Extensive context (20 messages)
  - User writing style analysis
  - Test with real conversations
  - User can always ignore suggestions
- **Backup:** Disable feature if quality poor

**6. Cultural Context Overload**
- **Risk:** Too many hints might annoy users
- **Mitigation:**
  - Show each hint only once
  - User toggle to disable
  - Only for truly significant cultural patterns
  - Dismissible
- **Backup:** Default to disabled, opt-in

---

## Timeline & Milestones

### Day 2-3: Core Infrastructure & Translation
- Set up Cloud Functions project
- Implement translation function
- Implement language detection
- Build translation UI (inline + auto-translate)
- Test with 10+ languages
- Cache translations in Firestore

**Deliverable:** Basic translation working in-app

### Day 3-4: Cultural Context & Formality
- Implement cultural context analysis
- Implement formality detection/adjustment
- Build UI for cultural hints
- Build formality analysis display
- Test with various languages and contexts

**Deliverable:** Cultural and formality features working

### Day 4-5: Slang/Idioms & Smart Replies
- Implement slang/idiom detection
- Build explanation UI
- Implement smart reply generation
- Build writing style learning
- Test reply quality

**Deliverable:** All 5 required features + advanced feature