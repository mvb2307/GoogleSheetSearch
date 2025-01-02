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
    @StateObject private var menuBarManager: MenuBarManager
    
    init() {
        let parser = GoogleSheetsParser()
        self._parser = StateObject(wrappedValue: parser)
        self._menuBarManager = StateObject(wrappedValue: MenuBarManager(parser: parser))
    }
    
    var body: some Scene {
        WindowGroup {
            VStack {
                if isAuthenticated {
                    ContentView(parser: parser, isAuthenticated: $isAuthenticated)
                        .frame(minWidth: 800, minHeight: 500)
                } else {
                    LoginView(isAuthenticated: $isAuthenticated, parser: parser)
                        .frame(minWidth: 400, minHeight: 500)
                }
            }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Toggle Search") {
                    NSApp.activate(ignoringOtherApps: true)
                    menuBarManager.togglePopover(nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .option])
            }
        }
        .onChange(of: isAuthenticated) { newValue in
            if !newValue {
                Task { @MainActor in
                    await menuBarManager.reinitialize(with: parser)
                }
            }
        }
    }
}
