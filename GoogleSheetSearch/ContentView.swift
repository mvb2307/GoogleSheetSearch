//
//  ContentView.swift
//  GoogleSheetSearch
//
//  Created by Martijn van Beek on 03/12/2024.
//

import SwiftUI
import SwiftSoup

struct AppStyle {
    static let cornerRadius: CGFloat = 12
    static let iconSize: CGFloat = 24
    static let padding: CGFloat = 20
    static let fontTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let fontHeading = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let fontBody = Font.system(size: 14)
    static let fontSmall = Font.system(size: 13)
    static let accentColor = Color.blue
    
    static let backgroundColor = Color(.windowBackgroundColor)
    static let controlBackgroundColor = Color(.controlBackgroundColor)
    static let secondaryTextColor = Color(.secondaryLabelColor)
    static let iconWidth: CGFloat = 32
    static let tableCornerRadius: CGFloat = 12
    static let statusBarHeight: CGFloat = 28
}

struct ContentView: View {
    @ObservedObject var parser: GoogleSheetsParser
    @Binding var isAuthenticated: Bool
    @State private var isUpdatingList = false
    @StateObject private var notificationManager = NotificationManager()
    @State private var previousSheets: [SheetData] = []
    @State private var searchText = ""
    @State private var selectedSheet: String?
    @State private var urlInput = ""
    @State private var showAllSheets = false
    @State private var isSearching = false
    @State private var updateCounter = 0
    @State private var showingDocumentation = false
    @State private var showingSettings = false
    @State private var showingWebView = true // New state to control WebView presentation
    @AppStorage("showFileCount") private var showFileCount = true
    @AppStorage("customSheetNames") private var customSheetNames: [String: String] = [:]
    @AppStorage("sheetOrder") private var sheetOrder: [String] = []
    @State private var showingRenameSheet = false
    @State private var sheetToRename: String? = nil
    @AppStorage("originalSheetOrder") private var originalSheetOrder: [String] = []
    
    // Update the orderedSheets computed property
    private var orderedSheets: [SheetData] {
        // Create a Set of valid sheet names for faster lookup
        let validSheets = Set(parser.sheets.map(\.sheetName))
        
        // If order is empty or needs cleanup, initialize it
        if sheetOrder.isEmpty || sheetOrder.contains(where: { !validSheets.contains($0) }) {
            DispatchQueue.main.async {
                // Use original order if available, otherwise get from parser
                let orderToUse = !originalSheetOrder.isEmpty ? originalSheetOrder : parser.sheets.map(\.sheetName)
                
                // Remove invalid entries and use original order for new entries
                self.sheetOrder = self.sheetOrder.filter { validSheets.contains($0) }
                let missingSheets = validSheets.subtracting(Set(self.sheetOrder))
                
                // Add missing sheets in their original order
                let orderedMissingSheets = orderToUse.filter { missingSheets.contains($0) }
                self.sheetOrder.append(contentsOf: orderedMissingSheets)
            }
        }
        
        // Return sheets in order, falling back to original order for new sheets
        return parser.sheets.sorted { sheet1, sheet2 in
            let index1 = sheetOrder.firstIndex(of: sheet1.sheetName) ??
                        originalSheetOrder.firstIndex(of: sheet1.sheetName) ??
                        Int.max
            let index2 = sheetOrder.firstIndex(of: sheet2.sheetName) ??
                        originalSheetOrder.firstIndex(of: sheet2.sheetName) ??
                        Int.max
            return index1 < index2
        }
    }
    
    var filteredResults: [(String, [FileEntry])] {
        if searchText.isEmpty {
            if showAllSheets {
                return parser.sheets.map { ($0.sheetName, $0.files) }
            } else if let selectedSheet = selectedSheet,
                      let selectedData = parser.sheets.first(where: { $0.sheetName == selectedSheet }) {
                return [(selectedData.sheetName, selectedData.files)]
            }
            return []
        } else {
            return parser.sheets.compactMap { sheet in
                let matchingFiles = sheet.files.filter { file in
                    let searchTerms = searchText.lowercased().split(separator: " ")
                    return searchTerms.allSatisfy { term in
                        file.name.localizedCaseInsensitiveContains(term) ||
                        file.folderName.localizedCaseInsensitiveContains(term)
                    }
                }
                return matchingFiles.isEmpty ? nil : (sheet.sheetName, matchingFiles)
            }
        }
    }
    
    private var currentViewID: String {
        if !searchText.isEmpty || isSearching {
            return "search-\(searchText)-\(updateCounter)"
        } else if showAllSheets {
            return "all-\(updateCounter)"
        } else if let selectedSheet = selectedSheet {
            return "sheet-\(selectedSheet)-\(updateCounter)"
        } else {
            return "placeholder-\(updateCounter)"
        }
    }
    
    // Update the updateSheetOrder function
    private func updateSheetOrder() {
        let currentSheetNames = Set(parser.sheets.map(\.sheetName))
        let currentOrder = Set(sheetOrder)
        
        // Store the original order from the parser
        originalSheetOrder = parser.sheets.map(\.sheetName)
        
        // Remove non-existent sheets
        sheetOrder = sheetOrder.filter { currentSheetNames.contains($0) }
        
        // Add new sheets in their original order
        let newSheets = currentSheetNames.subtracting(currentOrder)
        let orderedNewSheets = originalSheetOrder.filter { newSheets.contains($0) }
        sheetOrder.append(contentsOf: orderedNewSheets)
    }
    
    // Add this helper function inside ContentView
    private func displayName(for sheetName: String) -> String {
        customSheetNames[sheetName] ?? sheetName
    }
    private func checkForUpdates(currentSheets: [SheetData]) {
        let currentFiles = Dictionary(grouping: currentSheets.flatMap { sheet in
            sheet.files.map { (sheet.sheetName, $0) }
        }, by: { $0.1.folderName })
        
        let previousFiles = Dictionary(grouping: previousSheets.flatMap { sheet in
            sheet.files.map { (sheet.sheetName, $0) }
        }, by: { $0.1.folderName })
        
        var updates: [FileUpdate] = []
        let now = Date()
        
        // Check for new and modified files
        for (folderName, current) in currentFiles {
            let currentFile = current.first!
            
            if let previous = previousFiles[folderName]?.first {
                // File existed before, check for actual changes
                var changes: [String] = []
                
                // Compare size (dateCreated field)
                if currentFile.1.dateCreated != previous.1.dateCreated {
                    changes.append("Size changed: \(previous.1.dateCreated ?? "Unknown") → \(currentFile.1.dateCreated ?? "Unknown")")
                }
                
                // Compare date (name field)
                if currentFile.1.name != previous.1.name {
                    changes.append("Date changed: \(previous.1.name) → \(currentFile.1.name)")
                }
                
                // Compare location/description (size field)
                if currentFile.1.size != previous.1.size {
                    changes.append("Location changed: \(previous.1.size ?? "Unknown") → \(currentFile.1.size ?? "Unknown")")
                }
                
                // Only add if there are actual changes
                if !changes.isEmpty {
                    updates.append(FileUpdate(
                        fileName: currentFile.1.folderName,
                        sheetName: currentFile.0,
                        changeType: .modified,
                        timestamp: now,
                        details: changes.joined(separator: "\n")
                    ))
                }
            } else {
                // New file added
                updates.append(FileUpdate(
                    fileName: currentFile.1.folderName,
                    sheetName: currentFile.0,
                    changeType: .added,
                    timestamp: now,
                    details: """
                        Size: \(currentFile.1.dateCreated ?? "Unknown")
                        Date: \(currentFile.1.name)
                        Location: \(currentFile.1.size ?? "Unknown")
                        """
                ))
            }
        }
        
        // Check for removed files
        for (folderName, previous) in previousFiles {
            if currentFiles[folderName] == nil {
                let previousFile = previous.first!
                updates.append(FileUpdate(
                    fileName: previousFile.1.folderName,
                    sheetName: previousFile.0,
                    changeType: .removed,
                    timestamp: now,
                    details: """
                        Last known size: \(previousFile.1.dateCreated ?? "Unknown")
                        Last known date: \(previousFile.1.name)
                        Last known location: \(previousFile.1.size ?? "Unknown")
                        """
                ))
            }
        }
        
        // Sort updates by timestamp (newest first)
        let sortedUpdates = updates.sorted { $0.timestamp > $1.timestamp }
        
        // Clear existing notifications
        notificationManager.dismissAllUpdates()
        
        // Take the first 10 items (newest changes)
        let lastTenUpdates = Array(sortedUpdates.prefix(1000))
        lastTenUpdates.forEach { update in
            self.notificationManager.addUpdate(update)
        }
        
        // Update previous state
        previousSheets = currentSheets
    }
    
    var body: some View {
        NavigationSplitView {
            // Updated section in ContentView
            VStack(spacing: 0) {
                // URL Input and Refresh Section
                VStack(spacing: 8) {
                    TextField("Google Sheets URL", text: $urlInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                    
                    HStack {
                        Button(action: {
                            Task {
                                await parser.updateURL(urlInput)
                            }
                        }) {
                            Label("Update URL", systemImage: "link")
                        }
                        .disabled(urlInput.isEmpty)
                        
                        Button(action: {
                            Task {
                                await MainActor.run {
                                    withAnimation {
                                        searchText = ""
                                        isSearching = false
                                        selectedSheet = nil
                                        showAllSheets = false
                                        parser.sheets = []
                                    }
                                }
                                await parser.fetchData(forceRefresh: true)
                                await MainActor.run {
                                    withAnimation {
                                        updateCounter += 1
                                    }
                                }
                            }
                        }) {
                            Label("Refresh", systemImage: parser.isLoading ? "arrow.clockwise.circle" : "arrow.clockwise")
                                .opacity(parser.isLoading ? 0.5 : 1)
                        }
                        .disabled(parser.isLoading)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                
                // Updated Sheets List with rename and reorder functionality
                List(selection: $selectedSheet) {
                    Section("Sheets") {
                        Button(action: {
                            withAnimation {
                                showAllSheets = true
                                selectedSheet = nil
                            }
                        }) {
                            HStack {
                                Label("All Storage Locations", systemImage: "internaldrive.fill")
                                    .font(.system(size: 13))
                                if showFileCount {
                                    Spacer()
                                    let totalFiles = parser.sheets.reduce(0) { $0 + $1.files.count }
                                    let totalSize = parser.sheets.flatMap { $0.files }.reduce((0.0, "GB")) { (current, file) in
                                        let sizeStr = file.dateCreated?.replacingOccurrences(of: " GB", with: "") ?? "0"
                                        let size = Double(sizeStr) ?? 0
                                        return (current.0 + size, current.1)
                                    }
                                    let formattedSize = totalSize.0 >= 1000 ? (totalSize.0 / 1000, "TB") : totalSize
                                    Text("(\(totalFiles) files • \(String(format: "%.2f", formattedSize.0)) \(formattedSize.1))")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 12))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        
                        ForEach(orderedSheets) { sheet in
                            NavigationLink(value: sheet.sheetName) {
                                HStack {
                                    Label(displayName(for: sheet.sheetName),
                                          systemImage: "internaldrive")
                                        .font(.system(size: 13))
                                    if showFileCount {
                                        Spacer()
                                        Text("\(sheet.files.count)")
                                            .foregroundStyle(.secondary)
                                            .font(.system(size: 12))
                                    }
                                }
                            }
                            .contextMenu {
                                Button(action: {
                                    sheetToRename = sheet.sheetName
                                    showingRenameSheet = true
                                }) {
                                    Label("Change Display Name", systemImage: "pencil")
                                }
                                
                                if customSheetNames[sheet.sheetName] != nil {
                                    Button(action: {
                                        customSheetNames.removeValue(forKey: sheet.sheetName)
                                    }) {
                                        Label("Reset Display Name", systemImage: "arrow.counterclockwise")
                                    }
                                }
                            }
                        }
                        .onMove { source, destination in
                            withAnimation {
                                sheetOrder.move(fromOffsets: source, toOffset: destination)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .background(Color(.windowBackgroundColor))
                
                // Documentation button
                Divider()
                Button(action: {
                    showingDocumentation = true
                }) {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 16))
                            .symbolRenderingMode(.hierarchical)
                        Text("Documentation")
                            .font(.system(size: 14))
                        Spacer()
                    }
                    .foregroundStyle(.blue)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                .background(Color(.controlBackgroundColor))
            }
            .background(Color(.windowBackgroundColor))
            .navigationTitle("File Search")
        } detail: {
            VStack(spacing: 0) {
                SearchBar(text: $searchText, isSearching: $isSearching)
                    .frame(height: 45)
                    .padding()
                
                Group {
                    if parser.isLoading {
                        ContentLoadingView()
                    } else if let error = parser.error {
                        ErrorView(message: error.localizedDescription)
                    } else if !searchText.isEmpty || isSearching {
                        SearchResultsView(results: filteredResults, parser: parser)
                    } else if showAllSheets {
                        AllSheetsView(
                            sheets: parser.sheets,
                            parser: parser,
                            onClose: {
                                showAllSheets = false
                            }
                        )
                    } else if let _ = selectedSheet,
                              let selectedData = filteredResults.first {
                        FileListView(
                            sheetName: selectedData.0,
                            files: selectedData.1,
                            parser: parser
                        )
                    } else {
                        PlaceholderView()
                    }
                }
                .id(currentViewID)
                
                StatusBarView(
                    lastRefreshDate: parser.lastRefreshDate,
                    isLoading: parser.isLoading,
                    loadingMessage: parser.loadingMessage,
                    totalGB: parser.totalSize
                )
            }
            .background(Color(.windowBackgroundColor))
        }
        // Find the .toolbar section and replace it with this:
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    // New Button to Open WebView with Icon
                    Button(action: {
                        showingWebView = true  // Set the state to true when the button is pressed
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .help("Open Google Sheet")
                    .frame(width: 20)

                    // Notification Button
                    NotificationButton(manager: notificationManager)
                        .frame(width: 20)

                    // Settings Button
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .help("Settings")
                    .frame(width: 20)

                    Divider()
                        .frame(height: 16)

                    // Logout Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            isAuthenticated = false
                        }
                    }) {
                        Image(systemName: "xmark.square")
                            .font(.system(size: 20))
                            .foregroundStyle(AppStyle.accentColor)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .help("Logout")
                    .frame(width: 20)
                }
                .padding(.horizontal, 8)
            }
        }
        .sheet(isPresented: $showingDocumentation) {
            DocumentationView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(parser: parser)
        }
        .sheet(isPresented: $showingRenameSheet) {
            if let sheetName = sheetToRename {
                RenameSheet(
                    sheetName: sheetName,
                    currentName: customSheetNames[sheetName] ?? sheetName
                )
            }
        }
        .onChange(of: showingRenameSheet) { isShowing in
            if !isShowing {
                sheetToRename = nil
            }
        }
        .background(Color(.windowBackgroundColor))
        .task {
            await parser.fetchData()
        }
        .onAppear {
            updateSheetOrder()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sheetsDidUpdate)) { _ in
            withAnimation {
                updateSheetOrder()
                updateCounter += 1
                checkForUpdates(currentSheets: parser.sheets)
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    @Binding var isSearching: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: AppStyle.iconSize))
                .foregroundStyle(AppStyle.accentColor)
                .symbolRenderingMode(.hierarchical)
            
            TextField("Search files...", text: $text)
                .font(AppStyle.fontBody)
                .textFieldStyle(.plain)
                .onChange(of: text) { _ in
                    isSearching = !text.isEmpty
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    isSearching = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppStyle.padding)
        .background(
            RoundedRectangle(cornerRadius: AppStyle.cornerRadius)
                .fill(Color(.controlBackgroundColor))
        )
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}

struct FileListView: View {
    let sheetName: String
    let files: [FileEntry]
    let parser: GoogleSheetsParser
    @AppStorage("customSheetNames") private var customSheetNames: [String: String] = [:]
    @State private var sortOrder = [KeyPathComparator(\FileEntry.folderName)]
    
    private var displayName: String {
        customSheetNames[sheetName] ?? sheetName
    }
    
    var sortedFiles: [FileEntry] {
        return files.sorted(using: sortOrder)
    }
    
    var totalSize: (Double, String) {
        let totalGB = files.compactMap { file -> Double? in
            guard let sizeStr = file.dateCreated?.replacingOccurrences(of: " GB", with: ""),
                  let size = Double(sizeStr) else {
                return nil
            }
            return size
        }.reduce(0, +)
        
        if totalGB >= 1000 {
            return (totalGB / 1000, "TB")
        } else {
            return (totalGB, "GB")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "internaldrive")
                    .font(.system(size: AppStyle.iconSize))
                    .foregroundStyle(AppStyle.accentColor)
                    .symbolRenderingMode(.hierarchical)
                Text(displayName)
                    .font(AppStyle.fontHeading)
                Text("(\(files.count) files • \(String(format: "%.2f", totalSize.0)) \(totalSize.1))")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            
            Table(sortedFiles, selection: .constant(nil), sortOrder: $sortOrder) {
                TableColumn("File Name", value: \.folderName) { file in
                    Text(file.folderName)
                        .font(.system(size: 13))
                        .lineLimit(1)
                }
                .width(min: 250)
                
                TableColumn("Date Created", value: \.name) { file in
                    Text(file.name)
                        .font(.system(size: 13))
                        .lineLimit(1)
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
                
                TableColumn("Location", value: \.size.orEmpty) { file in
                    Text(file.size ?? "-")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .width(min: 200)
                
                TableColumn("Description", value: \.fileDescription.orEmpty) { file in
                    Text(file.fileDescription.orEmpty)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .width(min: 800)
            }
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius))
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }
}

struct ContentLoadingView: View {
    var body: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .frame(minHeight: 44)
            Text("Loading files...")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.top)
            Spacer()
        }
    }
}

struct PlaceholderView: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "internaldrive")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Select a hard drive from the sidebar to view files")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .padding(.top)
            Spacer()
        }
    }
}

struct ErrorView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)
                .symbolRenderingMode(.multicolor)
            Text("Error")
                .font(.system(.title2, design: .rounded).bold())
            Text(message)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct SearchResultsView: View {
    let results: [(String, [FileEntry])]
    let parser: GoogleSheetsParser
    @AppStorage("customSheetNames") private var customSheetNames: [String: String] = [:]
    @State private var sortOrder = [KeyPathComparator(\FileEntry.folderName)]
    
    private func displayName(for sheetName: String) -> String {
        customSheetNames[sheetName] ?? sheetName
    }
    
    var sortedFiles: [FileEntry] {
        results.flatMap { $0.1 }.sorted(using: sortOrder)
    }
    
    var totalSize: (Double, String) {
        let totalGB = sortedFiles.compactMap { file -> Double? in
            guard let sizeStr = file.dateCreated?.replacingOccurrences(of: " GB", with: ""),
                  let size = Double(sizeStr) else {
                return nil
            }
            return size
        }.reduce(0, +)
        
        if totalGB >= 1000 {
            return (totalGB / 1000, "TB")
        } else {
            return (totalGB, "GB")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: AppStyle.iconSize))
                    .foregroundStyle(AppStyle.accentColor)
                    .symbolRenderingMode(.hierarchical)
                Text("Search Results")
                    .font(AppStyle.fontHeading)
                Text("(\(sortedFiles.count) files)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("•")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("\(String(format: "%.2f", totalSize.0)) \(totalSize.1))")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            
            Table(sortedFiles, selection: .constant(nil), sortOrder: $sortOrder) {
                TableColumn("File Name", value: \.folderName) { file in
                    Text(file.folderName)
                        .font(.system(size: 13))
                }
                .width(min: 250)
                
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
                
                TableColumn("Location", value: \.size.orEmpty) { file in
                    Text(file.size ?? "-")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .width(min: 200)
                
                TableColumn("Description", value: \.fileDescription.orEmpty) { file in
                    Text(file.fileDescription.orEmpty)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .width(min: 800)
            }
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius))
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }
}

// New AllSheetsView
struct AllSheetsView: View {
    let sheets: [SheetData]
    let parser: GoogleSheetsParser
    let onClose: () -> Void
    @AppStorage("customSheetNames") private var customSheetNames: [String: String] = [:]
    @State private var sortOrder = [KeyPathComparator(\FileEntry.folderName)]
    
    private func displayName(for sheetName: String) -> String {
        customSheetNames[sheetName] ?? sheetName
    }
    
    var allFiles: [FileEntry] {
        sheets.flatMap { sheet in
            sheet.files.map { file in
                FileEntry(
                    name: file.name,
                    folderName: file.folderName,
                    dateCreated: file.dateCreated,
                    size: file.size,
                    fileDescription: file.fileDescription // Ensure this property exists in FileEntry
                )
            }
        }
    }
    
    var sortedFiles: [FileEntry] {
        return allFiles.sorted(using: sortOrder)
    }
    
    var totalSize: (Double, String) {
        let totalGB = sortedFiles.compactMap { file -> Double? in
            guard let sizeStr = file.dateCreated?.replacingOccurrences(of: " GB", with: ""),
                  let size = Double(sizeStr) else {
                return nil
            }
            return size
        }.reduce(0, +)
        
        if totalGB >= 1000 {
            return (totalGB / 1000, "TB")
        } else {
            return (totalGB, "GB")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: AppStyle.iconSize))
                    .foregroundStyle(AppStyle.accentColor)
                    .symbolRenderingMode(.hierarchical)
                Text("All Storage Locations")
                    .font(AppStyle.fontHeading)
                Text("(\(allFiles.count) files • \(String(format: "%.2f", totalSize.0)) \(totalSize.1))")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Table(sortedFiles, selection: .constant(nil), sortOrder: $sortOrder) {
                TableColumn("File Name", value: \.folderName) { file in
                    Text(file.folderName)
                        .font(.system(size: 13))
                }
                .width(min: 250)
                
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
                
                TableColumn("Location", value: \.size.orEmpty) { file in
                    Text(file.size ?? "-")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .width(min: 200)
                
                TableColumn("Description", value: \.fileDescription.orEmpty) { file in
                    Text(file.fileDescription.orEmpty)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .width(min: 800)
            }
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius))
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }
}

// Add this helper struct for the status bar
struct StatusBarView: View {
    let lastRefreshDate: Date?
    let isLoading: Bool
    let loadingMessage: String
    let totalGB: (Double, String)
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' HH:mm:ss"
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                Text(loadingMessage)
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut, value: loadingMessage)
            } else {
                Image(systemName: "arrow.clockwise.circle")
                    .foregroundStyle(.secondary)
                if let date = lastRefreshDate {
                    Text("Last refreshed on \(dateFormatter.string(from: date))")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            
            // Update the total size display
            Text("Total Storage All Drives: \(String(format: "%.2f", totalGB.0)) \(totalGB.1)")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            
            if isLoading {
                Text("Please wait for refresh to complete...")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal)
        .frame(height: 36)
        .background(.bar)
        .animation(.easeInOut, value: isLoading)
    }
}

struct DocumentationView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
                Text("Documentation")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(8)
            }
            .padding()
            
            Divider()
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 24) {
                    Group {
                        DocumentationSection(
                            icon: "checklist.checked",
                            title: "INDEX",
                            content: """
                            • What does this app do?
                            • Using the Search
                            • Data Updates
                            • Settings & Preferences
                            • Setting up the Google Sheet URL
                            • Need help?
                            • Storage Calculator
                            • Sheet Management
                            • User Accounts
                            """
                        )
                        DocumentationSection(
                            icon: "info.circle.fill",
                            title: "What does this app do?",
                            content: """
                            This app helps you quickly find files across multiple storage locations. Features include:
                            • Real-time file search across all Google sheets showing the HDD & SSD Contents.
                            • Automatic data refresh
                            • File size tracking and totals
                            • Sortable columns for all views
                            • Individual sheet and combined views
                            • Storage space monitoring (GB/TB)
                            • Custom sheet names and ordering
                            • Comprehensive search capabilities
                            """
                        )
                        
                        DocumentationSection(
                            icon: "magnifyingglass.circle.fill",
                            title: "Using the Search",
                            content: """
                            Finding files is easy:
                            • Type in the search box to find files across All Storage Locations
                            • Click on a sheet name to view only that sheet
                            • Click 'All Storage Locations' to see everything at once
                            • Use the X button to clear your search
                            
                            Table Features:
                            • Click any column header to sort by that column
                            • Click again to reverse sort order
                            • Columns include: File Name, Date Created, Size, and Location
                            
                            Sheet Management:
                            • Right-click sheets to rename them
                            • Drag and drop to reorder sheets
                            • Reset custom names via context menu
                            
                            Searching from the Menu Bar:
                            • You can now search from the menu bar without opening the app
                              simply click on the magnifying glass icon there and type what
                              you are looking for.
                            """
                        )
                        
                        DocumentationSection(
                            icon: "arrow.clockwise.circle.fill",
                            title: "Data Updates",
                            content: """
                            The app updates data in multiple ways:
                            • Automatic refresh (configurable in Settings)
                            • Manual refresh using the refresh button
                            • Force refresh by holding the refresh button
                            
                            Settings allow you to:
                            • Choose refresh interval (1-30 minutes)
                            • Enable/disable automatic updates
                            • Force immediate refresh when needed
                            """
                        )
                        
                        DocumentationSection(
                            icon: "gear.circle.fill",
                            title: "Settings & Preferences",
                            content: """
                            Customize the app through Settings:
                            • Auto-refresh interval selection
                            • Show/hide file counts in sidebar
                            • Choose default view on startup
                            • Reset Google Sheet URL
                            
                            Display Options:
                            • File counts per sheet
                            • Total storage usage (GB/TB)
                            • Last refresh timestamp
                            • Custom sheet display names
                            """
                        )
                        
                        DocumentationSection(
                            icon: "link.circle.fill",
                            title: "Setting up the Google Sheet URL",
                            content: """
                            The Google Sheet URL is automatically saved and you only need to set it once.
                            You'll only need to update it if:
                            • The original Google Sheet is deleted
                            • The sheet is moved to a new location
                            • You need to connect to a different sheet

                            To get a new URL:
                            1. Ask your office data manager for the URL
                            2. Get it directly from Google Sheets:
                               • Open the Google Sheet
                               • Click File > Share > Publish to web
                               • Choose 'Entire Document' and 'Web page'
                               • Click 'Publish' and copy the URL
                               • Paste the URL in the app's URL field

                            Note: The URL should start with 'https://docs.google.com/spreadsheets/'
                            """
                        )
                        
                        DocumentationSection(
                            icon: "exclamationmark.triangle.fill",
                            title: "Need help?",
                            content: """
                            If you're having trouble with:
                            • App functionality: Check this documentation first
                            • Google Sheet URL: Contact your office data manager
                            • Technical issues: Contact IT support
                            • Bug reports: Send to development team
                            
                            IMPORTANT: Due to how Google Sheets works, updates might take a moment to appear.
                            If you don't see recent changes, try refreshing again after a few seconds.
                            """
                        )
                        
                        // Add new section for Storage Calculator
                        DocumentationSection(
                            icon: "externaldrive.fill",
                            title: "Storage Calculator",
                            content: """
                            The Storage Calculator helps you monitor storage usage:
                            
                            Features:
                            • Enter total storage capacity in TB or GB
                            • Visual progress bar shows usage percentage
                            • Color-coded warnings (red when >90% full)
                            • Shows used and free storage
                            • Automatically updates with new files
                            
                            Usage:
                            1. Enter your total storage capacity
                            2. Choose unit (TB or GB)
                            3. View real-time storage statistics
                            4. Use reset button to clear settings
                            
                            Note: The calculator uses the total size of all files across all Storage Locations
                            """
                        )
                        
                        // Add new section for Sheet Management
                        DocumentationSection(
                            icon: "rectangle.stack.badge.person.crop.fill",
                            title: "Sheet Management",
                            content: """
                            Customize how sheets appear in the sidebar:
                            
                            Renaming Sheets:
                            • Right-click any sheet in the sidebar
                            • Choose "Change Display Name"
                            • Enter a new display name
                            • Original sheet name remains unchanged
                            • Use "Reset Display Name" to remove custom name
                            
                            Reordering Sheets:
                            • Click and drag sheets in the sidebar
                            • Drop to new position to reorder
                            • Order is preserved between sessions
                            • New sheets appear at the bottom
                            • Reset app to restore original order
                            
                            Tips:
                            • Custom names help organize related sheets
                            • Drag frequently used sheets to the top
                            • Right-click menu shows all sheet options
                            • Changes only affect local display
                            """
                        )
                        
                        // Add new section for Sheet Management
                        DocumentationSection(
                            icon: "person.circle.fill",
                            title: "User Accounts",
                            content: """
                            Creating & Managing User Accounts:

                            Creating an Account:
                            • Start the app and click on the "Create Account" button.
                            • Fill out the form with the required details.
                            • Click "Create Account" to finalize your account setup.

                            Logging In:
                            • Enter your credentials to log in.
                            • Select "Keep me signed in" for easier access.
                            • Note: The app will log you out after restarting your Mac or relaunching the app.
                            
                            Logging Out:
                            • Simply press the blue cross button in the top right of the app.

                            Forgotten Password:
                            • Contact the app administrator for help.
                            • Alternatively, reset your password via the app:
                            • Go to the Settings section.
                            • Navigate to User Accounts URL.
                            • Click the URL to access the Passwords section.
                            • Locate your account and set a new password.

                            Tips:
                            • Use "Keep me signed in" for quicker access.
                            • Restarting the app or Mac will require you to log in again.
                            • Regularly update your password for enhanced security.
                            """
                        )
                    }
                }
                .padding(.vertical, 20)
                .padding(.leading, 20)
                .padding(.trailing, 4)
            }
        }
        .frame(width: 600, height: 600)
        .background(Color(.windowBackgroundColor))
    }
}

struct DocumentationSection: View {
    let icon: String
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 32)
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Spacer()
            }
            
            Text(content)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .padding(.leading, 44)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

struct TableContainerStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppStyle.controlBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius))
    }
}

extension View {
    func tableContainer() -> some View {
        modifier(TableContainerStyle())
    }
}

struct SectionHeaderStyle: ViewModifier {
    let icon: String
    let title: String
    
    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: AppStyle.iconSize))
                    .foregroundStyle(AppStyle.accentColor)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: AppStyle.iconWidth)
                Text(title)
                    .font(AppStyle.fontHeading)
                Spacer()
            }
            .padding()
            
            content
        }
        .background(AppStyle.backgroundColor)
    }
}

extension View {
    func sectionHeader(icon: String, title: String) -> some View {
        modifier(SectionHeaderStyle(icon: icon, title: title))
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var parser: GoogleSheetsParser
    @AppStorage("autoRefreshInterval") private var autoRefreshInterval = 300.0
    @AppStorage("showFileCount") private var showFileCount = true
    @AppStorage("defaultView") private var defaultView = "last"
    @State private var newURL = ""
    @AppStorage("totalStorageCapacity") private var totalStorageCapacity = 0.0
    @AppStorage("storageUnit") private var storageUnit = "TB"
    @State private var stats: StorageStats = .empty
    
    
    // Move stats to a separate struct for better state management
    private struct StorageStats: Equatable {
        let used: Double
        let free: Double
        let usedPercentage: Double
        
        static let empty = StorageStats(used: 0, free: 0, usedPercentage: 0)
    }
    
    private func calculateStorageStats() -> StorageStats {
        let currentSize = parser.totalSize
        
        // Convert everything to TB for calculation
        let usedStorage = storageUnit == "TB" ? currentSize.0 : currentSize.0 / 1000
        let totalStorage = storageUnit == "TB" ? totalStorageCapacity : totalStorageCapacity / 1000
        
        let freeStorage = max(0, totalStorage - usedStorage)
        let usedPercentage = totalStorage > 0 ? (usedStorage / totalStorage) * 100 : 0
        
        return StorageStats(
            used: usedStorage,
            free: freeStorage,
            usedPercentage: usedPercentage
        )
    }
    
    private func updateStats() {
        stats = calculateStorageStats()
    }
    
    private func resetAll() {
        // Reset URL
        Task {
            await parser.updateURL("")
            newURL = ""
        }
        // Reset storage calculator
        totalStorageCapacity = 0.0
        storageUnit = "TB"
        updateStats()
    }
    
    private func resetStorageCalculator() {
        totalStorageCapacity = 0.0
        storageUnit = "TB"
        updateStats()
    }
    private func resetUserAccountsURL() {
        Task {
            await parser.updateUserAccountsURL("")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "gear")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
                Text("Settings")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(8)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Auto-refresh Settings
                    SettingsSection(
                        icon: "clock.arrow.circlepath",
                        title: "Auto Refresh",
                        content: {
                            Picker("Auto-refresh interval:", selection: $autoRefreshInterval) {
                                Text("1 minute").tag(60.0)
                                Text("5 minutes").tag(300.0)
                                Text("10 minutes").tag(600.0)
                                Text("30 minutes").tag(1800.0)
                                Text("Never").tag(0.0)
                            }
                            .labelsHidden()
                            
                            Text("How often the app should check for updates")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    )
                    
                    // Display Settings
                    SettingsSection(
                        icon: "eye",
                        title: "Display",
                        content: {
                            Toggle("Show file count in sidebar", isOn: $showFileCount)
                            
                            Picker("Default View:", selection: $defaultView) {
                                Text("Last Selected Sheet").tag("last")
                                Text("All Storage Locations").tag("all")
                                Text("None").tag("none")
                            }
                            .labelsHidden()
                            
                            Text("What to show when the app starts")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    )
                    
                    SettingsSection(
                        icon: "link",
                        title: "User Accounts URL",
                        content: {
                            VStack(alignment: .leading, spacing: 12) {
                                // Active URL display or warning
                                if let currentURL = parser.userAccountsURL, !currentURL.isEmpty {
                                    Text("Active URL:")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                    
                                    Button(action: {
                                        if let url = URL(string: currentURL) {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }) {
                                        Text(currentURL)
                                            .font(.system(size: 13))
                                            .foregroundColor(.blue)
                                            .textSelection(.enabled)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.textBackgroundColor))
                                    .cornerRadius(6)
                                }
                                
                                Text("New URL:")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                
                                TextField("Enter new User Accounts Sheet URL", text: $newURL)
                                    .textFieldStyle(.roundedBorder)
                                
                                HStack(spacing: 12) {
                                    Button(action: {
                                        Task {
                                            if !newURL.isEmpty {
                                                await parser.updateUserAccountsURL(newURL)
                                                newURL = ""  // Clear the input field after update
                                            }
                                        }
                                    }) {
                                        Label("Update URL", systemImage: "link")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(newURL.isEmpty)
                                    
                                    Button("Reset") {
                                        resetUserAccountsURL()
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                Text("Enter a new URL above or reset to start fresh")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    )
                    
                    // URL Settings
                    SettingsSection(
                        icon: "link",
                        title: "Google Sheet URL",
                        content: {
                            VStack(alignment: .leading, spacing: 12) {
                                // Active URL display or warning
                                if let currentURL = parser.currentURL, !currentURL.isEmpty {
                                    Text("Active URL:")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                    
                                    Button(action: {
                                        if let url = URL(string: currentURL) {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }) {
                                        Text(currentURL)
                                            .font(.system(size: 13))
                                            .foregroundColor(.blue)
                                            .textSelection(.enabled)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.textBackgroundColor))
                                    .cornerRadius(6)
                                }
                                
                                // Rest of the URL settings content remains the same
                                Text("New URL:")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                
                                TextField("Enter new Google Sheet URL", text: $newURL)
                                    .textFieldStyle(.roundedBorder)
                                
                                HStack(spacing: 12) {
                                    Button(action: {
                                        Task {
                                            if !newURL.isEmpty {
                                                await parser.updateURL(newURL)
                                                newURL = ""  // Clear the input field after update
                                            }
                                        }
                                    }) {
                                        Label("Update URL", systemImage: "link")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(newURL.isEmpty)
                                    
                                    Button("Reset") {
                                        resetAll()
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                Text("Enter a new URL above or reset to start fresh")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    )
                    
                    // Storage Calculator Section
                    SettingsSection(
                        icon: "externaldrive",
                        title: "Storage Calculator",
                        content: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    TextField("Total Storage", value: $totalStorageCapacity, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 100)
                                        .onChange(of: totalStorageCapacity) { _ in
                                            updateStats()
                                        }
                                    
                                    Picker("Unit", selection: $storageUnit) {
                                        Text("TB").tag("TB")
                                        Text("GB").tag("GB")
                                    }
                                    .labelsHidden()
                                    .frame(width: 80)
                                    .onChange(of: storageUnit) { _ in
                                        updateStats()
                                    }
                                    
                                    Button(action: resetStorageCalculator) {
                                        Image(systemName: "arrow.counterclockwise")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.bordered)
                                    .help("Reset Storage Calculator")
                                }
                                
                                // Storage visualization
                                if totalStorageCapacity > 0 {
                                    VStack(alignment: .leading, spacing: 8) {
                                        // Storage bar
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(.separatorColor))
                                                .frame(height: 8)
                                            
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(stats.usedPercentage > 90 ? Color.red : Color.blue)
                                                .frame(width: max(0, min(300 * CGFloat(stats.usedPercentage / 100), 300)))
                                                .frame(height: 8)
                                        }
                                        .frame(width: 300)
                                        
                                        // Stats display
                                        Group {
                                            StorageStatRow(
                                                color: stats.usedPercentage > 90 ? .red : .blue,
                                                label: "Used Storage:",
                                                value: stats.used,
                                                unit: storageUnit
                                            )
                                            
                                            StorageStatRow(
                                                color: Color(.separatorColor),
                                                label: "Free Storage:",
                                                value: stats.free,
                                                unit: storageUnit
                                            )
                                            
                                            HStack {
                                                Text("Usage:")
                                                    .foregroundStyle(.secondary)
                                                Text(String(format: "%.1f%%", stats.usedPercentage))
                                                    .bold()
                                                    .foregroundStyle(stats.usedPercentage > 90 ? Color.red : Color.primary)
                                            }
                                            .font(.system(size: 13))
                                        }
                                    }
                                } else {
                                    Text("Enter your total storage capacity above to see usage statistics")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    )
                    
                    // About Section
                    SettingsSection(
                        icon: "info.circle",
                        title: "About",
                        content: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("File Search v1.0.0")
                                    .bold()
                                Text("2024")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    )
                }
                .padding()
            }
        }
        .frame(width: 500, height: 400)
        .background(Color(.windowBackgroundColor))
        .onAppear {
    
        }
    }
}

struct SettingsSection<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Spacer()
            }
            
            content()
                .padding(.leading, 36)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

extension Array: RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

extension Dictionary: RawRepresentable where Key: Codable, Value: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Key: Value].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return result
    }
}

// Add this struct inside ContentView
private struct DropViewDelegate: DropDelegate {
    let item: String
    @Binding var sheetOrder: [String]
    
    func performDrop(info: DropInfo) -> Bool {
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Get the from index
        guard let fromIndex = Int(info.itemProviders(for: [.text]).first?.suggestedName ?? ""),
              let toIndex = sheetOrder.firstIndex(of: item) else { return }
        
        if fromIndex != toIndex {
            withAnimation {
                let fromItem = sheetOrder[fromIndex]
                sheetOrder.remove(at: fromIndex)
                sheetOrder.insert(fromItem, at: toIndex)
            }
        }
    }
}

// Replace the existing RenameSheet struct with this updated version
struct RenameSheet: View {
    @Environment(\.dismiss) var dismiss
    @FocusState private var isTextFieldFocused: Bool
    let sheetName: String
    @State private var newDisplayName: String
    @AppStorage("customSheetNames") private var customSheetNames: [String: String] = [:]
    
    init(sheetName: String, currentName: String) {
        self.sheetName = sheetName
        // Initialize with the current name
        _newDisplayName = State(initialValue: currentName)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Change Sidebar Display Name")
                .font(.title2.bold())
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Original name: \(sheetName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Display name", text: $newDisplayName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                    .focused($isTextFieldFocused)
                    .onAppear { isTextFieldFocused = true }
            }
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Save") {
                    let trimmedName = newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedName.isEmpty || trimmedName == sheetName {
                        customSheetNames.removeValue(forKey: sheetName)
                    } else {
                        customSheetNames[sheetName] = trimmedName
                    }
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// Add this helper view for storage stats rows
struct StorageStatRow: View {
    let color: Color
    let label: String
    let value: Double
    let unit: String
    
    var body: some View {
        HStack {
            Label {
                Text(label)
                    .foregroundStyle(.secondary)
            } icon: {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            Text(String(format: "%.2f %@", value, unit))
                .bold()
        }
        .font(.system(size: 13))
    }
}
