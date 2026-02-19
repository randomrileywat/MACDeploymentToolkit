//
//  HomebrewInstaller.swift
//  MacDeploymentToolkit
//
//  Homebrew package manager integration for installing applications
//

import Foundation

/// Handles application installation via Homebrew (casks and formulas)
class HomebrewInstaller {
    
    // MARK: - Properties
    
    private let brewPath = "/opt/homebrew/bin/brew"
    private let brewPathIntel = "/usr/local/bin/brew"
    
    /// Optional debug log callback — set by DeploymentManager to pipe diagnostics into the deployment log
    var debugLog: ((String) -> Void)?
    
    /// Admin password set by DeploymentManager after initial prompt; used for sudo -S
    var adminPassword: String?
    
    /// Cached resolved path to the brew binary (found once and reused)
    private var cachedBrewPath: String?
    
    /// Returns the full absolute path to the brew binary.
    /// Uses cached path if available, otherwise defaults to ARM path.
    /// The actual path discovery happens in isHomebrewInstalled() via shell.
    private var effectiveBrewPath: String {
        if let cached = cachedBrewPath {
            return cached
        }
        // Default to ARM path — isHomebrewInstalled() will update this
        // via shell-based discovery which isn't blocked by sandbox
        return brewPath
    }
    
    // MARK: - Homebrew Management
    
    /// Check if Homebrew is installed by trying to run the brew binary directly.
    /// This is the most reliable method — no shell, no PATH, no sandbox issues.
    func isHomebrewInstalled() async -> Bool {
        // Try ARM path first (Apple Silicon), then Intel path
        for path in [brewPath, brewPathIntel] {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            
            // Set the cached path so runBrewCommand uses this path
            cachedBrewPath = path
            
            // Verify it's actually executable by running it
            do {
                let result = try await runBrewCommand(["--version"])
                if result.exitCode == 0 {
                    return true
                }
            } catch {
                // This path didn't work, try next
            }
        }
        cachedBrewPath = nil
        return false
    }
    
    /// Install Homebrew non-interactively using the stored admin password.
    /// Pre-authenticates sudo, then streams installer output to the debugLog callback.
    func installHomebrew() async throws {
        guard let password = adminPassword else {
            throw HomebrewError.installationFailed("No admin password available. Cannot install Homebrew non-interactively.")
        }
        
        let escapedPassword = password.replacingOccurrences(of: "'", with: "'\\''")
        let installCommand = """
        echo '\(escapedPassword)' | sudo -S -v 2>/dev/null && \
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        """
        
        // Run with streaming output so progress appears in the deployment log
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ShellResult, Error>) in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", installCommand]
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                var env = ProcessInfo.processInfo.environment
                env["NONINTERACTIVE"] = "1"
                process.environment = env
                
                // Stream stderr (where the installer writes progress) to debugLog
                var allOutput = ""
                var allError = ""
                
                errorPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    if let line = String(data: data, encoding: .utf8) {
                        allError += line
                        // Send meaningful lines to the deployment log
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && !trimmed.contains("Password:") {
                            self?.debugLog?("  \(trimmed)")
                        }
                    }
                }
                
                outputPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    if let line = String(data: data, encoding: .utf8) {
                        allOutput += line
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            self?.debugLog?("  \(trimmed)")
                        }
                    }
                }
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    // Clean up handlers
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    
                    continuation.resume(returning: ShellResult(
                        output: allOutput,
                        error: allError,
                        exitCode: process.terminationStatus
                    ))
                } catch {
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        }
        
        if result.exitCode != 0 {
            throw HomebrewError.installationFailed("\(result.error)\n\(result.output)")
        }
        
        // After installing, re-detect the brew path so subsequent commands work
        cachedBrewPath = nil
        let found = await isHomebrewInstalled()
        if !found {
            throw HomebrewError.installationFailed("Homebrew installer completed but brew binary not found at expected paths.")
        }
    }
    
    /// Update Homebrew sources
    func updateHomebrew() async {
        do {
            _ = try await runBrewCommand(["update"])
        } catch {
            // Non-fatal, continue with existing catalog
            print("Warning: Failed to update Homebrew: \(error)")
        }
    }
    
    // MARK: - Package Installation
    
    /// Map of Homebrew package IDs to their actual app names in /Applications
    /// This handles cases where the app was installed manually (not via Homebrew)
    private let packageToAppName: [String: String] = [
        "spotify": "Spotify",
        "google-chrome": "Google Chrome",
        "vlc": "VLC",
        "zoom": "zoom.us",
        "slack": "Slack",
        "discord": "Discord",
        "visual-studio-code": "Visual Studio Code",
        "microsoft-teams": "Microsoft Teams",
        "dropbox": "Dropbox",
        "1password": "1Password",
        "firefox": "Firefox",
        "obs": "OBS",
        "steam": "Steam",
        "handbrake": "HandBrake",
        "audacity": "Audacity",
        "gimp": "GIMP",
        "inkscape": "Inkscape",
        "blender": "Blender",
        "figma": "Figma",
        "sketch": "Sketch",
        "affinity-designer": "Affinity Designer",
        "affinity-photo": "Affinity Photo",
        "affinity-publisher": "Affinity Publisher",
        "adobe-creative-cloud": "Adobe Creative Cloud",
        "notion": "Notion",
        "evernote": "Evernote",
        "sublime-text": "Sublime Text",
        "atom": "Atom",
        "iterm2": "iTerm",
        "docker": "Docker",
        "postman": "Postman",
        "insomnia": "Insomnia",
        "github": "GitHub Desktop",
        "sourcetree": "Sourcetree",
        "cyberduck": "Cyberduck",
        "transmit": "Transmit",
        "alfred": "Alfred",
        "raycast": "Raycast",
        "rectangle": "Rectangle",
        "magnet": "Magnet",
        "bartender": "Bartender",
        "cleanmymac": "CleanMyMac X",
        "appcleaner": "AppCleaner",
        "the-unarchiver": "The Unarchiver",
        "keka": "Keka",
        "ndi-tools": "NDI Tools",
        "wireshark": "Wireshark",
        "wireshark-app": "Wireshark",
        "resolume-arena": "Resolume Arena",
        "blackmagic-disk-speed-test": "Blackmagic Disk Speed Test",
        "qlab": "QLab",
        "companion": "Companion",
        "touchosc": "TouchOSC",
        "dante-controller": "Dante Controller",
        "dante-virtual-soundcard": "Dante Virtual Soundcard",
        "propresenter": "ProPresenter",
        "reaper": "REAPER",
        "waves-central": "Waves Central",
        "wireless-workbench": "Wireless Workbench",
        "packetsender": "Packet Sender"
    ]
    
    /// Check if a package is installed (checks /Applications first, then Homebrew)
    func isInstalled(packageId: String, type: InstallMethod.HomebrewType) async -> Bool {
        // For casks, first check if the app exists in /Applications
        // This handles apps that were installed manually (not via Homebrew)
        if type == .cask {
            // Try to find the app in /Applications
            if let appName = packageToAppName[packageId] {
                let appPath = "/Applications/\(appName).app"
                if FileManager.default.fileExists(atPath: appPath) {
                    return true
                }
                // Also check ~/Applications
                let userAppPath = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Applications")
                    .appendingPathComponent("\(appName).app")
                    .path
                if FileManager.default.fileExists(atPath: userAppPath) {
                    return true
                }
            }
            
            // Also try a capitalized version of the packageId as app name
            let capitalizedName = packageId.split(separator: "-")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
            let fallbackPath = "/Applications/\(capitalizedName).app"
            if FileManager.default.fileExists(atPath: fallbackPath) {
                return true
            }
        }
        
        // Fall back to checking Homebrew's package list
        do {
            let args: [String]
            switch type {
            case .cask:
                args = ["list", "--cask", packageId]
            case .formula:
                args = ["list", packageId]
            }
            
            let result = try await runBrewCommand(args)
            return result.exitCode == 0
        } catch {
            return false
        }
    }
    
    /// Install a package via Homebrew
    func install(packageId: String, type: InstallMethod.HomebrewType) async throws {
        let args: [String]
        switch type {
        case .cask:
            args = ["install", "--cask", "--force", packageId]
        case .formula:
            args = ["install", packageId]
        }
        
        let result = try await runBrewCommand(args)
        
        if result.exitCode != 0 {
            // Include full diagnostics in the error so they appear in the deployment log
            let diagnostic = "\(result.error)\n[args: \(args)]\n[stdout: \(result.output.prefix(300))]\n[brew: \(effectiveBrewPath)]"
            throw HomebrewError.packageInstallFailed(packageId, diagnostic)
        }
    }
    
    /// Uninstall a package via Homebrew
    func uninstall(packageId: String, type: InstallMethod.HomebrewType) async throws {
        let args: [String]
        switch type {
        case .cask:
            args = ["uninstall", "--cask", packageId]
        case .formula:
            args = ["uninstall", packageId]
        }
        
        let result = try await runBrewCommand(args)
        
        if result.exitCode != 0 {
            throw HomebrewError.packageUninstallFailed(packageId, result.error)
        }
    }
    
    /// Get information about a package
    func packageInfo(packageId: String, type: InstallMethod.HomebrewType) async throws -> String {
        let args: [String]
        switch type {
        case .cask:
            args = ["info", "--cask", packageId]
        case .formula:
            args = ["info", packageId]
        }
        
        let result = try await runBrewCommand(args)
        return result.output
    }
    
    // MARK: - Shell Command Execution
    
    /// Runs the brew binary DIRECTLY as a process — no shell, no PATH lookup.
    /// Streams output to debugLog in real-time for progress visibility.
    private func runBrewCommand(_ arguments: [String]) async throws -> ShellResult {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            let brewPath = self?.effectiveBrewPath ?? "/opt/homebrew/bin/brew"
            
            // Execute brew directly — bypasses zsh, PATH, and shell entirely
            process.executableURL = URL(fileURLWithPath: brewPath)
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            // Set Homebrew env vars so brew's internal Ruby scripts work correctly
            var env = ProcessInfo.processInfo.environment
            let homebrewPrefix = brewPath.contains("/opt/homebrew") ? "/opt/homebrew" : "/usr/local"
            env["HOMEBREW_PREFIX"] = homebrewPrefix
            env["HOMEBREW_CELLAR"] = "\(homebrewPrefix)/Cellar"
            env["HOMEBREW_REPOSITORY"] = homebrewPrefix
            env["PATH"] = "\(homebrewPrefix)/bin:\(homebrewPrefix)/sbin:/usr/bin:/bin:/usr/sbin:/sbin:\(env["PATH"] ?? "")"
            process.environment = env
            
            // Stream output for real-time progress
            var allOutput = ""
            var allError = ""
            
            outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                if let text = String(data: data, encoding: .utf8) {
                    allOutput += text
                    // Only log meaningful progress lines (skip noisy output)
                    for line in text.components(separatedBy: .newlines) {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if Self.isProgressLine(trimmed) {
                            self?.debugLog?("  \(trimmed)")
                        }
                    }
                }
            }
            
            errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                if let text = String(data: data, encoding: .utf8) {
                    allError += text
                    for line in text.components(separatedBy: .newlines) {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if Self.isProgressLine(trimmed) {
                            self?.debugLog?("  \(trimmed)")
                        }
                    }
                }
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                continuation.resume(returning: ShellResult(
                    output: allOutput,
                    error: allError,
                    exitCode: process.terminationStatus
                ))
            } catch {
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Runs a raw shell command WITHOUT injecting Homebrew PATH.
    /// Used by isHomebrewInstalled() to avoid circular dependency with commandWithPath.
    private func runShellCommandRaw(_ command: String) async throws -> ShellResult {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""
                
                continuation.resume(returning: ShellResult(
                    output: output,
                    error: error,
                    exitCode: process.terminationStatus
                ))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func runShellCommand(_ command: String) async throws -> ShellResult {
        // Inject Homebrew PATH into the command string itself so it survives
        // all subprocess spawning (brew's Ruby scripts call `brew` by bare name).
        // Setting process.environment alone is not enough because child processes
        // may spawn their own shells that don't inherit it.
        let fullCommand = commandWithPath(command)
        
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", fullCommand]
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            // Also set Homebrew env vars on the Process object itself as a safety net.
            // This covers any code paths where child processes read env directly.
            var env = ProcessInfo.processInfo.environment
            let homebrewPaths = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin"
            env["PATH"] = "\(homebrewPaths):/usr/bin:/bin:/usr/sbin:/sbin:\(env["PATH"] ?? "")"
            env["HOMEBREW_PREFIX"] = "/opt/homebrew"
            env["HOMEBREW_CELLAR"] = "/opt/homebrew/Cellar"
            env["HOMEBREW_REPOSITORY"] = "/opt/homebrew"
            process.environment = env
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""
                
                continuation.resume(returning: ShellResult(
                    output: output,
                    error: error,
                    exitCode: process.terminationStatus
                ))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Injects the full Homebrew environment into a command string as a single-line prefix.
    /// Always includes BOTH ARM and Intel paths — no FileManager checks (sandbox-safe).
    private func commandWithPath(_ command: String) -> String {
        return "export HOMEBREW_PREFIX=/opt/homebrew HOMEBREW_CELLAR=/opt/homebrew/Cellar HOMEBREW_REPOSITORY=/opt/homebrew PATH=/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH && \(command)"
    }
    
    /// Filters streaming output to only show meaningful progress lines.
    /// Reduces noise from verbose brew/installer output.
    private static func isProgressLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        // Always show lines that start with key indicators
        let showPrefixes = ["==>", "-->", "Downloading", "Installing", "Pouring",
                            "Cloning", "Updating", "Already", "Warning",
                            "Error", "fatal", "Successfully", "Linking",
                            "Moving", "Purging"]
        for prefix in showPrefixes {
            if trimmed.hasPrefix(prefix) { return true }
        }
        
        // Show percentage/progress indicators
        if trimmed.contains("###") || trimmed.contains("%") { return true }
        
        // Hide noisy lines
        let hidePrefixes = ["Password:", "sudo:", "  ", "#"]
        for prefix in hidePrefixes {
            if trimmed.hasPrefix(prefix) { return false }
        }
        
        // Hide very short lines (usually partial output)
        if trimmed.count < 5 { return false }
        
        // Default: hide (reduces verbosity)
        return false
    }
    
    private func runShellCommandWithElevation(_ command: String) async throws -> ShellResult {
        // Inject PATH into the command itself so it survives sudo/osascript environment resets
        let fullCommand = commandWithPath(command)
        
        // Use stored admin password with sudo -S to avoid repeated password prompts
        guard let password = adminPassword else {
            // Fallback: use osascript with administrator privileges (will prompt)
            let escapedCmd = fullCommand.replacingOccurrences(of: "\"", with: "\\\"")
            let script = "do shell script \"\(escapedCmd)\" with administrator privileges"
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
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
                        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                        continuation.resume(returning: ShellResult(output: output, error: error, exitCode: process.terminationStatus))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        
        // Primary path: pipe stored password to sudo -S (no GUI prompt)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let inputPipe = Pipe()
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                
                process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
                process.arguments = ["-S", "/bin/zsh", "-c", fullCommand]
                process.standardInput = inputPipe
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                do {
                    try process.run()
                    
                    let passwordData = (password + "\n").data(using: .utf8)!
                    inputPipe.fileHandleForWriting.write(passwordData)
                    inputPipe.fileHandleForWriting.closeFile()
                    
                    process.waitUntilExit()
                    
                    let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    
                    continuation.resume(returning: ShellResult(
                        output: output,
                        error: error,
                        exitCode: process.terminationStatus
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct ShellResult {
    let output: String
    let error: String
    let exitCode: Int32
}

enum HomebrewError: LocalizedError {
    case notInstalled
    case installationFailed(String)
    case packageInstallFailed(String, String)
    case packageUninstallFailed(String, String)
    case packageNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Homebrew is not installed"
        case .installationFailed(let error):
            return "Failed to install Homebrew: \(error)"
        case .packageInstallFailed(let packageId, let error):
            return "Failed to install \(packageId): \(error)"
        case .packageUninstallFailed(let packageId, let error):
            return "Failed to uninstall \(packageId): \(error)"
        case .packageNotFound(let packageId):
            return "Package not found: \(packageId)"
        }
    }
}
