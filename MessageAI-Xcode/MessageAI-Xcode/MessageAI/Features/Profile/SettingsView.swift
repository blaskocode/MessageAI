/**
 * SettingsView - Consolidated settings screen for all AI features and preferences
 * PR #10: User Settings & Preferences
 */

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // AI Features Section
                Section {
                    // Translation Settings
                    NavigationLink(destination: LanguageSettingsView(
                        selectedLanguages: $viewModel.selectedLanguages,
                        culturalHintsEnabled: $viewModel.culturalHintsEnabled
                    )) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Languages")
                                    .font(.body)
                                Text("\(viewModel.selectedLanguages.count) languages selected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Formality Analysis
                    HStack {
                        Image(systemName: "textformat")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Formality Analysis")
                                .font(.body)
                            Text("Analyze message formality levels")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $viewModel.autoAnalyzeFormality)
                    }
                    .aiFeatureAccessibility(
                        featureName: "Formality Analysis",
                        isEnabled: viewModel.autoAnalyzeFormality,
                        action: "toggle formality analysis"
                    )
                    
                    // Slang & Idioms
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Slang & Idioms")
                                .font(.body)
                            Text("Explain colloquialisms and idioms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $viewModel.autoDetectSlang)
                    }
                    .aiFeatureAccessibility(
                        featureName: "Slang & Idioms",
                        isEnabled: viewModel.autoDetectSlang,
                        action: "toggle slang detection"
                    )
                    
                    // Smart Replies
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.pink)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Smart Replies")
                                .font(.body)
                            Text("AI-powered reply suggestions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $viewModel.autoGenerateSmartReplies)
                    }
                    .aiFeatureAccessibility(
                        featureName: "Smart Replies",
                        isEnabled: viewModel.autoGenerateSmartReplies,
                        action: "toggle smart replies"
                    )
                    
                    // Cultural Context
                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.yellow)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cultural Context")
                                .font(.body)
                            Text("Show cultural hints and explanations")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $viewModel.culturalHintsEnabled)
                    }
                    .aiFeatureAccessibility(
                        featureName: "Cultural Context",
                        isEnabled: viewModel.culturalHintsEnabled,
                        action: "toggle cultural context"
                    )
                } header: {
                    Text("AI Features")
                } footer: {
                    Text("Enable AI features to enhance your messaging experience with intelligent insights and suggestions.")
                }
                
                // Appearance Section
                Section {
                    HStack {
                        Image(systemName: "moon")
                            .foregroundColor(.indigo)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dark Mode")
                                .font(.body)
                            Text("Use dark appearance")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $viewModel.darkModeEnabled)
                    }
                    .aiFeatureAccessibility(
                        featureName: "Dark Mode",
                        isEnabled: viewModel.darkModeEnabled,
                        action: "toggle dark mode"
                    )
                } header: {
                    Text("Appearance")
                }
                
                // Notifications Section
                Section {
                    HStack {
                        Image(systemName: "bell")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Local Notifications")
                                .font(.body)
                            Text("Show notifications for new messages")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $viewModel.notificationsEnabled)
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Receive notifications when you receive new messages, even when the app is in the foreground.")
                }
                
                // About Section
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("App Version")
                                .font(.body)
                            Text("1.0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Help & Support")
                                .font(.body)
                            Text("Get help with using MessageAI")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .dynamicTypeSupport()
        .onAppear {
            viewModel.loadSettings()
        }
    }
}

#Preview {
    SettingsView()
}
