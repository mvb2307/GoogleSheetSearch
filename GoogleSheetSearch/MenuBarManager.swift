//
//  MenuBarManager.swift
//  GoogleSheetSearch
//
//  Created by Martijn van Beek on 02/01/2025.
//

import SwiftUI
import AppKit

struct CommandKeyHelper {
    static var isCommandKeyPressed: Bool {
        NSEvent.modifierFlags.contains(.command)
    }
}

class MenuBarManager: NSObject, ObservableObject, NSPopoverDelegate {
    var statusItem: NSStatusItem?
    private var popover: NSPopover?
    @ObservedObject var parser: GoogleSheetsParser
    @Published var isShown = false  // Add this property
    private var isFirstSetup = true
    private var eventMonitor: Any?
    private var localEventMonitor: Any?
    private var isAnimating = false
    
    init(parser: GoogleSheetsParser) {
        self.parser = parser
        super.init()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.setupMenuBar()
        }
    }
    
    @MainActor
    func reinitialize(with parser: GoogleSheetsParser) async {
        cleanup()
        self.parser = parser
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusButton = self.statusItem?.button {
            statusButton.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
            statusButton.target = self
            statusButton.action = #selector(togglePopover(_:))
            statusButton.sendAction(on: [.leftMouseUp])
        }
        
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 700, height: 600)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        
        let contentView = MenuBarView(parser: parser)
            .environment(\.colorScheme, .dark)
        
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover
        
        // Monitor for clicks outside the popover
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, !self.isAnimating else { return }
            
            if let popover = self.popover,
               popover.isShown {
                if let window = event.window,
                   window.className != "NSStatusBarWindow" {
                    self.closePopover()
                }
            }
        }
        
        // Monitor for ESC key
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                self?.closePopover()
                return nil
            }
            return event
        }
    }
    
    private func closePopover() {
        guard !isAnimating else { return }
        isAnimating = true
        popover?.performClose(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isAnimating = false
        }
    }
    
    @objc public func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button,
              let popover = popover,
              !isAnimating else { return }
        
        if popover.isShown {
            closePopover()
        } else {
            isAnimating = true
            NSApp.activate(ignoringOtherApps: true)
            
            let buttonFrame = button.window?.convertToScreen(button.frame) ?? .zero
            let screenFrame = button.window?.screen?.frame ?? .zero
            
            #if DEBUG
            print("Screen frame: \(screenFrame)")
            print("Button screen frame: \(buttonFrame)")
            #endif
            
            // Calculate the ideal position for the popover
            let idealX = buttonFrame.minX - (700 - buttonFrame.width) / 2 // Center horizontally
            let idealY = buttonFrame.minY - 5 // Position just below the menu bar
            
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            
            // Ensure popover window stays on top and positioned correctly
            if let popoverWindow = popover.contentViewController?.view.window {
                popoverWindow.level = .popUpMenu
                popoverWindow.isMovable = false
                
                // Adjust frame to keep on screen and aligned with menu bar
                var frame = popoverWindow.frame
                
                // Set X position to center the popover relative to the button
                frame.origin.x = max(10, min(idealX, screenFrame.maxX - frame.width - 10))
                
                // Set Y position to be just below the menu bar
                frame.origin.y = screenFrame.maxY - frame.height - 24 // 24 is menu bar height
                
                // Ensure minimum size
                frame.size.width = 700
                frame.size.height = max(frame.size.height, 233)
                
                popoverWindow.setFrame(frame, display: true)
                
                #if DEBUG
                print("Final popover frame: \(frame)")
                #endif
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.isAnimating = false
            }
        }
    }
    
    func cleanup() {
        if let popover = popover, popover.isShown {
            popover.performClose(nil)
        }
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        if let localEventMonitor = localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }
        statusItem = nil
        popover = nil
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - NSPopoverDelegate
    
    func popoverWillShow(_ notification: Notification) {
        if let popover = notification.object as? NSPopover {
            popover.contentSize = NSSize(width: 700, height: 600)
            #if DEBUG
            print("Popover will show - size: \(popover.contentSize)")
            if let view = popover.contentViewController?.view {
                print("Popover view frame: \(view.frame)")
            }
            #endif
        }
    }
    
    func popoverDidShow(_ notification: Notification) {
        #if DEBUG
        if let popover = notification.object as? NSPopover,
           let view = popover.contentViewController?.view {
            print("Popover did show")
            print("Popover view frame: \(view.frame)")
            if let window = view.window {
                print("Popover window frame: \(window.frame)")
                print("Popover window level: \(window.level.rawValue)")
            }
        }
        #endif
    }
    
    func popoverDidClose(_ notification: Notification) {
        #if DEBUG
        print("Popover did close")
        #endif
    }
    
    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        return false
    }
}

struct MenuBarView: View {
    @ObservedObject var parser: GoogleSheetsParser
    @State private var searchText = ""
    
    private func getFilteredResults() -> [(String, [FileEntry])] {
        guard !searchText.isEmpty else { return [] }
        return parser.sheets.enumerated().compactMap { index, sheet in
            let filteredFiles = sheet.files.filter { file in
                file.name.localizedCaseInsensitiveContains(searchText) ||
                file.folderName.localizedCaseInsensitiveContains(searchText)
            }
            return filteredFiles.isEmpty ? nil : ("Sheet \(index + 1)", filteredFiles)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                
                TextField("Type to search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(searchText.isEmpty ? .secondary.opacity(0.5) : .secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .disabled(searchText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.textBackgroundColor))
            
            Divider()
            
            if !searchText.isEmpty {
                let results = getFilteredResults()
                if !results.isEmpty {
                    ResultsListView(results: results, parser: parser)
                } else {
                    EmptyResultsView(sheetsCount: parser.sheets.count)
                        .frame(height: 200)
                }
            } else {
                EmptyResultsView(sheetsCount: parser.sheets.count)
                    .frame(height: 200)
            }
        }
        .frame(width: 700)
    }
}

struct ResultsListView: View {
    let results: [(String, [FileEntry])]
    @ObservedObject var parser: GoogleSheetsParser
    @State private var sortOrder = [KeyPathComparator(\FileEntry.folderName)]
    
    private var sortedFiles: [FileEntry] {
        results.flatMap { $0.1 }.sorted(using: sortOrder)
    }
    
    private var tableHeight: CGFloat {
        let rowHeight: CGFloat = 25
        let headerHeight: CGFloat = 30
        let footerHeight: CGFloat = 36
        let minRows: Int = 2
        
        let numberOfRows = max(sortedFiles.count + 1, minRows)
        let calculatedHeight = CGFloat(numberOfRows) * rowHeight + headerHeight + footerHeight
        
        return min(calculatedHeight, 500)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Table(sortedFiles, selection: .constant(nil), sortOrder: $sortOrder) {
                TableColumn("File Name", value: \.folderName) { file in
                    Text(file.folderName)
                        .font(.system(size: 13))
                }
                .width(min: 225)
                
                TableColumn("Date Created", value: \.name) { file in
                    Text(file.name)
                        .font(.system(size: 13))
                }
                .width(min: 100)
                
                TableColumn("Size", value: \.dateCreated.orEmpty) { file in
                    if let sizeStr = file.dateCreated?.replacingOccurrences(of: " GB", with: ""),
                       let size = Double(sizeStr) {
                        let formatted = parser.formatSize(size)
                        Text("\(String(format: "%.2f", formatted.0)) \(formatted.1)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("-")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .width(min: 100)
                
                TableColumn("Description/ Location", value: \.size.orEmpty) { file in
                    Text(file.size ?? "-")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .width(min: 200)
            }
            .frame(height: tableHeight, alignment: .top)
            .background(Color(.controlBackgroundColor))
            
            Divider()
            ResultsFooterView(resultCount: sortedFiles.count, parser: parser)
        }
    }
}

struct EmptyResultsView: View {
    let sheetsCount: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
            Text("No results found")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("Try different search terms")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            #if DEBUG
            if CommandKeyHelper.isCommandKeyPressed {
                Text("Sheets count: \(sheetsCount)")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }
            #endif
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct ResultsFooterView: View {
    let resultCount: Int
    @ObservedObject var parser: GoogleSheetsParser
    
    var body: some View {
        HStack {
            Text("\(resultCount) results")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                Task {
                    await parser.fetchData(forceRefresh: true)
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .disabled(parser.isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
