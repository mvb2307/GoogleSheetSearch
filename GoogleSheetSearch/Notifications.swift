//
//  Notifications.swift
//  GoogleSheetSearch
//
//  Created by Martijn van Beek on 31/12/2024.
//

import SwiftUI

struct FileUpdate: Identifiable, Equatable {
    let id = UUID()
    let fileName: String
    let sheetName: String
    let changeType: ChangeType
    let timestamp: Date
    let details: String
    
    enum ChangeType {
        case added
        case modified
        case removed
        
        var icon: String {
            switch self {
            case .added: return "plus.circle.fill"
            case .modified: return "pencil.circle.fill"
            case .removed: return "minus.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .added: return .green
            case .modified: return .blue
            case .removed: return .red
            }
        }
    }
}

class NotificationManager: ObservableObject {
    @Published private(set) var updates: [FileUpdate] = []
    
    func addUpdate(_ update: FileUpdate) {
        updates.append(update)
    }
    
    func dismissUpdate(_ update: FileUpdate) {
        updates.removeAll { $0.id == update.id }
    }
    
    func dismissAllUpdates() {
        updates.removeAll()
    }
}

struct NotificationButton: View {
    @ObservedObject var manager: NotificationManager
    @State private var showingPopover = false
    
    var body: some View {
        Button(action: { showingPopover.toggle() }) {
            NotificationIcon(count: manager.updates.count)
        }
        .popover(
            isPresented: $showingPopover,
            arrowEdge: .bottom
        ) {
            VStack(alignment: .leading, spacing: 0) {
                // Header with clear all button
                HStack {
                    Text("Recent Changes")
                        .font(.headline)
                    Spacer()
                    if !manager.updates.isEmpty {
                        Button("Clear All") {
                            manager.dismissAllUpdates()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
                
                Divider()
                
                if manager.updates.isEmpty {
                    VStack(spacing: 12) {
                        Text("No Recent Changes")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(manager.updates) { update in
                                NotificationRow(update: update) {
                                    manager.dismissUpdate(update)
                                }
                                if update.id != manager.updates.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 400, maxHeight: 300)
                }
            }
            .background(Color(.windowBackgroundColor))
        }
        .buttonStyle(.plain)
    }
}

struct NotificationIcon: View {
    let count: Int
    
    var body: some View {
        Image(systemName: "bell.fill")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .symbolRenderingMode(.hierarchical)
            .overlay(alignment: .topTrailing) {
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(
                            Circle()
                                .fill(Color.red)
                        )
                        .offset(x: 6, y: -6)
                }
            }
    }
}

struct NotificationRow: View {
    let update: FileUpdate
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: update.changeType.icon)
                .foregroundStyle(update.changeType.color)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(update.fileName)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(update.timestamp, style: .relative)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                
                Text(update.sheetName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                Text(update.details)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(4)
        }
        .padding()
        .contentShape(Rectangle())
        .background(Color(.windowBackgroundColor))
    }
}
