//
//  ApplicationDefinition.swift
//  MacDeploymentToolkit
//
//  Data models for application definitions and deployment tracking
//

import Foundation
import SwiftUI

// MARK: - Application Definition

/// Represents an application that can be installed via the deployment toolkit
struct ApplicationDefinition: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: ApplicationCategory
    let installMethod: InstallMethod
    let packageId: String? // For Homebrew casks/formulas or mas-cli app IDs
    let downloadUrl: String? // For direct downloads
    let version: String?
    let macOsEquivalent: String? // If different from Windows version
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ApplicationDefinition, rhs: ApplicationDefinition) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Application Category

/// Categories for organizing applications in the tree view
enum ApplicationCategory: String, CaseIterable, Identifiable {
    case audio = "Audio"
    case video = "Video"
    case lighting = "Lighting"
    case networking = "Networking"
    case control = "Control"
    case system = "System"
    case testContent = "Test Content"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .audio: return "🎵"
        case .video: return "🎬"
        case .lighting: return "💡"
        case .networking: return "🌐"
        case .control: return "🎛️"
        case .system: return "⚙️"
        case .testContent: return "📦"
        }
    }
}

// MARK: - Installation Method

/// How an application should be installed
enum InstallMethod: Equatable {
    case homebrew(type: HomebrewType)
    case macAppStore(appId: String)
    case directDownload(format: InstallerFormat)
    case custom(handler: String)
    
    enum HomebrewType: String {
        case cask = "cask"    // GUI applications
        case formula = "formula" // CLI tools
    }
    
    enum InstallerFormat: String {
        case dmg = "dmg"
        case pkg = "pkg"
        case zip = "zip"
        case app = "app" // .app bundle in zip/dmg
    }
}

// MARK: - Deployment Task

/// Tracks the status of a deployment task
class DeploymentTask: ObservableObject, Identifiable {
    let id = UUID()
    let name: String
    let category: String
    
    @Published var status: TaskStatus = .pending
    @Published var statusDetail: String = "Pending..."
    
    init(name: String, category: String = "") {
        self.name = name
        self.category = category
    }
    
    var statusIcon: String {
        status.icon
    }
    
    var statusColor: Color {
        status.color
    }
}

// MARK: - Task Status

/// Status states for deployment tasks
enum TaskStatus {
    case pending
    case inProgress
    case success
    case failed
    case skipped
    
    var icon: String {
        switch self {
        case .pending: return "⏳"
        case .inProgress: return "⏳"
        case .success: return "✓"
        case .failed: return "✗"
        case .skipped: return "⊘"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .gray
        case .inProgress: return .orange
        case .success: return .green
        case .failed: return .red
        case .skipped: return .gray
        }
    }
}

// MARK: - Log Entry

/// Represents a single log entry with color coding
struct LogEntry: Identifiable {
    let id = UUID()
    let message: String
    let color: Color
    let timestamp: Date
    
    init(message: String, color: Color = .primary) {
        self.message = message
        self.color = color
        self.timestamp = Date()
    }
}

// MARK: - Log Level Colors

extension Color {
    static let logCyan = Color.cyan
    static let logYellow = Color.yellow
    static let logGreen = Color.green
    static let logRed = Color.red
    static let logGray = Color.gray
    static let logOrange = Color.orange
}
