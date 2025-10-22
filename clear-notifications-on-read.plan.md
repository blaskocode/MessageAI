<!-- 263f665c-b8e3-4a8a-a190-855d0cc747c6 35bfe69b-3dd0-4814-9621-5eb948348ffd -->
# Clear Notifications When Messages Are Read

## Problem

Local notifications remain visible even after the user reads messages through the conversation list, because notifications use random UUID identifiers that can't be tracked.

## Solution

Use the conversationId as the notification identifier, enabling targeted removal when messages are marked as read.

## Implementation Steps

### 1. Update NotificationService.swift (line 89)

**Change notification identifier from random UUID to conversationId:**

```swift
// Before:
let request = UNNotificationRequest(
    identifier: UUID().uuidString,
    content: content,
    trigger: trigger
)

// After:
let request = UNNotificationRequest(
    identifier: conversationId,  // Use conversationId for tracking
    content: content,
    trigger: nil  // Immediate delivery with persistence
)
```

This allows multiple messages from the same conversation to update the same notification rather than creating duplicates.

### 2. Add clearNotifications method to NotificationService.swift

**Add new method after clearBadgeCount() (around line 115):**

```swift
/// Clears notifications for a specific conversation
func clearNotificationsForConversation(conversationId: String) {
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [conversationId])
}
```

### 3. Call clearNotifications in ChatViewModel.swift

**Update markMessagesAsRead() method (around line 245-260):**

Find the existing `markMessagesAsRead()` method and add the notification clearing call at the end:

```swift
func markMessagesAsRead() {
    // ... existing code ...
    
    // Clear any lingering notifications for this conversation
    NotificationService.shared.clearNotificationsForConversation(conversationId: conversationId)
}
```

### 4. Add .list Presentation Option (Critical Fix)

**Update NotificationService.swift delegate method (line 141):**

```swift
// Before:
completionHandler([.banner, .sound, .badge])

// After:
completionHandler([.banner, .list, .sound, .badge])
//                         ^^^^^ Required for notification center persistence
```

**Why this matters:** Without `.list`, notifications only show as banners but don't persist in the notification center when users drag down from the top.

## Expected Behavior After Fix

1. User receives message → Notification banner appears and persists in notification center
2. User can drag down to see notification in notification list
3. User opens conversation (without tapping notification) → Messages marked as read → Notification automatically clears
4. Badge count already decrements correctly (existing behavior maintained)

## Files Modified

- `MessageAI-Xcode/MessageAI-Xcode/MessageAI/Services/NotificationService.swift` (3 changes)
  - Line 87: Changed identifier to conversationId
  - Line 118: Added clearNotificationsForConversation() method
  - Line 141: Added .list to presentation options
- `MessageAI-Xcode/MessageAI-Xcode/MessageAI/Features/Chat/ChatViewModel.swift` (1 change)
  - Line 291: Call clearNotificationsForConversation() in markMessagesAsRead()

## Status

✅ **COMPLETE** - All fixes implemented and tested successfully

