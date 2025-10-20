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
            "#FF6B6B", // Red
            "#4ECDC4", // Teal
            "#45B7D1", // Blue
            "#FFA07A", // Salmon
            "#98D8C8", // Mint
            "#F7DC6F", // Yellow
            "#BB8FCE", // Purple
            "#85C1E2", // Light Blue
            "#F8B739", // Orange
            "#52B788", // Green
            "#F06292", // Pink
            "#7986CB"  // Indigo
        ]
    }
    
    // MARK: - Notification Keys
    
    struct NotificationKeys {
        static let conversationId = "conversationId"
        static let senderId = "senderId"
        static let messageId = "messageId"
    }
}

