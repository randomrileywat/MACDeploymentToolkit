# Mac Deployment Toolkit - Usage Guide

## Overview
This toolkit automates macOS deployments by installing applications and configuring system settings using SwiftUI and native macOS APIs.

## Features
- ✅ **Multiple Installation Methods**: Homebrew casks/formulas, direct downloads (DMG/PKG/ZIP)
- ✅ **System Configuration**: Dock, theme, power settings, wallpaper, Finder preferences
- ✅ **Detailed Logging**: Color-coded logs for easy monitoring
- ✅ **Error Handling**: Graceful failure handling with summary reporting
- ✅ **Real-time Monitoring**: Network status and deployment progress tracking

## Prerequisites
- macOS 12.0 (Monterey) or later
- Administrator privileges
- Internet connection for downloading apps
- Xcode 14.0+ (for building from source)

## Quick Start

### 1. Launch the Application
1. Open **MacDeploymentToolkit.app**
2. Grant any requested permissions (Accessibility, Full Disk Access if needed)

### 2. Select Applications
- Expand categories by clicking the disclosure arrow
- Check the checkbox next to each application you want to install
- A badge shows the count of selected apps per category

### 3. Enable Mac Standardization (Optional)
- Check "Mac Standardization" to apply system configuration
- Enter the computer name for wallpaper customization
- Optionally browse for a custom icon image

### 4. Deploy
- Click the **Deploy** button to start
- Monitor progress in the summary panel
- View detailed logs in the deployment log section

## Application Installation Methods

### 1. Homebrew (Recommended)
Homebrew is the de facto package manager for macOS.

**Casks** (GUI Applications):
```bash
# Examples installed as casks
brew install --cask google-chrome
brew install --cask spotify
brew install --cask wireshark
```

**Formulas** (CLI Tools):
```bash
# Examples installed as formulas
brew install wget
brew install git
```

**Finding Homebrew Packages:**
```bash
# Search for packages
brew search "app name"

# Get package info
brew info package-name
```

### 2. Direct Download
For installers not available via Homebrew.

**Supported Formats:**
| Format | Description | Installation Method |
|--------|-------------|---------------------|
| `.dmg` | Disk Image | Mount, copy .app to /Applications |
| `.pkg` | Package Installer | Run with `installer` command |
| `.zip` | ZIP Archive | Extract, copy .app to /Applications |

## Mac Standardization Settings

### Dark Theme
Enables system-wide dark mode via System Events AppleScript.

### Dock Configuration
- **Position**: Bottom
- **Size**: 48px
- **Auto-hide**: Disabled
- **Show Recents**: Disabled
- **Default Apps**: Finder, Chrome/Safari, Terminal, System Settings

### Power Settings
- Prevent sleep when on AC power
- Prevent display sleep when on AC power
- Disable disk sleep

### Finder Preferences
- Show all filename extensions
- Show path bar
- Show status bar
- Default to list view
- Keep folders on top when sorting

### Custom Wallpaper
- Generates wallpaper with dark gradient background
- Overlays computer name text
- Includes custom company icon (if provided)

### Desktop Folders
- Creates "DIV Archive" folder on Desktop

### Bloatware Removal
Optionally removes pre-installed apps:
- GarageBand
- iMovie
- Keynote
- Numbers
- Pages

## Application Catalog

### Audio
| Application | Installation Method | Notes |
|-------------|---------------------|-------|
| Dante Controller | Direct Download | Official Audinate DMG |
| Dante Virtual Soundcard | Direct Download | Official Audinate DMG |
| Reaper | Homebrew Cask | `reaper` |
| Shure Update Utility | Direct Download | Official Shure DMG |
| Wireless Workbench | Direct Download | Supabase storage |
| Waves Central | Direct Download | Official Waves DMG |

### Video
| Application | Installation Method | Notes |
|-------------|---------------------|-------|
| Blackmagic ATEM Switchers | Direct Download | Supabase storage |
| Blackmagic Desktop Video | Direct Download | Supabase storage |
| NDI Tools | Homebrew Cask | `ndi-tools` |
| OBS Studio | Homebrew Cask | `obs` |
| VLC | Homebrew Cask | `vlc` |

### Lighting
| Application | Installation Method | Notes |
|-------------|---------------------|-------|
| sACN View | Direct Download | GitHub releases |
| QLC+ | Homebrew Cask | `qlcplus` |

### Networking
| Application | Installation Method | Notes |
|-------------|---------------------|-------|
| Angry IP Scanner | Homebrew Cask | `angry-ip-scanner` (macOS equivalent of Advanced IP Scanner) |
| Wireshark | Homebrew Cask | `wireshark` |
| Packet Sender | Homebrew Cask | `packetsender` |
| PTP Track Hound | Direct Download | If available for macOS |

### Control
| Application | Installation Method | Notes |
|-------------|---------------------|-------|
| Q-SYS Designer | Direct Download | Supabase storage |
| Q-SYS UCI Viewer | Direct Download | Supabase storage |

### System
| Application | Installation Method | Notes |
|-------------|---------------------|-------|
| Google Chrome | Homebrew Cask | `google-chrome` |
| Spotify | Homebrew Cask | `spotify` |
| Visual Studio Code | Homebrew Cask | `visual-studio-code` |
| Rectangle | Homebrew Cask | `rectangle` (window management) |

## Troubleshooting

### Homebrew Not Found
If Homebrew isn't installed, the toolkit will attempt to install it automatically. If this fails:

```bash
# Manual Homebrew installation
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Permission Denied Errors
Ensure the application has the necessary permissions:
1. Open **System Settings** → **Privacy & Security**
2. Grant access under **Accessibility** and **Full Disk Access** if needed

### Application Not Installing
Check the deployment log for specific error messages:
- **Download failed**: Check network connection and URL validity
- **Mount failed**: DMG may be corrupted, try manual download
- **PKG install failed**: May require additional permissions

### Network Connection Required
The status bar shows network connectivity. Ensure you have:
- Active internet connection
- No firewall blocking downloads

## Logs and Debugging

### Deployment Log
The deployment log panel shows color-coded messages:
- 🔵 **Cyan**: Section headers
- 🟡 **Yellow**: Warnings and informational
- 🟢 **Green**: Success messages
- 🔴 **Red**: Error messages
- ⚪ **Gray**: Detail messages

### Console Logs
For additional debugging, check Console.app:
```bash
# Filter logs by app name
log show --predicate 'processImagePath contains "MacDeploymentToolkit"' --last 1h
```

## Building from Source

### Requirements
- Xcode 15.0 or later
- macOS 13.0 (Ventura) SDK

### Build Steps
```bash
# Clone repository
git clone https://github.com/randomrileywat/MACDeploymentToolkit.git
cd MACDeploymentToolkit/MacDeploymentToolkit

# Build with Swift Package Manager
swift build

# Or open in Xcode
open Package.swift
```

### Creating a Distribution DMG
```bash
# Build release version
swift build -c release

# Create DMG using create-dmg
create-dmg \
  --volname "Mac Deployment Toolkit" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --app-drop-link 450 185 \
  "MacDeploymentToolkit.dmg" \
  ".build/release/MacDeploymentToolkit.app"
```

## Windows vs macOS Feature Comparison

| Feature | Windows | macOS |
|---------|---------|-------|
| Package Manager | Winget | Homebrew |
| Installer Formats | EXE, MSI, ZIP | DMG, PKG, ZIP |
| System Settings | Registry, PowerShell | defaults, AppleScript |
| Taskbar/Dock | syspin.exe, Registry | defaults write com.apple.dock |
| Theme Settings | Registry (SystemUsesLightTheme) | AppleScript (appearance preferences) |
| Power Settings | powercfg | pmset |
| UI Automation | UI Automation API | AppleScript (System Events) |

---

**Diversified Mac Deployment Toolkit** - Simplifying macOS workstation deployment for AV professionals.
