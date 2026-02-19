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
    
    /// Admin password set by DeploymentManager after initial prompt; used for sudo -S
    var adminPassword: String?
    
    private var effectiveBrewPath: String {
        if FileManager.default.fileExists(atPath: brewPath) {
            return brewPath
        } else if FileManager.default.fileExists(atPath: brewPathIntel) {
            return brewPathIntel
        }
        return "brew" // Fall back to PATH lookup
    }
    
    // MARK: - Homebrew Management
    
    /// Check if Homebrew is installed
    func isHomebrewInstalled() async -> Bool {
        return FileManager.default.fileExists(atPath: brewPath) ||
               FileManager.default.fileExists(atPath: brewPathIntel)
    }
    
    /// Install Homebrew
    func installHomebrew() async throws {
        let installScript = "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        
        // Note: Homebrew installation requires user interaction for password
        // In a deployment scenario, this would need to be handled differently
        // For now, we'll attempt the installation and let the user provide the password
        
        let result = try await runShellCommand(installScript)
        
        if result.exitCode != 0 {
            throw HomebrewError.installationFailed(result.error)
        }
    }
    
    /// Update Homebrew sources
    func updateHomebrew() async {
        do {
            _ = try await runShellCommand("\(effectiveBrewPath) update")
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
        "resolume-arena": "Resolume Arena",
        "blackmagic-disk-speed-test": "Blackmagic Disk Speed Test",
        "qlab": "QLab",
        "companion": "Companion",
        "touchosc": "TouchOSC",
        "dante-controller": "Dante Controller",
        "dante-virtual-soundcard": "Dante Virtual Soundcard"
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
            let command: String
            switch type {
            case .cask:
                command = "\(effectiveBrewPath) list --cask \(packageId)"
            case .formula:
                command = "\(effectiveBrewPath) list \(packageId)"
            }
            
            let result = try await runShellCommand(command)
            return result.exitCode == 0
        } catch {
            return false
        }
    }
    
    /// Install a package via Homebrew
    func install(packageId: String, type: InstallMethod.HomebrewType) async throws {
        let command: String
        switch type {
        case .cask:
            // Use --force to overwrite existing installations
            // Some casks require sudo for installation (e.g., ndi-tools, wireshark, resolume-arena)
            // Use osascript with admin privileges to handle password prompt
            command = "\(effectiveBrewPath) install --cask --force \(packageId)"
            let result = try await runShellCommandWithElevation(command)
            if result.exitCode != 0 {
                throw HomebrewError.packageInstallFailed(packageId, result.error)
            }
            return
        case .formula:
            command = "\(effectiveBrewPath) install \(packageId)"
        }
        
        let result = try await runShellCommand(command)
        
        if result.exitCode != 0 {
            throw HomebrewError.packageInstallFailed(packageId, result.error)
        }
    }
    
    /// Uninstall a package via Homebrew
    func uninstall(packageId: String, type: InstallMethod.HomebrewType) async throws {
        let command: String
        switch type {
        case .cask:
            command = "\(effectiveBrewPath) uninstall --cask \(packageId)"
        case .formula:
            command = "\(effectiveBrewPath) uninstall \(packageId)"
        }
        
        let result = try await runShellCommand(command)
        
        if result.exitCode != 0 {
            throw HomebrewError.packageUninstallFailed(packageId, result.error)
        }
    }
    
    /// Get information about a package
    func packageInfo(packageId: String, type: InstallMethod.HomebrewType) async throws -> String {
        let command: String
        switch type {
        case .cask:
            command = "\(effectiveBrewPath) info --cask \(packageId)"
        case .formula:
            command = "\(effectiveBrewPath) info \(packageId)"
        }
        
        let result = try await runShellCommand(command)
        return result.output
    }
    
    // MARK: - Shell Command Execution
    
    private func runShellCommand(_ command: String) async throws -> ShellResult {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.environment = ProcessInfo.processInfo.environment
            
            // Add Homebrew paths to PATH if needed
            var env = process.environment ?? [:]
            let homebrewPaths = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin"
            if let existingPath = env["PATH"] {
                env["PATH"] = "\(homebrewPaths):\(existingPath)"
            } else {
                env["PATH"] = homebrewPaths
            }
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
    
    private func runShellCommandWithElevation(_ command: String) async throws -> ShellResult {
        // Use stored admin password with sudo -S to avoid repeated password prompts
        // Falls back to osascript dialog if no password is stored
        guard let password = adminPassword else {
            // Fallback: use osascript with administrator privileges (will prompt)
            let script = """
            do shell script "\(command.replacingOccurrences(of: "\"", with: "\\\""))" with administrator privileges
            """
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let process = Process()
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                    process.arguments = ["-e", script]
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe
                    var env = ProcessInfo.processInfo.environment
                    let homebrewPaths = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin"
                    if let existingPath = env["PATH"] {
                        env["PATH"] = "\(homebrewPaths):\(existingPath)"
                    } else {
                        env["PATH"] = homebrewPaths
                    }
                    process.environment = env
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
                process.arguments = ["-S", "/bin/zsh", "-c", command]
                process.standardInput = inputPipe
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                // Add Homebrew paths to environment
                var env = ProcessInfo.processInfo.environment
                let homebrewPaths = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin"
                if let existingPath = env["PATH"] {
                    env["PATH"] = "\(homebrewPaths):\(existingPath)"
                } else {
                    env["PATH"] = homebrewPaths
                }
                process.environment = env
                
                do {
                    try process.run()
                    
                    // Write password to stdin for sudo -S
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
