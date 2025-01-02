//
//  LoginView.swift
//  GoogleSheetSearch
//
//  Created by Martijn van Beek on 31/12/2024.
//

import SwiftUI
import SwiftSoup
import WebKit
import os.log

#if DEBUG
extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier!
    static let networking = OSLog(subsystem: subsystem, category: "networking")
}
#endif

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isLoggedIn = false
    @State private var errorMessage: String? = nil
    @State private var showModal = true
    @State private var keepLoggedIn = false
    @State private var showNotification = false
    @State private var isLoading = false
    @State private var isShowingSignup = false
    @State private var signupFormUrl = "https://docs.google.com/forms/d/e/1FAIpQLSeayodN1FEeQhDSF78T12ILsfO5O-W85Ex0mF9Mapl9erPQ0g/viewform?usp=sf_link"
    @State private var showingForgotPasswordAlert = false
    @Binding var isAuthenticated: Bool
    @ObservedObject var parser: GoogleSheetsParser
    @Environment(\.scenePhase) var scenePhase
    @State private var users: [(username: String, password: String)] = []
    
    var body: some View {
        VStack {
            if isAuthenticated {
                VStack(spacing: 0) {
                    ContentView(parser: parser, isAuthenticated: $isAuthenticated)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                        .frame(maxHeight: .infinity)
                }
            } else {
                loginModal
            }
        }
        .background(AppStyle.backgroundColor)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            Task {
                await fetchUsernames()
                checkStoredCredentials()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    private var loginModal: some View {
        VStack {
            if showModal {
                VStack(spacing: AppStyle.padding) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppStyle.accentColor)
                        .padding(.bottom, 8)
                    
                    Text("Login")
                        .font(AppStyle.fontTitle)
                        .foregroundColor(.primary)
                    
                    CustomTextField(
                        placeholder: "Username",
                        text: $username,
                        icon: "person.fill"
                    )
                    
                    CustomTextField(
                        placeholder: "Password",
                        text: $password,
                        icon: "lock.fill",
                        isSecure: true
                    )
                    
                    Toggle(isOn: $keepLoggedIn) {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(AppStyle.secondaryTextColor)
                            Text("Keep me logged in")
                        }
                        .font(AppStyle.fontSmall)
                        .foregroundColor(AppStyle.secondaryTextColor)
                    }
                    .padding(.horizontal, 4)
                    .onChange(of: keepLoggedIn) { newValue in
                        if !newValue {
                            clearStoredCredentials()
                        }
                    }
                    Button(action: {
                        Task {
                            isLoading = true
                            await login()
                            isLoading = false
                        }
                    }) {
                        ZStack {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 20))
                                Text("Login")
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
                    .disabled(isLoading)
                    .padding(.top, 8)
                    
                    Button("Forgot Password?") {
                        showingForgotPasswordAlert = true
                    }
                    .buttonStyle(.plain)
                    .font(AppStyle.fontSmall)
                    .foregroundColor(AppStyle.secondaryTextColor)
                    .padding(.top, 4)
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    VStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(AppStyle.fontSmall)
                            .foregroundColor(AppStyle.secondaryTextColor)
                        
                        Button(action: {
                            isShowingSignup = true
                        }) {
                            Text("Create Account")
                                .fontWeight(.medium)
                                .foregroundColor(AppStyle.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AppStyle.padding)
                .frame(width: 320)
                .background(AppStyle.controlBackgroundColor)
                .cornerRadius(AppStyle.cornerRadius)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                .padding(.vertical, 50)
                .overlay(
                    ZStack {
                        if showNotification {
                            if isLoggedIn {
                                NotificationBanner(
                                    message: "Login Successful!",
                                    type: .success
                                )
                                .onAppear {
                                    dismissNotificationAndProceed()
                                }
                            } else if let error = errorMessage {
                                NotificationBanner(
                                    message: error,
                                    type: .error
                                )
                                .onAppear {
                                    dismissNotification()
                                }
                            }
                        }
                    }
                )
                .alert("Forgot Password", isPresented: $showingForgotPasswordAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Please contact your administrator for a new password by sending them an email. (martijn.vanbeek@by433.com)")
                }
                .sheet(isPresented: $isShowingSignup) {
                    SignupFormView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
    }
    // Helper methods
    private func fetchUsernames() async {
        guard let url = URL(string: "https://docs.google.com/spreadsheets/d/e/2PACX-1vRuRqeXwVMciCj6h3V7-CVECceDk_N5l01NM2vDrjd1tvu2MUY7f6G93jfTiUqXt1cxhyofS01Ca-iN/pubhtml") else {
            print("Invalid URL")
            return
        }
        
        do {
            let (htmlData, _) = try await URLSession.shared.data(from: url)
            let document = try SwiftSoup.parse(String(data: htmlData, encoding: .utf8)!)
            let rows = try document.select("table tbody tr")
            
            self.users = try rows.map { row in
                let cells = try row.select("td")
                let username = try cells[0].text()
                let password = try cells[1].text()
                return (username, password)
            }
        } catch {
            print("Error fetching user data: \(error.localizedDescription)")
            self.users = [] // Clear users array on error
        }
    }
    
    private func login() async {
        if username.isEmpty || password.isEmpty {
            errorMessage = "Please enter both username and password"
            showNotification = true
            return
        }
        
        // Try to fetch fresh data first
        await fetchUsernames()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Check if we have any users data
        if users.isEmpty {
            errorMessage = "Network error. Please check your connection and try again."
            showNotification = true
            return
        }
        
        if let user = users.first(where: { $0.username == username }) {
            if user.password == password {
                isLoggedIn = true
                errorMessage = nil
                showNotification = true
            } else {
                isLoggedIn = false
                errorMessage = "Invalid username or password"
                showNotification = true
            }
        } else {
            isLoggedIn = false
            errorMessage = "Invalid username or password"
            showNotification = true
        }
    }
    
    private func dismissNotification() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showNotification = false
                errorMessage = nil
            }
        }
    }
    
    private func dismissNotificationAndProceed() {
        // Reduced delay to 0.2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showNotification = false
                if keepLoggedIn {
                    storeCredentials()
                }
                isAuthenticated = true
                showModal = false
            }
            
            // Move data fetching outside of animation
            Task {
                await parser.fetchData(forceRefresh: true)
            }
        }
    }
    
    private func storeCredentials() {
        if keepLoggedIn {
            UserDefaults.standard.set(username, forKey: "savedUsername")
            UserDefaults.standard.set(password, forKey: "savedPassword")
            UserDefaults.standard.set(true, forKey: "keepLoggedIn")
            let bootTime = Date().timeIntervalSince1970
            UserDefaults.standard.set(bootTime, forKey: "lastLoginTime")
        } else {
            clearStoredCredentials()
        }
        UserDefaults.standard.synchronize()
    }
    
    private func clearStoredCredentials() {
        UserDefaults.standard.removeObject(forKey: "savedUsername")
        UserDefaults.standard.removeObject(forKey: "savedPassword")
        UserDefaults.standard.removeObject(forKey: "keepLoggedIn")
        UserDefaults.standard.removeObject(forKey: "lastLoginTime")
        UserDefaults.standard.synchronize()
    }
    
    private func checkStoredCredentials() {
        if UserDefaults.standard.bool(forKey: "keepLoggedIn"),
           let savedUsername = UserDefaults.standard.string(forKey: "savedUsername"),
           let savedPassword = UserDefaults.standard.string(forKey: "savedPassword"),
           let lastLoginTime = UserDefaults.standard.object(forKey: "lastLoginTime") as? Double {
            
            let processInfo = ProcessInfo.processInfo
            let bootTime = Date().timeIntervalSince1970 - processInfo.systemUptime
            
            if lastLoginTime < bootTime {
                clearStoredCredentials()
                return
            }
            
            // Just fill in the credentials but don't auto-login
            username = savedUsername
            password = savedPassword
            keepLoggedIn = true
            }
        }
    }

// Supporting Views
struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String = ""
    var isSecure: Bool = false
    @State private var showPassword: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .foregroundColor(AppStyle.secondaryTextColor)
                    .frame(width: 20)
            }
            
            Group {
                if isSecure {
                    if showPassword {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            
            if isSecure {
                Button(action: {
                    showPassword.toggle()
                }) {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(AppStyle.secondaryTextColor)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
            }
        }
        .textFieldStyle(PlainTextFieldStyle())
        .padding()
        .frame(height: AppStyle.iconWidth)
        .background(AppStyle.backgroundColor)
        .cornerRadius(AppStyle.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.cornerRadius)
                .stroke(AppStyle.secondaryTextColor.opacity(0.3), lineWidth: 1)
        )
    }
}

struct NotificationBanner: View {
    let message: String
    let type: NotificationType
    
    enum NotificationType {
        case success, error
        
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: type.icon)
            Text(message)
        }
        .font(AppStyle.fontHeading)
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(type.color.opacity(0.9))
        .cornerRadius(AppStyle.cornerRadius)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(), value: message)
    }
}

extension Color {
    func toHexString() -> String {
        let components = NSColor(self).cgColor.components!
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

extension Bundle {
    var appVersionString: String {
        let version = self.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = self.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
// Add this at the bottom of LoginView.swift, after all existing code
struct LogoutButton: View {
    @Binding var isAuthenticated: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isAuthenticated = false
                }
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16))
                        .symbolRenderingMode(.hierarchical)
                    Text("Logout")
                        .font(.system(size: 14))
                    Spacer()
                }
                .foregroundStyle(.red)
                .padding(.vertical, 5)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            .background(Color(.controlBackgroundColor))
        }
    }
}
