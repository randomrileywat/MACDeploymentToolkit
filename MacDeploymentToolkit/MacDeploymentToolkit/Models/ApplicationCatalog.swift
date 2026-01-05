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
                installMethod: .homebrew(type: .cask),
                packageId: "dante-controller",
                downloadUrl: nil,
                version: nil,
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
                installMethod: .homebrew(type: .cask),
                packageId: "waves-central",
                downloadUrl: nil,
                version: nil,
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "Araneo",
                category: .audio,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: nil, // TODO: Add download URL
                version: nil,
                macOsEquivalent: "d&b audiotechnik ArrayProcessing"
            ),
            ApplicationDefinition(
                name: "LA Network Manager",
                category: .audio,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: nil, // TODO: Add download URL
                version: nil,
                macOsEquivalent: "L-Acoustics network management"
            ),
            ApplicationDefinition(
                name: "d&b R1",
                category: .audio,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: nil, // TODO: Add download URL
                version: nil,
                macOsEquivalent: "d&b Remote control"
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
                name: "ProPresenter",
                category: .video,
                installMethod: .homebrew(type: .cask),
                packageId: "propresenter",
                downloadUrl: nil,
                version: nil,
                macOsEquivalent: "Presentation/worship software"
            ),
            ApplicationDefinition(
                name: "Resolume Arena",
                category: .video,
                installMethod: .homebrew(type: .cask),
                packageId: "resolume-arena",
                downloadUrl: nil,
                version: nil,
                macOsEquivalent: "Media server/VJ software"
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
            )
        ],
        
        // MARK: - Networking Applications
        .networking: [
            ApplicationDefinition(
                name: "Angry IP Scanner",
                category: .networking,
                installMethod: .directDownload(format: .zip),
                packageId: nil,
                downloadUrl: "https://angryip.org/download/",
                version: nil,
                macOsEquivalent: "macOS alternative to Advanced IP Scanner"
            ),
            ApplicationDefinition(
                name: "Wireshark",
                category: .networking,
                installMethod: .homebrew(type: .cask),
                packageId: "wireshark-app",
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
            ),
            ApplicationDefinition(
                name: "Luminet Monitor",
                category: .networking,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: nil, // TODO: Add download URL
                version: nil,
                macOsEquivalent: "Luminex network monitoring"
            )
        ],
        
        // MARK: - Control Applications
        .control: [
            ApplicationDefinition(
                name: "Companion",
                category: .control,
                installMethod: .homebrew(type: .cask),
                packageId: "companion",
                downloadUrl: nil,
                version: nil,
                macOsEquivalent: "Bitfocus stream deck/control"
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
            )
        ],
        
        // MARK: - Test Content
        .testContent: [
            ApplicationDefinition(
                name: "Audio Test Content",
                category: .testContent,
                installMethod: .custom(handler: "audiotestcontent"),
                packageId: nil,
                downloadUrl: "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/Video%20Test%20Content/Audio%20Test%20Content.zip?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL1ZpZGVvIFRlc3QgQ29udGVudC9BdWRpbyBUZXN0IENvbnRlbnQuemlwIiwiaWF0IjoxNzY3MzI5MDExLCJleHAiOjQ4ODkzOTMwMTF9.nIFHyBTsp5_4RObSkHVMZpK0yxF_GkNiImXmJa3Nyo4",
                version: nil,
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "Video Test Content",
                category: .testContent,
                installMethod: .custom(handler: "videotestcontent"),
                packageId: nil,
                downloadUrl: "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/Video%20Test%20Content/Video%20Test%20Content.zip?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL1ZpZGVvIFRlc3QgQ29udGVudC9WaWRlbyBUZXN0IENvbnRlbnQuemlwIiwiaWF0IjoxNzY3MzI5MDM1LCJleHAiOjQ4ODkzOTMwMzV9.k4fC53e3-adF5rhlPCyl8de4dbINxRj7OWGN9mEZopg",
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
