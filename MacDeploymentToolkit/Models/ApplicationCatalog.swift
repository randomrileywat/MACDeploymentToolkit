//
//  ApplicationCatalog.swift
//  MacDeploymentToolkit
//
//  Catalog of all available applications for deployment on macOS
//

import Foundation

/// Provides the catalog of all installable applications
struct ApplicationCatalog {
    
    /// All available applications organized by category
    static let applications: [ApplicationCategory: [ApplicationDefinition]] = [
        
        // MARK: - Audio Applications
        .audio: [
            ApplicationDefinition(
                name: "Dante Controller",
                category: .audio,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: "https://my.audinate.com/support/downloads/dante-controller",
                version: "4.16",
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "Dante Virtual Soundcard",
                category: .audio,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: "https://my.audinate.com/support/downloads/dante-virtual-soundcard",
                version: nil,
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "Reaper",
                category: .audio,
                installMethod: .homebrew(type: .cask),
                packageId: "reaper",
                downloadUrl: nil,
                version: nil,
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "Shure Update Utility",
                category: .audio,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: "https://pubs.shure.com/guide/SUU",
                version: nil,
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "Wireless Workbench",
                category: .audio,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: nil, // Will use Supabase
                version: "7.7.0",
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "Waves Central",
                category: .audio,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: "https://www.waves.com/downloads/central",
                version: nil,
                macOsEquivalent: nil
            )
        ],
        
        // MARK: - Video Applications
        .video: [
            ApplicationDefinition(
                name: "Blackmagic ATEM Switchers",
                category: .video,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: nil, // Will use Supabase
                version: "10.2",
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "Blackmagic Desktop Video",
                category: .video,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: nil, // Will use Supabase
                version: "15.3",
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "NDI Tools",
                category: .video,
                installMethod: .homebrew(type: .cask),
                packageId: "ndi-tools",
                downloadUrl: nil,
                version: "6",
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "OBS Studio",
                category: .video,
                installMethod: .homebrew(type: .cask),
                packageId: "obs",
                downloadUrl: nil,
                version: nil,
                macOsEquivalent: "Alternative for video production"
            ),
            ApplicationDefinition(
                name: "VLC",
                category: .video,
                installMethod: .homebrew(type: .cask),
                packageId: "vlc",
                downloadUrl: nil,
                version: nil,
                macOsEquivalent: nil
            )
        ],
        
        // MARK: - Lighting Applications
        .lighting: [
            ApplicationDefinition(
                name: "sACN View",
                category: .lighting,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: "https://github.com/docsteer/sacnview/releases",
                version: "2.1.3",
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "QLC+",
                category: .lighting,
                installMethod: .homebrew(type: .cask),
                packageId: "qlcplus",
                downloadUrl: nil,
                version: nil,
                macOsEquivalent: "Open source lighting control"
            )
        ],
        
        // MARK: - Networking Applications
        .networking: [
            ApplicationDefinition(
                name: "Angry IP Scanner",
                category: .networking,
                installMethod: .homebrew(type: .cask),
                packageId: "angry-ip-scanner",
                downloadUrl: nil,
                version: nil,
                macOsEquivalent: "macOS alternative to Advanced IP Scanner"
            ),
            ApplicationDefinition(
                name: "Wireshark",
                category: .networking,
                installMethod: .homebrew(type: .cask),
                packageId: "wireshark",
                downloadUrl: nil,
                version: nil,
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "Packet Sender",
                category: .networking,
                installMethod: .homebrew(type: .cask),
                packageId: "packetsender",
                downloadUrl: nil,
                version: nil,
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "PTP Track Hound",
                category: .networking,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: nil, // Will use Supabase if available for Mac
                version: "2.2.0",
                macOsEquivalent: nil
            )
        ],
        
        // MARK: - Control Applications
        .control: [
            ApplicationDefinition(
                name: "Q-SYS Designer",
                category: .control,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: nil, // Will use Supabase
                version: "10.1.0",
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "Q-SYS UCI Viewer",
                category: .control,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: nil, // Will use Supabase
                version: "10.1.0",
                macOsEquivalent: nil
            )
        ],
        
        // MARK: - System Applications
        .system: [
            ApplicationDefinition(
                name: "Google Chrome",
                category: .system,
                installMethod: .homebrew(type: .cask),
                packageId: "google-chrome",
                downloadUrl: nil,
                version: nil,
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "Spotify",
                category: .system,
                installMethod: .homebrew(type: .cask),
                packageId: "spotify",
                downloadUrl: nil,
                version: nil,
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "Visual Studio Code",
                category: .system,
                installMethod: .homebrew(type: .cask),
                packageId: "visual-studio-code",
                downloadUrl: nil,
                version: nil,
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "Rectangle",
                category: .system,
                installMethod: .homebrew(type: .cask),
                packageId: "rectangle",
                downloadUrl: nil,
                version: nil,
                macOsEquivalent: "Window management utility"
            )
        ],
        
        // MARK: - Test Content
        .testContent: [
            ApplicationDefinition(
                name: "Audio Test Content",
                category: .testContent,
                installMethod: .custom(handler: "audiotestcontent"),
                packageId: nil,
                downloadUrl: nil, // Will use Supabase
                version: nil,
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "Video Test Content",
                category: .testContent,
                installMethod: .custom(handler: "videotestcontent"),
                packageId: nil,
                downloadUrl: nil, // Will use Supabase
                version: nil,
                macOsEquivalent: nil
            )
        ]
    ]
    
    /// Get all applications as a flat list
    static var allApplications: [ApplicationDefinition] {
        applications.values.flatMap { $0 }
    }
    
    /// Get applications for a specific category
    static func applications(for category: ApplicationCategory) -> [ApplicationDefinition] {
        applications[category] ?? []
    }
}
