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
    
    /// Admin password set by DeploymentManager after initial prompt; used for sudo -S
    var adminPassword: String?
    
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
        // First, completely clear the dock persistent apps
        _ = try await runShellCommand("defaults delete com.apple.dock persistent-apps 2>/dev/null || true")
        
        // Re-initialize as empty array so -array-add works
        _ = try await runShellCommand("defaults write com.apple.dock persistent-apps -array")
        
        // List of apps to add to dock
        // Note: Finder is always shown by macOS — do NOT add it here or it appears twice
        let dockApps: [(name: String, path: String)] = [
            ("Chrome", "/Applications/Google Chrome.app"),
            ("Terminal", "/Applications/Utilities/Terminal.app"),
            ("System Preferences", "/System/Applications/System Preferences.app"),
            ("System Settings", "/System/Applications/System Settings.app")
        ]
        
        // Add each app individually using XML plist format with proper _CFURLStringType
        for app in dockApps {
            // Skip Chrome if not installed (Safari intentionally NOT added)
            if app.name == "Chrome" && !fileManager.fileExists(atPath: app.path) {
                continue
            }
            
            // For System Preferences/Settings, use the one that exists
            if app.name == "System Preferences" || app.name == "System Settings" {
                if !fileManager.fileExists(atPath: app.path) {
                    continue
                }
            }
            
            // Only add if the app exists
            if fileManager.fileExists(atPath: app.path) {
                try await addAppToDock(appPath: app.path)
            }
        }
    }
    
    /// Add an application to the Dock's persistent apps using proper plist format
    /// Uses XML plist with _CFURLStringType=0 (POSIX path) to prevent question mark icons
    func addAppToDock(appPath: String) async throws {
        // Verify the app exists before adding
        guard fileManager.fileExists(atPath: appPath) else { return }
        
        let addCommand = """
        defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>\(appPath)</string><key>_CFURLStringType</key><integer>0</integer></dict><key>file-label</key><string>\((appPath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: ""))</string></dict><key>tile-type</key><string>file-tile</string></dict>'
        """
        _ = try await runShellCommand(addCommand)
    }

    private func restartDock() async throws {
        _ = try await runShellCommand("killall Dock")
    }
    
    // MARK: - Power Settings
    
    /// Configure power settings (never sleep when plugged in)
    func configurePowerSettings() async throws {
        // Use osascript with admin privileges for pmset commands (avoid separate sudo prompts)
        // Prevent sleep when on AC power
        _ = try await runShellCommandWithElevation("pmset -c sleep 0")
        
        // Prevent display sleep when on AC power
        _ = try await runShellCommandWithElevation("pmset -c displaysleep 0")
        
        // Disable disk sleep
        _ = try await runShellCommandWithElevation("pmset -c disksleep 0")
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
        
        // Fill with solid black background
        let black = CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        context.setFillColor(black)
        context.fill(CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height))
        
        // Draw company icon in lower-right corner
        // Try custom path first, then fall back to bundled default logo
        var iconImage: NSImage? = nil
        var usingDefaultLogo = false
        
        if let iconPath = customIconPath, !iconPath.isEmpty {
            iconImage = NSImage(contentsOfFile: iconPath)
        }
        
        // Fall back to bundled default logo from asset catalog
        if iconImage == nil {
            // Asset catalog images must be loaded via NSImage(named:), not Bundle path
            iconImage = NSImage(named: "DefaultLogo")
            usingDefaultLogo = true
        }
        
        if let image = iconImage {
            let iconSize: CGFloat = 150
            let iconMargin: CGFloat = 50
            let iconRect = CGRect(
                x: screenSize.width - iconSize - iconMargin,
                y: iconMargin,
                width: iconSize,
                height: iconSize
            )
            
            if usingDefaultLogo {
                // Tint the logo white using CGContext blend modes.
                // This is more reliable than pixel manipulation because NSImage.cgImage()
                // can return nil for asset catalog images.
                // Strategy: create a temp NSImage, draw original, overlay white with .sourceAtop
                // blend mode (which only draws where the destination has alpha).
                let tintedSize = image.size
                let tintedImage = NSImage(size: tintedSize)
                tintedImage.lockFocus()
                
                // Draw the original logo
                image.draw(in: NSRect(origin: .zero, size: tintedSize),
                           from: .zero,
                           operation: .copy,
                           fraction: 1.0)
                
                // Overlay white, but only where the logo has alpha (sourceAtop)
                NSColor.white.setFill()
                NSRect(origin: .zero, size: tintedSize).fill(using: .sourceAtop)
                
                tintedImage.unlockFocus()
                
                // Draw the white-tinted logo into the wallpaper context
                if let tintedCG = tintedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    context.draw(tintedCG, in: iconRect)
                } else {
                    // Fallback: use NSGraphicsContext to draw directly
                    context.saveGState()
                    let tempNS = NSGraphicsContext(cgContext: context, flipped: false)
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = tempNS
                    tintedImage.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
                    NSGraphicsContext.restoreGraphicsState()
                    context.restoreGState()
                }
            } else {
                // Custom user-provided icon: draw as-is
                if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    context.draw(cgImage, in: iconRect)
                } else {
                    context.saveGState()
                    let tempNS = NSGraphicsContext(cgContext: context, flipped: false)
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = tempNS
                    image.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
                    NSGraphicsContext.restoreGraphicsState()
                    context.restoreGState()
                }
            }
        }
        
        // Draw computer name in lower-left corner
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext
        
        let font = NSFont.systemFont(ofSize: 72, weight: .bold)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        
        let textSize = (computerName as NSString).size(withAttributes: textAttributes)
        let margin: CGFloat = 100
        // Shift left and down slightly to better match the icon placement feel
        let textRect = CGRect(
            x: margin - 15,
            y: margin - 15,
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
        let url = URL(fileURLWithPath: imagePath)
        
        // Primary: use NSWorkspace API (reliable across macOS versions)
        var nsWorkspaceSucceeded = false
        for screen in NSScreen.screens {
            do {
                try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
                nsWorkspaceSucceeded = true
            } catch {
                // Will try AppleScript fallback below
            }
        }
        
        if nsWorkspaceSucceeded {
            return
        }
        
        // Fallback: AppleScript via System Events
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
                    // Use osascript with admin privileges for app removal (avoids separate sudo prompts)
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
        // Inject PATH into command so it survives sudo/osascript environment resets
        let fullCommand = "export PATH=/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:$PATH && \(command)"
        
        // Use stored admin password with sudo -S to avoid repeated password prompts
        guard let password = adminPassword else {
            // Fallback: osascript dialog (will prompt each time)
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
