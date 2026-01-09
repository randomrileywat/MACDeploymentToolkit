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
                downloadUrl: "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/MAC%20Deployment%20Installers/Audinate/DVS-4.5.2.3_macos.dmg?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL01BQyBEZXBsb3ltZW50IEluc3RhbGxlcnMvQXVkaW5hdGUvRFZTLTQuNS4yLjNfbWFjb3MuZG1nIiwiaWF0IjoxNzY3OTI4MzU1LCJleHAiOjQ4ODk5OTIzNTV9.iyiguKECmjApAKrorKq6SKTEJ3Izvoz5EbiYHGasPRQ",
                version: "4.5.2.3",
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
                installMethod: .directDownload(format: .pkg),
                packageId: nil,
                downloadUrl: "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/MAC%20Deployment%20Installers/Shure/Shure-Update-Utility-macOS-2.8.13.pkg?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL01BQyBEZXBsb3ltZW50IEluc3RhbGxlcnMvU2h1cmUvU2h1cmUtVXBkYXRlLVV0aWxpdHktbWFjT1MtMi44LjEzLnBrZyIsImlhdCI6MTc2NzkyODczNSwiZXhwIjo0ODg5OTkyNzM1fQ.A5T-zGQNXUokdpeuz8a1_6O-FCV7LRdfazuhM1RAFUY",
                version: "2.8.13",
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "Wireless Workbench",
                category: .audio,
                installMethod: .homebrew(type: .cask),
                packageId: "wireless-workbench",
                downloadUrl: nil,
                version: nil,
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
                downloadUrl: "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/MAC%20Deployment%20Installers/Luminex/._AraneoInstaller.dmg?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL01BQyBEZXBsb3ltZW50IEluc3RhbGxlcnMvTHVtaW5leC8uX0FyYW5lb0luc3RhbGxlci5kbWciLCJpYXQiOjE3Njc5MjcwNjEsImV4cCI6NDg4OTk5MTA2MX0.Wsq0mnqugGoM_HBpk_IQ9LgNpwItoTAD9Ba0xrCdrOk",
                version: nil,
                macOsEquivalent: "d&b audiotechnik ArrayProcessing"
            ),
            ApplicationDefinition(
                name: "LA Network Manager",
                category: .audio,
                installMethod: .directDownload(format: .pkg),
                packageId: nil,
                downloadUrl: "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/MAC%20Deployment%20Installers/L'Acoustics/LA%20Network%20Manager-2025.3.pkg?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL01BQyBEZXBsb3ltZW50IEluc3RhbGxlcnMvTCdBY291c3RpY3MvTEEgTmV0d29yayBNYW5hZ2VyLTIwMjUuMy5wa2ciLCJpYXQiOjE3Njc5MjgxMjksImV4cCI6NDg4OTk5MjEyOX0.3sGgu59AgpbjagWncPa6RsHn_M_1Y32MHmJjC5E_59E",
                version: "2025.3",
                macOsEquivalent: "L-Acoustics network management"
            ),
            ApplicationDefinition(
                name: "d&b R1",
                category: .audio,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/MAC%20Deployment%20Installers/d&b/dbaudio-r1-v3.42.4-mac.dmg?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL01BQyBEZXBsb3ltZW50IEluc3RhbGxlcnMvZCZiL2RiYXVkaW8tcjEtdjMuNDIuNC1tYWMuZG1nIiwiaWF0IjoxNzY3OTI4MzIyLCJleHAiOjQ4ODk5OTIzMjJ9.kM4-ATDn0PvUWEgJVFREY1eqZEUXkhDvtskBJ9zLOH4",
                version: "3.42.4",
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
                downloadUrl: "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/MAC%20Deployment%20Installers/Blackmagic%20Design/Blackmagic_ATEM_Switchers_10.2.dmg?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL01BQyBEZXBsb3ltZW50IEluc3RhbGxlcnMvQmxhY2ttYWdpYyBEZXNpZ24vQmxhY2ttYWdpY19BVEVNX1N3aXRjaGVyc18xMC4yLmRtZyIsImlhdCI6MTc2NzkyNzg2NywiZXhwIjo0ODg5OTkxODY3fQ.JJ4wJ5LyndFE-41sLos6iJTdlkpXvB6Er90mMbiblLY",
                version: "10.2",
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "Blackmagic Desktop Video",
                category: .video,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/MAC%20Deployment%20Installers/Blackmagic%20Design/Blackmagic_Desktop_Video_15.3.1.dmg?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL01BQyBEZXBsb3ltZW50IEluc3RhbGxlcnMvQmxhY2ttYWdpYyBEZXNpZ24vQmxhY2ttYWdpY19EZXNrdG9wX1ZpZGVvXzE1LjMuMS5kbWciLCJpYXQiOjE3Njc5MjcxMDcsImV4cCI6NDg4OTk5MTEwN30.nppzZ8ko06z3YwKLRZBUA_la9IkmfiFC7s3Za4rtsLk",
                version: "15.3.1",
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "Blackmagic Videohub",
                category: .video,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/MAC%20Deployment%20Installers/Blackmagic%20Design/Blackmagic_Videohub_11.0.dmg?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL01BQyBEZXBsb3ltZW50IEluc3RhbGxlcnMvQmxhY2ttYWdpYyBEZXNpZ24vQmxhY2ttYWdpY19WaWRlb2h1Yl8xMS4wLmRtZyIsImlhdCI6MTc2NzkyNzg5OSwiZXhwIjo0ODg5OTkxODk5fQ.Q1HJ0aEBOxO44U7fC5RkBmVyvnIheDxp6XWfwhm6VhM",
                version: "11.0",
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
                downloadUrl: "https://github.com/docsteer/sacnview/releases/download/v2.1.3/sACNView_2.1.3.dmg",
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
                downloadUrl: "https://github.com/angryip/ipscan/releases/download/3.9.3/ipscan-macX86-3.9.3.zip",
                downloadUrlArm: "https://github.com/angryip/ipscan/releases/download/3.9.3/ipscan-macArm64-3.9.3.zip",
                version: "3.9.3",
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
                installMethod: .directDownload(format: .run),
                packageId: nil,
                downloadUrl: "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/MAC%20Deployment%20Installers/PTP%20Trackhound/ptptrackhound_2.2.0_x86_64.run?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL01BQyBEZXBsb3ltZW50IEluc3RhbGxlcnMvUFRQIFRyYWNraG91bmQvcHRwdHJhY2tob3VuZF8yLjIuMF94ODZfNjQucnVuIiwiaWF0IjoxNzY3OTI4NDQwLCJleHAiOjQ4ODk5OTI0NDB9.9qWNbUgUqU16Q4YIZcLrslt3Ao-4UI4p7i71w3ICIWo",
                version: "2.2.0",
                macOsEquivalent: nil
            ),
            ApplicationDefinition(
                name: "Luminet Monitor",
                category: .networking,
                installMethod: .directDownload(format: .dmg),
                packageId: nil,
                downloadUrl: "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/MAC%20Deployment%20Installers/Luminex/LuminexInstaller.dmg?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL01BQyBEZXBsb3ltZW50IEluc3RhbGxlcnMvTHVtaW5leC9MdW1pbmV4SW5zdGFsbGVyLmRtZyIsImlhdCI6MTc2NzkyNzA3OSwiZXhwIjo0ODg5OTkxMDc5fQ.FebFNpFNsmGCQbrBpg8v-8HVaE8w2kSS_-DJNnwZk_Y",
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
