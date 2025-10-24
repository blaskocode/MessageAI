//
//  Color+Theme.swift
//  MessageAI
//
//  Created on October 21, 2025
//  Updated December 2024 - Fresh Purple-Teal Gradient Theme
//

import SwiftUI
import UIKit

extension Color {
    // Modern purple-to-teal gradient theme - Distinct from iMessage
    static let messagePrimary = Color(red: 0.55, green: 0.27, blue: 0.96) // #8B45F5 - Rich Purple
    static let messageSecondary = Color(red: 0.20, green: 0.78, blue: 0.85) // #33C7D9 - Vibrant Teal
    
    // Gradient for sent messages
    static let messageGradient = LinearGradient(
        colors: [messagePrimary, messageSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Adaptive background that changes with Light/Dark mode
    static let messageBackground = Color(uiColor: UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0) // Deep dark for dark mode
        default:
            return UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1.0) // Soft lavender-gray for light mode
        }
    })
    
    // Enhanced received message color with subtle tint
    static let messageReceived = Color(uiColor: UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1.0) // Dark gray with purple tint
        default:
            return UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0) // Light gray with lavender tint
        }
    })
    
    static let unreadIndicator = Color.messagePrimary
    static let accentPrimary = Color.messagePrimary
    
    // New accent colors for UI elements
    static let accentTeal = Color.messageSecondary
    static let accentPurple = Color.messagePrimary
    
    // Subtle gradient backgrounds
    static let subtleGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.8),
            Color.messagePrimary.opacity(0.1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
