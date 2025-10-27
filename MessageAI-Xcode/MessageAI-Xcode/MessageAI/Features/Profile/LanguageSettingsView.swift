//
//  LanguageSettingsView.swift
//  MessageAI
//
//  Created for PR #2: Translation & Language Detection
//

import SwiftUI

struct LanguageSettingsView: View {
    @Binding var selectedLanguages: Set<String>
    @Binding var culturalHintsEnabled: Bool
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var viewModel: SettingsViewModel
    
    // Common languages with their names
    private let availableLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("ru", "Russian"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("zh", "Chinese"),
        ("ar", "Arabic"),
        ("hi", "Hindi"),
        ("nl", "Dutch"),
        ("pl", "Polish"),
        ("tr", "Turkish"),
        ("vi", "Vietnamese"),
        ("th", "Thai"),
        ("id", "Indonesian"),
        ("sv", "Swedish"),
        ("da", "Danish"),
        ("fi", "Finnish"),
        ("no", "Norwegian"),
        ("cs", "Czech"),
        ("el", "Greek"),
        ("he", "Hebrew"),
        ("ro", "Romanian"),
        ("hu", "Hungarian"),
        ("uk", "Ukrainian")
    ]
    
    var body: some View {
        Form {
            Section {
                Text("Select all languages you're fluent in. Messages in other languages will show a translate button.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)
            }
            
            Section("Your Fluent Languages") {
                ForEach(availableLanguages, id: \.code) { language in
                    Button {
                        toggleLanguage(language.code)
                    } label: {
                        HStack {
                            Text(language.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedLanguages.contains(language.code) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Languages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
    
    private func toggleLanguage(_ code: String) {
        var updatedLanguages = selectedLanguages
        
        if updatedLanguages.contains(code) {
            // Don't allow removing if it's the last language
            if updatedLanguages.count > 1 {
                updatedLanguages.remove(code)
            } else {
                // Can't remove the last language
                return
            }
        } else {
            updatedLanguages.insert(code)
        }
        
        // Update the binding with the new set
        selectedLanguages = updatedLanguages
        
        // Save language changes to Firestore
        Task { @MainActor in
            await viewModel.saveCurrentLanguagesToFirestore()
        }
    }
}

#Preview {
    NavigationStack {
        LanguageSettingsView(
            selectedLanguages: .constant(["en", "es"]),
            culturalHintsEnabled: .constant(true)
        )
    }
}

