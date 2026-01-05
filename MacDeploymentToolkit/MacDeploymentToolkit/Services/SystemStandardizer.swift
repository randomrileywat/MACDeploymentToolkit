//
//  SystemStandardizer.swift
//  MacDeploymentToolkit
//
//  Handles macOS system standardization including wallpaper, dock, theme, and power settings
//

import Foundation
import AppKit
import CoreGraphics

/// Applies organizational standards to macOS system configuration
class SystemStandardizer {
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    
    // MARK: - Main Standardization Entry Point
    
    /// Apply all standardization settings
    func applyStandardization(computerName: String, customIconPath: String?) async throws {
        // Apply settings in order
        try await setDarkTheme()
        try await configureDock()
        try await configurePowerSettings()
        try await createDesktopFolders()
        try await setCustomWallpaper(computerName: computerName, customIconPath: customIconPath)
        try await removeUnwantedApps()
        try await configureFinderPreferences()
    }
    
    // MARK: - Dark Theme
    
    /// Enable dark mode system-wide
    func setDarkTheme() async throws {
        let script = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to true
            end tell
        end tell
        """
        
        try await runAppleScript(script)
    }
    
    // MARK: - Dock Configuration
    
    /// Configure Dock settings (position, size, auto-hide, pinned apps)
    func configureDock() async throws {
        // Set dock position to bottom
        try await runDefaultsCommand("com.apple.dock", key: "orientation", value: "bottom")
        
        // Set dock size
        try await runDefaultsCommand("com.apple.dock", key: "tilesize", value: "48", type: "int")
        
        // Disable auto-hide
        try await runDefaultsCommand("com.apple.dock", key: "autohide", value: "false", type: "bool")
        
        // Minimize windows into their application icon
        try await runDefaultsCommand("com.apple.dock", key: "minimize-to-application", value: "true", type: "bool")
        
        // Show indicator lights for open applications
        try await runDefaultsCommand("com.apple.dock", key: "show-process-indicators", value: "true", type: "bool")
        
        // Don't show recent applications in Dock
        try await runDefaultsCommand("com.apple.dock", key: "show-recents", value: "false", type: "bool")
        
        // Clear persistent apps and add standard ones
        try await configureDockApps()
        
        // Restart Dock to apply changes
        try await restartDock()
    }
    
    private func configureDockApps() async throws {
        // Clear existing persistent apps (this removes Safari and everything else)
        try await runDefaultsCommand("com.apple.dock", key: "persistent-apps", value: "()", type: "array")
        
        // Add Finder (always first)
        try await addAppToDock(path: "/System/Library/CoreServices/Finder.app")
        
        // Add Chrome if installed, otherwise skip browser (Safari not added)
        if fileManager.fileExists(atPath: "/Applications/Google Chrome.app") {
            try await addAppToDock(path: "/Applications/Google Chrome.app")
        }
        // Note: Safari is intentionally NOT added to the dock
        
        // Add Terminal
        try await addAppToDock(path: "/Applications/Utilities/Terminal.app")
        
        // Add System Preferences/Settings
        if #available(macOS 13.0, *) {
            try await addAppToDock(path: "/System/Applications/System Settings.app")
        } else {
            try await addAppToDock(path: "/System/Applications/System Preferences.app")
        }
    }
    
    private func addAppToDock(path: String) async throws {
        guard fileManager.fileExists(atPath: path) else { return }
        
        let script = """
        defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>\(path)</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
        """
        
        _ = try await runShellCommand(script)
    }
    
    private func restartDock() async throws {
        _ = try await runShellCommand("killall Dock")
    }
    
    // MARK: - Power Settings
    
    /// Configure power settings (never sleep when plugged in)
    func configurePowerSettings() async throws {
        // Prevent sleep when on AC power
        _ = try await runShellCommand("sudo pmset -c sleep 0")
        
        // Prevent display sleep when on AC power
        _ = try await runShellCommand("sudo pmset -c displaysleep 0")
        
        // Disable disk sleep
        _ = try await runShellCommand("sudo pmset -c disksleep 0")
    }
    
    // MARK: - Desktop Folders
    
    /// Create standard desktop folders
    func createDesktopFolders() async throws {
        let desktopPath = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        
        // Create DIV Archive folder
        let archivePath = desktopPath.appendingPathComponent("DIV Archive")
        if !fileManager.fileExists(atPath: archivePath.path) {
            try fileManager.createDirectory(at: archivePath, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Custom Wallpaper
    
    /// Generate and set custom wallpaper with computer name overlay
    func setCustomWallpaper(computerName: String, customIconPath: String?) async throws {
        // Generate wallpaper image
        let wallpaperPath = try await generateWallpaper(computerName: computerName, customIconPath: customIconPath)
        
        // Set as wallpaper
        try await setWallpaper(imagePath: wallpaperPath)
    }
    
    private func generateWallpaper(computerName: String, customIconPath: String?) async throws -> String {
        // Get screen resolution
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        
        // Create image context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(screenSize.width),
            height: Int(screenSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw StandardizationError.wallpaperGenerationFailed
        }
        
        // Fill with dark gradient background
        let darkBlue = CGColor(red: 0.05, green: 0.1, blue: 0.2, alpha: 1.0)
        let darkerBlue = CGColor(red: 0.02, green: 0.05, blue: 0.1, alpha: 1.0)
        
        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [darkBlue, darkerBlue] as CFArray,
            locations: [0.0, 1.0]
        )!
        
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: screenSize.height),
            end: CGPoint(x: screenSize.width, y: 0),
            options: []
        )
        
        // Draw company icon if provided
        if let iconPath = customIconPath,
           let iconImage = NSImage(contentsOfFile: iconPath) {
            let iconSize: CGFloat = 200
            let iconRect = CGRect(
                x: (screenSize.width - iconSize) / 2,
                y: (screenSize.height - iconSize) / 2 + 50,
                width: iconSize,
                height: iconSize
            )
            
            if let cgImage = iconImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                context.draw(cgImage, in: iconRect)
            }
        }
        
        // Draw computer name
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext
        
        let font = NSFont.systemFont(ofSize: 48, weight: .bold)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        
        let textSize = (computerName as NSString).size(withAttributes: textAttributes)
        let textRect = CGRect(
            x: (screenSize.width - textSize.width) / 2,
            y: (screenSize.height - textSize.height) / 2 - 100,
            width: textSize.width,
            height: textSize.height
        )
        
        (computerName as NSString).draw(in: textRect, withAttributes: textAttributes)
        
        NSGraphicsContext.restoreGraphicsState()
        
        // Save image
        guard let cgImage = context.makeImage() else {
            throw StandardizationError.wallpaperGenerationFailed
        }
        
        let wallpaperDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MacDeploymentToolkit")
        try? fileManager.createDirectory(at: wallpaperDir, withIntermediateDirectories: true)
        
        let wallpaperPath = wallpaperDir.appendingPathComponent("custom_wallpaper.png")
        
        let destination = CGImageDestinationCreateWithURL(wallpaperPath as CFURL, kUTTypePNG, 1, nil)!
        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)
        
        return wallpaperPath.path
    }
    
    private func setWallpaper(imagePath: String) async throws {
        let script = """
        tell application "System Events"
            tell every desktop
                set picture to "\(imagePath)"
            end tell
        end tell
        """
        
        try await runAppleScript(script)
    }
    
    // MARK: - Bloatware Removal
    
    /// Remove unwanted default applications
    func removeUnwantedApps() async throws {
        let unwantedApps = [
            "GarageBand",
            "iMovie",
            "Keynote",
            "Numbers",
            "Pages"
        ]
        
        for app in unwantedApps {
            let appPath = "/Applications/\(app).app"
            if fileManager.fileExists(atPath: appPath) {
                do {
                    // Try to remove with elevated privileges
                    _ = try await runShellCommandWithElevation("rm -rf '\(appPath)'")
                } catch {
                    // Non-fatal, continue with other apps
                    print("Warning: Could not remove \(app): \(error)")
                }
            }
        }
    }
    
    // MARK: - Finder Preferences
    
    /// Configure Finder preferences
    func configureFinderPreferences() async throws {
        // Show all filename extensions
        try await runDefaultsCommand("NSGlobalDomain", key: "AppleShowAllExtensions", value: "true", type: "bool")
        
        // Show path bar
        try await runDefaultsCommand("com.apple.finder", key: "ShowPathbar", value: "true", type: "bool")
        
        // Show status bar
        try await runDefaultsCommand("com.apple.finder", key: "ShowStatusBar", value: "true", type: "bool")
        
        // Default to list view
        try await runDefaultsCommand("com.apple.finder", key: "FXPreferredViewStyle", value: "Nlsv")
        
        // Keep folders on top when sorting by name
        try await runDefaultsCommand("com.apple.finder", key: "_FXSortFoldersFirst", value: "true", type: "bool")
        
        // Restart Finder
        _ = try await runShellCommand("killall Finder")
    }
    
    // MARK: - Helper Methods
    
    private func runDefaultsCommand(_ domain: String, key: String, value: String, type: String? = nil) async throws {
        var command = "defaults write \(domain) \(key)"
        
        if let type = type {
            command += " -\(type) \(value)"
        } else {
            command += " '\(value)'"
        }
        
        _ = try await runShellCommand(command)
    }
    
    private func runAppleScript(_ script: String) async throws {
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ShellResult, Error>) in
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
        
        if result.exitCode != 0 {
            throw StandardizationError.appleScriptFailed(result.error)
        }
    }
    
    private func runShellCommand(_ command: String) async throws -> ShellResult {
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
    
    private func runShellCommandWithElevation(_ command: String) async throws -> ShellResult {
        let script = """
        do shell script "\(command.replacingOccurrences(of: "\"", with: "\\\""))" with administrator privileges
        """
        
        return try await withCheckedThrowingContinuation { continuation in
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
}

// MARK: - Errors

enum StandardizationError: LocalizedError {
    case wallpaperGenerationFailed
    case appleScriptFailed(String)
    case settingChangeFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .wallpaperGenerationFailed:
            return "Failed to generate custom wallpaper"
        case .appleScriptFailed(let error):
            return "AppleScript execution failed: \(error)"
        case .settingChangeFailed(let setting):
            return "Failed to change setting: \(setting)"
        }
    }
}
