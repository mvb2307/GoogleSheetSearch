//
//  GoogleSheetsParser.swift
//  GoogleSheetSearch
//
//  Created by Martijn van Beek on 03/12/2024.
//

import Foundation
import SwiftUI
import SwiftSoup

struct SheetData: Identifiable {
    let id = UUID()
    let sheetName: String
    let files: [FileEntry]
    let lastModified: Date?
}

@objcMembers class FileEntry: NSObject {
    let id = UUID()
    dynamic let name: String
    dynamic let folderName: String
    dynamic let dateCreated: String?
    dynamic let size: String?
    
    init(name: String, folderName: String, dateCreated: String?, size: String?) {
        self.name = name
        self.folderName = folderName
        self.dateCreated = dateCreated
        self.size = size
        super.init()
    }
    
    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(id)
        return hasher.finalize()
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FileEntry else { return false }
        return id == other.id
    }
    
    override var description: String {
        return "\(folderName)/\(name)"
    }
}

extension FileEntry: Comparable {
    static func < (lhs: FileEntry, rhs: FileEntry) -> Bool {
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}

extension FileEntry: Identifiable {}

@MainActor
class GoogleSheetsParser: ObservableObject {
    @Published var sheets: [SheetData] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var lastRefreshDate: Date?
    @Published var loadingMessage: String = ""
    @Published private(set) var currentURL: String?
    private var refreshTimer: Timer?
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()
    
    @AppStorage("autoRefreshInterval") private var autoRefreshInterval = 300.0
    
    deinit {
        refreshTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupRefreshTimer() {
        refreshTimer?.invalidate()
        
        // Don't set up timer if autoRefreshInterval is 0 (Never)
        guard autoRefreshInterval > 0 else { return }
        
        weak var weakSelf = self
        refreshTimer = Timer.scheduledTimer(withTimeInterval: autoRefreshInterval, repeats: true) { _ in
            Task { @MainActor in
                if let strongSelf = weakSelf {
                    await strongSelf.fetchData()
                }
            }
        }
    }
    
    func startObservingSettings() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleSettingsChange),
            name: UserDefaults.didChangeNotification,
            object: nil)
    }
    
    @objc private func handleSettingsChange() {
        setupRefreshTimer()  // Reconfigure timer when settings change
    }
    
    func fetchData(forceRefresh: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        loadingMessage = "Starting refresh..."
        error = nil
        
        // Add URL validation
        guard let url = currentURL, !url.isEmpty,
              let requestURL = URL(string: url) else {
            await MainActor.run {
                error = NSError(domain: "", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid or empty URL"])
                loadingMessage = ""
                isLoading = false
            }
            return
        }
        
        do {
            loadingMessage = "Fetching latest data..."
            var request = URLRequest(url: requestURL)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            
            if forceRefresh {
                let timestamp = Date().timeIntervalSince1970
                let random = Int.random(in: 0...10000)
                let urlWithParams = url + "?t=\(timestamp)&r=\(random)"
                request = URLRequest(url: URL(string: urlWithParams)!)
            }
            
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    throw NSError(domain: "", code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])
                }
            }
            
            loadingMessage = "Processing data..."
            let newSheets = try await parseHTMLData(data)
            
            // Update UI in a single batch
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    // Clear existing sheets first
                    self.sheets.removeAll()
                    // Add new sheets
                    self.sheets = newSheets
                    self.lastRefreshDate = Date()
                    self.loadingMessage = ""
                    self.isLoading = false
                }
                // Force UI update
                NotificationCenter.default.post(name: .sheetsDidUpdate, object: nil)
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                self.loadingMessage = ""
                self.isLoading = false
            }
        }
    }
    
    func updateURL(_ url: String) async {
        currentURL = url.isEmpty ? nil : url
        UserDefaults.standard.set(url, forKey: "LastUsedSheetURL")
        
        if !url.isEmpty {
            await fetchData(forceRefresh: true)
        } else {
            // Clear the current data when URL is empty
            await MainActor.run {
                sheets = []
                error = nil
                lastRefreshDate = nil
                loadingMessage = ""
            }
        }
    }
    
    private func parseHTMLData(_ data: Data) async throws -> [SheetData] {
        let parseStartTime = Date()
        print("📦 Data size to parse: \(data.count) bytes")
        
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert data to string"])
        }
        
        let doc = try SwiftSoup.parse(htmlString)
        
        // Try to find last modified info
        let metaTags = try doc.select("meta[property=og:updated_time], meta[name=revised], meta[name=last-modified]")
        let lastModified = try metaTags.first()?.attr("content")
        
        let lastModifiedDate = lastModified.flatMap { dateString in
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: dateString)
        }
        
        let sheetNames = [
            "WH '18/'19_1",
            "433_HDD_1",
            "433_HDD_2",
            "433_HDD_3",
            "433_HDD_4",
            "433_HDD_5",
            "433_HDD_6",
            "433_HDD_7",
            "433_HDD_8",
            "433_HDD_9",
            "433_HDD_10",
            "SSD Backups (ON NAS)",
            "433 EDITS - 00 PAID PARTNERSHIPS",
            "433_HDD_11",
            "433_HDD_12",
            "433_HDD_13",
            "433_HDD_14",
            "433_HDD_15",
        ]
        
        let gridContainers = try doc.select("div.ritz.grid-container")
        var parsedSheets: [SheetData] = []
        
        for (index, container) in gridContainers.enumerated() {
            guard let table = try container.select("table").first() else { continue }
            
            let rows = try table.select("tr")
            let sheetName = index < sheetNames.count ? sheetNames[index] : "Sheet \(index + 1)"
            
            var files: [FileEntry] = []
            var hasValidContent = false
            
            for i in 1..<rows.size() {
                let row = rows.get(i)
                let cells = try row.select("td")
                
                if cells.size() >= 2 {
                    let folderName = try cells.get(0).text().trimmingCharacters(in: .whitespacesAndNewlines)
                    let fileName = try cells.get(1).text().trimmingCharacters(in: .whitespacesAndNewlines)
                    let dateCreated = cells.size() >= 3 ? try cells.get(2).text().trimmingCharacters(in: .whitespacesAndNewlines) : nil
                    let size = cells.size() >= 4 ? try cells.get(3).text().trimmingCharacters(in: .whitespacesAndNewlines) : nil
                    
                    if (!folderName.isEmpty && !fileName.isEmpty &&
                        folderName != "Folder Name" && fileName != "Name" &&
                        !fileName.hasPrefix("All files")) ||
                       sheetName == "SSD Backups (ON NAS)" ||
                       sheetName == "433 EDITS - 00 PAID PARTNERSHIPS" {
                        hasValidContent = true
                        let file = FileEntry(
                            name: fileName,
                            folderName: folderName,
                            dateCreated: dateCreated,
                            size: size
                        )
                        files.append(file)
                    }
                }
            }
            
            if hasValidContent ||
               sheetName == "SSD Backups (ON NAS)" ||
               sheetName == "433 EDITS - 00 PAID PARTNERSHIPS" ||
               sheetName.hasPrefix("Sheet") {
                let sheetData = SheetData(
                    sheetName: sheetName,
                    files: files,
                    lastModified: lastModifiedDate
                )
                parsedSheets.append(sheetData)
            }
        }
        
        if parsedSheets.isEmpty {
            throw NSError(domain: "", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No files found in sheets"])
        }
        
        print("Found \(parsedSheets.count) sheets with \(parsedSheets.reduce(0) { $0 + $1.files.count }) total files")
        
        let parseEndTime = Date()
        let parseDuration = parseEndTime.timeIntervalSince(parseStartTime)
        print("""
        📝 Parse Details:
        ----------------
        Sheets Found: \(parsedSheets.count)
        Total Files: \(parsedSheets.reduce(0) { $0 + $1.files.count })
        Parse Time: \(String(format: "%.2f", parseDuration))s
        ----------------
        """)
        
        return parsedSheets
    }
    
    var totalSize: (Double, String) {
        let totalGB = sheets.flatMap { $0.files }.compactMap { file -> Double? in
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
    
    func formatSize(_ sizeInGB: Double?) -> (Double, String) {
        guard let size = sizeInGB else { return (0, "GB") }
        if size >= 1000 {
            return (size / 1000, "TB")
        }
        return (size, "GB")
    }
    
    // Add these properties after the existing properties
    @Published private(set) var userAccountsURL: String?
    @Published var userAccountsSheets: [SheetData] = []

    // Add these methods at the bottom of the class, before the closing brace
    func updateUserAccountsURL(_ url: String) async {
        await MainActor.run {
            userAccountsURL = url.isEmpty ? nil : url
            UserDefaults.standard.set(url, forKey: "UserAccountsSheetURL")
            
            if !url.isEmpty {
                Task {
                    await fetchUserAccountsData(forceRefresh: true)
                }
            } else {
                userAccountsSheets = []
            }
        }
    }

    func fetchUserAccountsData(forceRefresh: Bool = false) async {
        guard !isLoading else { return }
        guard let url = userAccountsURL, !url.isEmpty,
              let requestURL = URL(string: url) else {
            return
        }
        
        isLoading = true
        loadingMessage = "Fetching user accounts data..."
        
        do {
            var request = URLRequest(url: requestURL)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            
            if forceRefresh {
                let timestamp = Date().timeIntervalSince1970
                let random = Int.random(in: 0...10000)
                let urlWithParams = url + "?t=\(timestamp)&r=\(random)"
                request = URLRequest(url: URL(string: urlWithParams)!)
            }
            
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    throw NSError(domain: "", code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])
                }
            }
            
            loadingMessage = "Processing user accounts data..."
            let newSheets = try await parseHTMLData(data)
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.userAccountsSheets = newSheets
                    self.loadingMessage = ""
                    self.isLoading = false
                }
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                self.loadingMessage = ""
                self.isLoading = false
            }
        }
    }

    // Modify the init() method to include userAccountsURL initialization
    init() {
        self.currentURL = "https://docs.google.com/spreadsheets/u/1/d/e/2PACX-1vTAyLw8I4Jwuqmq_n4fYdM5JdZba260kNdtHIEKXE6vLf3WF3u2mISZG-Y1ckMRejY79N7KRpO3wezI/pubhtml"
        self.userAccountsURL = UserDefaults.standard.string(forKey: "UserAccountsSheetURL") ?? "https://docs.google.com/spreadsheets/d/19gmkP27BtoP9xbDvrhGNBx2uN1BYWLAZNTSy8WRcNe4/edit?usp=sharing"
        setupRefreshTimer()
    }
}

extension Notification.Name {
    static let sheetsDidUpdate = Notification.Name("sheetsDidUpdate")
}
