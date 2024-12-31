//
//  LoginModalView.swift
//  GoogleSheetSearch
//
//  Created by Martijn van Beek on 31/12/2024.
//

import SwiftUI

struct LoginModalView: View {
    @Binding var username: String
    @Binding var password: String
    @Binding var isLoggedIn: Bool
    @Binding var errorMessage: String?
    @Binding var showModal: Bool
    let parser: GoogleSheetsParser

    var body: some View {
        VStack {
            VStack {
                Text("Login")
                    .font(.title)
                    .padding()
                
                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button("Login") {
                    Task {
                        await login()
                    }
                }
                .padding()
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()
            .frame(width: 300, height: 350)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 10)
            .padding(50) // Padding to give some space from the edges
            
            // If login is successful, show confirmation
            if isLoggedIn {
                Text("Login Successful!")
                    .foregroundColor(.green)
                    .padding()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            showModal = false // Close the modal after a successful login
                        }
                    }
            }
        }
        .transition(.move(edge: .bottom)) // Smooth modal animation
        .animation(.easeInOut, value: showModal) // Animation when modal appears
    }
    
    func login() async {
        // Simulate a login request, replace with your actual logic
        if username == "user" && password == "password" {
            isLoggedIn = true
        } else {
            errorMessage = "Invalid username or password"
        }
    }
}
