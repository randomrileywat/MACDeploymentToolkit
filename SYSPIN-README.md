# Using syspin.exe for Taskbar Pinning

The PC Deployment Toolkit uses `syspin.exe` to pin applications to the Windows 11 taskbar.

## Setup Instructions

### Option 1: Embed as Resource (Recommended - Maintains Single-File Executable)

1. Download syspin.exe from: https://www.technosys.net/products/utils/syspin
   - Direct download: https://www.technosys.net/download.aspx?file=syspin.zip
   - File size: ~13KB
   - Free utility by Technosys

2. Extract `syspin.exe` from the zip file

3. Add to Visual Studio project:
   - Copy `syspin.exe` to the project root directory
   - In Visual Studio Solution Explorer, right-click the project → Add → Existing Item
   - Select `syspin.exe`
   - Right-click `syspin.exe` in Solution Explorer → Properties
   - Set "Build Action" to "Embedded Resource"

4. Rebuild the project - syspin.exe will be embedded in your single executable

### Option 2: Skip Pinning (Works Without syspin.exe)

If you don't add syspin.exe as a resource, the toolkit will:
- Display a message that pinning is skipped
- Continue with all other deployment features normally

## How It Works

When pinning is triggered:
1. The toolkit checks for syspin.exe embedded in its resources
2. If found, extracts it to the Windows temp folder
3. Uses it to pin File Explorer and Google Chrome
4. Cleans up the temp file when done

## Manual Testing (Optional)

You can manually test syspin.exe:
```powershell
# Pin an application
.\syspin.exe "C:\Program Files\Google\Chrome\Application\chrome.exe" "Pin to taskbar"

# Unpin an application
.\syspin.exe "C:\Program Files\Google\Chrome\Application\chrome.exe" "Unpin from taskbar"
```

## Notes

- Embedding as a resource maintains your single-file executable
- The toolkit gracefully handles syspin's absence
- syspin.exe is a third-party utility that works reliably with Windows 11
- Extracted temp file is automatically cleaned up by Windows

