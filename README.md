# Diversified Deployment Toolkit

A cross-platform deployment solution for AV Production engineering workstations. Automates installation of specialized audio/video professional software, system standardization, and test content deployment.

## Platforms

| Platform | Framework | Status |
|----------|-----------|--------|
| **Windows** | .NET 8.0 / Windows Forms (C#) | ✅ Production |
| **macOS** | SwiftUI (Swift) | 🚧 In Development |

## Windows Version

The Windows version (`MainForm.cs`) is a fully-featured deployment application using:
- **Winget** for package management
- **PowerShell** for system configuration
- **UI Automation** for installer handling
- Single-file executable deployment

See [README-GUI.md](README-GUI.md) and [USAGE.md](USAGE.md) for Windows documentation.

## macOS Version

The macOS version (`MacDeploymentToolkit/`) is a native SwiftUI application using:
- **Homebrew** for package management
- **AppleScript** for system configuration
- DMG/PKG/ZIP installer handling
- Native .app bundle deployment

See [MacDeploymentToolkit/README.md](MacDeploymentToolkit/README.md) and [MacDeploymentToolkit/USAGE.md](MacDeploymentToolkit/USAGE.md) for macOS documentation.

## Features

### Application Installation
- Categorized application selection (Audio, Video, Lighting, Networking, Control, System)
- Multiple installation methods per platform
- Progress tracking and detailed logging
- Automatic dependency handling

### System Standardization
- Custom wallpaper with computer name overlay
- Taskbar/Dock configuration
- Dark theme enforcement
- Power settings optimization
- Bloatware removal
- Desktop folder organization

### Monitoring
- Real-time network connectivity status
- Deployment progress visualization
- Color-coded log output
- Task success/failure tracking

## Repository Structure

```
MACDeploymentToolkit/
├── MainForm.cs              # Windows GUI application (C#)
├── README.md                # This file
├── README-GUI.md            # Windows GUI documentation
├── USAGE.md                 # Windows usage guide
├── PRD_MacOS_Port.md        # macOS port requirements document
├── LICENSE                  # MIT License
└── MacDeploymentToolkit/    # macOS application (Swift)
    ├── MacDeploymentToolkitApp.swift
    ├── Models/
    │   ├── ApplicationDefinition.swift
    │   └── ApplicationCatalog.swift
    ├── Views/
    │   └── ContentView.swift
    ├── Services/
    │   ├── DeploymentManager.swift
    │   ├── NetworkMonitor.swift
    │   ├── HomebrewInstaller.swift
    │   ├── DirectDownloadInstaller.swift
    │   └── SystemStandardizer.swift
    ├── README.md
    ├── USAGE.md
    └── Package.swift
```

## Getting Started

### Windows
```powershell
# Build the application
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true

# Run as Administrator
.\PCDeploymentToolkit.exe
```

### macOS
```bash
# Navigate to macOS project
cd MacDeploymentToolkit

# Build with Swift
swift build

# Or open in Xcode
open Package.swift
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

---

**Diversified Deployment Toolkit** - Simplifying workstation deployment for AV professionals.
