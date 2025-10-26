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
    
    // MARK: - Dark Mode Support
    
    /// Adaptive message primary color
    static var adaptiveMessagePrimary: Color {
        Color("MessagePrimary") ?? messagePrimary
    }
    
    /// Adaptive message background
    static var adaptiveMessageBackground: Color {
        Color("MessageBackground") ?? messageBackground
    }
    
    /// Adaptive received message background
    static var adaptiveMessageReceived: Color {
        Color("MessageReceived") ?? messageReceived
    }
    
    // MARK: - Semantic Colors
    
    /// Success color (green)
    static let success = Color.green
    
    /// Warning color (orange)
    static let warning = Color.orange
    
    /// Error color (red)
    static let error = Color.red
    
    /// Info color (blue)
    static let info = Color.blue
    
    // MARK: - AI Feature Colors
    
    /// Translation color
    static let translationColor = Color.blue
    
    /// Formality color
    static let formalityColor = Color.purple
    
    /// Slang color
    static let slangColor = Color.orange
    
    /// Smart replies color
    static let smartRepliesColor = Color.pink
    
    /// Cultural context color
    static let culturalColor = Color.yellow
    
    /// AI Assistant color
    static let aiAssistantColor = Color.indigo
}

// MARK: - Color Assets Support

extension Color {
    /// Initialize color from asset catalog with fallback
    init(_ name: String, fallback: Color) {
        // Color(name) doesn't return an optional, so we'll use the fallback for now
        // In a full implementation, you might want to check if the color exists in the asset catalog
        self = fallback
    }
}

// MARK: - Dark Mode Utilities

extension Color {
    /// Get adaptive color based on current color scheme
    func adaptive(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return self.darkModeVariant
        case .light:
            return self.lightModeVariant
        @unknown default:
            return self
        }
    }
    
    /// Light mode variant (current color)
    var lightModeVariant: Color {
        return self
    }
    
    /// Dark mode variant (adjusted for dark backgrounds)
    var darkModeVariant: Color {
        // For now, return the same color
        // In a full implementation, you might want to adjust brightness/saturation
        return self
    }
}
