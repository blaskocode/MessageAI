//
//  NotificationService.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import Foundation
import UIKit
import UserNotifications

/// Handles local notification setup and management
@MainActor
class NotificationService: NSObject, ObservableObject {

    static let shared = NotificationService()

    /// Tracks which conversation is currently active to avoid duplicate notifications
    @Published var activeConversationId: String?

    /// Tracks unread message count for badge
    @Published private(set) var unreadCount: Int = 0

    private override init() {
        super.init()
        setupNotifications()
    }

    func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
        requestPermission()
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if !granted {
                print("❌ Notification permission denied: \(error?.localizedDescription ?? "Unknown")")
            }
        }
    }

    // MARK: - Local Notification Methods

    /// Triggers a local notification for a new message
    /// - Parameters:
    ///   - senderName: Display name of the message sender
    ///   - messageText: Content of the message
    ///   - conversationId: ID of the conversation
    ///   - conversationType: "direct" or "group"
    ///   - groupName: Optional group name for group chats
    func triggerLocalNotification(
        senderName: String,
        messageText: String,
        conversationId: String,
        conversationType: String,
        groupName: String? = nil
    ) {
        // Don't notify if this is the active conversation
        if activeConversationId == conversationId {
            return
        }

        // Create notification content
        let content = UNMutableNotificationContent()

        // Format title and body based on conversation type
        if conversationType == "group", let groupName = groupName {
            content.title = groupName
            content.body = "\(senderName): \(messageText.prefix(100))"
        } else {
            content.title = senderName
            content.body = String(messageText.prefix(100))
        }

        content.sound = .default
        content.badge = NSNumber(value: unreadCount + 1)

        // Add conversation ID to userInfo for navigation
        content.userInfo = [
            "conversationId": conversationId,
            "senderId": senderName
        ]

        // Create request (use conversationId as identifier for tracking)
        // Use nil trigger for immediate delivery that persists in notification center
        let request = UNNotificationRequest(
            identifier: conversationId,
            content: content,
            trigger: nil
        )

        // Add notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error showing notification: \(error)")
            }
        }

        // Increment badge count
        incrementBadgeCount()
    }

    /// Increments the unread message badge count
    func incrementBadgeCount() {
        unreadCount += 1
        updateAppBadge()
    }

    /// Clears the badge count (call when opening conversation list)
    func clearBadgeCount() {
        unreadCount = 0
        updateAppBadge()
    }
    
    /// Clears notifications for a specific conversation
    func clearNotificationsForConversation(conversationId: String) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [conversationId])
    }

    /// Updates the app icon badge
    private func updateAppBadge() {
        UNUserNotificationCenter.current().setBadgeCount(unreadCount) { error in
            if let error = error {
                print("❌ Error updating badge count: \(error)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {

    // Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner and add to notification center even when app is in foreground
        completionHandler([.banner, .list, .sound, .badge])
    }

    // Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Extract conversation ID from notification
        if let conversationId = userInfo["conversationId"] as? String {
            // Post notification to trigger navigation
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToConversation"),
                    object: nil,
                    userInfo: ["conversationId": conversationId]
                )
            }
        }

        completionHandler()
    }
}
