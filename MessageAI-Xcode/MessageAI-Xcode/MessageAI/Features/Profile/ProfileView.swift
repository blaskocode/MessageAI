// //  ProfileView.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var displayName = ""
    @State private var isEditing = false
    @State private var showLogoutConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()

                        // Profile Picture Placeholder
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 100, height: 100)
                            .overlay {
                                Text("AB")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                                    .fontWeight(.semibold)
                            }

                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Profile Information") {
                    if isEditing {
                        TextField("Display Name", text: $displayName)
                    } else {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(displayName.isEmpty ? "Not set" : displayName)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Section {
                    Button(isEditing ? "Save" : "Edit Profile") {
                        isEditing.toggle()
                        // TODO: Save profile changes
                    }

                    Button("Sign Out", role: .destructive) {
                        showLogoutConfirmation = true
                    }
                }
            }
            .navigationTitle("Profile")
            .confirmationDialog("Are you sure you want to sign out?", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    authViewModel.signOut()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
