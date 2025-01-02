//
//  SignupFormView.swift
//  GoogleSheetSearch
//
//  Created by Martijn van Beek on 02/01/2025.
//

import SwiftUI

struct SignupFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var showingSuccess = false
    @State private var errorMessage = ""
    
    private let formUrl = "https://docs.google.com/forms/d/e/1FAIpQLSeayodN1FEeQhDSF78T12ILsfO5O-W85Ex0mF9Mapl9erPQ0g/formResponse"
    
    var body: some View {
        VStack(spacing: AppStyle.padding) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            
            // Title
            VStack(spacing: 8) {
                Text("Create Account")
                    .font(AppStyle.fontTitle)
                    .foregroundColor(.primary)
                
                Text("Enter your details to create an account")
                    .font(AppStyle.fontSmall)
                    .foregroundColor(AppStyle.secondaryTextColor)
            }
            
            // Form Fields
            VStack(spacing: 16) {
                CustomTextField(
                    placeholder: "Email",
                    text: $email,
                    icon: "envelope.fill"
                )
                
                CustomTextField(
                    placeholder: "First Name",
                    text: $firstName,
                    icon: "person.fill"
                )
                
                CustomTextField(
                    placeholder: "Last Name",
                    text: $lastName,
                    icon: "person.fill"
                )
                
                CustomTextField(
                    placeholder: "Password",
                    text: $password,
                    icon: "lock.fill",
                    isSecure: true
                )
            }
            .padding(.horizontal)
            
            // Submit Button
            Button(action: submitForm) {
                ZStack {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20))
                        Text("Create Account")
                    }
                    .font(AppStyle.fontHeading)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppStyle.iconWidth)
                    .background(
                        RoundedRectangle(cornerRadius: AppStyle.cornerRadius)
                            .fill(AppStyle.accentColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppStyle.cornerRadius)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: AppStyle.accentColor.opacity(0.3), radius: 5, x: 0, y: 2)
                    )
                    .foregroundColor(.white)
                    .opacity(isLoading ? 0 : 1)
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isLoading || !isFormValid)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, AppStyle.padding)
        .frame(width: 320)
        .background(AppStyle.controlBackgroundColor)
        .cornerRadius(AppStyle.cornerRadius)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .overlay(
            ZStack {
                if showingError {
                    NotificationBanner(
                        message: errorMessage,
                        type: .error
                    )
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showingError = false
                        }
                    }
                }
                if showingSuccess {
                    NotificationBanner(
                        message: "Account created successfully!",
                        type: .success
                    )
                }
            }
        )
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !firstName.isEmpty && !lastName.isEmpty && !password.isEmpty
    }
    
    private func submitForm() {
        isLoading = true
        
        Task {
            do {
                var request = URLRequest(url: URL(string: formUrl)!)
                request.httpMethod = "POST"
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                
                let formData = [
                    "entry.821165045": firstName,
                    "entry.38514619": lastName,
                    "entry.1852538260": password,
                    "emailAddress": email,
                    "fvv": "1",
                    "draftResponse": "[]",
                    "pageHistory": "0",
                    "fbzx": "5622314453475514722"
                ]
                
                let formBody = formData.map { key, value in
                    let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                    let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                    return "\(encodedKey)=\(encodedValue)"
                }.joined(separator: "&")
                
                request.httpBody = formBody.data(using: .utf8)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                await MainActor.run {
                    isLoading = false
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 200 {
                        let responseString = String(data: data, encoding: .utf8) ?? ""
                        if responseString.contains("Form submitted") ||
                            !responseString.contains("error") {
                            showingSuccess = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                dismiss()
                            }
                        } else {
                            errorMessage = "Form submission failed. Please try again."
                            showingError = true
                        }
                    } else {
                        errorMessage = "Failed to submit form. Please try again."
                        showingError = true
                    }
                }
            } catch {
                print("Error submitting form: \(error)")
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Network error. Please check your connection and try again."
                    showingError = true
                }
            }
        }
    }
}

#if DEBUG
struct SignupFormView_Previews: PreviewProvider {
    static var previews: some View {
        SignupFormView()
    }
}
#endif
