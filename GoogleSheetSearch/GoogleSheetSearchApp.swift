//
//  GoogleSheetSearchApp.swift
//  GoogleSheetSearch
//
//  Created by Martijn van Beek on 03/12/2024.
//

import SwiftUI

@main
struct GoogleSheetSearchApp: App {
    @StateObject private var parser = GoogleSheetsParser()
    @State private var isAuthenticated = false // Track the authentication state
    
    var body: some Scene {
        WindowGroup {
            VStack {
                if isAuthenticated {
                    // Show ContentView only after login is successful
                    ContentView(parser: parser)
                        .frame(minWidth: 800, minHeight: 500)
                        .onAppear {
                            // Load last used URL if available
                            if let savedURL = UserDefaults.standard.string(forKey: "LastUsedSheetURL") {
                                Task {
                                    await parser.updateURL(savedURL)
                                }
                            }
                        }
                } else {
                    // Show the login view if the user is not authenticated
                    LoginView(isAuthenticated: $isAuthenticated, parser: parser) // Correct argument order
                        .frame(minWidth: 800, minHeight: 500)
                }
            }
            .onAppear {
                // Perform any setup when the app appears
            }
        }
    }
}
