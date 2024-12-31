//
//  LoginView.swift
//  GoogleSheetSearch
//
//  Created by Martijn van Beek on 31/12/2024.
//

import SwiftUI
import SwiftSoup
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
    @Binding var isAuthenticated: Bool
    @Environment(\.scenePhase) var scenePhase

    let parser: GoogleSheetsParser
    @State private var users: [(username: String, password: String)] = []

    var body: some View {
        VStack {
            if isAuthenticated {
                ContentView(parser: parser)
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
                }
                .padding(AppStyle.padding)
                .frame(width: 320)
                .background(AppStyle.controlBackgroundColor)
                .cornerRadius(AppStyle.cornerRadius)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
    }

    func fetchUsernames() async {
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
            
            #if DEBUG
            print("✅ User data fetched successfully")
            #endif
            
        } catch {
            #if DEBUG
            print("❌ Error fetching user data: \(error.localizedDescription)")
            #endif
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation {
                showNotification = false
                if keepLoggedIn {
                    storeCredentials()
                }
                isAuthenticated = true
                showModal = false
                
                Task {
                    await parser.fetchData(forceRefresh: true)
                }
            }
        }
    }
    
    func login() async {
        if username.isEmpty || password.isEmpty {
            errorMessage = "Please enter both username and password"
            showNotification = true
            return
        }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
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
    
    private func storeCredentials() {
        if keepLoggedIn {
            UserDefaults.standard.set(username, forKey: "savedUsername")
            UserDefaults.standard.set(password, forKey: "savedPassword")
            UserDefaults.standard.set(true, forKey: "keepLoggedIn")
            // Store the current boot timestamp
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
            
            // Get the system boot time
            let processInfo = ProcessInfo.processInfo
            let bootTime = Date().timeIntervalSince1970 - processInfo.systemUptime
            
            // If the last login was before the current boot time, clear credentials
            if lastLoginTime < bootTime {
                clearStoredCredentials()
                return
            }
            
            username = savedUsername
            password = savedPassword
            keepLoggedIn = true
        }
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

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String = ""
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .foregroundColor(AppStyle.secondaryTextColor)
                    .frame(width: 20)
            }
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
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
