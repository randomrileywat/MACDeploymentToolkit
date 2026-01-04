# Product Requirements Document: PC Deployment Toolkit - macOS Port

**Document Version:** 1.0  
**Last Updated:** January 4, 2026  
**Purpose:** To define requirements for porting the PC Deployment Toolkit to macOS

---

## 1. Executive Summary

### 1.1 Product Overview
The PC Deployment Toolkit is an automated deployment application designed for AV Production engineering workstations. It provides a unified interface for installing specialized audio/video professional software, system standardization, and test content deployment. The application is currently Windows-only and requires porting to macOS to support Mac-based workstations.

### 1.2 Target Users
- AV Production Engineers
- IT Deployment Technicians
- System Administrators managing mixed Windows/Mac environments

### 1.3 Core Value Proposition
- **Automation**: Reduces 2+ hour manual deployment to supervised automated process
- **Standardization**: Ensures consistent workstation configuration across organization
- **Error Reduction**: Eliminates manual installation mistakes
- **Time Savings**: Parallel installations and silent automation
- **Audit Trail**: Complete deployment logging for compliance/troubleshooting

---

## 2. Application Architecture

### 2.1 Technology Stack (Windows)
- **Framework**: .NET 8.0, Windows Forms
- **Language**: C# 12
- **Deployment**: Self-contained single-file executable
- **OS Integration**: Windows API (P/Invoke), PowerShell scripts
- **Package Management**: Winget (Windows Package Manager)
- **UI Automation**: System.Windows.Automation, UIAutomationClient
- **Network**: HttpClient, Supabase REST API
- **Compression**: System.IO.Compression (ZIP extraction)

### 2.2 Recommended Technology Stack (macOS)
- **Framework**: SwiftUI (native) or Electron (cross-platform)
- **Language**: Swift (native) or TypeScript/JavaScript (Electron)
- **Deployment**: .dmg or .app bundle
- **OS Integration**: macOS Cocoa APIs, shell scripts (bash/zsh)
- **Package Management**: Homebrew, mas-cli (Mac App Store), DMG/PKG installers
- **UI Automation**: AppleScript, Automator, or NSAppleScript APIs
- **Network**: URLSession (Swift) or Electron's net module
- **Compression**: Archive/UnArchive utilities (Swift) or Node.js libraries

### 2.3 Application Structure

```
PCDeploymentToolkit/
├── Core/
│   ├── MainForm - Primary UI and orchestration
│   ├── DeploymentEngine - Installation logic coordinator
│   ├── NetworkMonitor - Connection health checking
│   └── LoggingService - Centralized logging
├── Installers/
│   ├── WingetInstaller - Package manager installations
│   ├── CustomInstaller - Direct downloads and custom installs
│   ├── ContentDeployer - Test content extraction
│   └── AutoClicker - UI automation for silent installs
├── SystemConfig/
│   ├── StandardizationApplier - System settings management
│   ├── WallpaperGenerator - Custom branded wallpapers
│   ├── TaskbarManager - Taskbar/Dock configuration
│   └── BloatwareRemover - Unwanted software cleanup
├── Models/
│   ├── DeploymentTask - Task tracking and status
│   └── ApplicationDefinition - App metadata and install config
└── Resources/
    ├── default_icon.png - Company branding
    ├── syspin.exe (Windows) - Taskbar pinning utility
    └── Embedded resources - Icons, config files
```

---

## 3. Feature Requirements

### 3.1 Core Features (Must Have)

#### 3.1.1 Application Selection Interface
**Description**: Hierarchical tree view with categorized applications

**Functionality**:
- Multi-select checkbox tree with collapsible categories
- Categories:
  - Audio (8 applications)
  - Video (8 applications)
  - Lighting (4 applications)
  - Networking (5 applications)
  - Control (3 applications)
  - System (2 applications)
  - Test Content (2 packages)
- Custom visual rendering (categories without checkboxes, child items with checkboxes)
- Expand/collapse categories
- Real-time selection tracking
- Persistent UI state (expanded categories remain expanded)

**Windows Implementation Details**:
- TreeView with DrawMode = OwnerDrawAll
- Custom DrawNode event handler for checkbox hiding on categories
- NodeMouseClick for checkbox toggling
- BeforeCollapse/BeforeExpand for category management
- AfterCheck event triggers deploy button state update

**macOS Considerations**:
- Use NSOutlineView or SwiftUI List with DisclosureGroup
- Custom cell rendering for checkbox control
- NSOutlineViewDelegate for expand/collapse management
- State management for real-time UI updates

#### 3.1.2 PC/System Standardization
**Description**: Automated OS configuration for organizational standards

**Features**:
- Custom wallpaper generation with computer name overlay + company icon
- Lock screen customization (same wallpaper)
- User profile icon reset/custom icon
- Dark theme enforcement
- Taskbar/Dock configuration:
  - Pin File Manager and Browser
  - Remove default pins
  - Left-align taskbar (Windows) / Dock positioning (macOS)
  - Hide widgets/extras
- Power settings (never sleep when plugged in)
- Desktop folder creation ("DIV Archive")
- Network Connections shortcut creation
- Bloatware/unwanted app removal
- Startup app disabling
- Desktop shortcut cleanup

**Windows Implementation**:
- PowerShell scripts for registry manipulation
- SystemParametersInfo Win32 API for wallpaper
- AppxPackage cmdlets for bloatware removal
- syspin.exe utility for taskbar pinning
- System.Drawing for wallpaper image generation

**macOS Considerations**:
- `defaults write` commands for system preferences
- NSWorkspace for wallpaper/icon setting
- `osascript` for Dock manipulation
- `launchctl` for startup items
- Native image processing (Core Graphics / Image I/O)
- Finder preferences via plist files
- System Integrity Protection (SIP) constraints

#### 3.1.3 Package Management Integration
**Description**: Leverage platform package managers for reliable installs

**Windows**: Winget (Windows Package Manager)
- Automatic Winget installation if missing
- Source updates before installation
- Silent installation with acceptance flags
- User-context fallback via scheduled tasks
- Hash override for problematic packages
- Exit code handling (0 = success, 3010 = reboot required)

**macOS**: Homebrew + mas-cli
- Homebrew Cask for GUI applications
- Homebrew Formula for CLI tools
- `mas` (Mac App Store CLI) for App Store apps
- Silent installation flags where available
- Sudo elevation handling
- Installation verification via `brew list` or filesystem checks

#### 3.1.4 Direct Download Installation
**Description**: Support for applications not in package managers

**Functionality**:
- HTTP/HTTPS downloads with progress tracking
- Supabase storage integration with authentication
- Support for multiple installer formats:
  - **Windows**: .exe, .msi, .zip
  - **macOS**: .dmg, .pkg, .app bundles, .zip
- Silent installation parameter passing
- Extraction for archive formats
- Timeout handling (10-15 minutes per app)
- Cleanup of temporary files

**Installation Arguments**:
- Windows: /S, /silent, /qn, /VERYSILENT
- macOS: --silent, installer -pkg, hdiutil attach/detach

#### 3.1.5 UI Automation for Silent Installs
**Description**: Automatic clicking through installer dialogs

**Windows Implementation**:
- PowerShell script with UI Automation assemblies
- Deployment-wide autoclicker process (runs for all installs)
- Elevated execution to see UAC-protected windows
- Window enumeration via Win32 EnumWindows
- Control detection: buttons, checkboxes, radio buttons
- Pattern matching for common installer controls
- Fallback keyboard automation (Tab + Enter for UAC)
- Special handling:
  - Untick "Launch after install" checkboxes
  - Check "I Agree" checkboxes and radio buttons
  - Click Next/Install/OK/Yes buttons
  - Avoid Cancel/No/Disagree buttons
  - Handles InstallAware, Inno Setup, NSIS, Windows Security dialogs

**macOS Considerations**:
- AppleScript UI scripting (System Events)
- Accessibility permissions required
- `cliclick` or similar for programmatic clicking
- Challenge: macOS installers are more standardized, may need less automation
- Security: Gatekeeper and notarization requirements
- Consider Apple Script for .app/DMG mounting and dragging

#### 3.1.6 Deployment Progress Tracking
**Description**: Real-time visual feedback during deployment

**Features**:
- Summary panel with task list:
  - Task name with bold font
  - Status icon (⏳ pending, ✓ success, ✗ failed)
  - Status detail text
  - Color-coded status (gray/orange/green/red)
- Marquee progress bar during installation
- Live status label updates
- Friendly rotating messages during deployment
- Detailed deployment log (terminal-style)
- Time elapsed tracking
- Final summary with statistics

**UI Elements**:
- Panel: 650x417px, white background
- Summary Title: "Deployment Progress" → friendly messages → "Deployment Complete! ✓"
- Task List: Scrollable RichTextBox with colored text
- Log Area: Dark theme (30,30,30 bg, 220,220,220 fg) console font
- Status Label: Right-aligned (pre-deploy), left-aligned (during deploy)
- Deploy Button: 160x40px, blue (#0078D4) when enabled, gray when disabled

#### 3.1.7 Network Connection Monitoring
**Description**: Real-time network availability checking

**Functionality**:
- Initial check on application launch
- Periodic checks every 5 seconds via timer
- Ping test to reliable host (8.8.8.8)
- Visual indicators:
  - Status label: "Network connection required" (red) when offline
  - Status label: "Select applications to deploy" (gray) when nothing selected
  - Status label: "Ready to deploy" (gray) when ready
- Deploy button state management:
  - Disabled when no network
  - Disabled when nothing selected
  - Enabled only when both conditions met
- No disruptive popups (status shown in label only)

#### 3.1.8 Logging System
**Description**: Comprehensive deployment audit trail

**Features**:
- Color-coded console output:
  - Cyan: Section headers (=== Section ===)
  - Yellow: Warnings and informational messages
  - Green: Success messages (✓)
  - Red: Errors (✗)
  - Gray: Detail/context messages (indented with •)
  - Orange: Important warnings (⚠️)
- Timestamped deployment start
- Per-application installation tracking
- PowerShell script output capture (filtered for progress bars)
- Final summary with counts and duration
- Scrollable view with auto-scroll to latest

### 3.2 Advanced Features (Nice to Have)

#### 3.2.1 Test Content Deployment
**Description**: Download and extract test media files to Desktop

**Functionality**:
- Audio Test Content package
- Video Test Content package  
- Auto-installation of VLC with Video Test Content
- Extraction to named folders on Desktop
- Progress tracking for large downloads
- Supabase CDN integration

#### 3.2.2 Administrator/Elevated Privilege Detection
**Description**: Ensure sufficient permissions for system modifications

**Windows**: WindowsIdentity.GetCurrent() → WindowsPrincipal → WindowsBuiltInRole.Administrator  
**macOS**: Check for `sudo` privileges or admin group membership

#### 3.2.3 Application-Specific Post-Install Actions
**Description**: Custom cleanup after certain installations

**Examples**:
- Close auto-launched windows (Araneo, NDI Tools, Advanced IP Scanner)
- Pin Chrome to taskbar/dock after installation
- Driver wizard automation (NovaLCT Silicon Labs CP210x)
- Wait for background installation processes (Audio Architect)

### 3.3 Excluded Features (Out of Scope for Initial Port)
- Remote deployment (all installations are local)
- Multi-machine orchestration
- User profile migration
- Software license management
- Update checking for installed applications
- Uninstall functionality

---

## 4. Application Catalog

### 4.1 Audio Applications
| Application | Type | Installation Method |
|-------------|------|---------------------|
| Audio Architect 2.55.3 | Custom | Direct download (ZIP) |
| Dante Controller 4.16 | Custom | Direct download (EXE) |
| Dante Virtual Soundcard | Winget | Audinate.DanteVirtualSoundcard |
| Milan Manager 2.4 | Custom | Direct download (ZIP) |
| Reaper | Winget | Cockos.REAPER |
| Shure Update Utility | Winget | Shure.UpdateUtility |
| Waves Central | Custom | Direct download (EXE) |
| Wireless Workbench 7.7.0 | Winget/Supabase | Shure.WirelessWorkbench.7 (fallback to Supabase) |

### 4.2 Video Applications
| Application | Type | Installation Method |
|-------------|------|---------------------|
| Blackmagic ATEM Switchers 10.2 | Custom | Supabase (ZIP) |
| Blackmagic Desktop Video 15.3 | Custom | Supabase (MSI) |
| Blackmagic Videohub 11.0 | Custom | Supabase (EXE) |
| Brompton Tessera Remote 3.5 | Custom | Direct download (EXE) |
| NDI 6 Tools | Winget | NDI.NDITools |
| Novastar Coex VMP 1.5 | Custom | Direct download (ZIP) |
| Novastar NovaLCT 5.8 | Custom | Direct download (ZIP) |
| Ross Dashboard 9.15.1 | Custom | Supabase (EXE) |

### 4.3 Lighting Applications
| Application | Type | Installation Method |
|-------------|------|---------------------|
| Araneo | Custom | Supabase (EXE) |
| CueServer Studio 5.2.7 | Custom | Direct download (EXE) |
| Luminet Monitor 2.3.7 | Custom | Direct download (ZIP) |
| sACN View 2.1.3 | Custom | GitHub release (EXE) |

### 4.4 Networking Applications
| Application | Type | Installation Method |
|-------------|------|---------------------|
| Advanced IP Scanner | Winget | Famatech.AdvancedIPScanner |
| Netgear Engage 2.3.1.8 | Custom | Supabase (EXE) |
| Packet Sender | Winget | NagleCode.PacketSender |
| PTP Track Hound 2.2.0 | Custom | Supabase (EXE) |
| Wireshark | Winget | WiresharkFoundation.Wireshark |

### 4.5 Control Applications
| Application | Type | Installation Method |
|-------------|------|---------------------|
| Q-SYS Designer 10.1.0 | Custom | Supabase (EXE) |
| Q-SYS Designer LTS 9.13.1 | Custom | Supabase (EXE) |
| Q-SYS UCI Viewer 10.1.0 | Custom | Supabase (EXE) |

### 4.6 System Applications
| Application | Type | Installation Method |
|-------------|------|---------------------|
| Google Chrome | Winget | Google.Chrome |
| Spotify | Winget | Spotify.Spotify |

### 4.7 Test Content
| Package | Type | Installation Method |
|---------|------|---------------------|
| Audio Test Content | Custom | Supabase (ZIP to Desktop) |
| Video Test Content | Custom | Supabase (ZIP to Desktop) + VLC |

### 4.8 macOS Equivalent Mappings
**To be determined during implementation. Considerations:**
- Many professional AV apps have macOS versions (Dante, NDI, Reaper, Wireshark, Q-SYS)
- Some Windows-only apps may need alternatives (Advanced IP Scanner → Angry IP Scanner)
- Mac-specific additions: Xcode Command Line Tools, QuickTime Pro features
- App Store apps via `mas-cli` (e.g., Xcode, Final Cut Pro if applicable)

---

## 5. UI/UX Specifications

### 5.1 Layout Dimensions
- **Window Size**: 690x740px (fixed, not resizable)
- **Title**: "Diversified PC Deployment Toolkit"
- **Icon**: Embedded DIVIconRGB.ico (company branding)

### 5.2 Main Screen Layout (Pre-Deployment)

```
┌──────────────────────────────────────────────────────────────┐
│  Diversified PC Deployment Toolkit                     [─][□][×]│
├──────────────────────────────────────────────────────────────┤
│  Title: "Diversified PC Deployment Toolkit" (16pt, Blue)    │
│  Instructions: "Select applications to install:" (10pt)     │
├──────────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────┐     │
│  │  ▼ Audio                                           │     │
│  │    □ Audio Architect                               │     │
│  │    □ Dante Controller                              │     │
│  │    □ Dante Virtual Soundcard                       │     │
│  │    ...                                             │     │
│  │  ▼ Video                                           │     │
│  │    □ Blackmagic ATEM Switchers                     │     │
│  │    □ Blackmagic Desktop Video Setup                │     │
│  │    ...                                             │     │
│  │  [Scrollable TreeView - 620x450px]                │     │
│  └────────────────────────────────────────────────────┘     │
│  □ PC Standardization (Taskbar, Theme, Power, Bloat...)     │
│     Computer Name (for wallpaper): [______________]          │
│     Custom Icon (optional): [______________] [Browse]        │
│  ─────────────────────────────────────────────────────       │
│                             [Select apps to deploy] [Deploy] │
└──────────────────────────────────────────────────────────────┘
```

### 5.3 Deployment Screen Layout

```
┌──────────────────────────────────────────────────────────────┐
│  Diversified PC Deployment Toolkit                     [─][□][×]│
├──────────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────────┐ │
│  │  🚀 Great time to grab a coffee!                       │ │
│  │                                                        │ │
│  │  ⏳  PC Standardization - In progress...              │ │
│  │  ✓   Google Chrome - Installed successfully           │ │
│  │  ⏳  Advanced IP Scanner - Checking...                │ │
│  │  ⏳  Dante Controller - Pending...                    │ │
│  │  [Summary Panel - 650x417px]                          │ │
│  └────────────────────────────────────────────────────────┘ │
│  [████████████████░░░░░░░░░░░░] Progress Bar               │
│  Deployment Log:           Installing Advanced IP Scanner...│
│  ┌────────────────────────────────────────────────────────┐ │
│  │ === Deployment Started ===                             │ │
│  │ Checking for Winget availability...                    │ │
│  │   ✓ Winget is available                                │ │
│  │ Installing Advanced IP Scanner...                      │ │
│  │   • Downloading...                                     │ │
│  │ [Dark terminal-style log - 650x203px]                  │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

### 5.4 Color Scheme
- **Primary Blue**: #0078D4 (buttons, headings)
- **Success Green**: #00AA00
- **Warning Yellow**: #FFAA00
- **Error Red**: #DD0000
- **Background**: White (#FFFFFF)
- **Log Background**: Dark (#1E1E1E)
- **Log Text**: Light gray (#DCDCDC)
- **Disabled Gray**: #B4B4B4

### 5.5 Typography
- **Title**: Segoe UI, 16pt, Bold
- **Section Headers**: Segoe UI, 14pt, Bold
- **Body Text**: Segoe UI, 10pt
- **Tree Items**: Segoe UI, 9pt
- **Log Text**: Consolas, 10pt (monospace)
- **Status Icons**: Segoe UI, 14pt (for emoji-style icons)

### 5.6 Button States
- **Enabled**: Blue background (#0078D4), white text, hand cursor
- **Disabled**: Gray background (#B4B4B4), white text, default cursor
- **Custom Paint**: Disabled state maintains white text (not system gray)

### 5.7 Interaction Patterns
- **Checkboxes**: Only on child items, categories don't have checkboxes
- **Tree Expansion**: Click on category name or arrow to expand/collapse
- **Checkbox Toggle**: Click directly on checkbox (20px hit area)
- **Real-time Validation**: Button enables/disables based on selection + network
- **No Popups**: All status shown in status label (except critical errors)

---

## 6. System Integration

### 6.1 Windows Integration (Current)
- **Registry Manipulation**: PowerShell Set-ItemProperty for system settings
- **Wallpaper**: SystemParametersInfo Win32 API
- **Icons**: Registry keys for account pictures
- **Taskbar**: syspin.exe utility, registry for alignment/widgets
- **Bloatware**: Get-AppxPackage, Remove-AppxPackage PowerShell cmdlets
- **Installer Automation**: UI Automation assemblies, Win32 SendMessage
- **Elevation**: Process.StartInfo.Verb = "runas"

### 6.2 macOS Integration (Proposed)
- **System Preferences**: `defaults write` command-line tool
- **Wallpaper**: NSWorkspace setDesktopImageURL or osascript
- **Icons**: System Preferences → Users & Groups (may need AppleScript)
- **Dock**: `defaults write com.apple.dock`, `killall Dock`
- **Bloatware**: `rm -rf /Applications/Unwanted.app` (with sudo)
- **Installer Automation**: AppleScript, System Events, Accessibility API
- **Elevation**: `osascript -e "do shell script \"command\" with administrator privileges"`
- **DMG Mounting**: `hdiutil attach`, drag to /Applications, `hdiutil detach`
- **PKG Installation**: `installer -pkg file.pkg -target /`

### 6.3 Filesystem Locations

**Windows**:
- Installers: `%TEMP%`
- Wallpaper: `%USERPROFILE%\Pictures\custom_wallpaper.png`
- Lock Screen: `%LOCALAPPDATA%\Microsoft\Windows\SystemData\LockScreen.jpg`
- Account Icon: `%LOCALAPPDATA%\Microsoft\Windows\AccountPictures\user_icon.png`
- Desktop: `%USERPROFILE%\Desktop`
- Registry: HKCU, HKLM

**macOS**:
- Installers: `/tmp` or `~/Downloads`
- Wallpaper: `~/Library/Application Support/` or direct API call
- Account Icon: `/Library/User Pictures/` or via System Preferences
- Desktop: `~/Desktop`
- Preferences: `~/Library/Preferences/` (plist files)
- Applications: `/Applications` (system), `~/Applications` (user)

### 6.4 Permission Requirements

**Windows**:
- Administrator privileges for:
  - Software installation
  - Registry writes (HKLM)
  - AppxPackage operations
  - Scheduled task creation

**macOS**:
- Administrator password for:
  - Software installation (PKG, DMG to /Applications)
  - System Preferences changes
  - Homebrew installations
  - Launchctl modifications
- Accessibility permissions for:
  - UI automation (System Events control)
  - Keyboard/mouse events
- Full Disk Access (potentially):
  - Accessing certain system files

---

## 7. Data Storage & Configuration

### 7.1 Embedded Resources
- **default_icon.png**: Company logo (2048x2048 recommended)
- **syspin.exe** (Windows only): Taskbar pinning utility
- **DIVIconRGB.ico**: Application icon

### 7.2 External Dependencies
- **Supabase Storage**: Cloud-hosted installers and test content
  - URL: https://incdoepqrbwaagatikgb.supabase.co
  - Auth: Service key in SUPABASE_SERVICE_KEY constant
  - Files: Signed URLs with long expiration (2059)
  - Used for: Large installers, test content, proprietary software

### 7.3 Application State
- **In-Memory Only**: No persistent configuration or state
- **Deployment Tasks**: List<DeploymentTask> tracking current operations
- **Network State**: Boolean flags (isNetworkAvailable, isDeploying)
- **UI State**: TreeView expanded/collapsed, checkbox selections (lost on close)

### 7.4 Logging
- **Display Only**: No log file persistence (all in-memory RichTextBox)
- **Format**: Timestamped sections with color coding
- **Scroll Management**: Auto-scroll to bottom on new messages

---

## 8. Error Handling & Edge Cases

### 8.1 Network Failures
- **Detection**: Ping to 8.8.8.8 with 3-second timeout
- **Response**: Disable deploy button, show red "Network connection required" status
- **Recovery**: Automatic re-enable when network restored (5-second polling)

### 8.2 Installation Failures
- **Detection**: Non-zero exit codes from installers
- **Response**: Mark task as ✗ failed, log error, continue with remaining tasks
- **Special Cases**: Exit code 3010 = success but reboot required

### 8.3 Missing Administrator Privileges
- **Detection**: WindowsIdentity check on Deploy button click
- **Response**: Show MessageBox explaining admin requirement, abort deployment

### 8.4 Winget Not Available
- **Detection**: Get-Command winget check
- **Response**: Attempt automatic installation from aka.ms/getwinget
- **Fallback**: Show error and abort if installation fails

### 8.5 Installer Timeouts
- **Detection**: Process.WaitForExit with 10-minute timeout
- **Response**: Kill process, mark as failed, continue
- **Special Cases**: Audio Architect gets 15 minutes (InstallAware delays)

### 8.6 Duplicate Installations
- **Detection**: Registry check (IsAppInstalledAsync) or Winget list before install
- **Response**: Skip installation, mark as "Already installed" (success)
- **Special Cases**: Version-agnostic checking for Q-SYS apps (major.minor only)

### 8.7 Post-Install Window Cleanup Failures
- **Detection**: Try/catch on CloseAppWindowsAsync
- **Response**: Log warning, continue (non-critical)

### 8.8 Wallpaper Generation Failures
- **Detection**: Try/catch on image generation
- **Response**: Log error, continue without wallpaper (non-critical)

---

## 9. Performance & Scalability

### 9.1 Current Performance Characteristics
- **Typical Deployment Time**: 30-120 minutes (network and app count dependent)
- **Concurrent Operations**: Sequential app installations (one at a time)
- **Background Processes**: Deployment-wide autoclicker, status timer
- **Memory Footprint**: ~50-100 MB (estimated, primarily installer downloads)
- **Network Usage**: Burst downloads (up to 2 GB for full deployment)

### 9.2 Optimization Strategies
- **Parallelization**: Apps could be installed in parallel (requires refactoring)
- **Caching**: Downloaded installers could be cached locally
- **Incremental Updates**: Check existing versions before re-installing
- **Bandwidth Throttling**: None currently (could add for shared networks)

### 9.3 Scalability Constraints
- **Single Machine**: Designed for local deployment only
- **Single User**: No multi-user concurrency
- **Installer Availability**: Dependent on external CDNs and package managers

---

## 10. Security & Compliance

### 10.1 Security Considerations

**Windows**:
- **Elevation**: Requires administrator privileges (UAC prompt)
- **Code Signing**: Recommended for production (not currently implemented)
- **Hash Verification**: Winget hash override disabled after deployment
- **Network Security**: HTTPS for all downloads, Supabase API key embedded
- **Credential Storage**: None (no user credentials handled)

**macOS**:
- **Gatekeeper**: Will require app signing and notarization for distribution
- **Keychain**: Consider using Keychain for API keys (vs hardcoded)
- **SIP**: System Integrity Protection may restrict certain operations
- **TCC**: Transparency, Consent, and Control for Accessibility/Full Disk Access

### 10.2 Privacy Considerations
- **No Telemetry**: No usage data collected or transmitted
- **No PII**: Computer name is local only (used for wallpaper text)
- **Logging**: All logs are local, not transmitted

### 10.3 Compliance
- **Licensing**: Respects application EULAs (automated "I Agree" clicking)
- **Software Provenance**: All software from official sources (vendor sites, Winget, Homebrew)
- **Open Source**: No GPL violations (uses MIT/Apache libraries)

---

## 11. Testing & Quality Assurance

### 11.1 Test Scenarios

**Functional Testing**:
- [ ] All applications install successfully
- [ ] PC Standardization applies all settings
- [ ] Network monitoring enables/disables button correctly
- [ ] Deployment completes without errors
- [ ] Logs capture all installation details
- [ ] Restart prompt appears after completion
- [ ] Already-installed apps are skipped correctly

**Error Handling Testing**:
- [ ] Missing admin privileges shows error
- [ ] Network disconnection during deployment
- [ ] Invalid installer URL handling
- [ ] Corrupted download handling
- [ ] Installer crash recovery
- [ ] Timeout handling for slow installs

**UI/UX Testing**:
- [ ] Tree view expands/collapses correctly
- [ ] Checkboxes toggle properly
- [ ] Status label updates in real-time
- [ ] Deploy button enables/disables correctly
- [ ] Progress bar animates during installation
- [ ] Log scrolls automatically
- [ ] Summary panel updates per-task status

**Integration Testing**:
- [ ] Winget integration works
- [ ] Supabase downloads authenticate properly
- [ ] Wallpaper generates with correct resolution
- [ ] Taskbar/Dock pins correctly
- [ ] Bloatware removal succeeds
- [ ] Auto-clicker handles various installer types

**Performance Testing**:
- [ ] Full deployment completes in reasonable time
- [ ] Memory usage stays under 500 MB
- [ ] Network bandwidth is utilized efficiently
- [ ] Application remains responsive during deployment

### 11.2 Test Environments
- **Windows**: Windows 10 22H2, Windows 11 23H2 (minimum)
- **macOS**: macOS Sonoma 14.x, macOS Sequoia 15.x (recommended)
- **Network**: Gigabit LAN, 100 Mbps WAN, 10 Mbps slow connection
- **Hardware**: Various CPU/RAM configurations (minimum 8 GB RAM)

---

## 12. Deployment & Distribution

### 12.1 Build Process

**Windows**:
```bash
dotnet publish -c Release -r win-x64 --self-contained true \
  -p:PublishSingleFile=true \
  -p:IncludeNativeLibrariesForSelfExtract=true
```
Output: `PCDeploymentToolkit.exe` (~150 MB single file)

**macOS (Proposed)**:
- SwiftUI: Xcode build → .app bundle → .dmg via create-dmg
- Electron: `electron-builder` → .dmg or .pkg

### 12.2 Distribution Methods
- **Internal Network Share**: Copy .exe/.dmg to file server
- **USB Drive**: Bootable USB with deployment tool
- **Cloud Storage**: Download from internal portal
- **No Auto-Update**: Manual distribution of new versions

### 12.3 Version Management
- **Semantic Versioning**: v1.0.0 format (major.minor.patch)
- **Changelog**: Manual documentation in README
- **Backward Compatibility**: Not required (fresh installs only)

---

## 13. Future Enhancements (Roadmap)

### 13.1 Phase 1: macOS Parity (This Document)
- Port all existing Windows features to macOS
- Maintain feature parity between platforms
- Unified UI/UX where possible

### 13.2 Phase 2: Cross-Platform Refinements
- Unified codebase (Electron or Avalonia)
- Shared application catalog with platform detection
- Config file for application definitions (JSON)

### 13.3 Phase 3: Advanced Features
- Remote deployment via SSH/RDP
- Pre-flight system checks (disk space, OS version)
- Post-deployment verification (smoke tests)
- Installation package caching
- Incremental/differential updates

### 13.4 Phase 4: Enterprise Features
- Multi-machine orchestration
- Centralized logging/reporting
- License key management
- User profile migration tools
- Integration with MDM solutions (Jamf, Intune)

---

## 14. Technical Challenges & Considerations

### 14.1 macOS-Specific Challenges

**UI Automation**:
- macOS Accessibility API is more restrictive than Windows UI Automation
- AppleScript is slower and less reliable for modern apps
- May need separate automation strategies per installer type

**Package Management**:
- Homebrew requires Xcode Command Line Tools (automatic prompt)
- Mac App Store apps need `mas-cli` and Apple ID sign-in
- DMG mounting/unmounting is more manual than Windows MSI

**System Permissions**:
- TCC (Transparency, Consent, Control) prompts for many operations
- Full Disk Access may be required for some system modifications
- Gatekeeper will quarantine unsigned apps (need developer certificate)

**Application Differences**:
- Many Windows AV apps don't have macOS equivalents
- Some vendors provide separate Mac versions with different features
- May need to maintain separate application catalogs

### 14.2 Cross-Platform Considerations

**UI Framework**:
- Native (SwiftUI) provides best performance and OS integration
- Electron provides code reuse but larger bundle size
- Avalonia (C#) could reuse Windows codebase but immature macOS support

**Scripting**:
- PowerShell vs Bash/Zsh - fundamentally different approaches
- Windows Registry vs macOS plist/defaults - no direct mapping
- COM automation vs AppleScript - different capabilities

**File Paths**:
- Windows backslashes vs macOS forward slashes
- Drive letters vs unified root filesystem
- Case-insensitive (Windows) vs case-sensitive (macOS APFS)

---

## 15. Success Criteria

### 15.1 MVP (Minimum Viable Product)
- [ ] macOS application launches and displays UI correctly
- [ ] At least 10 core applications install successfully
- [ ] Basic system standardization (wallpaper, dock, theme)
- [ ] Deployment completes without crashes
- [ ] Network monitoring functional
- [ ] Logs capture all operations

### 15.2 Feature Parity
- [ ] All Windows applications have macOS equivalents
- [ ] All system standardization features ported
- [ ] UI matches Windows version (with platform-appropriate styling)
- [ ] Performance within 20% of Windows version
- [ ] Error handling comprehensive

### 15.3 Production Ready
- [ ] Signed and notarized for macOS Gatekeeper
- [ ] Passes all test scenarios
- [ ] Documentation complete (README, USAGE)
- [ ] Deployment time < 2 hours for full install
- [ ] No known critical bugs

---

## 16. Appendix

### 16.1 Key Code Locations (Windows)

**Main Entry Points**:
- `MainForm_Load` (line 88): Application initialization
- `BtnInstall_Click` (line 521): Deployment orchestration
- `DeployAsync` (line 622): Main deployment loop
- `InitializeComponent` (line 102): UI construction

**Installation Methods**:
- `InstallWingetAppAsync` (line 3260): Winget integration
- `InstallCustomAppAsync` (line 1176): Direct downloads
- `InstallDirectDownloadAsync` (line 2859): HTTP downloads
- `InstallExeAsync` (line 3191): EXE installer execution
- `InstallMsiAsync` (line 3151): MSI installer execution
- `ExtractAndInstallZipAsync` (line 3092): ZIP extraction and install

**System Configuration**:
- `ApplyPCStandardizationAsync` (line 1115): Orchestrates all config
- `CreateCustomWallpaperAsync` (line 2218): Wallpaper generation
- `SetLockScreenImageAsync` (line 2024): Lock screen customization
- `ResetUserProfileIconAsync` (line 2083): User icon management
- `ConfigureTaskbarSettingsAsync` (line 1300): Taskbar/widget config
- `PinToTaskbarAsync` (line 1671): Taskbar pinning
- `RemoveBloatwareAsync` (line 1524): AppX package removal

**Automation**:
- `AutoClickDialogsAsync` (line 3363): Deployment-wide UI automation
- `CheckNetworkConnectionAsync` (line 4489): Network monitoring
- `UpdateDeployButtonState` (line 4529): Button enable/disable logic

**Utilities**:
- `RunPowerShellScriptAsync` (line 2390): PowerShell execution wrapper
- `LogMessage` (line 4432): Colored logging
- `UpdateSummaryDisplay` (line 4595): Task list rendering

### 16.2 Configuration Constants

```csharp
// Supabase Storage
const string SUPABASE_URL = "https://incdoepqrbwaagatikgb.supabase.co";
const string SUPABASE_SERVICE_KEY = "eyJh..."; // Truncated

// Windows API
const int SPI_SETDESKWALLPAPER = 0x0014;
const int SPIF_UPDATEINIFILE = 0x01;
const int SPIF_SENDCHANGE = 0x02;

// Timing
const int NETWORK_CHECK_INTERVAL = 5000; // 5 seconds
const int FRIENDLY_MESSAGE_INTERVAL = 8000; // 8 seconds
const int AUTOCLICKER_DELAY = 15000; // 15 seconds for app launch

// Timeouts
const int POWERSHELL_TIMEOUT = 30000; // 30 seconds default
const int INSTALL_TIMEOUT = 600000; // 10 minutes
const int AUDIO_ARCHITECT_TIMEOUT = 900000; // 15 minutes
```

### 16.3 External Dependencies (Windows)

**NuGet Packages**:
- System.Drawing.Common - Image generation
- SixLabors.ImageSharp - WebP support (if used)

**Windows APIs**:
- user32.dll - SystemParametersInfo, EnumWindows
- UIAutomationClient.dll - UI automation
- UIAutomationTypes.dll - Automation patterns

**External Tools**:
- syspin.exe - Taskbar pinning (embedded)
- winget - Windows Package Manager (auto-installed)

**PowerShell Modules**:
- None (uses built-in cmdlets)

### 16.4 macOS Equivalent Dependencies (Proposed)

**Package Managers**:
- Homebrew (brew.sh)
- mas-cli (Mac App Store CLI)

**System Frameworks**:
- Cocoa (Foundation, AppKit)
- System Events (AppleScript)
- Security Framework (authorization)

**External Tools**:
- cliclick or similar (UI automation)
- create-dmg (DMG creation)
- dockutil (Dock manipulation)

### 16.5 Glossary

- **Winget**: Windows Package Manager, official Microsoft package manager for Windows 10+
- **Homebrew**: Popular package manager for macOS
- **SIP**: System Integrity Protection, macOS security feature limiting system modifications
- **TCC**: Transparency, Consent, and Control, macOS privacy permission system
- **UAC**: User Account Control, Windows elevation prompt system
- **Gatekeeper**: macOS security feature that verifies app signatures
- **Notarization**: Apple's malware scanning service for app distribution
- **AppX**: Universal Windows Platform app package format
- **DMG**: Apple Disk Image, macOS installer format
- **PKG**: macOS installer package format
- **Supabase**: Open-source Firebase alternative, used here for file storage/CDN

---

## Document Approval

**Author**: GitHub Copilot (AI Assistant)  
**Reviewer**: [To be assigned]  
**Approver**: [To be assigned]  

**Revision History**:
| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-04 | AI Assistant | Initial document creation |

---

**End of Document**
