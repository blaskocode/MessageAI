/**
 * SettingsViewModel - Manages all user settings and preferences
 * PR #10: User Settings & Preferences
 */

import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    // AI Feature Settings
    @Published var autoAnalyzeFormality: Bool = false
    @Published var autoDetectSlang: Bool = false
    @Published var autoGenerateSmartReplies: Bool = true
    
    // Appearance Settings
    @Published var darkModeEnabled: Bool = false
    
    // Notification Settings
    @Published var notificationsEnabled: Bool = true
    
    private let profileViewModel = ProfileViewModel()
    
    // Computed properties for language and cultural settings
    var selectedLanguages: Set<String> {
        get { Set(profileViewModel.currentUser?.fluentLanguages ?? ["en"]) }
        set { profileViewModel.updateLanguages(newValue) }
    }
    
    var culturalHintsEnabled: Bool {
        get { profileViewModel.currentUser?.culturalHintsEnabled ?? true }
        set { profileViewModel.updateCulturalHints(newValue) }
    }
    
    init() {
        loadSettings()
    }
    
    func loadSettings() {
        // Load AI settings from UserDefaults
        autoAnalyzeFormality = UserDefaults.standard.bool(forKey: "autoAnalyzeFormality")
        autoDetectSlang = UserDefaults.standard.bool(forKey: "autoDetectSlang")
        autoGenerateSmartReplies = UserDefaults.standard.bool(forKey: "autoGenerateSmartReplies")
        
        // Load appearance settings
        darkModeEnabled = UserDefaults.standard.bool(forKey: "darkModeEnabled")
        
        // Load notification settings
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        
        print("🔧 [Settings] Loaded settings:")
        print("  - Formality: \(autoAnalyzeFormality)")
        print("  - Slang: \(autoDetectSlang)")
        print("  - Smart Replies: \(autoGenerateSmartReplies)")
        print("  - Dark Mode: \(darkModeEnabled)")
        print("  - Notifications: \(notificationsEnabled)")
        print("  - Languages: \(selectedLanguages)")
        print("  - Cultural Hints: \(culturalHintsEnabled)")
    }
    
    func saveSettings() {
        // Save AI settings to UserDefaults
        UserDefaults.standard.set(autoAnalyzeFormality, forKey: "autoAnalyzeFormality")
        UserDefaults.standard.set(autoDetectSlang, forKey: "autoDetectSlang")
        UserDefaults.standard.set(autoGenerateSmartReplies, forKey: "autoGenerateSmartReplies")
        
        // Save appearance settings
        UserDefaults.standard.set(darkModeEnabled, forKey: "darkModeEnabled")
        
        // Save notification settings
        UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        
        print("💾 [Settings] Saved all settings")
    }
    
    // MARK: - AI Feature Toggles
    
    func toggleFormalityAnalysis() {
        autoAnalyzeFormality.toggle()
        UserDefaults.standard.set(autoAnalyzeFormality, forKey: "autoAnalyzeFormality")
        print("🔧 [Settings] Formality analysis: \(autoAnalyzeFormality)")
    }
    
    func toggleSlangDetection() {
        autoDetectSlang.toggle()
        UserDefaults.standard.set(autoDetectSlang, forKey: "autoDetectSlang")
        print("🔧 [Settings] Slang detection: \(autoDetectSlang)")
    }
    
    func toggleSmartReplies() {
        autoGenerateSmartReplies.toggle()
        UserDefaults.standard.set(autoGenerateSmartReplies, forKey: "autoGenerateSmartReplies")
        print("🔧 [Settings] Smart replies: \(autoGenerateSmartReplies)")
    }
    
    // MARK: - Appearance Settings
    
    func toggleDarkMode() {
        darkModeEnabled.toggle()
        UserDefaults.standard.set(darkModeEnabled, forKey: "darkModeEnabled")
        
        // Apply dark mode immediately
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.first?.overrideUserInterfaceStyle = darkModeEnabled ? .dark : .light
        }
        
        print("🌙 [Settings] Dark mode: \(darkModeEnabled)")
    }
    
    // MARK: - Notification Settings
    
    func toggleNotifications() {
        notificationsEnabled.toggle()
        UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        
        // Request notification permissions if enabling
        if notificationsEnabled {
            NotificationService.shared.requestPermission()
        }
        
        print("🔔 [Settings] Notifications: \(notificationsEnabled)")
    }
    
    // MARK: - Language Settings
    
    func updateLanguages(_ languages: Set<String>) {
        selectedLanguages = languages
        profileViewModel.updateLanguages(languages)
        print("🌍 [Settings] Languages updated: \(languages)")
    }
}
