# PC Deployment Toolkit - Usage Guide

## Overview
This toolkit automates Windows PC deployments by installing applications and configuring system settings using PowerShell.

## Features
- ✅ **Multiple Installation Methods**: Winget, Chocolatey, and direct downloads
- ✅ **System Configuration**: Registry settings, Windows features, computer name, timezone, power plans
- ✅ **Detailed Logging**: Timestamped logs for troubleshooting
- ✅ **Error Handling**: Graceful failure handling with summary reporting
- ✅ **Modular Design**: Easy to customize via JSON configuration

## Prerequisites
- Windows 10/11 (or Windows Server 2016+)
- PowerShell 5.1 or later
- Administrator privileges
- Internet connection for downloading apps

## Quick Start

### 1. Run the Deployment
```powershell
# Right-click PowerShell and "Run as Administrator"
cd "path\to\PCDeploymentToolkit"
.\Deploy-PC.ps1
```

### 2. Optional Parameters
```powershell
# Use a custom configuration file
.\Deploy-PC.ps1 -ConfigFile "custom-config.json"

# Skip application installation (settings only)
.\Deploy-PC.ps1 -SkipApps

# Skip system settings (apps only)
.\Deploy-PC.ps1 -SkipSettings
```

## Configuration File (config.json)

### Application Installation Methods

#### 1. Winget (Recommended)
Winget is built into Windows 11 and modern Windows 10 installations.

```json
{
  "name": "Google Chrome",
  "method": "winget",
  "id": "Google.Chrome"
}
```

**Finding Winget IDs:**
```powershell
winget search "app name"
```

#### 2. Chocolatey
Requires Chocolatey to be installed first. Install from: https://chocolatey.org/

```json
{
  "name": "Notepad++",
  "method": "chocolatey",
  "package": "notepadplusplus"
}
```

**Finding Chocolatey Packages:**
Visit https://community.chocolatey.org/packages

#### 3. Direct Download
For installers not available via package managers.

```json
{
  "name": "Custom App",
  "method": "download",
  "url": "https://example.com/installer.exe",
  "fileExtension": ".exe",
  "installArgs": "/S /D=C:\\Program Files\\CustomApp"
}
```

### System Settings

#### Computer Settings
```json
"computer": {
  "computerName": "WORKSTATION-01",
  "timezone": "Eastern Standard Time",
  "powerPlan": "High performance"
}
```

**Available Timezones:**
```powershell
Get-TimeZone -ListAvailable
```

**Available Power Plans:**
- "Balanced"
- "High performance"
- "Power saver"

#### Registry Settings
```json
"registry": [
  {
    "path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
    "name": "Hidden",
    "value": 1,
    "type": "DWord",
    "description": "Show hidden files"
  }
]
```

**Registry Value Types:**
- String
- ExpandString
- Binary
- DWord
- MultiString
- QWord

#### Windows Features
```json
"windowsFeatures": [
  "Microsoft-Hyper-V-All",
  "Containers",
  "TelnetClient",
  "TFTP"
]
```

**List Available Features:**
```powershell
Get-WindowsOptionalFeature -Online | Select-Object FeatureName, State
```

## Common Applications (Winget IDs)

| Application | Winget ID |
|------------|-----------|
| Google Chrome | Google.Chrome |
| Mozilla Firefox | Mozilla.Firefox |
| Microsoft Edge | Microsoft.Edge |
| Visual Studio Code | Microsoft.VisualStudioCode |
| 7-Zip | 7zip.7zip |
| VLC Media Player | VideoLAN.VLC |
| Adobe Acrobat Reader | Adobe.Acrobat.Reader.64-bit |
| Zoom | Zoom.Zoom |
| Microsoft Teams | Microsoft.Teams |
| Slack | SlackTechnologies.Slack |
| Git | Git.Git |
| Python | Python.Python.3.11 |
| Node.js | OpenJS.NodeJS |
| Docker Desktop | Docker.DockerDesktop |

## Useful Registry Tweaks

### Windows Explorer
```json
{
  "path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
  "name": "ShowTaskViewButton",
  "value": 0,
  "type": "DWord",
  "description": "Hide Task View button"
}
```

### Disable Windows Update Auto Restart
```json
{
  "path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU",
  "name": "NoAutoRebootWithLoggedOnUsers",
  "value": 1,
  "type": "DWord",
  "description": "Prevent auto restart after updates"
}
```

### Dark Mode
```json
{
  "path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
  "name": "AppsUseLightTheme",
  "value": 0,
  "type": "DWord",
  "description": "Enable dark mode for apps"
}
```

## Troubleshooting

### Script Execution Policy Error
If you get "execution policy" errors:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Winget Not Found
Install App Installer from the Microsoft Store or update Windows.

### Check Logs
All deployments create timestamped log files in the script directory:
```
deployment-20231206-143022.log
```

### Manual Verification
Check installed apps:
```powershell
winget list
```

Check Windows features:
```powershell
Get-WindowsOptionalFeature -Online | Where-Object {$_.State -eq "Enabled"}
```

## Best Practices

1. **Test First**: Run on a test VM before deploying to production
2. **Backup Configuration**: Keep your config.json in version control
3. **Document Changes**: Use the "description" field in registry settings
4. **Review Logs**: Check deployment logs for any failures
5. **Staged Rollout**: Deploy to a small group first
6. **Restart Planning**: Some installations require restarts - plan accordingly

## Advanced Usage

### Create Multiple Configurations
```powershell
# Developer workstation
.\Deploy-PC.ps1 -ConfigFile "config-developer.json"

# Office workstation
.\Deploy-PC.ps1 -ConfigFile "config-office.json"

# Kiosk mode
.\Deploy-PC.ps1 -ConfigFile "config-kiosk.json"
```

### Network Deployment
Copy the toolkit to a network share and run remotely:
```powershell
\\server\share\PCDeploymentToolkit\Deploy-PC.ps1
```

### Schedule Automated Deployment
Use Task Scheduler to run deployment on first login or at specific times.

## Support
For issues or questions, review the log files and verify your configuration against this guide.
