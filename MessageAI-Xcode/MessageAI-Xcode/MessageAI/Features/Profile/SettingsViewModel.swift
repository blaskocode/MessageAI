/**
 * SettingsViewModel - Manages all user settings and preferences
 * PR #10: User Settings & Preferences
 */

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
class SettingsViewModel: ObservableObject {
    // AI Feature Settings
    @Published var autoAnalyzeFormality: Bool = false
    @Published var autoDetectSlang: Bool = false
    @Published var autoGenerateSmartReplies: Bool = true
    
    // Appearance Settings
    @Published var darkModeEnabled: Bool = false {
        didSet {
            // Only save and apply if this is a user change (not initial load)
            if darkModeEnabled != oldValue {
                // Save to UserDefaults
                UserDefaults.standard.set(darkModeEnabled, forKey: "darkModeEnabled")
                
                // Apply dark mode immediately to all windows
                applyDarkMode(darkModeEnabled)
                
                print("🌙 [Settings] Dark mode: \(darkModeEnabled)")
            }
        }
    }
    
    // Notification Settings
    @Published var notificationsEnabled: Bool = true
    
    // Language and cultural settings - stored locally
    @Published var selectedLanguages: Set<String> = []
    
    @Published var culturalHintsEnabled: Bool = true
    
    private let db = Firestore.firestore()
    private var userId: String? {
        Auth.auth().currentUser?.uid
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
        
        // Load notification settings (default to true if not set)
        let hasNotificationPreference = UserDefaults.standard.object(forKey: "notificationsEnabled") != nil
        if hasNotificationPreference {
            notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        } else {
            notificationsEnabled = true // Default to enabled
            UserDefaults.standard.set(true, forKey: "notificationsEnabled")
        }
        
        // Load languages and cultural hints from Firestore
        Task {
            await loadLanguagesFromFirestore()
        }
        
        print("🔧 [Settings] Loaded settings:")
        print("  - Formality: \(autoAnalyzeFormality)")
        print("  - Slang: \(autoDetectSlang)")
        print("  - Smart Replies: \(autoGenerateSmartReplies)")
        print("  - Dark Mode: \(darkModeEnabled)")
        print("  - Notifications: \(notificationsEnabled)")
        
        // Apply saved dark mode preference immediately
        applyDarkMode(darkModeEnabled)
    }
    
    @MainActor
    private func loadLanguagesFromFirestore() async {
        guard let userId = userId else {
            // Set defaults
            selectedLanguages = ["en"]
            culturalHintsEnabled = true
            print("🔧 [Settings] No user ID - using defaults")
            return
        }
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            guard document.exists,
                  let data = document.data() else {
                // User document doesn't exist - use defaults
                selectedLanguages = ["en"]
                culturalHintsEnabled = true
                print("🔧 [Settings] User document not found - using defaults")
                return
            }
            
            // Load languages
            if let languages = data["fluentLanguages"] as? [String] {
                selectedLanguages = Set(languages)
            } else {
                selectedLanguages = ["en"]
            }
            
            // Load cultural hints setting
            culturalHintsEnabled = data["culturalHintsEnabled"] as? Bool ?? true
            
            print("🔧 [Settings] Loaded from Firestore:")
            print("  - Languages: \(selectedLanguages)")
            print("  - Cultural Hints: \(culturalHintsEnabled)")
        } catch {
            print("❌ [Settings] Error loading from Firestore: \(error)")
            // Use defaults on error
            selectedLanguages = ["en"]
            culturalHintsEnabled = true
        }
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
    
    private func applyDarkMode(_ enabled: Bool) {
        // Apply dark mode to all windows immediately
        DispatchQueue.main.async {
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        window.overrideUserInterfaceStyle = enabled ? .dark : .light
                    }
                }
            }
        }
    }
    
    func toggleDarkMode() {
        darkModeEnabled.toggle()
        // The didSet will handle saving and applying
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
        
        // Save to Firestore
        Task {
            await saveLanguagesToFirestore(languages)
        }
        
        print("🌍 [Settings] Languages updated: \(languages)")
    }
    
    func saveCurrentLanguagesToFirestore() async {
        print("🌍 [Settings] Saving languages to Firestore: \(selectedLanguages)")
        await saveLanguagesToFirestore(selectedLanguages)
    }
    
    private func saveLanguagesToFirestore(_ languages: Set<String>) async {
        guard let userId = userId else {
            print("❌ [Settings] No user ID - cannot save languages")
            return
        }
        
        do {
            try await db.collection("users").document(userId).updateData([
                "fluentLanguages": Array(languages)
            ])
            print("✅ [Settings] Languages saved to Firestore: \(languages)")
        } catch {
            print("❌ [Settings] Error saving languages to Firestore: \(error)")
            print("❌ [Settings] Error details: \(error.localizedDescription)")
        }
    }
    
    func updateCulturalHints(_ enabled: Bool) {
        culturalHintsEnabled = enabled
        
        // Save to Firestore
        Task {
            await saveCulturalHintsToFirestore(enabled)
        }
        
        print("💡 [Settings] Cultural hints updated: \(enabled)")
    }
    
    private func saveCulturalHintsToFirestore(_ enabled: Bool) async {
        guard let userId = userId else {
            print("❌ [Settings] No user ID - cannot save cultural hints")
            return
        }
        
        do {
            try await db.collection("users").document(userId).updateData([
                "culturalHintsEnabled": enabled
            ])
            print("✅ [Settings] Cultural hints saved to Firestore: \(enabled)")
        } catch {
            print("❌ [Settings] Error saving cultural hints to Firestore: \(error)")
        }
    }
}
