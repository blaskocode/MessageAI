//
//  ProfileView.swift
//  MessageAI
//
//  User profile and settings management
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showLogoutConfirmation = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    // Profile Picture Section
                    Section {
                        let profileURL = viewModel.currentUser?.profilePictureURL
                        let profileColorHex = viewModel.currentUser?.profileColorHex ?? "#007AFF"
                        let initials = viewModel.currentUser?.initials ?? "?"
                        
                        HStack {
                            Spacer()
                            
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                ZStack {
                                    // Profile Picture
                                    // Validate URL: must be http(s) and not a color hex
                                    if let profileURL = profileURL, 
                                       !profileURL.isEmpty,
                                       !profileURL.hasPrefix("#"),
                                       profileURL.hasPrefix("http") {
                                        AsyncImage(url: URL(string: profileURL)) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 100, height: 100)
                                                    .clipShape(Circle())
                                            case .failure, .empty:
                                                Circle()
                                                    .fill(Color(hex: profileColorHex))
                                                    .frame(width: 100, height: 100)
                                                    .overlay {
                                                        Text(initials)
                                                            .font(.system(size: 40, weight: .semibold))
                                                            .foregroundColor(.white)
                                                    }
                                            @unknown default:
                                                Circle()
                                                    .fill(Color(hex: profileColorHex))
                                                    .frame(width: 100, height: 100)
                                                    .overlay {
                                                        Text(initials)
                                                            .font(.system(size: 40, weight: .semibold))
                                                            .foregroundColor(.white)
                                                    }
                                            }
                                        }
                                    } else {
                                        Circle()
                                            .fill(Color(hex: profileColorHex))
                                            .frame(width: 100, height: 100)
                                            .overlay {
                                                Text(initials)
                                                    .font(.system(size: 40, weight: .semibold))
                                                    .foregroundColor(.white)
                                            }
                                    }
                                    
                                    // Camera overlay
                                    Circle()
                                        .fill(Color.black.opacity(0.4))
                                        .frame(width: 100, height: 100)
                                        .overlay {
                                            VStack(spacing: 4) {
                                                Image(systemName: "camera.fill")
                                                    .font(.title2)
                                                    .foregroundColor(.white)
                                                Text("Change")
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                }
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 20)
                        .listRowBackground(Color.clear)
                    }
                    
                    // Profile Information
                    Section("Profile Information") {
                        // Email (read-only)
                        HStack {
                            Label("Email", systemImage: "envelope.fill")
                            Spacer()
                            Text(viewModel.email)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        // Display Name (Editable)
                        HStack {
                            Label("Name", systemImage: "person.fill")
                            TextField("Enter your name", text: $viewModel.displayName)
                                .multilineTextAlignment(.trailing)
                                .submitLabel(.done)
                                .onSubmit {
                                    Task {
                                        await viewModel.saveProfile()
                                    }
                                }
                        }
                    }
                    
                    // AI & Translation Settings (PR #2)
                    Section {
                        NavigationLink {
                            LanguageSettingsView(
                                selectedLanguages: $viewModel.selectedLanguages,
                                culturalHintsEnabled: $viewModel.culturalHintsEnabled
                            )
                            .onChange(of: viewModel.selectedLanguages) { _, newValue in
                                viewModel.updateLanguages(newValue)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Languages")
                                        .font(.body)
                                    Text("\(viewModel.selectedLanguages.count) language\(viewModel.selectedLanguages.count == 1 ? "" : "s") selected")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Toggle(isOn: Binding(
                            get: { viewModel.culturalHintsEnabled },
                            set: { viewModel.updateCulturalHints($0) }
                        )) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                    .frame(width: 24)
                                Text("Cultural Context Hints")
                            }
                        }
                        
                        Toggle(isOn: $viewModel.autoAnalyzeFormality) {
                            HStack {
                                Image(systemName: "person.2.badge.gearshape")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                Text("Auto-Analyze Formality")
                            }
                        }
                        
                        Toggle(isOn: $viewModel.autoDetectSlang) {
                            HStack {
                                Image(systemName: "text.bubble")
                                    .foregroundColor(.purple)
                                    .frame(width: 24)
                                Text("Auto-Detect Slang & Idioms")
                            }
                        }
                        
                        Toggle(isOn: $viewModel.autoGenerateSmartReplies) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.purple)
                                    .frame(width: 24)
                                Text("Smart Reply Suggestions")
                            }
                        }
                    } header: {
                        Text("AI & Translation")
                    } footer: {
                        Text("Enable automatic slang detection and smart reply suggestions that match your writing style.")
                    }
                    
                    // Actions
                    Section {
                        Button(role: .destructive) {
                            showLogoutConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.right.square.fill")
                                Text("Sign Out")
                            }
                        }
                    }
                    
                    // App Info
                    Section {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("2.0.0")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Build")
                            Spacer()
                            Text("Phase 2 - AI Features")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    } header: {
                        Text("About")
                    }
                }
                
                // Loading Overlay
                if viewModel.isLoading {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .alert("Success", isPresented: .constant(viewModel.successMessage != nil)) {
                Button("OK") {
                    viewModel.successMessage = nil
                }
            } message: {
                if let success = viewModel.successMessage {
                    Text(success)
                }
            }
            .confirmationDialog(
                "Are you sure you want to sign out?",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authViewModel.signOut()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .onAppear {
            if viewModel.currentUser == nil {
                viewModel.loadUserData()
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    await viewModel.uploadProfilePhoto(data)
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
