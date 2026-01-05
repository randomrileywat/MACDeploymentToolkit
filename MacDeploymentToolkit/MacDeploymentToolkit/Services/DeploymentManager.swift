//
//  DeploymentManager.swift
//  MacDeploymentToolkit
//
//  Main deployment orchestrator that coordinates application installation
//  and system standardization tasks
//

import Foundation
import SwiftUI
import Combine

/// Main deployment manager that orchestrates all installation and configuration tasks
@MainActor
class DeploymentManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isDeploying = false
    @Published var tasks: [DeploymentTask] = []
    @Published var logEntries: [LogEntry] = []
    @Published var currentStatus: String = ""
    @Published var friendlyMessage: String = "Deployment Progress"
    
    // MARK: - Private Properties
    
    private var friendlyMessageTimer: Timer?
    private var currentMessageIndex = 0
    private let friendlyMessages = [
        "☕ Great time to grab a coffee!",
        "🚀 Installing your applications...",
        "🛸 Beaming in the last bits of your setup...",
        "🎯 Almost there! Good things take time...",
        "🔧 Optimizing settings and configuring preferences...",
        "🎨 Personalizing your Mac experience...",
        "🌐 Aligning with the universe... or at least macOS.",
        "🤖 Teaching your Mac some new tricks...",
        "🔍 Checking all the boxes (literally)...",
        "📦 Unpacking your digital goodies...",
        "📡 Negotiating with package managers...",
        "🔧 Tightening a few virtual screws...",
        "📘 Reading the manual so you don't have to..."
    ]
    
    // Services
    private let homebrewInstaller = HomebrewInstaller()
    private let directDownloadInstaller = DirectDownloadInstaller()
    private let systemStandardizer = SystemStandardizer()
    
    // Admin privileges
    private var sudoKeepaliveProcess: Process?
    
    // Supabase configuration
    private let supabaseUrl = "https://incdoepqrbwaagatikgb.supabase.co"
    private let supabaseServiceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImluY2RvZXBxcmJ3YWFnYXRpa2diIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjkwNzA0OSwiZXhwIjoyMDc4NDgzMDQ5fQ.5qjYJq7OGWAdBIVZqzpRE71aJEEOvbko9m3VDVJuQQA"
    
    // MARK: - Deployment Control
    
    /// Start the deployment process with selected applications and options
    func startDeployment(
        applications: [ApplicationDefinition],
        macStandardization: Bool,
        computerName: String,
        customIconPath: String?
    ) {
        guard !isDeploying else { return }
        
        isDeploying = true
        tasks.removeAll()
        logEntries.removeAll()
        
        // Initialize tasks
        if macStandardization {
            tasks.append(DeploymentTask(name: "Mac Standardization", category: "System"))
        }
        
        for app in applications {
            tasks.append(DeploymentTask(name: app.name, category: app.category.rawValue))
        }
        
        // Start friendly messages
        startFriendlyMessages()
        
        // Run deployment asynchronously
        Task {
            await runDeployment(
                applications: applications,
                macStandardization: macStandardization,
                computerName: computerName,
                customIconPath: customIconPath
            )
        }
    }
    
    /// Main deployment execution
    private func runDeployment(
        applications: [ApplicationDefinition],
        macStandardization: Bool,
        computerName: String,
        customIconPath: String?
    ) async {
        let startTime = Date()
        
        log("=== Mac Deployment Started ===", color: .logCyan)
        log("Timestamp: \(formatDate(startTime))", color: .logGray)
        log("")
        
        var successCount = 0
        var failCount = 0
        
        // Step 0: Request admin privileges once at the start (for ALL deployments)
        // This covers: Homebrew installation, PKG installers, system settings, etc.
        log("Requesting administrator privileges...", color: .logYellow)
        log("(You will only need to enter your password once)", color: .logGray)
        currentStatus = "Requesting admin privileges..."
        
        let adminGranted = await requestAdminPrivileges()
        if adminGranted {
            log("✓ Administrator privileges granted", color: .logGreen)
        } else {
            log("⚠ Administrator privileges not granted - some features may fail", color: .logOrange)
        }
        log("")
        
        // Step 1: Mac Standardization
        if macStandardization {
            updateTask("Mac Standardization", status: .inProgress, detail: "In progress...")
            log("=== Applying Mac Standardization ===", color: .logCyan)
            currentStatus = "Configuring system settings..."
            
            do {
                try await systemStandardizer.applyStandardization(
                    computerName: computerName,
                    customIconPath: customIconPath
                )
                updateTask("Mac Standardization", status: .success, detail: "Completed successfully")
                successCount += 1
            } catch {
                updateTask("Mac Standardization", status: .failed, detail: "Failed: \(error.localizedDescription)")
                log("✗ Mac Standardization failed: \(error.localizedDescription)", color: .logRed)
                failCount += 1
            }
            log("")
        }
        
        // Step 2: Check for Homebrew if needed
        let needsHomebrew = applications.contains { app in
            if case .homebrew = app.installMethod { return true }
            return false
        }
        
        if needsHomebrew {
            log("Checking for Homebrew availability...", color: .logYellow)
            
            let hasHomebrew = await homebrewInstaller.isHomebrewInstalled()
            
            if !hasHomebrew {
                log("Homebrew not found. Installing...", color: .logYellow)
                
                do {
                    try await homebrewInstaller.installHomebrew()
                    log("✓ Homebrew installed successfully", color: .logGreen)
                } catch {
                    log("✗ Failed to install Homebrew: \(error.localizedDescription)", color: .logRed)
                    log("Some applications may not be installable without Homebrew", color: .logOrange)
                }
            } else {
                log("✓ Homebrew is available", color: .logGreen)
            }
            
            // Update Homebrew
            log("Updating Homebrew...", color: .logYellow)
            await homebrewInstaller.updateHomebrew()
            log("")
        }
        
        // Step 3: Install Applications
        log("=== Installing Applications ===", color: .logCyan)
        
        for app in applications {
            updateTask(app.name, status: .inProgress, detail: "Checking...")
            currentStatus = "Checking \(app.name)..."
            
            do {
                // Check if already installed
                let isInstalled = await isApplicationInstalled(app)
                
                if isInstalled {
                    updateTask(app.name, status: .success, detail: "Already installed")
                    log("✓ \(app.name) is already installed", color: .logGreen)
                    successCount += 1
                    continue
                }
                
                // Install the application
                updateTask(app.name, status: .inProgress, detail: "Installing...")
                currentStatus = "Installing \(app.name)..."
                log("Installing \(app.name)...", color: .logYellow)
                
                try await installApplication(app)
                
                updateTask(app.name, status: .success, detail: "Installed successfully")
                log("✓ \(app.name) installed successfully", color: .logGreen)
                successCount += 1
                
            } catch {
                updateTask(app.name, status: .failed, detail: "Failed: \(error.localizedDescription)")
                log("✗ \(app.name) failed: \(error.localizedDescription)", color: .logRed)
                failCount += 1
            }
            
            log("")
        }
        
        // Deployment Complete
        let duration = Date().timeIntervalSince(startTime)
        stopFriendlyMessages()
        
        // Stop the sudo keepalive process and release credentials
        stopSudoKeepalive()
        log("✓ Admin privileges released", color: .logGray)
        
        log("=== Deployment Complete ===", color: .logCyan)
        log("Duration: \(formatDuration(duration))", color: .logGray)
        log("Results: \(successCount) succeeded, \(failCount) failed", color: successCount > 0 ? .logGreen : .logRed)
        
        friendlyMessage = "Deployment Complete! ✓"
        currentStatus = "Deployment complete"
        
        // Note: Keep isDeploying true so the UI stays on the deployment view
    }
    
    // MARK: - Admin Privileges
    
    /// Request admin privileges once at the start - caches sudo credentials
    /// User enters password once, then all subsequent sudo commands use cached credentials
    private func requestAdminPrivileges() async -> Bool {
        // Use osascript to prompt for admin credentials and cache them
        let script = """
        do shell script "sudo -v" with administrator privileges
        """
        
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                // Start a background process to keep sudo alive
                startSudoKeepalive()
                return true
            }
        } catch {
            // User cancelled or error occurred
        }
        
        return false
    }
    
    /// Starts a background process that keeps sudo credentials alive
    private func startSudoKeepalive() {
        sudoKeepaliveProcess = Process()
        sudoKeepaliveProcess?.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // Refresh sudo every 4 minutes (sudo timeout is usually 5 minutes)
        sudoKeepaliveProcess?.arguments = ["-c", "while true; do sudo -v; sleep 240; done"]
        
        try? sudoKeepaliveProcess?.run()
    }
    
    /// Stop the sudo keepalive process when deployment completes
    private func stopSudoKeepalive() {
        sudoKeepaliveProcess?.terminate()
        sudoKeepaliveProcess = nil
        // Invalidate sudo credentials
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-k"]
        try? process.run()
        process.waitUntilExit()
    }
    
    // MARK: - Application Installation
    
    /// Check if an application is already installed
    private func isApplicationInstalled(_ app: ApplicationDefinition) async -> Bool {
        switch app.installMethod {
        case .homebrew(let type):
            guard let packageId = app.packageId else { return false }
            return await homebrewInstaller.isInstalled(packageId: packageId, type: type)
            
        case .macAppStore(let appId):
            // Check if app exists in /Applications
            return FileManager.default.fileExists(atPath: "/Applications/\(app.name).app")
            
        case .directDownload, .custom:
            // Check common installation paths
            let appPath = "/Applications/\(app.name).app"
            let alternatePath = FileManager.default.homeDirectoryForCurrentUser.path + "/Applications/\(app.name).app"
            return FileManager.default.fileExists(atPath: appPath) || FileManager.default.fileExists(atPath: alternatePath)
        }
    }
    
    /// Install an application based on its installation method
    private func installApplication(_ app: ApplicationDefinition) async throws {
        switch app.installMethod {
        case .homebrew(let type):
            guard let packageId = app.packageId else {
                throw DeploymentError.missingPackageId(app.name)
            }
            try await homebrewInstaller.install(packageId: packageId, type: type)
            
        case .macAppStore(let appId):
            // TODO: Implement mas-cli installation
            throw DeploymentError.notImplemented("Mac App Store installation")
            
        case .directDownload(let format):
            guard let downloadUrl = app.downloadUrl else {
                // Try Supabase for apps without direct URLs
                throw DeploymentError.missingDownloadUrl(app.name)
            }
            try await directDownloadInstaller.install(
                name: app.name,
                url: downloadUrl,
                format: format
            )
            
        case .custom(let handler):
            try await handleCustomInstallation(app, handler: handler)
        }
    }
    
    /// Handle custom installation types (test content, etc.)
    private func handleCustomInstallation(_ app: ApplicationDefinition, handler: String) async throws {
        switch handler {
        case "audiotestcontent":
            log("  • Downloading Audio Test Content...", color: .logGray)
            // TODO: Download from Supabase and extract to Desktop
            throw DeploymentError.notImplemented("Audio Test Content")
            
        case "videotestcontent":
            log("  • Downloading Video Test Content...", color: .logGray)
            // TODO: Download from Supabase and extract to Desktop, install VLC
            throw DeploymentError.notImplemented("Video Test Content")
            
        default:
            throw DeploymentError.unknownHandler(handler)
        }
    }
    
    // MARK: - Task Management
    
    private func updateTask(_ name: String, status: TaskStatus, detail: String) {
        if let index = tasks.firstIndex(where: { $0.name == name }) {
            tasks[index].status = status
            tasks[index].statusDetail = detail
        }
    }
    
    // MARK: - Logging
    
    func log(_ message: String, color: Color = .primary) {
        let entry = LogEntry(message: message, color: color)
        logEntries.append(entry)
    }
    
    // MARK: - Friendly Messages
    
    private func startFriendlyMessages() {
        currentMessageIndex = 0
        friendlyMessage = friendlyMessages[0]
        
        friendlyMessageTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            let nextIndex = (self.currentMessageIndex + 1) % self.friendlyMessages.count
            DispatchQueue.main.async {
                self.currentMessageIndex = nextIndex
                self.friendlyMessage = self.friendlyMessages[nextIndex]
            }
        }
    }
    
    private func stopFriendlyMessages() {
        friendlyMessageTimer?.invalidate()
        friendlyMessageTimer = nil
    }
    
    // MARK: - Formatting Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Deployment Errors

enum DeploymentError: LocalizedError {
    case missingPackageId(String)
    case missingDownloadUrl(String)
    case notImplemented(String)
    case unknownHandler(String)
    case installationFailed(String)
    case homebrewNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .missingPackageId(let name):
            return "No package ID specified for \(name)"
        case .missingDownloadUrl(let name):
            return "No download URL specified for \(name)"
        case .notImplemented(let feature):
            return "\(feature) is not yet implemented"
        case .unknownHandler(let handler):
            return "Unknown custom handler: \(handler)"
        case .installationFailed(let reason):
            return "Installation failed: \(reason)"
        case .homebrewNotAvailable:
            return "Homebrew is not available"
        }
    }
}
