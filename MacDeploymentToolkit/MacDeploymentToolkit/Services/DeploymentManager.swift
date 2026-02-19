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
    @Published var isComplete = false
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
    
    // Wire up debug logging so HomebrewInstaller diagnostics appear in the deployment log
    private func setupDebugLogging() {
        homebrewInstaller.debugLog = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.log(message, color: .logGray)
            }
        }
    }
    
    // Admin privileges
    private var sudoKeepaliveProcess: Process?
    private var adminPassword: String?
    
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
        isComplete = false
        tasks.removeAll()
        logEntries.removeAll()
        
        // Wire up debug logging
        setupDebugLogging()
        
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
            currentStatus = "Checking for Homebrew..."
            
            var hasHomebrew = await homebrewInstaller.isHomebrewInstalled()
            
            if !hasHomebrew {
                log("Homebrew not found. Installing (this may take a few minutes)...", color: .logYellow)
                currentStatus = "Installing Homebrew..."
                
                do {
                    try await homebrewInstaller.installHomebrew()
                    log("✓ Homebrew installed successfully", color: .logGreen)
                    hasHomebrew = true
                } catch {
                    log("✗ Failed to install Homebrew: \(error.localizedDescription)", color: .logRed)
                    log("Homebrew apps will be skipped. Install Homebrew manually and retry.", color: .logOrange)
                }
            } else {
                log("✓ Homebrew is available", color: .logGreen)
            }
            
            if hasHomebrew {
                // Update Homebrew
                log("Updating Homebrew...", color: .logYellow)
                currentStatus = "Updating Homebrew..."
                await homebrewInstaller.updateHomebrew()
            }
            log("")
        }
        
        // Step 3: Install Applications
        log("=== Installing Applications ===", color: .logCyan)
        
        var newlyInstalledApps: [ApplicationDefinition] = []
        
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
                newlyInstalledApps.append(app)
                
            } catch {
                updateTask(app.name, status: .failed, detail: "Failed: \(error.localizedDescription)")
                log("✗ \(app.name) failed: \(error.localizedDescription)", color: .logRed)
                failCount += 1
            }
            
            log("")
        }
        
        // Step 4: Pin newly installed apps to the Dock
        if !newlyInstalledApps.isEmpty {
            log("=== Pinning Applications to Dock ===", color: .logCyan)
            currentStatus = "Pinning apps to Dock..."
            
            for app in newlyInstalledApps {
                if let appPath = findInstalledAppPath(app) {
                    do {
                        try await systemStandardizer.addAppToDock(appPath: appPath)
                        log("  • Pinned \(app.name) to Dock", color: .logGray)
                    } catch {
                        log("  • Could not pin \(app.name) to Dock", color: .logGray)
                    }
                }
            }
            
            // Restart Dock to apply pinned apps
            do {
                _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                    DispatchQueue.global(qos: .userInitiated).async {
                        let process = Process()
                        let outputPipe = Pipe()
                        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
                        process.arguments = ["Dock"]
                        process.standardOutput = outputPipe
                        process.standardError = Pipe()
                        do {
                            try process.run()
                            process.waitUntilExit()
                            continuation.resume(returning: "")
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
                log("✓ Dock updated with new applications", color: .logGreen)
            } catch {
                log("⚠ Could not restart Dock", color: .logOrange)
            }
            log("")
        }
        
        // Deployment Complete
        let duration = Date().timeIntervalSince(startTime)
        stopFriendlyMessages()
        
        // Stop the sudo keepalive process and release credentials
        stopSudoKeepalive()
        homebrewInstaller.cleanupAskpassScript()
        log("✓ Admin privileges released", color: .logGray)
        
        log("=== Deployment Complete ===", color: .logCyan)
        log("Duration: \(formatDuration(duration))", color: .logGray)
        log("Results: \(successCount) succeeded, \(failCount) failed", color: successCount > 0 ? .logGreen : .logRed)
        
        friendlyMessage = "Deployment Complete! ✓"
        currentStatus = "Deployment complete"
        isComplete = true
        
        // Note: Keep isDeploying true so the UI stays on the deployment view
    }
    
    // MARK: - Admin Privileges
    
    /// Request admin privileges once at the start - caches sudo credentials
    /// Uses osascript to prompt for password via GUI dialog, then validates sudo
    private func requestAdminPrivileges() async -> Bool {
        // Prompt user for their password using a GUI dialog
        let promptScript = """
        set dialogResult to display dialog "Enter your administrator password for deployment operations:" default answer "" with hidden answer buttons {"Cancel", "OK"} default button "OK" with icon caution
        return text returned of dialogResult
        """
        
        // Run osascript asynchronously to avoid blocking UI
        let password: String? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", promptScript]
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    if process.terminationStatus == 0 {
                        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                        let pwd = (String(data: outputData, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        continuation.resume(returning: pwd.isEmpty ? nil : pwd)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
        
        guard let password = password else {
            return false
        }
        
        // Validate the password asynchronously
        let isValid: Bool = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let validateProcess = Process()
                let validateInput = Pipe()
                let validateOutput = Pipe()
                let validateError = Pipe()
                
                validateProcess.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
                validateProcess.arguments = ["-S", "-v"]
                validateProcess.standardInput = validateInput
                validateProcess.standardOutput = validateOutput
                validateProcess.standardError = validateError
                
                do {
                    try validateProcess.run()
                    
                    // Write password to stdin
                    let passwordData = (password + "\n").data(using: .utf8)!
                    validateInput.fileHandleForWriting.write(passwordData)
                    validateInput.fileHandleForWriting.closeFile()
                    
                    validateProcess.waitUntilExit()
                    continuation.resume(returning: validateProcess.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
        
        if isValid {
            // Store password for reuse by all services (avoids repeated prompts)
            adminPassword = password
            homebrewInstaller.adminPassword = password
            directDownloadInstaller.adminPassword = password
            systemStandardizer.adminPassword = password
            
            startSudoKeepalive(password: password)
            return true
        }
        
        return false
    }
    
    /// Starts a background process that keeps sudo credentials alive
    private func startSudoKeepalive(password: String) {
        sudoKeepaliveProcess = Process()
        let inputPipe = Pipe()
        
        sudoKeepaliveProcess?.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // Refresh sudo every 4 minutes (sudo timeout is usually 5 minutes)
        // Pipe the password to sudo -S -v each cycle
        sudoKeepaliveProcess?.arguments = ["-c", "while true; do echo \"\(password.replacingOccurrences(of: "\"", with: "\\\""))\" | sudo -S -v 2>/dev/null; sleep 240; done"]
        sudoKeepaliveProcess?.standardInput = inputPipe
        
        try? sudoKeepaliveProcess?.run()
    }
    
    /// Stop the sudo keepalive process when deployment completes
    private func stopSudoKeepalive() {
        sudoKeepaliveProcess?.terminate()
        sudoKeepaliveProcess = nil
        // Clear stored password from memory
        adminPassword = nil
        homebrewInstaller.adminPassword = nil
        directDownloadInstaller.adminPassword = nil
        systemStandardizer.adminPassword = nil
        
        // Invalidate sudo credentials (fire and forget, don't block)
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            process.arguments = ["-k"]
            try? process.run()
            process.waitUntilExit()
        }
    }
    
    // MARK: - Application Installation
    
    /// Check if an application is already installed
    private func isApplicationInstalled(_ app: ApplicationDefinition) async -> Bool {
        // First do a broad check: scan /Applications (including subdirectories) for a matching .app bundle
        // This handles cases where the installed app name differs slightly from catalog name
        if appExistsInApplications(app.name) {
            return true
        }
        
        // Second: check via Spotlight (mdfind) — catches apps installed anywhere on the system
        if await spotlightFindApp(app.name) {
            return true
        }
        
        // Third: for Homebrew apps, also check Homebrew's package list
        switch app.installMethod {
        case .homebrew(let type):
            guard let packageId = app.packageId else { return false }
            return await homebrewInstaller.isInstalled(packageId: packageId, type: type)
            
        case .macAppStore:
            return false  // Already checked above
            
        case .directDownload, .custom:
            return false  // Already checked above
        }
    }
    
    /// Scan /Applications (and ~/Applications) for an app whose name contains the search term
    /// Does case-insensitive matching and handles partial names (e.g., "Blackmagic Desktop Video" matches
    /// "Blackmagic Desktop Video.app" or "Blackmagic Desktop Video Setup.app")
    /// Also scans one level of subdirectories (e.g., /Applications/Renewed Vision/ProPresenter.app)
    private func appExistsInApplications(_ appName: String) -> Bool {
        let fm = FileManager.default
        let searchLower = appName.lowercased()
        
        let directories = [
            "/Applications",
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]
        
        for dir in directories {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            
            for item in contents {
                let itemPath = (dir as NSString).appendingPathComponent(item)
                
                if item.hasSuffix(".app") {
                    let installedName = String(item.dropLast(4)).lowercased()  // strip .app
                    if installedName == searchLower || installedName.contains(searchLower) || searchLower.contains(installedName) {
                        return true
                    }
                }
                
                // Check subdirectories one level deep (e.g., /Applications/Renewed Vision/ProPresenter.app)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue, !item.hasSuffix(".app") {
                    if let subContents = try? fm.contentsOfDirectory(atPath: itemPath) {
                        for subItem in subContents {
                            if subItem.hasSuffix(".app") {
                                let subName = String(subItem.dropLast(4)).lowercased()
                                if subName == searchLower || subName.contains(searchLower) || searchLower.contains(subName) {
                                    return true
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return false
    }
    
    /// Use Spotlight (mdfind) to search for an installed application anywhere on the system
    private func spotlightFindApp(_ appName: String) async -> Bool {
        do {
            let result: String = try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let process = Process()
                    let outputPipe = Pipe()
                    
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
                    process.arguments = ["kMDItemContentTypeTree == 'com.apple.application-bundle' && kMDItemDisplayName == '*\(appName)*'cd"]
                    process.standardOutput = outputPipe
                    process.standardError = Pipe()
                    
                    do {
                        try process.run()
                        process.waitUntilExit()
                        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(data: data, encoding: .utf8) ?? ""
                        continuation.resume(returning: output)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            return !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return false
        }
    }
    
    /// Find the full path to an installed app in /Applications (including subdirectories)
    /// Returns the first matching .app path, or nil if not found
    private func findInstalledAppPath(_ app: ApplicationDefinition) -> String? {
        let fm = FileManager.default
        let searchLower = app.name.lowercased()
        
        let directories = [
            "/Applications",
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]
        
        for dir in directories {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            
            for item in contents {
                let itemPath = (dir as NSString).appendingPathComponent(item)
                
                if item.hasSuffix(".app") {
                    let installedName = String(item.dropLast(4)).lowercased()
                    if installedName == searchLower || installedName.contains(searchLower) || searchLower.contains(installedName) {
                        return itemPath
                    }
                }
                
                // Check subdirectories one level deep
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue, !item.hasSuffix(".app") {
                    if let subContents = try? fm.contentsOfDirectory(atPath: itemPath) {
                        for subItem in subContents {
                            if subItem.hasSuffix(".app") {
                                let subName = String(subItem.dropLast(4)).lowercased()
                                if subName == searchLower || subName.contains(searchLower) || searchLower.contains(subName) {
                                    return (itemPath as NSString).appendingPathComponent(subItem)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Install an application based on its installation method
    private func installApplication(_ app: ApplicationDefinition) async throws {
        switch app.installMethod {
        case .homebrew(let type):
            guard let packageId = app.packageId else {
                throw DeploymentError.missingPackageId(app.name)
            }
            try await homebrewInstaller.install(packageId: packageId, type: type)
            
        case .macAppStore:
            // TODO: Implement mas-cli installation
            throw DeploymentError.notImplemented("Mac App Store installation")
            
        case .directDownload(let format):
            guard let downloadUrl = app.effectiveDownloadUrl else {
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
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                let nextIndex = (self.currentMessageIndex + 1) % self.friendlyMessages.count
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
