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
    @State private var isAuthenticated = false
    
    var body: some Scene {
        WindowGroup {
            VStack {
                if isAuthenticated {
                    ContentView(parser: parser)
                        .frame(minWidth: 800, minHeight: 500)
                        .onAppear {
                            if let savedURL = UserDefaults.standard.string(forKey: "LastUsedSheetURL") {
                                Task {
                                    await parser.updateURL(savedURL)
                                }
                            }
                        }
                } else {
                    LoginView(isAuthenticated: $isAuthenticated, parser: parser)
                        .frame(minWidth: 400, minHeight: 500)
                }
            }
        }
    }
}
