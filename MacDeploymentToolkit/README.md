# Diversified Mac Deployment Toolkit

A macOS application for automated deployment of AV Production engineering workstations. This is the macOS port of the PC Deployment Toolkit, providing a unified interface for installing specialized audio/video professional software, system standardization, and test content deployment.

## Features

### Application Installation
- **Homebrew Integration**: Automated installation via Homebrew casks and formulas
- **Direct Downloads**: Support for DMG, PKG, and ZIP installers
- **Application Catalog**: Pre-configured list of professional AV software
  - Audio: Dante Controller, Reaper, Wireless Workbench, etc.
  - Video: NDI Tools, Blackmagic software, VLC, etc.
  - Lighting: sACN View, QLC+
  - Networking: Wireshark, Angry IP Scanner, Packet Sender
  - Control: Q-SYS Designer, Q-SYS UCI Viewer
  - System: Google Chrome, Spotify, VS Code, Rectangle

### Mac Standardization
- **Custom Wallpaper**: Generate wallpaper with computer name overlay and company branding
- **Dock Configuration**: Standard dock layout with essential applications
- **Dark Theme**: System-wide dark mode
- **Power Settings**: Prevent sleep when on AC power
- **Finder Preferences**: Show extensions, path bar, status bar
- **Desktop Organization**: Create standard folder structure

### Real-time Monitoring
- **Network Status**: Continuous connectivity monitoring
- **Deployment Progress**: Visual task list with status indicators
- **Detailed Logging**: Color-coded deployment log

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building)
- Administrator privileges (for installation and system configuration)

## Installation

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/randomrileywat/MACDeploymentToolkit.git
   cd MACDeploymentToolkit
   ```

2. Open the Xcode project:
   ```bash
   cd MacDeploymentToolkit
   open MacDeploymentToolkit.xcodeproj
   ```

3. Build and run in Xcode (⌘+R)

### Distribution

The application can be distributed as:
- `.app` bundle (direct copy to /Applications)
- `.dmg` disk image (recommended for distribution)

## Usage

1. **Launch the Application**: Open MacDeploymentToolkit.app
2. **Select Applications**: Check the applications you want to install from the categorized list
3. **Enable Standardization** (Optional): Check "Mac Standardization" to configure system settings
4. **Deploy**: Click the Deploy button to start installation

### Application Categories

| Category | Applications |
|----------|-------------|
| Audio | Dante Controller, Dante Virtual Soundcard, Reaper, Shure Update Utility, Wireless Workbench, Waves Central |
| Video | Blackmagic ATEM Switchers, Blackmagic Desktop Video, NDI Tools, OBS Studio, VLC |
| Lighting | sACN View, QLC+ |
| Networking | Angry IP Scanner, Wireshark, Packet Sender, PTP Track Hound |
| Control | Q-SYS Designer, Q-SYS UCI Viewer |
| System | Google Chrome, Spotify, Visual Studio Code, Rectangle |
| Test Content | Audio Test Content, Video Test Content |

## Architecture

```
MacDeploymentToolkit/
├── MacDeploymentToolkitApp.swift    # Application entry point
├── Models/
│   ├── ApplicationDefinition.swift  # Data models for apps and tasks
│   └── ApplicationCatalog.swift     # Complete application catalog
├── Views/
│   └── ContentView.swift            # Main UI view
└── Services/
    ├── DeploymentManager.swift      # Deployment orchestration
    ├── NetworkMonitor.swift         # Network connectivity
    ├── HomebrewInstaller.swift      # Homebrew integration
    ├── DirectDownloadInstaller.swift # DMG/PKG/ZIP handling
    └── SystemStandardizer.swift     # System configuration
```

## Technology Stack

- **Framework**: SwiftUI
- **Language**: Swift 5.9+
- **Package Management**: Homebrew, mas-cli (planned)
- **System Integration**: AppleScript, defaults, launchctl

## Permissions Required

- **Administrator Access**: For installing applications and changing system settings
- **Accessibility**: For UI automation (if implemented)
- **Full Disk Access**: For modifying certain system files (optional)

## Comparison with Windows Version

| Feature | Windows | macOS |
|---------|---------|-------|
| Package Manager | Winget | Homebrew |
| Installer Formats | EXE, MSI, ZIP | DMG, PKG, ZIP |
| System Settings | Registry, PowerShell | defaults, AppleScript |
| Taskbar/Dock | syspin.exe | defaults write |
| UI Automation | UI Automation API | AppleScript (System Events) |

## Known Limitations

- Some Windows-only AV applications don't have macOS equivalents
- Mac App Store apps require Apple ID sign-in (mas-cli not yet implemented)
- System Integrity Protection (SIP) may restrict certain operations
- Gatekeeper requires signed apps for distribution

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Original PC Deployment Toolkit by Diversified Engineering
- Homebrew project for macOS package management
- All the AV software vendors whose products we support

---

**Diversified Mac Deployment Toolkit** - Simplifying workstation deployment for AV professionals.
