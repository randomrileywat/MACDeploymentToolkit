# PC Deployment Toolkit - Windows GUI

A simple Windows Forms application for deploying software to Windows PCs.

## Features

- ✅ Clean, modern Windows Forms interface
- ✅ Checkbox selection for applications
- ✅ Real-time installation log with color-coded messages
- ✅ Progress indicator
- ✅ Administrator privilege detection
- ✅ Winget integration for reliable installations

## Applications Included

- **Google Chrome** - Popular web browser
- **Advanced IP Scanner** - Network IP scanner tool

## Requirements

- Windows 10 or Windows 11
- .NET 8.0 Runtime
- Winget (App Installer from Microsoft Store)
- Administrator privileges

## Building the Application

### Option 1: Using Visual Studio
1. Open the folder in Visual Studio 2022
2. Build the solution (Ctrl+Shift+B)
3. Run with F5

### Option 2: Using Command Line
```powershell
# Navigate to the project folder
cd "c:\Users\rwatson\One Diversified\Faith & Performance - Engineering\00-Wish List Docs\04-Programming\Riley's Sandbox\Utility\Computer Deployment\PCDeploymentToolkit"

# Build the application
dotnet build

# Run the application
dotnet run
```

### Option 3: Publish as Standalone EXE
```powershell
# Create a single-file executable
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true

# The executable will be in: bin\Release\net8.0-windows\win-x64\publish\PCDeploymentGUI.exe
```

## Running the Application

1. **Right-click** `PCDeploymentGUI.exe` and select **"Run as Administrator"**
   - The app.manifest is configured to request admin privileges automatically
   
2. **Select applications** you want to install using the checkboxes

3. **Click "Install Selected Applications"**

4. **Monitor progress** in the log window

## How It Works

The application uses:
- **Winget** for application installation (built into Windows 10/11)
- **PowerShell** processes to execute Winget commands
- **Async/await** patterns for non-blocking UI
- **Color-coded logging** for easy status tracking

## Troubleshooting

### "Winget is not available"
- Install **App Installer** from the Microsoft Store
- Restart your computer
- Update Windows to the latest version

### "Administrator Required" message
- Right-click the executable and select "Run as Administrator"
- Check User Account Control (UAC) settings

### Application fails to install
- Check your internet connection
- Review the log output for specific error messages
- Try installing manually with: `winget install --id <AppId>`

## Adding More Applications

To add more applications, edit `MainForm.cs`:

1. Add a new checkbox in `InitializeComponent()`:
```csharp
chkMyApp = new CheckBox
{
    Text = "My Application",
    Font = new Font("Segoe UI", 10),
    Location = new Point(40, 155), // Adjust Y position
    Size = new Size(300, 25),
    Checked = true
};
this.Controls.Add(chkMyApp);
```

2. Add installation logic in `InstallApplicationsAsync()`:
```csharp
if (chkMyApp.Checked)
{
    lblStatus.Text = "Installing My Application...";
    bool success = await InstallWingetAppAsync("My Application", "Publisher.AppName");
    if (success) successCount++; else failCount++;
}
```

3. Find Winget app IDs:
```powershell
winget search "application name"
```

## License

This project is provided as-is for internal use.
