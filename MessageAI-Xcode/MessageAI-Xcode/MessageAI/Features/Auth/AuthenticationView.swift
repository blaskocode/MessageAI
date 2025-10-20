//
//  AuthenticationView.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUpMode = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
                // Logo / Title
                VStack(spacing: 8) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("MessageAI")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.bottom, 40)
                
                // Input Fields
                VStack(spacing: 16) {
                    if isSignUpMode {
                        TextField("Display Name", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.words)
                    }
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(isSignUpMode ? .newPassword : .password)
                }
                .padding(.horizontal, 40)
                
                // Error Message
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Action Button
                Button(action: handleAuth) {
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text(isSignUpMode ? "Sign Up" : "Sign In")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal, 40)
                .disabled(authViewModel.isLoading)
                
                // Toggle Mode
                Button(action: { isSignUpMode.toggle() }) {
                    Text(isSignUpMode ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }
    
    private func handleAuth() {
        Task {
            if isSignUpMode {
                await authViewModel.signUp(email: email, password: password, displayName: displayName)
            } else {
                await authViewModel.signIn(email: email, password: password)
            }
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthViewModel())
}

