/**
 * AccessibilityViewModifier - Accessibility enhancements for UI components
 * Provides VoiceOver support, Dynamic Type, and accessibility labels
 */

import SwiftUI

// MARK: - Accessibility View Modifier

struct AccessibilityViewModifier: ViewModifier {
    let label: String
    let hint: String?
    let value: String?
    let traits: AccessibilityTraits
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
    }
}

extension View {
    /// Add comprehensive accessibility support to any view
    func accessibilitySupport(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self.modifier(AccessibilityViewModifier(
            label: label,
            hint: hint,
            value: value,
            traits: traits
        ))
    }
}

// MARK: - Message Bubble Accessibility

extension View {
    /// Accessibility support for message bubbles
    func messageBubbleAccessibility(
        message: Message,
        isFromCurrentUser: Bool,
        senderName: String? = nil
    ) -> some View {
        let label = isFromCurrentUser ? 
            "Your message: \(message.text ?? "")" :
            "Message from \(senderName ?? "Unknown"): \(message.text ?? "")"
        
        let hint = isFromCurrentUser ? 
            "Double tap to edit or delete" :
            "Double tap to reply or translate"
        
        return self
            .accessibilitySupport(
                label: label,
                hint: hint,
                traits: .isButton
            )
    }
}

// MARK: - AI Feature Accessibility

extension View {
    /// Accessibility support for AI feature buttons
    func aiFeatureAccessibility(
        featureName: String,
        isEnabled: Bool,
        action: String
    ) -> some View {
        let label = "\(featureName) \(isEnabled ? "enabled" : "disabled")"
        let hint = "Double tap to \(action)"
        
        return self
            .accessibilitySupport(
                label: label,
                hint: hint,
                traits: .isButton
            )
    }
}

// MARK: - Form Accessibility

extension View {
    /// Accessibility support for form inputs
    func formFieldAccessibility(
        label: String,
        placeholder: String? = nil,
        value: String? = nil,
        isRequired: Bool = false
    ) -> some View {
        let accessibilityLabel = isRequired ? "\(label), required" : label
        let accessibilityValue = value ?? placeholder ?? ""
        
        return self
            .accessibilitySupport(
                label: accessibilityLabel,
                value: accessibilityValue,
                traits: .isStaticText
            )
    }
}

// MARK: - Navigation Accessibility

extension View {
    /// Accessibility support for navigation elements
    func navigationAccessibility(
        title: String,
        destination: String? = nil
    ) -> some View {
        let hint = destination != nil ? "Double tap to go to \(destination!)" : "Double tap to navigate"
        
        return self
            .accessibilitySupport(
                label: title,
                hint: hint,
                traits: .isButton
            )
    }
}

// MARK: - Dynamic Type Support

extension View {
    /// Apply Dynamic Type scaling to text
    func dynamicTypeSupport() -> some View {
        self
            .dynamicTypeSize(.small ... .accessibility3)
    }
}

// MARK: - High Contrast Support

extension View {
    /// Apply high contrast colors when needed
    func highContrastSupport() -> some View {
        self
            .preferredColorScheme(nil) // Let system decide
    }
}

// MARK: - VoiceOver Announcements

class AccessibilityAnnouncer: ObservableObject {
    static let shared = AccessibilityAnnouncer()
    
    private init() {}
    
    func announce(_ message: String) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
    
    func announceMessageReceived(from sender: String) {
        announce("New message from \(sender)")
    }
    
    func announceTranslationComplete() {
        announce("Translation complete")
    }
    
    func announceFormalityAnalysis(level: String) {
        announce("Formality level: \(level)")
    }
    
    func announceSlangDetected(count: Int) {
        announce("\(count) slang expressions detected")
    }
}
