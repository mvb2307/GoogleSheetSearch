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
    
    var body: some Scene {
        WindowGroup {
            ContentView(parser: parser)
                .task {
                    // Force refresh on app launch
                    await parser.fetchData(forceRefresh: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}
