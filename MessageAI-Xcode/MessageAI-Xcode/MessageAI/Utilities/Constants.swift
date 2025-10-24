// //  Constants.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import Foundation

struct Constants {

    // MARK: - Firebase Collections

    struct Collections {
        static let users = "users"
        static let conversations = "conversations"
        static let messages = "messages"
        static let typing = "typing"
    }

    // MARK: - UI Constants

    struct UI {
        static let messageLimit = 50
        static let maxImageSize: Int64 = 10_000_000 // 10MB
        static let imageThumbnailSize: CGFloat = 200
        static let profileImageSize: CGFloat = 100
    }

    // MARK: - Profile Colors

    struct ProfileColors {
        static let palette = [
            "#8B45F5", // Rich Purple (matches messagePrimary)
            "#33C7D9", // Vibrant Teal (matches messageSecondary)
            "#FF6B9D", // Modern Pink
            "#4ECDC4", // Soft Teal
            "#A8E6CF", // Mint Green
            "#FFD93D", // Golden Yellow
            "#6C5CE7", // Deep Purple
            "#74B9FF", // Sky Blue
            "#FD79A8", // Coral Pink
            "#00B894", // Emerald Green
            "#FDCB6E", // Warm Orange
            "#E17055"  // Terracotta
        ]
    }

    // MARK: - Notification Keys

    struct NotificationKeys {
        static let conversationId = "conversationId"
        static let senderId = "senderId"
        static let messageId = "messageId"
    }
}
