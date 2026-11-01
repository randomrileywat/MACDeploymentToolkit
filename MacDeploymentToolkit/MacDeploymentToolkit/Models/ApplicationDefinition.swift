//
//  ApplicationDefinition.swift
//  MacDeploymentToolkit
//
//  Data models for application definitions and deployment tracking
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Application Definition

/// Represents an application that can be installed via the deployment toolkit
struct ApplicationDefinition: Identifiable, Hashable {
    let id: UUID
    let name: String
    let category: ApplicationCategory
    let installMethod: InstallMethod
    let packageId: String? // For Homebrew casks/formulas or mas-cli app IDs
    let downloadUrl: String? // For direct downloads (Intel/x86_64 or universal)
    let downloadUrlArm: String? // For ARM/Apple Silicon downloads (nil = use downloadUrl for both)
    /// Vendor installer used when a Homebrew install fails. Intel build, or a universal build.
    let fallbackDownloadUrl: String?
    /// Apple Silicon vendor installer. Nil means `fallbackDownloadUrl` is used on Apple Silicon too.
    let fallbackDownloadUrlArm: String?
    /// Intel vendor installer. Nil means `fallbackDownloadUrl` is used on Intel too.
    let fallbackDownloadUrlIntel: String?
    let version: String?
    let macOsEquivalent: String? // If different from Windows version
    let detectionMethod: DetectionMethod?
    let detectionValue: String?
    let sortOrder: Int
    
    /// Initialize with optional ARM-specific URL
    init(id: UUID = UUID(), name: String, category: ApplicationCategory, installMethod: InstallMethod,
         packageId: String? = nil, downloadUrl: String? = nil, downloadUrlArm: String? = nil,
         fallbackDownloadUrl: String? = nil, fallbackDownloadUrlArm: String? = nil,
         fallbackDownloadUrlIntel: String? = nil,
         version: String? = nil, macOsEquivalent: String? = nil,
         detectionMethod: DetectionMethod? = nil, detectionValue: String? = nil,
         sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.category = category
        self.installMethod = installMethod
        self.packageId = packageId
        self.downloadUrl = downloadUrl
        self.downloadUrlArm = downloadUrlArm
        self.fallbackDownloadUrl = fallbackDownloadUrl
        self.fallbackDownloadUrlArm = fallbackDownloadUrlArm
        self.fallbackDownloadUrlIntel = fallbackDownloadUrlIntel
        self.version = version
        self.macOsEquivalent = macOsEquivalent
        self.detectionMethod = detectionMethod
        self.detectionValue = detectionValue
        self.sortOrder = sortOrder
    }
    
    /// Returns the appropriate download URL based on system architecture
    var effectiveDownloadUrl: String? {
        downloadUrl(forAppleSilicon: SystemArchitecture.isAppleSilicon)
    }

    func downloadUrl(forAppleSilicon isAppleSilicon: Bool) -> String? {
        if isAppleSilicon, let armUrl = Self.nonEmpty(downloadUrlArm) {
            return armUrl
        }
        return Self.nonEmpty(downloadUrl)
    }

    /// Vendor fallback for the current CPU. Chip-specific columns win over the shared URL.
    var effectiveFallbackDownloadUrl: String? {
        fallbackDownloadUrl(forAppleSilicon: SystemArchitecture.isAppleSilicon)
    }

    func fallbackDownloadUrl(forAppleSilicon isAppleSilicon: Bool) -> String? {
        let shared = Self.nonEmpty(fallbackDownloadUrl)
        if isAppleSilicon {
            return Self.nonEmpty(fallbackDownloadUrlArm) ?? shared
        }
        return Self.nonEmpty(fallbackDownloadUrlIntel) ?? shared
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ApplicationDefinition, rhs: ApplicationDefinition) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - System Architecture Detection

/// Utility for detecting CPU architecture
enum SystemArchitecture {
    /// Returns true if running on Apple Silicon (ARM64)
    static var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
    
    /// Returns the current architecture name
    static var current: String {
        isAppleSilicon ? "Apple Silicon (ARM64)" : "Intel (x86_64)"
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
        case run = "run" // Self-extracting shell script (requires chmod +x and sudo)

        /// Format implied by a download URL. Query strings are ignored.
        init?(downloadURL: String) {
            let trimmed = downloadURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let components = URLComponents(string: trimmed),
                  let ext = components.path.split(separator: ".").last?.lowercased(),
                  !ext.isEmpty else {
                return nil
            }
            switch ext {
            case "dmg": self = .dmg
            case "pkg", "mpkg": self = .pkg
            case "zip": self = .zip
            case "app": self = .app
            case "run": self = .run
            default: return nil
            }
        }
    }
}

// MARK: - Installed-app detection

/// How the catalog says an app should be detected on disk.
enum DetectionMethod: String {
    case appBundle = "app_bundle"
    case brew = "brew"
    case filePath = "file_path"
    /// Database value is "none" (no local detection). Named `skip` so it is not
    /// confused with Optional.none.
    case skip = "none"
}

#if canImport(SwiftUI)
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
    // Color.cyan is macOS 12+, so we define our own for macOS 11 compatibility
    static let logCyan = Color(red: 0, green: 0.75, blue: 0.85)
    static let logYellow = Color.yellow
    static let logGreen = Color.green
    static let logRed = Color.red
    static let logGray = Color.gray
    static let logOrange = Color.orange
}
#endif
