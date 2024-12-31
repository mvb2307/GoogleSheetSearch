//
//  LoginView.swift
//  GoogleSheetSearch
//
//  Created by Martijn van Beek on 31/12/2024.
//

import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isLoggedIn = false
    @State private var errorMessage: String? = nil
    @State private var showModal = true // To control the popup appearance
    @Binding var isAuthenticated: Bool

    let parser: GoogleSheetsParser
    
    var body: some View {
        VStack {
            if isAuthenticated {
                // Main content view once authenticated
                ContentView(parser: parser) // Show ContentView after login
            } else {
                // Show login modal when not authenticated
                loginModal
            }
        }
        .background(Color.gray)
    }
    
    private var loginModal: some View {
        VStack {
            if showModal {
                VStack {
                    Text("Login")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.primary) // Use SwiftUI Color.primary
                        .padding(.top, 20)
                    
                    TextField("Username", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .frame(height: 45)
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .frame(height: 45)
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                    
                    Button("Login") {
                        Task {
                            await login()
                        }
                    }
                    .padding(.top)
                    .padding(.horizontal)
                    .frame(height: 45)
                    .background(Color.blue) // App theme color for buttons
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding(.top)
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 40)
                .frame(width: 300, height: 400)
                .background(Color.white) // White background for modal
                .cornerRadius(12)
                .shadow(radius: 20)
                .overlay(
                    VStack {
                        if isLoggedIn {
                            Text("Login Successful!")
                                .foregroundColor(.green)
                                .font(.headline)
                                .padding()
                                .onAppear {
                                    // Simulate login success
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        isAuthenticated = true
                                        showModal = false // Close the modal after a successful login
                                    }
                                }
                        }
                    }
                )
                .transition(.move(edge: .bottom))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)) // Dim background
        .onTapGesture {
            // Dismiss the modal if the background is tapped
            showModal = false
        }
    }
    
    func login() async {
        // Default user credentials
        let defaultUsername = "admin"
        let defaultPassword = "admin"
        
        // Check the login credentials
        if username == defaultUsername && password == defaultPassword {
            isLoggedIn = true
        } else {
            errorMessage = "Invalid username or password"
        }
    }
}
