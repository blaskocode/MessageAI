//
//  Color+Theme.swift
//  MessageAI
//
//  Created on October 21, 2025
//

import SwiftUI

extension Color {
    // Telegram-inspired blue theme
    static let messagePrimary = Color(red: 0.27, green: 0.55, blue: 0.96) // #458FED
    static let messageBackground = Color(red: 0.94, green: 0.96, blue: 0.98) // #F0F5F9
    static let messageReceived = Color(.systemGray6)
    static let unreadIndicator = Color.messagePrimary
    static let accentPrimary = Color.messagePrimary
}
