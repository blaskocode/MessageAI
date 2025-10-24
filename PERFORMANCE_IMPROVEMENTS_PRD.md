# Performance & UX Improvements PRD

## Executive Summary

This PRD outlines critical performance and user experience improvements to MessageAI, focusing on four key areas: intelligent autoscroll behavior, message pagination for long conversations, profile image caching, and AI response speed optimization. These improvements will make the app feel faster, smoother, and more professional, matching the UX quality of industry-standard messaging apps like iMessage and WhatsApp.

## Problem Statement

### Current Issues

1. **Autoscroll Interruptions**: Four competing scroll handlers always force scroll to bottom, interrupting users reading message history. Content changes (badges, translations) can push content off-screen.

2. **Performance Degradation**: Loading all messages on chat open causes slow initial load times for long conversations (500+ messages), excessive memory usage, and poor performance.

3. **Slow Profile Pictures**: Profile images reload from network every time, causing flickering and slow rendering.

4. **Slow AI Features**: Current AI model (GPT-4 Turbo) takes 3-8 seconds for responses, creating perceived lag.

### User Impact

- Users reading old messages get interrupted by new content
- Long conversations take 3-5 seconds to open
- Profile pictures flicker and reload unnecessarily
- AI features feel sluggish compared to other app interactions

## Goals & Success Metrics

### Goals

1. **Smooth, Non-Intrusive UX**: Users can read message history without interruption
2. **Fast Initial Load**: Conversations open in < 1 second regardless of length
3. **Instant Profile Pictures**: Images load from cache immediately
4. **Responsive AI**: AI features respond in < 2 seconds

### Success Metrics

- Initial chat load time: < 1 second (currently 3-5 seconds for long chats)
- AI response time: < 2 seconds (currently 3-8 seconds)
- Profile image load time: < 100ms from cache (currently 500-1000ms from network)
- Zero user complaints about scroll interruptions
- Memory usage: < 50MB for 500 message conversation (currently 150MB+)

## Solution Overview

### 1. Sticky-Bottom Autoscroll

**Concept**: Only auto-scroll when user is at/near bottom of conversation. If user has scrolled up to read history, don't interrupt them.

**Implementation**:
- Track scroll position using SwiftUI `GeometryReader` and `PreferenceKey`
- Calculate precise distance from actual content bottom (within 100 points = "at bottom")
- Unified `contentVersion` counter tracks all content changes (new messages, badges, translations)
- Single scroll handler replaces 4 competing handlers
- Only triggers scroll when `isAtBottom == true`

**Benefits**:
- Natural, non-intrusive behavior matching iMessage/WhatsApp
- Fixes content going off-screen
- Eliminates jarring scroll jumps
- Preserves user's reading position

### 2. Automatic Message Pagination

**Concept**: Load 50 most recent messages initially, automatically load more as user scrolls up (no "Load More" button).

**Implementation**:
- Initial load: Firestore query with `.limit(50)` and real-time listener
- Separate listener for new messages arriving after initial load (bulletproof real-time)
- Pagination trigger: When user scrolls within 5 messages of top
- Debounce mechanism prevents duplicate loads
- Preserve scroll position at same message during load (LazyVStack prepending)
- After 2 failed retry attempts: Show inline error "Couldn't load messages. Tap to retry"
- AI features available on paginated messages (cache checked first)
- Smart Replies ONLY for new incoming messages (not paginated history)

**Benefits**:
- Fast initial load (50 messages vs 500+)
- Seamless infinite scroll like iMessage
- Reduced memory usage (only renders visible messages)
- Better network efficiency

### 3. Profile Image Caching

**Concept**: Aggressive URLCache configuration + ETag support for instant image loads with background freshness checks.

**Implementation**:
- Configure `URLCache` with 50MB memory, 200MB disk
- Dedicated cache directory: `ProfileImageCache`
- Firebase Storage ETags automatically handled
- Disable animation on cache hit to prevent flickering
- Images load instantly from cache, silently refresh in background

**Benefits**:
- Instant profile picture rendering
- No flickering or reloading
- Matches iMessage/WhatsApp behavior
- Automatic cache invalidation via ETags

### 4. AI Model Switch (GPT-4o-mini)

**Concept**: Replace `gpt-4-turbo-preview` with `gpt-4o-mini` across all Cloud Functions.

**Implementation**:
- Update 12 occurrences across 8 Cloud Function files
- No prompt changes required (same API)
- Redeploy all functions

**Benefits**:
- 2-3x faster response times (2-3 seconds vs 5-8 seconds)
- 60x cheaper ($0.15/1M input tokens vs $10/1M)
- Minimal quality loss (GPT-4o-mini still highly capable)
- Better user experience (responsive AI)

## Technical Architecture

### iOS (SwiftUI)

**New State Variables**:
```swift
// ChatViewModel
@Published var contentVersion: Int = 0
@Published var isAtBottom: Bool = true
@Published var isLoadingMore = false
@Published var canLoadMore = true
@Published var paginationError: String?
@Published var isPaginationTriggered = false
private var lastLoadedMessage: DocumentSnapshot?
private var newMessageListener: ListenerRegistration?
private let pageSize = 50
```

**Scroll Tracking**:
- `ScrollOffsetPreferenceKey` custom PreferenceKey
- GeometryReader in LazyVStack background
- Precise distance calculation from content bottom

**Pagination Flow**:
1. User opens chat → Load 50 recent + start new message listener
2. User scrolls to 5th message from top → Trigger `loadMoreMessages()`
3. Check `isPaginationTriggered` flag (debounce)
4. Fetch 50 older messages with cursor
5. Prepend to messages array (preserves scroll position)
6. Reset debounce flag

### Backend (Firebase Cloud Functions)

**No changes required** - Only model name swap:
```typescript
// Before
model: 'gpt-4-turbo-preview'

// After
model: 'gpt-4o-mini'
```

**Files to update**:
- `ai/translation.ts`
- `ai/languageDetection.ts`
- `ai/cultural.ts`
- `ai/formality.ts`
- `ai/slang.ts`
- `ai/smartReplies.ts`
- `ai/assistant.ts`
- `ai/structuredData.ts`

### Firebase (Firestore)

**New Query Methods**:
```swift
// Initial load: 50 recent with real-time listener
fetchRecentMessages(conversationId, limit: 50)

// New messages after initial load
fetchNewMessages(conversationId, after: timestamp)

// Pagination: 50 older before cursor
fetchMessagesBefore(conversationId, before: snapshot, limit: 50)
```

**Composite Index** (if filtering by participant in future):
```
conversations/{conversationId}/messages
- timestamp (descending)
- participants (array-contains)
```

## User Experience Flows

### Scenario 1: Opening a Long Conversation

**Before**:
1. Tap conversation → Loading spinner (3-5 seconds)
2. All 500 messages load at once
3. Profile pictures load one-by-one (flickering)
4. Finally renders chat

**After**:
1. Tap conversation → Instantly shows 50 recent messages (< 1 second)
2. Profile pictures appear instantly from cache
3. Scroll up → More messages load automatically as needed
4. Smooth, fast experience

### Scenario 2: Reading Old Messages While New Arrive

**Before**:
1. User scrolls up to read message from 2 weeks ago
2. New message arrives → Scroll jumps to bottom (interruption)
3. User loses reading position, frustrated

**After**:
1. User scrolls up to read old messages (`isAtBottom = false`)
2. New message arrives → Silently appends to bottom
3. User continues reading, uninterrupted
4. When user scrolls back to bottom → Sees new message

### Scenario 3: Using AI Features on Old Messages

**Before**:
1. User scrolls to old message
2. Taps translate → Works (no cache)
3. Takes 3-5 seconds for translation

**After**:
1. User scrolls to old message (paginated or cached)
2. Taps translate → Checks cache first
3. If cached: Instant (< 100ms)
4. If not cached: Fast API call (< 2 seconds with GPT-4o-mini)
5. Smart Replies NEVER appear on old messages (only new incoming)

### Scenario 4: Profile Pictures

**Before**:
1. User opens chat → Profile pictures load from network
2. Close and reopen chat → Pictures reload (flicker)
3. Slow, annoying experience

**After**:
1. User opens chat → Profile pictures instant from cache
2. Background check: If updated, silently refresh
3. Close and reopen → Still instant
4. Smooth, professional feel

## Edge Cases & Error Handling

### Pagination Failures

**Scenario**: Network error while loading older messages

**Handling**:
1. First failure: Auto-retry after 0.5 seconds (silent)
2. Second failure: Auto-retry after 0.5 seconds (silent)
3. After 2 retries: Show inline error "Couldn't load messages. Tap to retry"
4. User taps → Reset retry counter, try again
5. If persistent: Error remains visible until success

### Race Conditions

**Scenario**: User rapidly scrolls through top 5 messages

**Handling**:
- `isPaginationTriggered` flag prevents duplicate loads
- Only one `loadMoreMessages()` call at a time
- Subsequent triggers wait until first completes

### New Messages During Pagination

**Scenario**: User loading old messages while new message arrives

**Handling**:
- Separate listeners: `recentMessagesListener` + `newMessageListener`
- New messages trigger `contentVersion++`
- If `isAtBottom = true`: Auto-scroll
- If `isAtBottom = false`: Silent append, no scroll
- Smart Replies only trigger for new messages (not paginated)

### Cache Staleness

**Scenario**: User changes profile picture

**Handling**:
- URLCache respects Firebase Storage ETags
- On app open: Shows cached image instantly
- Background check: Requests with `If-None-Match` header
- If changed: 200 response, new image, cache updated
- If unchanged: 304 response, keeps cached version
- Update appears within 1-2 seconds without flicker

### First Message Reached

**Scenario**: User scrolls to very first message in conversation

**Handling**:
- `canLoadMore = false` when fetched count < `pageSize`
- No loading indicator at top
- Show subtle text "Beginning of conversation" with timestamp

## Testing Strategy

### Automated Tests (Unit)

**ChatViewModel**:
- `test_contentVersion_incrementsOnNewMessage()`
- `test_contentVersion_incrementsOnTranslation()`
- `test_isAtBottom_tracksScrollPosition()`
- `test_pagination_debounce()`
- `test_pagination_retryLogic()`
- `test_smartReplies_onlyForNewMessages()`

**FirebaseService**:
- `test_fetchRecentMessages_limit50()`
- `test_fetchMessagesBefore_cursor()`
- `test_fetchNewMessages_afterTimestamp()`

### Manual Testing (QA Checklist)

**Autoscroll (Sticky Bottom)**:
- [ ] User at bottom → new message auto-scrolls
- [ ] User reading history → no interruption
- [ ] Formality badge loads → scrolls only if at bottom
- [ ] Translation appears → scrolls only if at bottom
- [ ] Keyboard opens → scrolls only if at bottom
- [ ] Content never goes off-screen
- [ ] Typing indicator appears → smooth, no jumps

**Pagination**:
- [ ] Initial load shows ~50 messages in < 1 second
- [ ] Scroll to top → auto-loads more (no button)
- [ ] Scroll position stays at same message during load
- [ ] Loading spinner appears briefly at top
- [ ] After 2 failed retries → shows error
- [ ] Tapping error text retries successfully
- [ ] Can translate/analyze old messages (uses cache)
- [ ] No Smart Replies on old messages
- [ ] Smart Replies appear for new incoming messages
- [ ] Rapid scrolling doesn't trigger duplicate loads

**Image Caching**:
- [ ] First load → pictures load quickly
- [ ] Reopen app → profile pictures instant
- [ ] No flickering or reloading
- [ ] Background refresh works (change profile pic, reopen app)

**AI Speed**:
- [ ] Translation: < 2 seconds
- [ ] Cultural context: < 2 seconds
- [ ] Formality analysis: < 2 seconds
- [ ] Slang detection: < 2 seconds
- [ ] Smart replies: < 2 seconds
- [ ] AI Assistant: < 2 seconds
- [ ] Quality still high (no degradation)

### Performance Testing

**Metrics to Track**:
- Initial chat load time (target: < 1 second)
- Memory usage for 500 message conversation (target: < 50MB)
- AI response times (target: < 2 seconds average)
- Profile image load time from cache (target: < 100ms)
- Scroll FPS during content changes (target: 60 FPS)

## Launch Plan

### Phase 1: iOS UI Changes (PR #11)
- Sticky-bottom autoscroll
- Message pagination
- Profile image caching
- **Risk**: Low (UI-only changes, no backend impact)
- **Rollback**: Revert commits, redeploy

### Phase 2: Backend Model Switch (PR #12)
- Update all Cloud Functions to GPT-4o-mini
- Deploy and monitor
- **Risk**: Low (same API, proven model)
- **Rollback**: Revert to gpt-4-turbo-preview, redeploy

### Phase 3: Testing & Iteration
- QA testing checklist
- Performance monitoring
- User feedback collection
- Bug fixes if needed

## Dependencies

- **iOS**: SwiftUI (iOS 16+), Firebase SDK 10.x
- **Backend**: Firebase Cloud Functions, OpenAI API (gpt-4o-mini)
- **Storage**: Firebase Storage with ETag support

## Open Questions

1. **Pagination page size**: 50 messages optimal? (Can adjust based on testing)
2. **Cache size**: 200MB disk cache sufficient? (Can increase if needed)
3. **Bottom threshold**: 100 points optimal? (Can fine-tune based on user feedback)

## Success Criteria (Definition of Done)

- [ ] All automated tests passing
- [ ] All manual QA checklist items passing
- [ ] Initial chat load < 1 second (measured)
- [ ] AI responses < 2 seconds average (measured)
- [ ] Profile images < 100ms from cache (measured)
- [ ] Memory usage < 50MB for 500 messages (measured)
- [ ] Zero scroll interruptions during history reading
- [ ] Code review approved
- [ ] Documentation updated (README, memory bank)
- [ ] Deployed to production

## Future Enhancements

- **Smart prefetching**: Load next 50 messages before user reaches top
- **Batch cache reads**: Fetch formality/slang cache for all 50 messages in one query
- **Background sync**: Preload recent conversations in background
- **Adaptive page size**: Adjust based on device performance
- **Scroll velocity tracking**: Predict user intent, prefetch accordingly

