//
//  Color+Theme.swift
//  MessageAI
//
//  Created on October 21, 2025
//

import SwiftUI
import UIKit

extension Color {
    // Telegram-inspired blue theme
    static let messagePrimary = Color(red: 0.27, green: 0.55, blue: 0.96) // #458FED
    
    // Adaptive background that changes with Light/Dark mode
    static let messageBackground = Color(uiColor: UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0) // Dark gray for dark mode
        default:
            return UIColor(red: 0.94, green: 0.96, blue: 0.98, alpha: 1.0) // Light blue-gray for light mode
        }
    })
    
    static let messageReceived = Color(.systemGray6)
    static let unreadIndicator = Color.messagePrimary
    static let accentPrimary = Color.messagePrimary
}
