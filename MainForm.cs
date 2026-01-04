using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Net.NetworkInformation;

namespace PCDeploymentGUI;

public partial class MainForm : Form
{
    // Windows API for setting wallpaper
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);

    private const int SPI_SETDESKWALLPAPER = 0x0014;
    private const int SPIF_UPDATEINIFILE = 0x01;
    private const int SPIF_SENDCHANGE = 0x02;

    private TreeView treeApplications = null!;
    private CheckBox chkPCStandardization = null!;
    private TextBox txtComputerName = null!;
    private TextBox txtIconPath = null!;
    private Button btnBrowseIcon = null!;
    private Button btnInstall = null!;
    private RichTextBox txtLog = null!;
    private Label lblLog = null!;
    private ProgressBar progressBar = null!;
    private Label lblStatus = null!;
    private RichTextBox txtSummary = null!;
    private Panel pnlSummary = null!;
    private Label lblSummaryTitle = null!;
    private Label lblTitle = null!;
    private Label lblInstructions = null!;
    private Label lblComputerName = null!;
    private Label lblIconPath = null!;
    private Label separator = null!;
    
    // Network monitoring
    private System.Windows.Forms.Timer? networkCheckTimer;
    private bool isNetworkAvailable = true;
    private bool isDeploying = false;
    
    // Dictionary to track Winget package IDs
    private Dictionary<string, string> wingetPackages = new Dictionary<string, string>();
    
    // Deployment task tracking
    private class DeploymentTask
    {
        public string Name { get; set; } = "";
        public string Status { get; set; } = "⏳"; // ⏳ pending, ✓ success, ✗ failed
        public string Details { get; set; } = "Pending...";
        public Color StatusColor { get; set; } = Color.Gray;
    }
    private List<DeploymentTask> deploymentTasks = new List<DeploymentTask>();
    
    // Deployment-wide autoclicker
    private CancellationTokenSource? autoClickerCancellation;
    private Task? autoClickerTask;
    private Process? autoClickerProcess;
    
    // Friendly status messages
    private System.Windows.Forms.Timer? statusMessageTimer;
    private int currentMessageIndex = 0;
    private readonly string[] friendlyMessages = new[]
    {
        "☕ Great time to grab a coffee!",
        "🚀 Installing your applications...",
        "🛸 Beaming in the last bits of your setup...",
        "🎯 Almost there! Good things take time...",
        "🔧 Optimizing settings and cleaning up bloatware...",
        "🎨 Personalizing your desktop experience...",
        "🌐 Aligning with the universe... or at least Windows.",
        "🤖 Teaching your system some new tricks...",
        "🔍 Checking all the boxes (literally)...",
        "📦 Unpacking your digital goodies...",
        "📡 Negotiating with drivers...",
        "🔧 Tightening a few virtual screws...",
        "📘 Reading the manual so you don't have to..."
    };

    // Supabase configuration
    private const string SUPABASE_URL = "https://incdoepqrbwaagatikgb.supabase.co";
    private const string SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImluY2RvZXBxcmJ3YWFnYXRpa2diIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjkwNzA0OSwiZXhwIjoyMDc4NDgzMDQ5fQ.5qjYJq7OGWAdBIVZqzpRE71aJEEOvbko9m3VDVJuQQA";

    public MainForm()
    {
        InitializeComponent();
        this.Load += MainForm_Load;
    }

    private async void MainForm_Load(object? sender, EventArgs e)
    {
        // Check network connection on startup
        await CheckNetworkConnectionAsync();
        
        // Set up network monitoring timer (check every 5 seconds)
        networkCheckTimer = new System.Windows.Forms.Timer();
        networkCheckTimer.Interval = 5000;
        networkCheckTimer.Tick += async (s, args) => await CheckNetworkConnectionAsync();
        networkCheckTimer.Start();
        
        // Initial deploy button state update
        UpdateDeployButtonState();
    }

    private void InitializeComponent()
    {
        this.Text = "Diversified PC Deployment Toolkit";
        this.ClientSize = new Size(690, 740);
        this.StartPosition = FormStartPosition.CenterScreen;
        this.FormBorderStyle = FormBorderStyle.FixedDialog;
        this.MaximizeBox = false;
        
        // Load the application icon from embedded resources
        try
        {
            var assembly = System.Reflection.Assembly.GetExecutingAssembly();
            var resourceNames = assembly.GetManifestResourceNames();
            var iconResourceName = resourceNames.FirstOrDefault(n => n.EndsWith("DIVIconRGB.ico"));
            
            if (iconResourceName != null)
            {
                var iconStream = assembly.GetManifestResourceStream(iconResourceName);
                if (iconStream != null)
                {
                    this.Icon = new Icon(iconStream);
                }
            }
        }
        catch (Exception ex)
        {
            // Fallback to default icon if loading fails
            System.Diagnostics.Debug.WriteLine($"Icon loading failed: {ex.Message}");
            try { this.Icon = SystemIcons.Application; } catch { }
        }

        // Title Label
        lblTitle = new Label
        {
            Text = "Diversified PC Deployment Toolkit",
            Font = new Font("Segoe UI", 16, FontStyle.Bold),
            Location = new Point(20, 20),
            Size = new Size(400, 35),
            ForeColor = Color.FromArgb(0, 120, 212)
        };
        this.Controls.Add(lblTitle);

        // Instructions
        lblInstructions = new Label
        {
            Text = "Select applications to install:",
            Font = new Font("Segoe UI", 10),
            Location = new Point(20, 65),
            Size = new Size(300, 25),
            AutoSize = false
        };
        this.Controls.Add(lblInstructions);
        
        // Summary Panel (hidden initially)
        pnlSummary = new Panel
        {
            Location = new Point(20, 65),
            Size = new Size(650, 417),
            BorderStyle = BorderStyle.FixedSingle,
            BackColor = Color.White,
            Visible = false
        };
        
        lblSummaryTitle = new Label
        {
            Text = "Deployment Progress",
            Font = new Font("Segoe UI", 14, FontStyle.Bold),
            Location = new Point(10, 10),
            Size = new Size(630, 40),
            ForeColor = Color.FromArgb(0, 120, 212)
        };
        pnlSummary.Controls.Add(lblSummaryTitle);
        
        txtSummary = new RichTextBox
        {
            Location = new Point(10, 55),
            Size = new Size(630, 352),
            ReadOnly = true,
            BorderStyle = BorderStyle.None,
            BackColor = Color.White,
            Font = new Font("Segoe UI", 10)
        };
        pnlSummary.Controls.Add(txtSummary);
        this.Controls.Add(pnlSummary);

        // Application TreeView with categories
        treeApplications = new TreeView
        {
            Location = new Point(35, 95),
            Size = new Size(620, 450),  // Expanded height to fill log area
            CheckBoxes = true,
            Font = new Font("Segoe UI", 9),
            DrawMode = TreeViewDrawMode.OwnerDrawAll,
            ShowPlusMinus = true,
            ShowLines = true
        };
        
        // Custom draw to hide category checkboxes
        treeApplications.DrawNode += (s, e) =>
        {
            if (e.Node == null) return;
            
            // Draw the background
            e.Graphics.FillRectangle(
                e.Node.IsSelected ? SystemBrushes.Highlight : Brushes.White,
                e.Bounds);
            
            // Determine if this is a category node
            bool isCategory = e.Node.Tag?.ToString() == "category";
            
            // Calculate positions
            int indent = e.Node.Level * 20;
            int checkBoxOffset = isCategory ? 0 : 20; // No space for category checkbox
            int textOffset = indent + checkBoxOffset + 3;
            
            // Draw checkbox for child nodes only
            if (!isCategory && e.Node.Parent != null)
            {
                var checkBoxState = e.Node.Checked ? 
                    System.Windows.Forms.VisualStyles.CheckBoxState.CheckedNormal : 
                    System.Windows.Forms.VisualStyles.CheckBoxState.UncheckedNormal;
                    
                System.Windows.Forms.CheckBoxRenderer.DrawCheckBox(
                    e.Graphics,
                    new Point(indent + 2, e.Bounds.Top + 1),
                    checkBoxState);
            }
            
            // Draw expand/collapse icon for categories
            if (isCategory)
            {
                string expandIcon = e.Node.IsExpanded ? "▼" : "▶";
                e.Graphics.DrawString(
                    expandIcon,
                    new Font("Segoe UI", 8),
                    Brushes.Gray,
                    new Point(indent, e.Bounds.Top + 2));
                textOffset += 15;
            }
            
            // Draw text
            var textColor = e.Node.IsSelected ? SystemBrushes.HighlightText : SystemBrushes.ControlText;
            var font = isCategory ? new Font("Segoe UI", 9, FontStyle.Bold) : new Font("Segoe UI", 9);
            e.Graphics.DrawString(
                e.Node.Text,
                font,
                textColor,
                new Point(textOffset, e.Bounds.Top + 1));
        };
        
        // Handle mouse clicks to toggle checkboxes
        treeApplications.NodeMouseClick += (s, e) =>
        {
            if (e.Node == null) return;
            
            bool isCategory = e.Node.Tag?.ToString() == "category";
            int indent = e.Node.Level * 20;
            
            if (!isCategory)
            {
                // Toggle checkbox for child nodes
                // Check if click was on checkbox area (first 20 pixels after indent)
                if (e.X >= indent && e.X <= indent + 20)
                {
                    e.Node.Checked = !e.Node.Checked;
                }
            }
        };
        
        // Update deploy button state when checkbox state changes
        treeApplications.AfterCheck += (s, e) =>
        {
            UpdateDeployButtonState();
        };
        
        // Handle expand/collapse for categories using BeforeCollapse/BeforeExpand
        // to prevent double-toggling issues
        treeApplications.BeforeCollapse += (s, e) =>
        {
            // Allow collapse only for category nodes
            if (e.Node?.Tag?.ToString() != "category")
            {
                e.Cancel = true;
            }
        };
        
        treeApplications.BeforeExpand += (s, e) =>
        {
            // Allow expand only for category nodes
            if (e.Node?.Tag?.ToString() != "category")
            {
                e.Cancel = true;
            }
        };
        
        // Audio Category
        var audioNode = new TreeNode("Audio") { Tag = "category" };
        audioNode.Nodes.Add(new TreeNode("Audio Architect") { Tag = "custom:audioarchitect" });
        audioNode.Nodes.Add(new TreeNode("Dante Controller") { Tag = "custom:dantecontroller" });
        audioNode.Nodes.Add(new TreeNode("Dante Virtual Soundcard") { Tag = "Audinate.DanteVirtualSoundcard" });
        audioNode.Nodes.Add(new TreeNode("Milan Manager") { Tag = "custom:milanmanager" });
        audioNode.Nodes.Add(new TreeNode("Reaper") { Tag = "Cockos.REAPER" });
        audioNode.Nodes.Add(new TreeNode("Shure Update Utility") { Tag = "Shure.UpdateUtility" });
        audioNode.Nodes.Add(new TreeNode("Waves Central") { Tag = "custom:wavescentral" });
        audioNode.Nodes.Add(new TreeNode("Wireless Workbench") { Tag = "Shure.WirelessWorkbench.7" });
        treeApplications.Nodes.Add(audioNode);
        
        // Video Category
        var videoNode = new TreeNode("Video") { Tag = "category" };
        videoNode.Nodes.Add(new TreeNode("Blackmagic ATEM Switchers") { Tag = "custom:blackmagicatem" });
        videoNode.Nodes.Add(new TreeNode("Blackmagic Desktop Video Setup") { Tag = "custom:blackmagicdesktopvideo" });
        videoNode.Nodes.Add(new TreeNode("Blackmagic Videohub Routers") { Tag = "custom:blackmagicvideohub" });
        videoNode.Nodes.Add(new TreeNode("Brompton Tessera Remote") { Tag = "custom:bromptonremote" });
        videoNode.Nodes.Add(new TreeNode("NDI 6 Tools") { Tag = "NDI.NDITools" });
        videoNode.Nodes.Add(new TreeNode("Novastar Coex VMP") { Tag = "custom:novastarcoex" });
        videoNode.Nodes.Add(new TreeNode("Novastar NovaLCT") { Tag = "custom:novastarlct" });
        videoNode.Nodes.Add(new TreeNode("Ross Dashboard") { Tag = "custom:rossdashboard" });
        treeApplications.Nodes.Add(videoNode);
        
        // Lighting Category
        var lightingNode = new TreeNode("Lighting") { Tag = "category" };
        lightingNode.Nodes.Add(new TreeNode("Araneo") { Tag = "custom:araneo" });
        lightingNode.Nodes.Add(new TreeNode("CueServer Studio") { Tag = "custom:cueserver" });
        lightingNode.Nodes.Add(new TreeNode("Luminet Monitor") { Tag = "custom:luminetmonitor" });
        lightingNode.Nodes.Add(new TreeNode("sACN View") { Tag = "custom:sacnview" });
        treeApplications.Nodes.Add(lightingNode);
        
        // Networking Category
        var networkingNode = new TreeNode("Networking") { Tag = "category" };
        networkingNode.Nodes.Add(new TreeNode("Advanced IP Scanner") { Tag = "Famatech.AdvancedIPScanner" });
        networkingNode.Nodes.Add(new TreeNode("Netgear Engage 2.3.1.8") { Tag = "custom:netgearengage" });
        networkingNode.Nodes.Add(new TreeNode("Packet Sender") { Tag = "NagleCode.PacketSender" });
        networkingNode.Nodes.Add(new TreeNode("PTP Track Hound") { Tag = "custom:ptptrackhound" });
        networkingNode.Nodes.Add(new TreeNode("Wireshark") { Tag = "WiresharkFoundation.Wireshark" });
        treeApplications.Nodes.Add(networkingNode);
        
        // Control Category
        var controlNode = new TreeNode("Control") { Tag = "category" };
        controlNode.Nodes.Add(new TreeNode("Q-SYS Designer 10.1.0") { Tag = "custom:qsysdesigner" });
        controlNode.Nodes.Add(new TreeNode("Q-SYS Designer LTS 9.13.1") { Tag = "custom:qsysdesignerlts" });
        controlNode.Nodes.Add(new TreeNode("Q-SYS UCI Viewer 10.1.0") { Tag = "custom:qsysuci" });
        treeApplications.Nodes.Add(controlNode);
        
        // System Category
        var systemNode = new TreeNode("System") { Tag = "category" };
        systemNode.Nodes.Add(new TreeNode("Google Chrome") { Tag = "Google.Chrome" });
        systemNode.Nodes.Add(new TreeNode("Spotify") { Tag = "Spotify.Spotify" });
        treeApplications.Nodes.Add(systemNode);
        
        // Test Content Category
        var testContentNode = new TreeNode("Test Content") { Tag = "category" };
        testContentNode.Nodes.Add(new TreeNode("Audio Test Content") { Tag = "custom:audiotestcontent" });
        testContentNode.Nodes.Add(new TreeNode("Video Test Content") { Tag = "custom:videotestcontent" });
        treeApplications.Nodes.Add(testContentNode);
        
        // Expand all categories by default
        treeApplications.ExpandAll();
        
        this.Controls.Add(treeApplications);

        // PC Standardization Checkbox (now above separator)
        chkPCStandardization = new CheckBox
        {
            Text = "PC Standardization (Taskbar, Theme, Power Settings, Bloatware Removal, Wallpaper)",
            Font = new Font("Segoe UI", 10),
            Location = new Point(40, 555),
            Size = new Size(600, 30),
            Checked = false,
            AutoSize = false
        };
        chkPCStandardization.CheckedChanged += (s, e) => UpdateDeployButtonState();
        this.Controls.Add(chkPCStandardization);

        // Computer Name Input
        lblComputerName = new Label
        {
            Text = "Computer Name (for wallpaper):",
            Font = new Font("Segoe UI", 9),
            Location = new Point(60, 588),
            Size = new Size(250, 20),
            AutoSize = false
        };
        this.Controls.Add(lblComputerName);

        txtComputerName = new TextBox
        {
            Font = new Font("Segoe UI", 10),
            Location = new Point(60, 610),
            Size = new Size(300, 25),
            Text = Environment.MachineName
        };
        this.Controls.Add(txtComputerName);

        // Icon Path Input
        lblIconPath = new Label
        {
            Text = "Custom Icon (optional):",
            Font = new Font("Segoe UI", 9),
            Location = new Point(380, 588),
            Size = new Size(200, 20),
            AutoSize = false
        };
        this.Controls.Add(lblIconPath);

        txtIconPath = new TextBox
        {
            Font = new Font("Segoe UI", 9),
            Location = new Point(380, 610),
            Size = new Size(200, 25),
            PlaceholderText = "Select an image..."
        };
        this.Controls.Add(txtIconPath);

        btnBrowseIcon = new Button
        {
            Text = "Browse",
            Font = new Font("Segoe UI", 9),
            Location = new Point(585, 609),
            Size = new Size(75, 27),
            Cursor = Cursors.Hand
        };
        btnBrowseIcon.Click += BtnBrowseIcon_Click;
        this.Controls.Add(btnBrowseIcon);

        // Separator (now between PC Standardization section and Deploy area)
        separator = new Label
        {
            Text = "",
            BorderStyle = BorderStyle.Fixed3D,
            Location = new Point(20, 660),
            Size = new Size(650, 2)
        };
        this.Controls.Add(separator);

        // Status Label (to the left of deploy button)
        lblStatus = new Label
        {
            Text = "Ready to deploy",
            Font = new Font("Segoe UI", 10),
            Location = new Point(20, 687),
            Size = new Size(480, 25),
            ForeColor = Color.Gray,
            TextAlign = ContentAlignment.MiddleRight
        };
        this.Controls.Add(lblStatus);

        // Deploy Button (rightmost, 160px wide with right edge at 670)
        btnInstall = new Button
        {
            Text = "Deploy",
            Font = new Font("Segoe UI", 11, FontStyle.Bold),
            Location = new Point(510, 677),
            Size = new Size(160, 40),
            BackColor = Color.FromArgb(0, 120, 212),
            ForeColor = Color.White,
            FlatStyle = FlatStyle.Flat,
            Cursor = Cursors.Hand
        };
        btnInstall.FlatAppearance.BorderSize = 0;
        btnInstall.Click += BtnInstall_Click;
        btnInstall.EnabledChanged += (s, e) => UpdateDeployButtonAppearance();
        // Custom paint to maintain white text when disabled
        btnInstall.Paint += (s, e) =>
        {
            if (!btnInstall.Enabled)
            {
                var btn = (Button)s!;
                e.Graphics.Clear(btn.BackColor);
                var textSize = e.Graphics.MeasureString(btn.Text, btn.Font);
                var x = (btn.Width - textSize.Width) / 2;
                var y = (btn.Height - textSize.Height) / 2;
                using var brush = new SolidBrush(Color.White);
                e.Graphics.DrawString(btn.Text, btn.Font, brush, x, y);
            }
        };
        this.Controls.Add(btnInstall);

        // Progress Bar (hidden initially)
        progressBar = new ProgressBar
        {
            Location = new Point(20, 457),
            Size = new Size(650, 25),
            Style = ProgressBarStyle.Continuous,
            Visible = false
        };
        this.Controls.Add(progressBar);

        // Log TextBox (hidden initially)
        lblLog = new Label
        {
            Text = "Deployment Log:",
            Font = new Font("Segoe UI", 10, FontStyle.Bold),
            Location = new Point(20, 492),
            Size = new Size(160, 25),
            Visible = false  // Hidden initially
        };
        this.Controls.Add(lblLog);

        txtLog = new RichTextBox
        {
            Location = new Point(20, 517),
            Size = new Size(650, 203),
            ScrollBars = RichTextBoxScrollBars.Vertical,
            ReadOnly = true,
            Font = new Font("Consolas", 10),
            BackColor = Color.FromArgb(30, 30, 30),
            ForeColor = Color.FromArgb(220, 220, 220),
            Visible = false  // Hidden initially
        };
        this.Controls.Add(txtLog);
    }

    private void BtnBrowseIcon_Click(object? sender, EventArgs e)
    {
        using var openFileDialog = new OpenFileDialog
        {
            Title = "Select Icon Image",
            Filter = "Image Files|*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.gif;*.ico|All Files|*.*",
            FilterIndex = 1
        };

        if (openFileDialog.ShowDialog() == DialogResult.OK)
        {
            txtIconPath.Text = openFileDialog.FileName;
        }
    }

    private async void BtnInstall_Click(object? sender, EventArgs e)
    {
        // Check if running as administrator
        if (!IsAdministrator())
        {
            MessageBox.Show(
                "This application must be run as Administrator to install software.\n\n" +
                "Please right-click the application and select 'Run as Administrator'.",
                "Administrator Required",
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning);
            return;
        }

        // Check if any apps or settings are selected
        bool anyAppSelected = HasCheckedApplications();
        if (!anyAppSelected && !chkPCStandardization.Checked)
        {
            MessageBox.Show(
                "Please select at least one application or configuration option.",
                "No Selection",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information);
            return;
        }

        // Set deploying state and stop network timer
        isDeploying = true;
        networkCheckTimer?.Stop();
        
        // Disable controls during deployment
        btnInstall.Enabled = false;
        btnInstall.Visible = false;
        treeApplications.Enabled = false;
        treeApplications.Visible = false;
        chkPCStandardization.Enabled = false;
        chkPCStandardization.Visible = false;
        txtComputerName.Enabled = false;
        txtComputerName.Visible = false;
        txtIconPath.Enabled = false;
        txtIconPath.Visible = false;
        btnBrowseIcon.Enabled = false;
        btnBrowseIcon.Visible = false;
        lblInstructions.Visible = false;
        lblComputerName.Visible = false;
        lblIconPath.Visible = false;
        separator.Visible = false;
        
        // Show log area
        lblLog.Visible = true;
        txtLog.Visible = true;
        txtLog.Clear();
        
        // Show and configure progress bar
        progressBar.Location = new Point(20, 457);
        progressBar.Visible = true;
        progressBar.Style = ProgressBarStyle.Marquee;
        
        // Move status label to log area and left-align for deployment status
        lblStatus.Location = new Point(170, 492);
        lblStatus.Size = new Size(500, 25);
        lblStatus.TextAlign = ContentAlignment.MiddleLeft;
        
        // Start friendly status messages
        StartFriendlyMessages();
        
        // Show summary panel
        pnlSummary.Visible = true;
        pnlSummary.BringToFront();
        InitializeDeploymentTasks();
        UpdateSummaryDisplay();

        try
        {
            await DeployAsync();
        }
        catch (Exception ex)
        {
            LogMessage($"ERROR: {ex.Message}", Color.Red);
            MessageBox.Show(
                $"An error occurred during deployment:\n\n{ex.Message}",
                "Deployment Error",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
        finally
        {
            // Keep deployment view (don't restore controls)
            progressBar.Visible = false;
            
            // Stop friendly messages and show completion
            StopFriendlyMessages();
            lblStatus.Text = "Deployment complete";
            lblStatus.ForeColor = Color.Green;
        }
    }
    
    private bool HasCheckedApplications()
    {
        foreach (TreeNode categoryNode in treeApplications.Nodes)
        {
            foreach (TreeNode appNode in categoryNode.Nodes)
            {
                if (appNode.Checked)
                    return true;
            }
        }
        return false;
    }

    private async Task DeployAsync()
    {
        var startTime = DateTime.Now;
        LogMessage("=== PC Deployment Started ===", Color.Cyan);
        LogMessage($"Timestamp: {startTime:yyyy-MM-dd HH:mm:ss}", Color.Gray);
        LogMessage("");

        int successCount = 0;
        int failCount = 0;
        int totalOperations = 0;

        // STEP 1: Apply PC Standardization FIRST (includes wallpaper)
        if (chkPCStandardization.Checked)
        {
            totalOperations++;
            UpdateTaskStatus("PC Standardization", "⏳", "In progress...", Color.Orange);
            LogMessage("=== Applying PC Standardization ===", Color.Cyan);
            lblStatus.Text = "Configuring system settings...";
            try
            {
                await ApplyPCStandardizationAsync();
                UpdateTaskStatus("PC Standardization", "✓", "Completed successfully", Color.Green);
            }
            catch (Exception ex)
            {
                UpdateTaskStatus("PC Standardization", "✗", $"Failed: {ex.Message}", Color.Red);
            }
            LogMessage("");
        }

        // STEP 2: Install Applications from TreeView
        var checkedApps = GetCheckedApplications();
        if (checkedApps.Count > 0)
        {
            totalOperations += checkedApps.Count;
            LogMessage("=== Installing Applications ===", Color.Cyan);
            
            // Check if Winget is needed
            var needsWinget = checkedApps.Any(app => !app.Value.StartsWith("custom:"));
            
            if (needsWinget)
            {
                // Check if Winget is available
                LogMessage("Checking for Winget availability...", Color.Yellow);
                bool hasWinget = await CheckWingetAvailableAsync();

                if (!hasWinget)
                {
                    LogMessage("Winget not found. Installing App Installer...", Color.Yellow);
                    bool installed = await InstallWingetAsync();
                    
                    if (!installed)
                    {
                        LogMessage("ERROR: Failed to install Winget.", Color.Red);
                        MessageBox.Show(
                            "Winget (App Installer) is required but could not be installed automatically.\n\n" +
                            "Please install 'App Installer' from the Microsoft Store manually and try again.",
                            "Winget Installation Failed",
                            MessageBoxButtons.OK,
                            MessageBoxIcon.Warning);
                        return;
                    }
                    
                    LogMessage("✓ Winget installed successfully", Color.Green);
                }
                else
                {
                    LogMessage("Winget is available ✓", Color.Green);
                }
                
                // Update winget sources to get latest package information and hashes
                LogMessage("Updating Winget sources...", Color.Yellow);
                await UpdateWingetSourcesAsync();
                
                // Enable InstallerHashOverride setting for packages like Wireless Workbench
                LogMessage("Configuring Winget settings...", Color.Yellow);
                await EnableWingetHashOverrideAsync();
                
                LogMessage("");
            }
            
            // Start deployment-wide autoclicker that will scan for any installer windows
            LogMessage("Starting deployment-wide autoclicker...", Color.Yellow);
            autoClickerCancellation = new CancellationTokenSource();
            autoClickerTask = Task.Run(async () => await AutoClickDialogsAsync("Deployment", autoClickerCancellation.Token));
            LogMessage("✓ Autoclicker is now monitoring for installer windows", Color.Green);
            LogMessage("");
            
            // Install apps in the order they appear in the task list
            foreach (var app in checkedApps)
            {
                UpdateTaskStatus(app.Key, "⏳", "Checking...", Color.Orange);
                lblStatus.Text = $"Checking {app.Key}...";
                
                try
                {
                    bool isCustom = app.Value.StartsWith("custom:");
                    bool isInstalled;
                    
                    // Check if already installed
                    if (isCustom)
                    {
                        string appNameToCheck = app.Key;
                        
                        // For Q-SYS UCI Viewer, strip all version numbers (version independent)
                        if (app.Key.StartsWith("Q-SYS UCI Viewer"))
                        {
                            appNameToCheck = "Q-SYS UCI Viewer";
                            isInstalled = await IsAppInstalledAsync(appNameToCheck);
                        }
                        // For PTP Trackhound, search for partial name (actual installed name is "PTP Track Hound 2 (Solo Mode)")
                        else if (app.Key.StartsWith("PTP Trackhound"))
                        {
                            appNameToCheck = "PTP Track Hound";
                            isInstalled = await IsAppInstalledAsync(appNameToCheck);
                        }
                        // For Luminet Monitor, check by file path since it may not create registry entry
                        else if (app.Key.StartsWith("Luminet Monitor"))
                        {
                            // Check if the executable exists at the known installation path
                            string luminetPath = @"C:\Program Files\Luminex Network Intelligence\LumiNetMonitor_64bit\LuminetMonitorv2.exe";
                            isInstalled = System.IO.File.Exists(luminetPath);
                        }
                        // For sACN View, check by file path (may not register properly)
                        else if (app.Key.StartsWith("sACN View"))
                        {
                            // Check common installation paths
                            string sacnPath1 = @"C:\Program Files\sACNView\sACNView.exe";
                            string sacnPath2 = @"C:\Program Files (x86)\sACNView\sACNView.exe";
                            isInstalled = System.IO.File.Exists(sacnPath1) || System.IO.File.Exists(sacnPath2);
                        }
                        // For Araneo, check by file path (may not register properly)
                        else if (app.Key.StartsWith("Araneo"))
                        {
                            // Check for Start Menu shortcut (most reliable indicator)
                            string araneoShortcut = @"C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Araneo\Araneo.lnk";
                            // Check actual installation path
                            string araneoPath = @"C:\Program Files\Araneo\Araneo\Araneo.exe";
                            // Also check x86 path as fallback
                            string araneoPathX86 = @"C:\Program Files (x86)\Araneo\Araneo\Araneo.exe";
                            
                            isInstalled = System.IO.File.Exists(araneoShortcut) || 
                                         System.IO.File.Exists(araneoPath) || 
                                         System.IO.File.Exists(araneoPathX86);
                        }
                        // For Netgear Engage, check by file path (installs to user directory)
                        else if (app.Key.StartsWith("Netgear Engage"))
                        {
                            // Netgear Engage installs to user's home directory
                            string userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                            string netgearUserPath = Path.Combine(userProfile, @"Netgear\Engage\Engage.exe");
                            
                            // Also check Program Files as fallback
                            string netgearPath1 = @"C:\Program Files\Engage\Engage.exe";
                            string netgearPath2 = @"C:\Program Files (x86)\Engage\Engage.exe";
                            
                            isInstalled = System.IO.File.Exists(netgearUserPath) || 
                                         System.IO.File.Exists(netgearPath1) || 
                                         System.IO.File.Exists(netgearPath2);
                        }
                        // For Novastar Coex VMP, check by registry name (truncate version)
                        else if (app.Key.StartsWith("Novastar Coex VMP"))
                        {
                            appNameToCheck = "Coex VMP";
                            isInstalled = await IsAppInstalledAsync(appNameToCheck);
                        }
                        // For Novastar NovaLCT, check by registry name (truncate version)
                        else if (app.Key.StartsWith("Novastar NovaLCT"))
                        {
                            appNameToCheck = "NovaLCT";
                            isInstalled = await IsAppInstalledAsync(appNameToCheck);
                        }
                        // For Brompton Tessera Remote, check by registry name (truncate version)
                        else if (app.Key.StartsWith("Brompton Tessera Remote"))
                        {
                            appNameToCheck = "Tessera Remote";
                            isInstalled = await IsAppInstalledAsync(appNameToCheck);
                        }
                        // For Audio Architect, check by registry name (truncate version)
                        else if (app.Key.StartsWith("Audio Architect"))
                        {
                            appNameToCheck = "Audio Architect";
                            isInstalled = await IsAppInstalledAsync(appNameToCheck);
                        }
                        // For Milan Manager, check by registry name (truncate version)
                        else if (app.Key.StartsWith("Milan Manager"))
                        {
                            appNameToCheck = "Milan Manager";
                            isInstalled = await IsAppInstalledAsync(appNameToCheck);
                        }
                        // For Ross Dashboard, check by registry name (check for "Dashboard")
                        else if (app.Key.StartsWith("Ross Dashboard"))
                        {
                            appNameToCheck = "Dashboard";
                            LogMessage($"  Checking for: {appNameToCheck}", Color.Gray);
                            isInstalled = await IsAppInstalledAsync(appNameToCheck);
                        }
                        // For Blackmagic Desktop Video, check for "Blackmagic Desktop Video"
                        else if (app.Key.StartsWith("Blackmagic Desktop Video"))
                        {
                            appNameToCheck = "Blackmagic Desktop Video";
                            LogMessage($"  Checking for: {appNameToCheck}", Color.Gray);
                            isInstalled = await IsAppInstalledAsync(appNameToCheck);
                        }
                        // For Blackmagic ATEM Switchers, check for "Blackmagic ATEM Switchers"
                        else if (app.Key.StartsWith("Blackmagic ATEM Switchers"))
                        {
                            appNameToCheck = "Blackmagic ATEM Switchers";
                            LogMessage($"  Checking for: {appNameToCheck}", Color.Gray);
                            isInstalled = await IsAppInstalledAsync(appNameToCheck);
                        }
                        // For Blackmagic Videohub, check for "Blackmagic Videohub"
                        else if (app.Key.StartsWith("Blackmagic Videohub"))
                        {
                            appNameToCheck = "Blackmagic Videohub";
                            LogMessage($"  Checking for: {appNameToCheck}", Color.Gray);
                            isInstalled = await IsAppInstalledAsync(appNameToCheck);
                        }
                        // For other Q-SYS apps, keep major.minor version to allow different branches
                        else if (app.Key.StartsWith("Q-SYS"))
                        {
                            // Strip only the patch version: "10.1.0" -> "10.1"
                            var match = System.Text.RegularExpressions.Regex.Match(app.Key, @"^(.+\s\d+\.\d+)\.\d+$");
                            if (match.Success)
                            {
                                appNameToCheck = match.Groups[1].Value;
                                // For LTS versions, also remove "LTS" label: "Q-SYS Designer LTS 9.13" -> "Q-SYS Designer 9.13"
                                appNameToCheck = appNameToCheck.Replace(" LTS ", " ");
                            }
                            isInstalled = await IsAppInstalledAsync(appNameToCheck);
                        }
                        else
                        {
                            isInstalled = await IsAppInstalledAsync(appNameToCheck);
                        }
                    }
                    else
                    {
                        isInstalled = await IsWingetAppInstalledAsync(app.Value);
                    }
                    
                    if (isInstalled)
                    {
                        successCount++;
                        UpdateTaskStatus(app.Key, "✓", "Already installed", Color.Green);
                        LogMessage($"✓ {app.Key} is already installed", Color.Green);
                        
                        // If Chrome is already installed, still pin it to taskbar
                        if (app.Value == "Google.Chrome")
                        {
                            LogMessage("  Pinning Chrome to taskbar...", Color.Gray);
                            await PinChromeToTaskbarAsync();
                        }
                        
                        continue;
                    }
                    
                    UpdateTaskStatus(app.Key, "⏳", isCustom ? "Downloading..." : "Installing...", Color.Orange);
                    lblStatus.Text = $"Installing {app.Key}...";
                    
                    bool success;
                    if (isCustom)
                    {
                        success = await InstallCustomAppAsync(app.Key, app.Value);
                    }
                    else
                    {
                        success = await InstallWingetAppAsync(app.Key, app.Value);
                    }
                    
                    if (success)
                    {
                        successCount++;
                        UpdateTaskStatus(app.Key, "✓", "Installed successfully", Color.Green);
                        
                        // If Chrome was just installed, set it as default browser
                        if (app.Value == "Google.Chrome")
                        {
                            LogMessage("  Pinning Chrome to taskbar...", Color.Gray);
                            await PinChromeToTaskbarAsync();
                        }
                        
                        // If NDI was just installed, close the popup window
                        if (app.Value == "NDI.NDITools")
                        {
                            await CloseAppWindowsAsync("NDI Tools", 10000, "NDI Launcher", "NDI");
                        }
                        
                        // If Advanced IP Scanner was just installed, close the auto-launched window
                        if (app.Value == "Famatech.AdvancedIPScanner")
                        {
                            await CloseAppWindowsAsync("Advanced IP Scanner", 5000, "advanced_ip_scanner", "ipscan","Advanced IP Scanner");
                        }
                    }
                    else
                    {
                        failCount++;
                        UpdateTaskStatus(app.Key, "✗", isCustom ? "Download or installation failed (check log)" : "Winget installation failed (check log for details)", Color.Red);
                    }
                }
                catch (Exception ex)
                {
                    failCount++;
                    string errorMsg = ex.Message;
                    if (ex.InnerException != null)
                    {
                        errorMsg = ex.InnerException.Message;
                    }
                    UpdateTaskStatus(app.Key, "✗", $"Error: {errorMsg}", Color.Red);
                }
            }
            
            LogMessage("");
        }

        // Calculate deployment time
        var endTime = DateTime.Now;
        var duration = endTime - startTime;
        string durationText;
        if (duration.TotalHours >= 1)
        {
            durationText = $"{(int)duration.TotalHours}h {duration.Minutes}m {duration.Seconds}s";
        }
        else if (duration.TotalMinutes >= 1)
        {
            durationText = $"{(int)duration.TotalMinutes}m {duration.Seconds}s";
        }
        else
        {
            durationText = $"{duration.Seconds}s";
        }

        // Summary
        LogMessage("=== Deployment Summary ===", Color.Cyan);
        LogMessage($"Completed Operations: {totalOperations}", Color.White);
        LogMessage($"Time Taken: {durationText}", Color.White);
        LogMessage("", Color.White);
        if (checkedApps.Count > 0)
        {
            LogMessage($"Applications installed: {successCount}", Color.Green);
            LogMessage($"Applications failed: {failCount}", failCount > 0 ? Color.Red : Color.Gray);
        }
        if (chkPCStandardization.Checked)
        {
            LogMessage("System standardization: Applied", Color.Green);
        }
        LogMessage("");
        
        // Wait for final UAC prompts and window closing tasks to complete
        LogMessage("Waiting for final installations to settle (45 seconds)...", Color.Yellow);
        await Task.Delay(45000); // Allow time for final UAC prompts and window closing (longest is Coex VMP at 30s)
        
        // Stop the deployment-wide autoclicker
        if (autoClickerCancellation != null)
        {
            LogMessage("Stopping autoclicker...", Color.Yellow);
            autoClickerCancellation.Cancel();
            if (autoClickerTask != null)
            {
                try
                {
                    await Task.WhenAny(autoClickerTask, Task.Delay(5000)); // Wait max 5 seconds
                }
                catch
                {
                    // Ignore autoclicker shutdown errors
                }
            }
            autoClickerCancellation.Dispose();
            autoClickerCancellation = null;
            autoClickerTask = null;
            LogMessage("✓ Autoclicker stopped", Color.Green);
        }
        
        // Restore security settings
        await DisableWingetHashOverrideAsync();
        
        LogMessage("");
        LogMessage("Deployment completed!", Color.Cyan);

        lblStatus.Text = checkedApps.Count > 0
            ? $"Complete - {successCount} installed, {failCount} failed" 
            : "Complete - System configured";
        lblStatus.ForeColor = failCount > 0 ? Color.Orange : Color.Green;
        
        // Prompt for restart
        var restartResult = MessageBox.Show(
            "Deployment completed!\n\nSome applications require a restart to complete their installations. Would you like to restart now?",
            "Restart Computer?",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Question);
        
        if (restartResult == DialogResult.Yes)
        {
            LogMessage("Restarting computer...", Color.Yellow);
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo()
            {
                FileName = "shutdown",
                Arguments = "/r /t 10 /c \"PC Deployment completed - restarting in 10 seconds\"",
                CreateNoWindow = true,
                UseShellExecute = false
            });
            
            // Close the application
            Application.Exit();
        }
    }
    
    private Dictionary<string, string> GetCheckedApplications()
    {
        var checkedApps = new Dictionary<string, string>();
        
        foreach (TreeNode categoryNode in treeApplications.Nodes)
        {
            foreach (TreeNode appNode in categoryNode.Nodes)
            {
                if (appNode.Checked && appNode.Tag != null)
                {
                    checkedApps[appNode.Text] = appNode.Tag.ToString()!;
                }
            }
        }
        
        return checkedApps;
    }
    
    private async Task<bool> InstallCustomAppAsync(string appName, string customTag)
    {
        switch (customTag)
        {
            case "custom:dantecontroller":
                return await InstallDirectDownloadAsync(
                    "Dante Controller",
                    "https://audinate-software-updates.sgp1.cdn.digitaloceanspaces.com/DanteController/4/4.16/DanteController-4.16.1.5_windows.exe",
                    "/S"); 
                    
            case "custom:sacnview":
                return await InstallDirectDownloadAsync(
                    "sACN View",
                    "https://github.com/docsteer/sacnview/releases/download/v2.1.3/sACNView_v2.1.3.exe",
                    "/S"); 
                    
            case "custom:luminetmonitor":
                return await InstallDirectDownloadAsync(
                    "Luminet Monitor",
                    "https://www.luminex.be/wp-content/uploads/doccenter/LumiNet-Monitor-2.3.7_WIN.zip",
                    "/S /NCRC");
                    
            case "custom:araneo":
                {
                    bool result = await InstallDirectDownloadAsync(
                        "Araneo",
                        "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/Luminex/AraneoInstaller.exe?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL0x1bWluZXgvQXJhbmVvSW5zdGFsbGVyLmV4ZSIsImlhdCI6MTc2NTIxNjI3MiwiZXhwIjo0ODg3MjgwMjcyfQ.2fZHqm06NukFEblGSXOkHxjUJNym1s9ye8lcUD4wlVw",
                        "/S /NCRC");
                    if (result)
                    {
                        await CloseAppWindowsAsync("Araneo", 15000, "Araneo");
                    }
                    return result;
                }
                    
            case "custom:cueserver":
                return await InstallDirectDownloadAsync(
                    "CueServer Studio",
                    "https://downloads.interactive-online.com/CueServer%20Studio/Software/CueServer%20Studio%20(v5.2.7)%20Win%20(64-bit).exe",
                    "/S"); 
                    
            case "custom:qsysdesigner":
                return await InstallDirectDownloadAsync(
                    "Q-SYS Designer 10.1.0",
                    "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/Q-SYS/Q-SYS%20Designer%20Installer%2010.1.0.exe?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL1EtU1lTL1EtU1lTIERlc2lnbmVyIEluc3RhbGxlciAxMC4xLjAuZXhlIiwiaWF0IjoxNzY1MjE0NTg0LCJleHAiOjQ4ODcyNzg1ODR9.jdRl6PdBQq211vNkg6z_GARF9Ys0KeAcypdJdFgrxL4",
                    "/S"); 
                    
            case "custom:qsysdesignerlts":
                return await InstallDirectDownloadAsync(
                    "Q-SYS Designer LTS 9.13.1",
                    "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/Q-SYS/Q-SYS%20Designer%20Installer%209.13.1.exe?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL1EtU1lTL1EtU1lTIERlc2lnbmVyIEluc3RhbGxlciA5LjEzLjEuZXhlIiwiaWF0IjoxNzY1MjE0NjEwLCJleHAiOjQ4ODcyNzg2MTB9.c2yTmot1Vek29nSUwkkqSO8wZClEwE-EoDASWC0f-EE",
                    "/S"); 
                    
            case "custom:qsysuci":
                return await InstallDirectDownloadAsync(
                    "Q-SYS UCI Viewer 10.1.0",
                    "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/Q-SYS/Q-SYS%20UCI%20Viewer%20Installer%2010.1.0.exe?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL1EtU1lTL1EtU1lTIFVDSSBWaWV3ZXIgSW5zdGFsbGVyIDEwLjEuMC5leGUiLCJpYXQiOjE3NjUyMTQ2MjUsImV4cCI6NDg4NzI3ODYyNX0.XQ3E4_nC-FwYN_GMoM5dy-AzjAjBfOOopqldkrsu7p8",
                    "/S"); 
                    
            case "custom:ptptrackhound":
                return await InstallDirectDownloadAsync(
                    "PTP Track Hound",
                    "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/Utilities/ptptrackhound_2.2.0_setup.exe?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL1V0aWxpdGllcy9wdHB0cmFja2hvdW5kXzIuMi4wX3NldHVwLmV4ZSIsImlhdCI6MTc2NTIxNTEzNiwiZXhwIjo0ODg3Mjc5MTM2fQ.rq75jtpUoH_rERmsQn2AAMosVExhQUXmjNzAFrCYsMQ",
                    "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"); 
                    
            case "custom:netgearengage":
                {
                    bool result = await InstallDirectDownloadAsync(
                        "Netgear Engage 2.3.1.8",
                        "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/Netgear/Netgear-Engage-2.3.1.8.exe?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL05ldGdlYXIvTmV0Z2Vhci1FbmdhZ2UtMi4zLjEuOC5leGUiLCJpYXQiOjE3NjUyMTY3MDgsImV4cCI6NDg4NzI4MDcwOH0.TahMqzI5CTwVQSrCCYRIUGnjTA_3kCzAQcEY1avXcWs",
                        "/S /V/qn"); // Disable autoclicker - installs silently without it
                    if (result)
                    {
                        await CloseAppWindowsAsync("Netgear Engage", 20000, "Engage", "Engage.exe");
                    }
                    return result;
                }
                    
            case "custom:audioarchitect":
                return await InstallDirectDownloadAsync(
                    "Audio Architect",
                    "https://adn.harmanpro.com/softwares/wares/2265_1715615400/AudioArchitect_v2.55.3.zip",
                    "/S");
                    
            case "custom:novastarcoex":
                {
                    bool result = await InstallDirectDownloadAsync(
                        "Novastar Coex VMP",
                        "https://en-website001.oss-us-east-1.aliyuncs.com/Coex%20VMP%20V1.5.0__Windows.zip",
                        "/S");
                    if (result)
                    {
                        await CloseAppWindowsAsync("Coex VMP", 30000, "VNNOX", "VMP");
                    }
                    return result;
                }
                    
            case "custom:novastarlct":
                {
                    bool result = await InstallDirectDownloadAsync(
                        "Novastar NovaLCT",
                        "https://en-website001.oss-us-east-1.aliyuncs.com/NovaLCT%20V5.8.1.zip",
                        "/S");
                    if (result)
                    {
                        await CloseAppWindowsAsync("NovaLCT", 30000, "NovaLCT_Mars", "NovaLCT");
                    }
                    return result;
                }
                    
            case "custom:bromptonremote":
                return await InstallDirectDownloadAsync(
                    "Brompton Tessera Remote",
                    "https://dl.bromptontech.com/tessera/management_app/Tessera_Remote_v3.5.2_installer.exe",
                    "/S"); 
                    
            case "custom:milanmanager":
                return await InstallDirectDownloadAsync(
                    "Milan Manager",
                    "https://milanmanager.com/files/downloads/windows/app/MilanManager-V2.4.1.zip",
                    "/S"); 
                    
            case "custom:blackmagicdesktopvideo":
                return await InstallDirectDownloadAsync(
                    "Blackmagic Desktop Video 15.3",
                    "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/Blackmagic%20Design/Desktop%20Video%20Installer%20v15.3.msi?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL0JsYWNrbWFnaWMgRGVzaWduL0Rlc2t0b3AgVmlkZW8gSW5zdGFsbGVyIHYxNS4zLm1zaSIsImlhdCI6MTc2NTI0NzIzOSwiZXhwIjo0ODg3MzExMjM5fQ.gwYU83yMksaQBbU9-FsvIBt7KpmHad7UJnqnHNVtAW4",
                    "/quiet /norestart");
                    
            case "custom:wavescentral":
                return await InstallDirectDownloadAsync(
                    "Waves Central",
                    "https://cf-installers.waves.com/WavesCentral/Install_Waves_Central.exe",
                    "/S /V\"/qn\"");
                    
            case "custom:blackmagicatem":
                return await InstallDirectDownloadAsync(
                    "Blackmagic ATEM Switchers 10.2",
                    "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/Blackmagic%20Design/Blackmagic_ATEM_Switchers_Windows_10.2.zip?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL0JsYWNrbWFnaWMgRGVzaWduL0JsYWNrbWFnaWNfQVRFTV9Td2l0Y2hlcnNfV2luZG93c18xMC4yLnppcCIsImlhdCI6MTc2NjA3Mzc2NywiZXhwIjo0ODg4MTM3NzY3fQ.QQxiEWwsNMdRw8OrMAxE4RSk9NezqEfulfOUZamchIA",
                    "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART");
                    
            case "custom:blackmagicvideohub":
                return await InstallDirectDownloadAsync(
                    "Blackmagic Videohub 11.0",
                    "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/Blackmagic%20Design/Install%20Videohub%20v11.0.exe?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL0JsYWNrbWFnaWMgRGVzaWduL0luc3RhbGwgVmlkZW9odWIgdjExLjAuZXhlIiwiaWF0IjoxNzY1MjQ3NTM3LCJleHAiOjQ4ODczMTE1Mzd9.Snfr0cUMPNClPrkX9zyMk7VScFibEE9xmTMUL8_HynI",
                    "/S"); 
                    
            case "custom:rossdashboard":
                return await InstallDirectDownloadAsync(
                    "Ross Dashboard 9.15.1",
                    "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/Ross%20Video/DB9.15.1_setup_64.exe?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL1Jvc3MgVmlkZW8vREI5LjE1LjFfc2V0dXBfNjQuZXhlIiwiaWF0IjoxNzY1MjE1OTA5LCJleHAiOjQ4ODcyNzk5MDl9.dq4cfraep6p-D-fiC0B4aL8oyDb75d6SHE2E23vE33Q",
                    "/S"); 
                    
            case "custom:audiotestcontent":
                return await DownloadAndExtractToDesktopAsync(
                    "Audio Test Content",
                    "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/Video%20Test%20Content/Audio%20Test%20Content.zip?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL1ZpZGVvIFRlc3QgQ29udGVudC9BdWRpbyBUZXN0IENvbnRlbnQuemlwIiwiaWF0IjoxNzY3MzI5MDExLCJleHAiOjQ4ODkzOTMwMTF9.nIFHyBTsp5_4RObSkHVMZpK0yxF_GkNiImXmJa3Nyo4");
                    
            case "custom:videotestcontent":
                {
                    // Download and extract the video test content
                    bool contentResult = await DownloadAndExtractToDesktopAsync(
                        "Video Test Content",
                        "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/Video%20Test%20Content/Video%20Test%20Content.zip?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL1ZpZGVvIFRlc3QgQ29udGVudC9WaWRlbyBUZXN0IENvbnRlbnQuemlwIiwiaWF0IjoxNzY3MzI5MDM1LCJleHAiOjQ4ODkzOTMwMzV9.k4fC53e3-adF5rhlPCyl8de4dbINxRj7OWGN9mEZopg");
                    
                    // Also install VLC Player for viewing the content
                    LogMessage("Installing VLC Player for video playback...", Color.Yellow);
                    bool vlcInstalled = await IsWingetAppInstalledAsync("VideoLAN.VLC");
                    if (!vlcInstalled)
                    {
                        await InstallWingetAppAsync("VLC Media Player", "VideoLAN.VLC");
                    }
                    else
                    {
                        LogMessage("  ✓ VLC Media Player is already installed", Color.Green);
                    }
                    
                    return contentResult;
                }
                    
            default:
                LogMessage($"  ✗ {appName}: Unknown custom app type", Color.Red);
                return false;
        }
    }

    private async Task ApplyPCStandardizationAsync()
    {
        // Run quick registry-based operations in parallel batches
        LogMessage("Applying system configuration...", Color.Yellow);
        
        // Batch 1: Custom wallpaper first (most visible change)
        LogMessage("  • Setting custom wallpaper...", Color.Gray);
        await ApplyCustomWallpaperAsync();
        
        LogMessage("  • Setting lock screen image...", Color.Gray);
        await SetLockScreenImageAsync();
        
        LogMessage("  • Resetting user profile icon...", Color.Gray);
        await ResetUserProfileIconAsync();
        
        LogMessage("  • Cleaning up desktop shortcuts...", Color.Gray);
        await CleanupDesktopShortcutsAsync();
        
        // Batch 2: Quick registry settings
        LogMessage("  • Setting dark theme...", Color.Gray);
        await SetDarkThemeAsync();

        // Batch 3: Taskbar operations (do early before other changes)
        LogMessage("  • Unpinning default taskbar icons...", Color.Gray);
        await UnpinTaskbarIconsAsync();
        
        // Configure taskbar settings (this restarts Explorer)
        LogMessage("  • Configuring taskbar settings (hiding widgets, aligning left, etc.)...", Color.Gray);
        await ConfigureTaskbarSettingsAsync();
        
        // Wait for Explorer to fully restart before pinning
        LogMessage("  • Waiting for Explorer to stabilize...", Color.Gray);
        await Task.Delay(5000);
        
        // Pin apps AFTER Explorer restart so they stick
        LogMessage("  • Pinning apps to taskbar...", Color.Gray);
        await PinToTaskbarAsync();

        // Batch 4: File system operations (run sequentially but faster)
        LogMessage("  • Creating desktop folders...", Color.Gray);
        await CreateDIVArchiveFolderAsync();
        
        await DisableStartupAppsAsync();
        await CreateNetworkConnectionsShortcutAsync();

        // Configure power settings before uninstalls
        LogMessage("  • Configuring power settings...", Color.Gray);
        await ConfigurePowerSettingsAsync();

        // Batch 5: App operations (slower, run separately - OneDrive first)
        LogMessage("  • Uninstalling OneDrive...", Color.Gray);
        await UninstallOneDriveAsync();
        
        LogMessage("  • Removing bloatware apps...", Color.Gray);
        await RemoveBloatwareAsync();

        LogMessage("PC Standardization complete ✓", Color.Green);
    }

    private async Task ApplyCustomWallpaperAsync()
    {
        string computerName = txtComputerName.Text.Trim();

        if (string.IsNullOrEmpty(computerName))
        {
            LogMessage("Setting custom wallpaper (no text)...", Color.Yellow);
        }
        else
        {
            LogMessage($"Setting custom wallpaper: {computerName}...", Color.Yellow);
        }
        
        // Check for icon path - if empty, extract embedded default_icon.png
        string iconPath = txtIconPath.Text.Trim();
        if (string.IsNullOrEmpty(iconPath))
        {
            // First try app directory (for development/debug)
            string defaultIconPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "default_icon.png");
            
            if (!File.Exists(defaultIconPath))
            {
                // Extract from embedded resource (for single-file publish)
                try
                {
                    var assembly = System.Reflection.Assembly.GetExecutingAssembly();
                    
                    // Try different possible resource names
                    var possibleNames = new[] 
                    {
                        "PCDeploymentToolkit.default_icon.png",
                        "default_icon.png",
                        "PCDeploymentGUI.default_icon.png"
                    };
                    
                    System.IO.Stream? iconStream = null;
                    string? foundResourceName = null;
                    
                    foreach (var name in possibleNames)
                    {
                        iconStream = assembly.GetManifestResourceStream(name);
                        if (iconStream != null)
                        {
                            foundResourceName = name;
                            break;
                        }
                    }
                    
                    if (iconStream != null && foundResourceName != null)
                    {
                        using (iconStream)
                        {
                            defaultIconPath = Path.Combine(Path.GetTempPath(), "default_icon.png");
                            using (var fileStream = File.Create(defaultIconPath))
                            {
                                iconStream.CopyTo(fileStream);
                            }
                        }
                    }
                    else
                    {
                        defaultIconPath = string.Empty;
                    }
                }
                catch (Exception ex)
                {
                    LogMessage($"  • Could not extract default icon: {ex.Message}", Color.Yellow);
                    defaultIconPath = string.Empty;
                }
            }
            
            if (!string.IsNullOrEmpty(defaultIconPath) && File.Exists(defaultIconPath))
            {
                iconPath = defaultIconPath;
                LogMessage($"  • Using default icon", Color.Gray);
            }
            else
            {
                LogMessage($"  • No custom icon specified, wallpaper will have text only", Color.Gray);
            }
        }
        
        await CreateCustomWallpaperAsync(computerName, iconPath);
    }

    private async Task ConfigureTaskbarSettingsAsync()
    {
        try
        {
            // Combined script for all taskbar-related registry settings
            string script = @"
                # Align taskbar to the left (Windows 11)
                $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                if (-not (Test-Path $regPath)) {
                    New-Item -Path $regPath -Force | Out-Null
                }
                Set-ItemProperty -Path $regPath -Name 'TaskbarAl' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

                # Show search icon, hide task view
                $searchPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
                if (-not (Test-Path $searchPath)) {
                    New-Item -Path $searchPath -Force | Out-Null
                }
                Set-ItemProperty -Path $searchPath -Name 'SearchboxTaskbarMode' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $regPath -Name 'ShowTaskViewButton' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

                # Disable Widgets - permanent removal via uninstalling Web Experience Pack
                Write-Host ""Removing Windows Widgets...""
                
                # Method 1: Uninstall Windows Web Experience Pack (Widgets backend)
                Write-Host ""  Uninstalling Windows Web Experience Pack...""
                try {
                    $webExpPackages = Get-AppxPackage -Name '*WebExperience*' -ErrorAction SilentlyContinue
                    if ($webExpPackages) {
                        foreach ($pkg in $webExpPackages) {
                            Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                            Write-Host ""    Removed: $($pkg.Name)""
                        }
                        Write-Host ""  \u2713 Web Experience Pack uninstalled""
                    } else {
                        Write-Host ""  Web Experience Pack not found (already removed or not installed)""
                    }
                } catch {
                    Write-Host ""  Failed to uninstall Web Experience Pack: $($_.Exception.Message)""
                }
                
                # Method 2: TaskbarMn = Widgets icon (Windows 11) - disable icon if uninstall fails
                Set-ItemProperty -Path $regPath -Name 'TaskbarMn' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Write-Host ""  TaskbarMn = 0""
                
                # Method 3: DisableWidgets policy (fallback)
                $policyPath = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
                if (-not (Test-Path $policyPath)) {
                    New-Item -Path $policyPath -Force | Out-Null
                }
                Set-ItemProperty -Path $policyPath -Name 'DisableWidgets' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Write-Host ""  DisableWidgets policy = 1""
                
                # Method 4: Disable News and Interests
                $newsPath = 'HKCU:\Software\Policies\Microsoft\Dsh'
                if (-not (Test-Path $newsPath)) {
                    New-Item -Path $newsPath -Force | Out-Null
                }
                Set-ItemProperty -Path $newsPath -Name 'AllowNewsAndInterests' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Write-Host ""  AllowNewsAndInterests policy = 0""
                
                Write-Host ""Widget removal complete""

                # Disable notifications
                $notifPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications'
                if (-not (Test-Path $notifPath)) {
                    New-Item -Path $notifPath -Force | Out-Null
                }
                Set-ItemProperty -Path $notifPath -Name 'ToastEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                
                # Prevent Explorer from opening folders on restart
                Set-ItemProperty -Path $regPath -Name 'NoSetFolders' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                
                # Restart Explorer to apply taskbar changes (it will auto-restart)
                Get-Process explorer | Stop-Process -Force
            ";
            
            await RunPowerShellScriptAsync(script, 60000); // 60 second timeout for AppX uninstall + registry ops
        }
        catch (Exception ex)
        {
            LogMessage($"    ✗ Taskbar config error: {ex.Message}", Color.Red);
        }
    }

    private async Task UnpinTaskbarIconsAsync()
    {
        try
        {
            string script = @"
                Write-Host ""=== Unpinning default taskbar icons ===""
                
                # Method 1: Remove pinned shortcuts from taskbar folder
                $appData = [Environment]::GetFolderPath('ApplicationData')
                $taskbarPath = Join-Path $appData 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'
                
                # Remove all existing pinned shortcuts (we'll re-pin what we want later)
                if (Test-Path $taskbarPath) {
                    Write-Host ""Clearing existing taskbar shortcuts...""
                    Get-ChildItem $taskbarPath -Filter '*.lnk' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                    Write-Host ""  Shortcuts cleared""
                }
                
                # Method 2: Clear pinned apps via registry (Windows 11)
                Write-Host ""Clearing registry pinned items...""
                try {
                    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband'
                    Remove-ItemProperty -Path $regPath -Name 'Favorites' -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $regPath -Name 'FavoritesResolve' -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $regPath -Name 'FavoritesChanges' -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $regPath -Name 'FavoritesVersion' -ErrorAction SilentlyContinue
                    Write-Host ""  Registry cleared""
                } catch {
                    Write-Host ""  Registry clear skipped: $_""
                }
                
                # Disable Copilot button
                Write-Host ""Disabling Copilot button...""
                $explorerPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                if (-not (Test-Path $explorerPath)) {
                    New-Item -Path $explorerPath -Force | Out-Null
                }
                Set-ItemProperty -Path $explorerPath -Name 'ShowCopilotButton' -Value 0 -Type DWord -Force
                
                # Disable Task View button
                Write-Host ""Disabling Task View button...""
                Set-ItemProperty -Path $explorerPath -Name 'ShowTaskViewButton' -Value 0 -Type DWord -Force
                
                # Note: We don't restart Explorer here - that will be done after pinning new items
                Write-Host ""Unpinning complete!""
            ";
            
            await RunPowerShellScriptAsync(script, 15000); // 15 second timeout for unpinning
        }
        catch (Exception ex)
        {
            LogMessage($"    ✗ Taskbar configuration error: {ex.Message}", Color.Red);
        }
    }

    private async Task DisableStartupAppsAsync()
    {
        try
        {
            string script = @"
                # Disable common startup apps via registry
                $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
                if (Test-Path $regPath) {
                    $startupApps = @('Teams', 'Skype', 'Spotify', 'Discord', 'OneDrive')
                    $currentEntries = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
                    if ($currentEntries) {
                        $currentEntries.PSObject.Properties | ForEach-Object {
                            $propName = $_.Name
                            foreach ($app in $startupApps) {
                                if ($propName -like '*' + $app + '*') {
                                    Remove-ItemProperty -Path $regPath -Name $propName -ErrorAction SilentlyContinue
                                    break
                                }
                            }
                        }
                    }
                }
            ";
            
            await RunPowerShellScriptAsync(script, 15000); // Increased from 5000 to 15000 to prevent timeout
        }
        catch (Exception ex)
        {
            LogMessage($"    ✗ Disable startup apps error: {ex.Message}", Color.Red);
        }
    }

    private async Task UninstallOneDriveAsync()
    {
        try
        {
            string script = @"
                # Kill OneDrive process
                Write-Host ""Stopping OneDrive processes...""
                Get-Process -Name OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                
                # Verify processes are terminated (retry up to 3 times)
                $retries = 0
                while ((Get-Process -Name OneDrive -ErrorAction SilentlyContinue) -and ($retries -lt 3)) {
                    Write-Host ""  OneDrive still running, waiting...""
                    Start-Sleep -Seconds 2
                    Get-Process -Name OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                    $retries++
                }
                
                Write-Host ""  OneDrive processes terminated""
                Start-Sleep -Seconds 3

                # Uninstall OneDrive - try both locations
                $setup32 = ""$env:SystemRoot\System32\OneDriveSetup.exe""
                $setup64 = ""$env:SystemRoot\SysWOW64\OneDriveSetup.exe""
                
                Write-Host ""Checking for OneDrive setup at: $setup64""
                if (Test-Path $setup64) {
                    Write-Host ""Running OneDrive uninstall from SysWOW64...""
                    Start-Process -FilePath $setup64 -ArgumentList '/uninstall' -NoNewWindow -Wait -ErrorAction SilentlyContinue
                    Write-Host ""  OneDrive uninstall completed""
                }
                elseif (Test-Path $setup32) {
                    Write-Host ""Running OneDrive uninstall from System32...""
                    Start-Process -FilePath $setup32 -ArgumentList '/uninstall' -NoNewWindow -Wait -ErrorAction SilentlyContinue
                    Write-Host ""  OneDrive uninstall completed""
                } else {
                    Write-Host ""OneDrive setup not found (may already be uninstalled)""
                }
                
                # Wait for uninstall to complete
                Start-Sleep -Seconds 3

                # Remove OneDrive from File Explorer sidebar
                New-PSDrive -PSProvider Registry -Root HKEY_CLASSES_ROOT -Name HKCR -ErrorAction SilentlyContinue | Out-Null
                Remove-Item -Path 'HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -Path 'HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' -Recurse -Force -ErrorAction SilentlyContinue
                
                # Remove OneDrive folder from user profile
                $oneDriveFolder = Join-Path $env:USERPROFILE 'OneDrive'
                if (Test-Path $oneDriveFolder) {
                    Remove-Item -Path $oneDriveFolder -Recurse -Force -ErrorAction SilentlyContinue
                }
            ";
            
            await RunPowerShellScriptAsync(script, 60000); // 60 second timeout for OneDrive uninstall
        }
        catch (Exception ex)
        {
            LogMessage($"    ✗ OneDrive uninstall error: {ex.Message}", Color.Red);
        }
    }

    private async Task RemoveBloatwareAsync()
    {
        try
        {
            string script = @"
                # List of bloatware apps to remove
                $bloatware = @(
                    'Microsoft.XboxApp',
                    'Microsoft.Xbox.TCUI',
                    'Microsoft.XboxGamingOverlay',
                    'Microsoft.XboxGameOverlay',
                    'Microsoft.XboxIdentityProvider',
                    'Microsoft.XboxSpeechToTextOverlay',
                    'Microsoft.GamingApp',
                    'Microsoft.GamingServices',
                    'Microsoft.GetHelp',
                    'Microsoft.Getstarted',
                    'Microsoft.MicrosoftSolitaireCollection',
                    'Microsoft.People',
                    'Microsoft.WindowsFeedbackHub',
                    'Microsoft.YourPhone',
                    'Microsoft.MicrosoftOfficeHub',
                    'Microsoft.SkypeApp',
                    'Microsoft.Zune*',
                    'Microsoft.BingWeather',
                    'Microsoft.BingNews',
                    'Microsoft.Windows.Copilot'
                )

                foreach ($app in $bloatware) {
                    try {
                        # Remove for current user
                        Get-AppxPackage -Name $app | Remove-AppxPackage -ErrorAction SilentlyContinue
                        
                        # Remove provisioned package (prevents reinstall for new users)
                        Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $app | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
                    } catch {
                        # Silently continue if app not found
                    }
                }
                
                # Disable Copilot via registry
                try {
                    $regPath = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'
                    if (-not (Test-Path $regPath)) {
                        New-Item -Path $regPath -Force | Out-Null
                    }
                    Set-ItemProperty -Path $regPath -Name 'TurnOffWindowsCopilot' -Value 1 -Type DWord -Force
                } catch {
                    # Silently continue
                }
                
                # Disable Xbox Game Bar
                try {
                    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                } catch {
                    # Silently continue
                }
            ";
            
            await RunPowerShellScriptAsync(script, 120000); // 120 second timeout for app removal
        }
        catch (Exception ex)
        {
            LogMessage($"    ✗ Bloatware removal error: {ex.Message}", Color.Red);
        }
    }

    private async Task PinChromeToTaskbarAsync()
    {
        try
        {
            // Extract syspin.exe from embedded resources to temp location
            string syspinPath = Path.Combine(Path.GetTempPath(), "syspin.exe");
            
            // Check if syspin.exe exists as an embedded resource
            var assembly = System.Reflection.Assembly.GetExecutingAssembly();
            var resourceName = assembly.GetManifestResourceNames()
                .FirstOrDefault(r => r.EndsWith("syspin.exe"));
            
            if (resourceName != null)
            {
                using (var stream = assembly.GetManifestResourceStream(resourceName))
                {
                    if (stream != null)
                    {
                        using (var fileStream = new FileStream(syspinPath, FileMode.Create, FileAccess.Write))
                        {
                            await stream.CopyToAsync(fileStream);
                        }
                    }
                }
            }
            
            string script = $@"
                $syspinPath = ""{syspinPath}""
                
                if (-not (Test-Path $syspinPath)) {{
                    return
                }}
                
                # Find Chrome installation
                $chromePaths = @(
                    ""$env:ProgramFiles\Google\Chrome\Application\chrome.exe"",
                    ""${{env:ProgramFiles(x86)}}\Google\Chrome\Application\chrome.exe"",
                    ""$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe""
                )
                
                foreach ($chromePath in $chromePaths) {{
                    if (Test-Path $chromePath) {{
                        try {{
                            & $syspinPath $chromePath 'Pin to taskbar'
                        }} catch {{
                            # Ignore errors
                        }}
                        break
                    }}
                }}
            ";
            
            await RunPowerShellScriptAsync(script, 15000, showWindow: false);
            LogMessage("    Chrome pinned to taskbar", Color.Green);
        }
        catch (Exception ex)
        {
            LogMessage($"    ✗ Chrome pin error: {ex.Message}", Color.Red);
        }
    }

    private async Task ConfigurePowerSettingsAsync()
    {
        try
        {
            string script = @"
                # Set never sleep when plugged in
                powercfg /change monitor-timeout-ac 0
                powercfg /change standby-timeout-ac 0
                powercfg /change disk-timeout-ac 0
                powercfg /change hibernate-timeout-ac 0
            ";
            
            await RunPowerShellScriptAsync(script, 15000);
        }
        catch (Exception ex)
        {
            LogMessage($"    ✗ Power settings error: {ex.Message}", Color.Red);
        }
    }

    private async Task SetDarkThemeAsync()
    {
        try
        {
            string script = @"
                # Set dark theme for apps and system
                if (-not (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize')) {
                    New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Force | Out-Null
                }
                Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -Value 0 -Type DWord -Force
                Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'SystemUsesLightTheme' -Value 0 -Type DWord -Force
            ";
            
            await RunPowerShellScriptAsync(script, 5000);
        }
        catch (Exception ex)
        {
            LogMessage($"    ✗ Dark theme error: {ex.Message}", Color.Red);
        }
    }

    private async Task PinToTaskbarAsync()
    {
        try
        {
            // Extract syspin.exe from embedded resources to temp location
            string syspinPath = Path.Combine(Path.GetTempPath(), "syspin.exe");
            
            // Check if syspin.exe exists as an embedded resource
            var assembly = System.Reflection.Assembly.GetExecutingAssembly();
            var resourceName = assembly.GetManifestResourceNames()
                .FirstOrDefault(r => r.EndsWith("syspin.exe"));
            
            if (resourceName != null)
            {
                using (var stream = assembly.GetManifestResourceStream(resourceName))
                {
                    if (stream != null)
                    {
                        using (var fileStream = new FileStream(syspinPath, FileMode.Create, FileAccess.Write))
                        {
                            await stream.CopyToAsync(fileStream);
                        }
                    }
                }
            }
            
            string script = $@"
                $syspinPath = ""{syspinPath}""
                
                if (-not (Test-Path $syspinPath)) {{
                    return
                }}
                
                # Pin File Explorer
                $explorerPath = 'C:\Windows\explorer.exe'
                try {{
                    & $syspinPath $explorerPath 'Pin to taskbar'
                }} catch {{
                    # Ignore errors
                }}
                
                # Pin Google Chrome (if installed)
                $chromePaths = @(
                    ""$env:ProgramFiles\Google\Chrome\Application\chrome.exe"",
                    ""${{env:ProgramFiles(x86)}}\Google\Chrome\Application\chrome.exe"",
                    ""$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe""
                )
                
                foreach ($chromePath in $chromePaths) {{
                    if (Test-Path $chromePath) {{
                        try {{
                            & $syspinPath $chromePath 'Pin to taskbar'
                        }} catch {{
                            # Ignore errors
                        }}
                        break
                    }}
                }}
            ";
            
            await RunPowerShellScriptAsync(script, 15000, showWindow: false);
        }
        catch (Exception ex)
        {
            LogMessage($"    ✗ Pin to taskbar error: {ex.Message}", Color.Red);
        }
    }

    private async Task CreateDIVArchiveFolderAsync()
    {
        try
        {
            string desktopPath = Environment.GetFolderPath(Environment.SpecialFolder.Desktop);
            string divArchivePath = Path.Combine(desktopPath, "DIV Archive");
            
            // Create the folder if it doesn't exist
            if (!Directory.Exists(divArchivePath))
            {
                Directory.CreateDirectory(divArchivePath);
            }
            else
            {
                LogMessage("    DIV Archive folder already exists", Color.Gray);
            }
            
            await Task.CompletedTask; // Keep async signature consistent
        }
        catch (Exception ex)
        {
            LogMessage($"    ✗ DIV Archive folder error: {ex.Message}", Color.Red);
        }
    }

    private async Task CreateNetworkConnectionsShortcutAsync()
    {
        try
        {
            string script = @"
                # Create a shortcut to Network Connections on the desktop
                $WshShell = New-Object -ComObject WScript.Shell
                $desktopPath = [Environment]::GetFolderPath('Desktop')
                $shortcutPath = Join-Path $desktopPath 'Network Connections.lnk'
                
                $Shortcut = $WshShell.CreateShortcut($shortcutPath)
                $Shortcut.TargetPath = 'C:\Windows\System32\control.exe'
                $Shortcut.Arguments = 'ncpa.cpl'
                $Shortcut.Description = 'View Network Connections'
                $Shortcut.IconLocation = 'C:\Windows\System32\ncpa.cpl,0'
                $Shortcut.Save()
                
                Write-Output 'Network Connections shortcut created'
            ";
            
            await RunPowerShellScriptAsync(script, 10000);
        }
        catch (Exception ex)
        {
            LogMessage($"    ✗ Network shortcut error: {ex.Message}", Color.Red);
        }
    }

    private async Task CreateCustomWallpaperAsync(string computerName, string? iconPath)
    {
        try
        {
            // Create wallpaper image in C# - use Pictures folder for persistence (not temp)
            string picturesPath = Environment.GetFolderPath(Environment.SpecialFolder.MyPictures);
            string wallpaperPath = Path.Combine(picturesPath, "custom_wallpaper.png");
            
            await Task.Run(() =>
            {
                // Get screen resolution
                int width = Screen.PrimaryScreen?.Bounds.Width ?? 1920;
                int height = Screen.PrimaryScreen?.Bounds.Height ?? 1080;

                using var bitmap = new Bitmap(width, height);
                using var graphics = Graphics.FromImage(bitmap);
                
                // Set black background
                graphics.Clear(Color.Black);
                
                // Configure rendering
                graphics.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAlias;
                graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
                
                // Setup positioning variables
                float padding = width * 0.02f; // 2% padding
                float taskbarMargin = 80f; // Extra margin to account for taskbar
                float iconExtraPadding = 20f; // Extra padding for icon to account for built-in transparency
                
                // Only calculate text measurements if computer name is provided
                SizeF textSize = SizeF.Empty;
                Font? font = null;
                float textX = padding;
                
                if (!string.IsNullOrEmpty(computerName))
                {
                    // Calculate font size for bottom corner (larger and more visible)
                    float fontSize = width / 20f; // Increased from 35f to 20f for larger text
                    font = new Font("Segoe UI", fontSize, FontStyle.Bold);
                    
                    // Measure text size
                    textSize = graphics.MeasureString(computerName, font);
                }
                
                // Draw custom icon in bottom-right corner if provided (need to calculate icon position first)
                int iconHeight = 0;
                if (!string.IsNullOrEmpty(iconPath) && File.Exists(iconPath))
                {
                    try
                    {
                        using var iconImage = LoadImageFromFile(iconPath);
                        
                        // Calculate icon size (proportional to screen, max 15% of height)
                        int maxIconHeight = (int)(height * 0.15f);
                        float iconScale = Math.Min(1.0f, (float)maxIconHeight / iconImage.Height);
                        int iconWidth = (int)(iconImage.Width * iconScale);
                        iconHeight = (int)(iconImage.Height * iconScale);
                        
                        // Position in bottom-right corner with extra padding to compensate for transparent space in icon
                        float iconX = width - iconWidth - padding - iconExtraPadding;
                        float iconY = height - iconHeight - padding - taskbarMargin;
                        
                        // Draw the icon with high quality
                        graphics.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                        graphics.DrawImage(iconImage, iconX, iconY, iconWidth, iconHeight);
                    }
                    catch
                    {
                        // If icon fails to load, continue without it
                        iconHeight = 0;
                    }
                }
                
                // Draw text only if computer name is provided
                if (!string.IsNullOrEmpty(computerName) && font != null)
                {
                    // Center text vertically with icon
                    float textY;
                    if (iconHeight > 0)
                    {
                        // Center text with icon
                        float iconCenterY = height - (iconHeight /  2f) - padding - taskbarMargin;
                        textY = iconCenterY - (textSize.Height / 2f);
                    }
                    else
                    {
                        // No icon, just use taskbar margin
                        textY = height - textSize.Height - padding - taskbarMargin;
                    }
                    
                    // Draw text in white
                    using var brush = new SolidBrush(Color.White);
                    graphics.DrawString(computerName, font, brush, textX, textY);
                    
                    // Dispose font
                    font.Dispose();
                }
                
                // Save the image
                bitmap.Save(wallpaperPath, System.Drawing.Imaging.ImageFormat.Png);
            });

            LogMessage($"    • Wallpaper image created: {wallpaperPath}", Color.Gray);

            // Set wallpaper using Windows API directly (more reliable than PowerShell)
            try
            {
                // Set registry values for persistence
                Microsoft.Win32.Registry.SetValue(
                    @"HKEY_CURRENT_USER\Control Panel\Desktop",
                    "Wallpaper",
                    wallpaperPath);
                
                Microsoft.Win32.Registry.SetValue(
                    @"HKEY_CURRENT_USER\Control Panel\Desktop",
                    "WallpaperStyle",
                    "10", // Fill
                    Microsoft.Win32.RegistryValueKind.String);
                
                Microsoft.Win32.Registry.SetValue(
                    @"HKEY_CURRENT_USER\Control Panel\Desktop",
                    "TileWallpaper",
                    "0",
                    Microsoft.Win32.RegistryValueKind.String);

                // Apply wallpaper immediately using Windows API
                SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, wallpaperPath, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
                
                LogMessage($"    ✓ Wallpaper set: {computerName}", Color.Green);
            }
            catch (Exception ex)
            {
                LogMessage($"    ✗ Failed to apply wallpaper: {ex.Message}", Color.Red);
            }
        }
        catch (Exception ex)
        {
            LogMessage($"    ✗ Wallpaper error: {ex.Message}", Color.Red);
        }
    }

    private async Task SetLockScreenImageAsync()
    {
        try
        {
            // Use the same custom wallpaper for lock screen
            string picturesPath = Environment.GetFolderPath(Environment.SpecialFolder.MyPictures);
            string wallpaperPath = Path.Combine(picturesPath, "custom_wallpaper.png");
            
            if (!File.Exists(wallpaperPath))
            {
                LogMessage($"    ⚠ Lock screen not set: custom_wallpaper.png not found", Color.Yellow);
                return;
            }

            // Copy to Windows lock screen location
            string lockScreenPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                @"Microsoft\Windows\SystemData\LockScreen.jpg");
            
            string lockScreenDir = Path.GetDirectoryName(lockScreenPath)!;
            if (!Directory.Exists(lockScreenDir))
            {
                Directory.CreateDirectory(lockScreenDir);
            }

            // Copy the wallpaper as the lock screen image
            File.Copy(wallpaperPath, lockScreenPath, true);

            // Set registry keys to apply the lock screen image
            string escapedLockScreenPath = lockScreenPath.Replace("\\", "\\\\");
            string script = $@"
                # Set personalization lock screen image registry keys
                $personalizationPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen'
                if (-not (Test-Path $personalizationPath)) {{
                    New-Item -Path $personalizationPath -Force | Out-Null
                }}
                
                # Set lock screen image path
                Set-ItemProperty -Path $personalizationPath -Name 'BackgroundImagePath' -Value '{escapedLockScreenPath}' -Force
                
                # Disable Windows Spotlight on lock screen
                $contentDeliveryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
                if (-not (Test-Path $contentDeliveryPath)) {{
                    New-Item -Path $contentDeliveryPath -Force | Out-Null
                }}
                Set-ItemProperty -Path $contentDeliveryPath -Name 'RotatingLockScreenEnabled' -Value 0 -Type DWord -Force
                Set-ItemProperty -Path $contentDeliveryPath -Name 'RotatingLockScreenOverlayEnabled' -Value 0 -Type DWord -Force
                
                Write-Host 'Lock screen image configured'
            ";

            await RunPowerShellScriptAsync(script, 5000, showWindow: false);
            LogMessage($"    ✓ Lock screen image set", Color.Green);
        }
        catch (Exception ex)
        {
            LogMessage($"    ⚠ Could not set lock screen: {ex.Message}", Color.Yellow);
        }
    }

    private async Task ResetUserProfileIconAsync()
    {
        try
        {
            // Check if custom icon exists
            string iconPath = txtIconPath.Text.Trim();
            string targetIconPath = "";
            
            if (!string.IsNullOrEmpty(iconPath) && File.Exists(iconPath))
            {
                // Use custom icon specified by user
                string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                targetIconPath = Path.Combine(localAppData, @"Microsoft\Windows\AccountPictures", "user_icon.png");
                
                string accountPicturesDir = Path.GetDirectoryName(targetIconPath)!;
                if (!Directory.Exists(accountPicturesDir))
                {
                    Directory.CreateDirectory(accountPicturesDir);
                }
                
                File.Copy(iconPath, targetIconPath, true);
                LogMessage($"    • Using custom user icon", Color.Gray);
            }
            else
            {
                // Check for default embedded icon
                string defaultIconPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "default_icon.png");
                
                if (!File.Exists(defaultIconPath))
                {
                    // Try extracting from embedded resource
                    var assembly = System.Reflection.Assembly.GetExecutingAssembly();
                    var possibleNames = new[] 
                    {
                        "PCDeploymentToolkit.default_icon.png",
                        "default_icon.png",
                        "PCDeploymentGUI.default_icon.png"
                    };
                    
                    System.IO.Stream? iconStream = null;
                    foreach (var name in possibleNames)
                    {
                        iconStream = assembly.GetManifestResourceStream(name);
                        if (iconStream != null) break;
                    }
                    
                    if (iconStream != null)
                    {
                        using (iconStream)
                        {
                            defaultIconPath = Path.Combine(Path.GetTempPath(), "default_icon.png");
                            using (var fileStream = File.Create(defaultIconPath))
                            {
                                iconStream.CopyTo(fileStream);
                            }
                        }
                    }
                }
                
                if (File.Exists(defaultIconPath))
                {
                    string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                    targetIconPath = Path.Combine(localAppData, @"Microsoft\Windows\AccountPictures", "user_icon.png");
                    
                    string accountPicturesDir = Path.GetDirectoryName(targetIconPath)!;
                    if (!Directory.Exists(accountPicturesDir))
                    {
                        Directory.CreateDirectory(accountPicturesDir);
                    }
                    
                    File.Copy(defaultIconPath, targetIconPath, true);
                    LogMessage($"    • Using default user icon", Color.Gray);
                }
                else
                {
                    // Reset to system default by removing custom picture
                    LogMessage($"    • Resetting to Windows default user icon", Color.Gray);
                    targetIconPath = ""; // Will trigger registry cleanup below
                }
            }

            // Set or clear user profile icon via registry
            string escapedIconPath = targetIconPath.Replace("\\", "\\\\");
            string script = $@"
                $userName = $env:USERNAME
                $userSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
                
                # Set registry path for user account picture
                $regPath = ""HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\$userSid""
                
                if ('{escapedIconPath}' -ne '') {{
                    # Set custom icon
                    if (-not (Test-Path $regPath)) {{
                        New-Item -Path $regPath -Force | Out-Null
                    }}
                    Set-ItemProperty -Path $regPath -Name 'Image448' -Value '{escapedIconPath}' -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $regPath -Name 'Image240' -Value '{escapedIconPath}' -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $regPath -Name 'Image96' -Value '{escapedIconPath}' -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $regPath -Name 'Image32' -Value '{escapedIconPath}' -Force -ErrorAction SilentlyContinue
                    Write-Host 'User profile icon set to custom image'
                }} else {{
                    # Reset to default by removing registry entries
                    if (Test-Path $regPath) {{
                        Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Host 'User profile icon reset to Windows default'
                    }} else {{
                        Write-Host 'User profile icon already at default'
                    }}
                }}
            ";

            await RunPowerShellScriptAsync(script, 5000, showWindow: false);
            LogMessage($"    ✓ User profile icon configured", Color.Green);
        }
        catch (Exception ex)
        {
            LogMessage($"    ⚠ Could not set user icon: {ex.Message}", Color.Yellow);
        }
    }

    private async Task CleanupDesktopShortcutsAsync()
    {
        try
        {
            string script = @"
                # Get all desktop paths (current user and public)
                $desktopPaths = @(
                    [Environment]::GetFolderPath('Desktop'),
                    'C:\Users\Public\Desktop'
                )
                
                foreach ($desktop in $desktopPaths) {
                    if (Test-Path $desktop) {
                        # Remove Microsoft Edge shortcut
                        $edgeShortcuts = Get-ChildItem -Path $desktop -Filter '*Edge*.lnk' -ErrorAction SilentlyContinue
                        foreach ($shortcut in $edgeShortcuts) {
                            Remove-Item -Path $shortcut.FullName -Force -ErrorAction SilentlyContinue
                            Write-Host ""Removed: $($shortcut.Name)""
                        }
                    }
                }
                Write-Host ""Desktop cleanup complete""
            ";
            
            await RunPowerShellScriptAsync(script, 10000);
        }
        catch (Exception ex)
        {
            LogMessage($"    ✗ Desktop cleanup error: {ex.Message}", Color.Red);
        }
    }

    private static Image LoadImageFromFile(string filePath)
    {
        string extension = Path.GetExtension(filePath).ToLowerInvariant();
        
        // For WebP files, we need special handling
        if (extension == ".webp")
        {
            // Convert WebP to Bitmap using ImageSharp
            try
            {
                using var fileStream = File.OpenRead(filePath);
                using var image = SixLabors.ImageSharp.Image.Load(fileStream);
                
                // Convert to System.Drawing.Bitmap via PNG encoding
                var memoryStream = new MemoryStream();
                image.Save(memoryStream, new SixLabors.ImageSharp.Formats.Png.PngEncoder());
                memoryStream.Position = 0;
                return Image.FromStream(memoryStream);
            }
            catch
            {
                // Fallback to standard loading if ImageSharp fails
                return Image.FromFile(filePath);
            }
        }
        
        // For other formats (PNG, JPG, BMP, GIF, ICO), use standard .NET loading
        return Image.FromFile(filePath);
    }

    private async Task RunPowerShellScriptAsync(string script, int timeoutMs = 30000, bool showWindow = false)
    {
        string? tempScriptPath = null;
        
        try
        {
            // For visible windows or when we need elevation, use a temp file
            bool needsElevation = script.Contains("Get-Process") || script.Contains("UIAutomation"); // Auto-click scripts need elevation
            bool needsCallOperator = script.Contains("& $"); // Call operator syntax requires temp file execution
            bool useTempFile = showWindow || needsElevation || needsCallOperator;
            
            if (useTempFile)
            {
                tempScriptPath = Path.Combine(Path.GetTempPath(), $"deploy_script_{Guid.NewGuid()}.ps1");
                File.WriteAllText(tempScriptPath, script);
            }
            
            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = useTempFile
                        ? $"-NoProfile -ExecutionPolicy Bypass -File \"{tempScriptPath}\""
                        : $"-NoProfile -ExecutionPolicy Bypass -Command \"{script.Replace("\"", "`\"")}\"",
                    UseShellExecute = useTempFile, // Must use shell execute for elevation
                    RedirectStandardOutput = !useTempFile,
                    RedirectStandardError = !useTempFile,
                    CreateNoWindow = !showWindow,
                    WindowStyle = showWindow ? ProcessWindowStyle.Normal : ProcessWindowStyle.Hidden,
                    Verb = needsElevation ? "runas" : "" // Elevate for auto-click to see elevated installer windows
                }
            };

            process.Start();
            
            // Add timeout to prevent hanging
            var completedInTime = await Task.Run(() => process.WaitForExit(timeoutMs));
            
            if (!completedInTime)
            {
                process.Kill();
                throw new Exception($"PowerShell script timed out after {timeoutMs / 1000} seconds");
            }

            if (process.ExitCode != 0)
            {
                // Only read StandardError if it was redirected (not using shell execute)
                if (!useTempFile && process.StartInfo.RedirectStandardError)
                {
                    string error = await process.StandardError.ReadToEndAsync();
                    if (!string.IsNullOrWhiteSpace(error))
                    {
                        throw new Exception(error);
                    }
                }
            }
        }
        finally
        {
            // Clean up temp script file
            if (tempScriptPath != null && File.Exists(tempScriptPath))
            {
                try { File.Delete(tempScriptPath); } catch { }
            }
        }
    }

    private async Task EnableWingetHashOverrideAsync()
    {
        try
        {
            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -Command \"winget settings --enable InstallerHashOverride\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true,
                    Verb = "runas"
                }
            };

            process.Start();
            await process.WaitForExitAsync();

            if (process.ExitCode == 0)
            {
                LogMessage("  ✓ Winget hash override enabled", Color.Green);
            }
        }
        catch (Exception ex)
        {
            LogMessage($"  ⚠ Could not enable hash override: {ex.Message}", Color.Yellow);
        }
    }

    private async Task UpdateWingetSourcesAsync()
    {
        try
        {
            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -Command \"winget source update\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                }
            };

            process.Start();
            
            // Read output streams to prevent blocking
            var outputTask = process.StandardOutput.ReadToEndAsync();
            var errorTask = process.StandardError.ReadToEndAsync();
            
            // Wait for process with timeout (30 seconds)
            var timeoutTask = Task.Delay(30000);
            var exitTask = process.WaitForExitAsync();
            
            var completedTask = await Task.WhenAny(exitTask, timeoutTask);
            
            if (completedTask == timeoutTask)
            {
                process.Kill();
                LogMessage("  ⚠ Winget source update timed out (continuing anyway)", Color.Yellow);
                return;
            }

            // Ensure output is fully read
            await outputTask;
            await errorTask;

            if (process.ExitCode == 0)
            {
                LogMessage("  ✓ Winget sources updated", Color.Green);
            }
            else
            {
                LogMessage("  ⚠ Winget source update had issues (continuing anyway)", Color.Yellow);
            }
        }
        catch (Exception ex)
        {
            LogMessage($"  ⚠ Could not update winget sources: {ex.Message}", Color.Yellow);
        }
    }

    private async Task DisableWingetHashOverrideAsync()
    {
        try
        {
            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -Command \"winget settings --disable InstallerHashOverride\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true,
                    Verb = "runas"
                }
            };

            process.Start();
            await process.WaitForExitAsync();

            if (process.ExitCode == 0)
            {
                LogMessage("  ✓ Winget hash override disabled (security restored)", Color.Green);
            }
        }
        catch (Exception ex)
        {
            LogMessage($"  ⚠ Could not disable hash override: {ex.Message}", Color.Yellow);
        }
    }

    private async Task<bool> CheckWingetAvailableAsync()
    {
        try
        {
            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -Command \"Get-Command winget -ErrorAction Stop\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                }
            };

            process.Start();
            string output = await process.StandardOutput.ReadToEndAsync();
            await process.WaitForExitAsync();

            return process.ExitCode == 0 && !string.IsNullOrEmpty(output);
        }
        catch
        {
            return false;
        }
    }

    private async Task<bool> InstallWingetAsync()
    {
        try
        {
            LogMessage("  Downloading App Installer (winget)...", Color.Yellow);
            
            // Download the latest App Installer from Microsoft
            string appInstallerUrl = "https://aka.ms/getwinget";
            string tempFile = Path.Combine(Path.GetTempPath(), "Microsoft.DesktopAppInstaller.msixbundle");
            
            using (var httpClient = new HttpClient())
            {
                httpClient.Timeout = TimeSpan.FromMinutes(5);
                var response = await httpClient.GetAsync(appInstallerUrl);
                response.EnsureSuccessStatusCode();
                
                var content = await response.Content.ReadAsByteArrayAsync();
                await File.WriteAllBytesAsync(tempFile, content);
            }
            
            LogMessage("  Installing App Installer...", Color.Yellow);
            
            // Install using PowerShell Add-AppxPackage
            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = $"-NoProfile -ExecutionPolicy Bypass -Command \"Add-AppxPackage -Path '{tempFile}'\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true,
                    Verb = "runas" // Run as administrator
                }
            };
            
            process.Start();
            await process.WaitForExitAsync();
            
            // Clean up
            try { File.Delete(tempFile); } catch { }
            
            if (process.ExitCode == 0)
            {
                // Wait a moment for winget to become available
                await Task.Delay(2000);
                return await CheckWingetAvailableAsync();
            }
            
            return false;
        }
        catch (Exception ex)
        {
            LogMessage($"  Error installing winget: {ex.Message}", Color.Red);
            return false;
        }
    }

    private async Task<bool> IsWingetAppInstalledAsync(string wingetId)
    {
        try
        {
            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = $"-NoProfile -Command \"winget list --id {wingetId} --exact --accept-source-agreements 2>&1\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                }
            };

            process.Start();
            string output = await process.StandardOutput.ReadToEndAsync();
            string error = await process.StandardError.ReadToEndAsync();
            await process.WaitForExitAsync();

            // If the app is installed, output will contain the app ID
            // Also check if winget returned "No installed package found" or similar messages
            bool hasAppId = output.Contains(wingetId, StringComparison.OrdinalIgnoreCase);
            bool notFoundMessage = output.Contains("No installed package found", StringComparison.OrdinalIgnoreCase) || 
                                   output.Contains("No package found", StringComparison.OrdinalIgnoreCase);
            
            return hasAppId && !notFoundMessage && process.ExitCode == 0;
        }
        catch
        {
            return false;
        }
    }

    private async Task<bool> IsAppInstalledAsync(string appName)
    {
        return await Task.Run(() =>
        {
            try
            {
                // Check both 64-bit and 32-bit registry paths
                string[] registryPaths = new[]
                {
                    @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                    @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
                };

                foreach (var path in registryPaths)
                {
                    using var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(path);
                    if (key != null)
                    {
                        foreach (var subkeyName in key.GetSubKeyNames())
                        {
                            using var subkey = key.OpenSubKey(subkeyName);
                            var displayName = subkey?.GetValue("DisplayName")?.ToString();
                            
                            if (!string.IsNullOrEmpty(displayName) && 
                                displayName.IndexOf(appName, StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                return true;
                            }
                        }
                    }
                }
                
                return false;
            }
            catch
            {
                return false;
            }
        });
    }

    private async Task<bool> InstallWingetAppAsync(string appName, string wingetId)
    {
        LogMessage($"Installing {appName}...", Color.Yellow);

        try
        {
            Process process;
            string? userContextScriptPath = null; // Track temp script for cleanup
            bool useUserContextFallback = false;
            
            // Try admin installation first for all apps (including Spotify with --scope user)
            LogMessage($"  Attempting standard installation...", Color.Gray);
            string scopeFlag = wingetId == "Spotify.Spotify" ? "--scope user" : "";
            string command = $"winget install --id {wingetId} --source winget --silent --accept-package-agreements --accept-source-agreements {scopeFlag}".Trim();
            
            process = new Process
                {
                    StartInfo = new ProcessStartInfo
                    {
                        FileName = "powershell.exe",
                        Arguments = $"-NoProfile -Command \"{command}\"",
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        CreateNoWindow = true,
                        Verb = "runas"
                    }
                };

                process.OutputDataReceived += (s, e) =>
                {
                    if (!string.IsNullOrEmpty(e.Data))
                    {
                        string line = e.Data.Trim();
                        
                        // Skip any line containing block/progress characters (including garbled UTF-8)
                        if (line.Contains("█") || line.Contains("░") || line.Contains("▒") || 
                            line.Contains("▓") || line.Contains("━") || line.Contains("─") || line.Contains("│") ||
                            line.Contains("â–") || line.Contains("â•") || // Garbled UTF-8 block characters
                            (line.Contains("KB") && line.Contains("MB") && line.Length < 100)) // Progress lines like "1024 KB / 161 MB"
                        {
                            return;
                        }
                        
                        // Skip spinner/animation frames
                        if (line == "|" || line == "/" || line == "-" || line == "\\" ||
                            line.All(c => c == '|' || c == '/' || c == '-' || c == '\\' || char.IsWhiteSpace(c)))
                        {
                            return;
                        }
                        
                        BeginInvoke(() => LogMessage($"    {e.Data}", Color.LightGray));
                    }
                };

                process.ErrorDataReceived += (s, e) =>
                {
                    if (!string.IsNullOrEmpty(e.Data))
                    {
                        BeginInvoke(() => LogMessage($"    {e.Data}", Color.Yellow));
                    }
                };

                process.Start();
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();
                await process.WaitForExitAsync();
                
                // Check if admin installation succeeded
                if (process.ExitCode == 0 || process.ExitCode == 3010)
                {
                    if (process.ExitCode == 0)
                    {
                        LogMessage($"✓ {appName} installed successfully", Color.Green);
                    }
                    else
                    {
                        LogMessage($"✓ {appName} installed successfully (reboot required)", Color.Yellow);
                    }
                    return true;
                }
                
                // Special handling for Wireless Workbench - try Supabase before hash override
                if (wingetId == "Shure.WirelessWorkbench.7")
                {
                    LogMessage($"  Standard installation failed, attempting Supabase download for {appName}...", Color.Yellow);
                    string supabaseUrl = "https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/Shure/Wireless-Workbench-Windows-7.7.0.exe?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9iMThlMzFjNi05NmI2LTRhZjItOTI1Mi1iYzA5NWM1NTEwNmQiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJpbnN0YWxsZXJzL1NodXJlL1dpcmVsZXNzLVdvcmtiZW5jaC1XaW5kb3dzLTcuNy4wLmV4ZSIsImlhdCI6MTc2NzAzNTM3OCwiZXhwIjo0ODg5MDk5Mzc4fQ.9im86Kbamz-_IsUb1dodjSNYTIyO9Dzf-fUPwznatlc";
                    bool supabaseSuccess = await InstallDirectDownloadAsync(appName, supabaseUrl, "/S");
                    if (supabaseSuccess)
                    {
                        LogMessage($"✓ {appName} installed successfully via Supabase", Color.Green);
                        return true;
                    }
                    
                    LogMessage($"  Supabase download failed, falling back to user context with hash override...", Color.Yellow);
                }
                else
                {
                    LogMessage($"  Standard installation failed, trying user context with hash override...", Color.Yellow);
                }
                
                useUserContextFallback = true;
            
            // User context installation with scheduled task (for Spotify and fallback cases)
            if (useUserContextFallback)
            {
                string taskName = $"WingetInstall_{wingetId.Replace(".", "_")}_{DateTime.Now.Ticks}";
                string hashFlag = "--ignore-security-hash";
                string wingetCommand = $"winget install --id {wingetId} --source winget --silent --accept-package-agreements --accept-source-agreements {scopeFlag} {hashFlag}".Trim();
                
                // Create PowerShell script as temp file to avoid quote escaping issues
                userContextScriptPath = Path.Combine(Path.GetTempPath(), $"{taskName}.ps1");
                string createTask = $@"
                    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -Command ""{wingetCommand}""'
                    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName '{taskName}' -Action $action -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName '{taskName}'

# Wait for task to complete
$timeout = 300
$elapsed = 0
while ($elapsed -lt $timeout) {{
    $task = Get-ScheduledTask -TaskName '{taskName}' -ErrorAction SilentlyContinue
    if ($task.State -eq 'Ready') {{ break }}
    Start-Sleep -Seconds 2
    $elapsed += 2
}}

# Get task result
$taskInfo = Get-ScheduledTaskInfo -TaskName '{taskName}'
$exitCode = $taskInfo.LastTaskResult

# Clean up
Unregister-ScheduledTask -TaskName '{taskName}' -Confirm:$false

exit $exitCode
";
                
                File.WriteAllText(userContextScriptPath, createTask);
                
                process = new Process
                {
                    StartInfo = new ProcessStartInfo
                    {
                        FileName = "powershell.exe",
                        Arguments = $"-NoProfile -ExecutionPolicy Bypass -File \"{userContextScriptPath}\"",
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        CreateNoWindow = true,
                        Verb = "runas" // Need admin to create scheduled task
                    }
                };

                process.OutputDataReceived += (s, e) =>
                {
                    if (!string.IsNullOrEmpty(e.Data))
                    {
                        string line = e.Data.Trim();
                        
                        // Skip any line containing block/progress characters (including garbled UTF-8)
                        if (line.Contains("█") || line.Contains("░") || line.Contains("▒") || 
                            line.Contains("▓") || line.Contains("━") || line.Contains("─") || line.Contains("│") ||
                            line.Contains("â–") || line.Contains("â•") || // Garbled UTF-8 block characters
                            (line.Contains("KB") && line.Contains("MB") && line.Length < 100)) // Progress lines like "1024 KB / 161 MB"
                        {
                            return;
                        }
                        
                        // Skip spinner/animation frames
                        if (line == "|" || line == "/" || line == "-" || line == "\\" ||
                            line.All(c => c == '|' || c == '/' || c == '-' || c == '\\' || char.IsWhiteSpace(c)))
                        {
                            return;
                        }
                        
                        BeginInvoke(() => LogMessage($"    {e.Data}", Color.LightGray));
                    }
                };

                process.ErrorDataReceived += (s, e) =>
                {
                    if (!string.IsNullOrEmpty(e.Data))
                    {
                        BeginInvoke(() => LogMessage($"    {e.Data}", Color.Yellow));
                    }
                };

                process.Start();
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();
                await process.WaitForExitAsync();
                
                // Clean up user context temp script
                if (userContextScriptPath != null)
                {
                    try
                    {
                        if (File.Exists(userContextScriptPath))
                        {
                            File.Delete(userContextScriptPath);
                        }
                    }
                    catch { }
                }

                if (process.ExitCode == 0)
                {
                    LogMessage($"✓ {appName} installed successfully", Color.Green);
                    return true;
                }
                else if (process.ExitCode == 3010)
                {
                    LogMessage($"✓ {appName} installed successfully (reboot required)", Color.Yellow);
                    return true;
                }
                else
                {
                    LogMessage($"✗ {appName} installation failed (Exit code: {process.ExitCode})", Color.Red);
                    
                    // Special fallback for Spotify - try direct download
                    if (wingetId == "Spotify.Spotify")
                    {
                        LogMessage($"  Attempting direct download fallback for {appName}...", Color.Yellow);
                        string spotifyUrl = "https://download.scdn.co/SpotifySetup.exe";
                        bool directSuccess = await InstallDirectDownloadAsync(appName, spotifyUrl, "/silent");
                        if (directSuccess)
                        {
                            LogMessage($"✓ {appName} installed successfully via direct download fallback", Color.Green);
                            return true;
                        }
                    }
                    
                    return false;
                }
            }
            
            return false;
        }
        catch (Exception ex)
        {
            LogMessage($"✗ Error installing {appName}: {ex.Message}", Color.Red);
            return false;
        }
    }

    private async Task<bool> InstallDirectDownloadAsync(string appName, string downloadUrl, string installArgs)
    {
        LogMessage($"Downloading {appName} from direct source...", Color.Yellow);

        try
        {
            // Determine file extension from URL (strip query parameters first)
            string urlWithoutQuery = downloadUrl.Split('?')[0];
            string extension = Path.GetExtension(urlWithoutQuery).ToLower();
            if (string.IsNullOrEmpty(extension))
            {
                extension = ".exe"; // Default to exe if no extension
            }

            string tempFile = Path.Combine(Path.GetTempPath(), $"{appName.Replace(" ", "_")}_installer{extension}");

            // Download the file
            LogMessage($"  Downloading installer...", Color.Gray);
            using (var httpClient = new HttpClient())
            {
                httpClient.Timeout = TimeSpan.FromMinutes(10); // Allow time for larger downloads
                
                // Add Supabase authentication if this is a Supabase storage URL
                if (downloadUrl.Contains("supabase.co/storage"))
                {
                    httpClient.DefaultRequestHeaders.Add("apikey", SUPABASE_SERVICE_KEY);
                    httpClient.DefaultRequestHeaders.Add("Authorization", $"Bearer {SUPABASE_SERVICE_KEY}");
                    LogMessage($"  Using Supabase authentication", Color.Gray);
                }
                
                var response = await httpClient.GetAsync(downloadUrl, HttpCompletionOption.ResponseHeadersRead);
                response.EnsureSuccessStatusCode();

                var totalBytes = response.Content.Headers.ContentLength ?? 0;
                using var contentStream = await response.Content.ReadAsStreamAsync();
                using var fileStream = new FileStream(tempFile, FileMode.Create, FileAccess.Write, FileShare.None);

                var buffer = new byte[8192];
                long totalRead = 0;
                int bytesRead;

                while ((bytesRead = await contentStream.ReadAsync(buffer, 0, buffer.Length)) > 0)
                {
                    await fileStream.WriteAsync(buffer, 0, bytesRead);
                    totalRead += bytesRead;

                    if (totalBytes > 0)
                    {
                        var progress = (int)((totalRead * 100) / totalBytes);
                        BeginInvoke(() => lblStatus.Text = $"Downloading {appName}... {progress}%");
                    }
                }
            }

            LogMessage($"  ✓ Download complete", Color.Green);

            // Update status to show installation phase
            BeginInvoke(() => lblStatus.Text = $"Installing {appName}...");

            // Handle different file types
            if (extension == ".zip")
            {
                // Extract zip file to specified location
                return await ExtractAndInstallZipAsync(appName, tempFile, installArgs);
            }
            else if (extension == ".msi")
            {
                // Install MSI using msiexec
                return await InstallMsiAsync(appName, tempFile, installArgs);
            }
            else
            {
                // Assume it's an executable installer
                // Disable auto-click for apps that require user input
                
                // For NovaLCT, launch a background watcher for the Device Driver Installation Wizard
                if (appName.Contains("NovaLCT") || appName.Contains("Nova"))
                {
                    _ = Task.Run(async () =>
                    {
                        try
                        {
                            await Task.Delay(10000); // Wait 10 seconds for main installer to start
                            await LaunchDriverWizardWatcherAsync();
                        }
                        catch (Exception ex)
                        {
                            LogMessage($"  Wizard watcher exception: {ex.Message}", Color.Red);
                        }
                    });
                }
                
                return await InstallExeAsync(appName, tempFile, installArgs);
            }
        }
        catch (Exception ex)
        {
            string errorDetail = ex.Message;
            if (ex is HttpRequestException httpEx)
            {
                // Don't include URLs in error messages for privacy
                if (httpEx.StatusCode.HasValue)
                {
                    errorDetail = $"Network error: HTTP {(int)httpEx.StatusCode} ({httpEx.StatusCode})";
                }
                else
                {
                    errorDetail = "Network error: Unable to download installer";
                }
            }
            else if (ex is UnauthorizedAccessException)
            {
                errorDetail = $"Permission denied: {ex.Message}";
            }
            else if (ex is System.IO.IOException)
            {
                errorDetail = $"File system error: {ex.Message}";
            }
            
            LogMessage($"✗ Error installing {appName}: {errorDetail}", Color.Red);
            return false;
        }
    }

    private async Task<bool> DownloadAndExtractToDesktopAsync(string contentName, string downloadUrl)
    {
        LogMessage($"Downloading {contentName}...", Color.Yellow);

        try
        {
            // Create zip file path
            string tempFile = Path.Combine(Path.GetTempPath(), $"{contentName.Replace(" ", "_")}.zip");

            // Download the file
            LogMessage($"  Downloading zip file...", Color.Gray);
            using (var httpClient = new HttpClient())
            {
                httpClient.Timeout = TimeSpan.FromMinutes(10);
                
                // Add Supabase authentication
                if (downloadUrl.Contains("supabase.co/storage"))
                {
                    httpClient.DefaultRequestHeaders.Add("apikey", SUPABASE_SERVICE_KEY);
                    httpClient.DefaultRequestHeaders.Add("Authorization", $"Bearer {SUPABASE_SERVICE_KEY}");
                }
                
                var response = await httpClient.GetAsync(downloadUrl, HttpCompletionOption.ResponseHeadersRead);
                response.EnsureSuccessStatusCode();

                var totalBytes = response.Content.Headers.ContentLength ?? 0;
                using var contentStream = await response.Content.ReadAsStreamAsync();
                using var fileStream = new FileStream(tempFile, FileMode.Create, FileAccess.Write, FileShare.None);

                var buffer = new byte[8192];
                long totalRead = 0;
                int bytesRead;

                while ((bytesRead = await contentStream.ReadAsync(buffer, 0, buffer.Length)) > 0)
                {
                    await fileStream.WriteAsync(buffer, 0, bytesRead);
                    totalRead += bytesRead;

                    if (totalBytes > 0)
                    {
                        var progress = (int)((totalRead * 100) / totalBytes);
                        BeginInvoke(() => lblStatus.Text = $"Downloading {contentName}... {progress}%");
                    }
                }
            }

            LogMessage($"  ✓ Download complete", Color.Green);

            // Extract to Desktop
            string desktopPath = Environment.GetFolderPath(Environment.SpecialFolder.Desktop);
            string extractPath = Path.Combine(desktopPath, contentName);
            
            // Create directory if it doesn't exist
            if (Directory.Exists(extractPath))
            {
                LogMessage($"  Removing existing folder...", Color.Gray);
                Directory.Delete(extractPath, recursive: true);
            }
            Directory.CreateDirectory(extractPath);
            
            LogMessage($"  Extracting to Desktop/{contentName}...", Color.Yellow);
            BeginInvoke(() => lblStatus.Text = $"Extracting {contentName}...");

            // Extract using .NET
            await Task.Run(() =>
            {
                System.IO.Compression.ZipFile.ExtractToDirectory(tempFile, extractPath, overwriteFiles: true);
            });

            LogMessage($"  ✓ Extraction complete", Color.Green);
            LogMessage($"  Location: {extractPath}", Color.Gray);

            // Clean up zip file
            try
            {
                if (File.Exists(tempFile))
                {
                    File.Delete(tempFile);
                }
            }
            catch { }

            return true;
        }
        catch (HttpRequestException httpEx)
        {
            string errorDetail;
            if (httpEx.StatusCode.HasValue)
            {
                errorDetail = $"Network error: HTTP {(int)httpEx.StatusCode} ({httpEx.StatusCode})";
            }
            else
            {
                errorDetail = "Network error: Unable to download content";
            }
            LogMessage($"  ✗ {errorDetail}", Color.Red);
            return false;
        }
        catch (Exception ex)
        {
            LogMessage($"  ✗ Error: {ex.Message}", Color.Red);
            return false;
        }
    }

    private async Task<bool> ExtractAndInstallZipAsync(string appName, string zipFile, string extractPath)
    {
        try
        {
            LogMessage($"  Extracting {appName}...", Color.Yellow);
            LogMessage($"  Source: {zipFile}", Color.Gray);

            // Use temp directory for extraction
            string tempExtractPath = Path.Combine(Path.GetTempPath(), $"{appName.Replace(" ", "_")}_extracted");
            
            // Create directory if it doesn't exist
            if (Directory.Exists(tempExtractPath))
            {
                Directory.Delete(tempExtractPath, recursive: true);
            }
            Directory.CreateDirectory(tempExtractPath);
            LogMessage($"  Extracting to temporary location...", Color.Gray);

            // Extract using .NET
            await Task.Run(() =>
            {
                System.IO.Compression.ZipFile.ExtractToDirectory(zipFile, tempExtractPath, overwriteFiles: true);
            });

            LogMessage($"  ✓ Extraction complete", Color.Green);

            // Clean up zip file
            try
            {
                if (File.Exists(zipFile))
                {
                    File.Delete(zipFile);
                }
            }
            catch { }

            // Look for installer files (.exe, .msi) in the extracted folder
            var installerFiles = Directory.GetFiles(tempExtractPath, "*.exe", SearchOption.AllDirectories)
                .Concat(Directory.GetFiles(tempExtractPath, "*.msi", SearchOption.AllDirectories))
                .Where(f => !Path.GetFileName(f).StartsWith("unins", StringComparison.OrdinalIgnoreCase)) // Skip uninstallers
                .ToList();

            if (installerFiles.Any())
            {
                // Found installer(s), run the first one
                string installerPath = installerFiles.First();
                string installerName = Path.GetFileName(installerPath);
                LogMessage($"  Found installer: {installerName}", Color.Green);
                
                // Determine installer type and run it
                if (installerPath.EndsWith(".msi", StringComparison.OrdinalIgnoreCase))
                {
                    LogMessage($"  Running MSI installer...", Color.Yellow);
                    bool result = await InstallMsiAsync(appName, installerPath, "/qn");
                    
                    // Clean up temp folder
                    try { Directory.Delete(tempExtractPath, recursive: true); } catch { }
                    
                    return result;
                }
                else
                {
                    LogMessage($"  Running EXE installer...", Color.Yellow);
                    
                    // For NovaLCT, launch a background watcher for the Device Driver Installation Wizard
                    if (appName.Contains("NovaLCT") || appName.Contains("Nova"))
                    {
                        _ = Task.Run(async () =>
                        {
                            try
                            {
                                await Task.Delay(10000); // Wait 10 seconds for main installer to start
                                await LaunchDriverWizardWatcherAsync();
                            }
                            catch (Exception ex)
                            {
                                LogMessage($"  Wizard watcher exception: {ex.Message}", Color.Red);
                            }
                        });
                    }
                    
                    // Try common silent install arguments
                    string silentArgs = extractPath; // Use extractPath as the silent install arg if provided
                    if (string.IsNullOrEmpty(silentArgs))
                    {
                        silentArgs = "/S"; // Default to NSIS silent flag
                    }
                    
                    // Run installer (deployment-wide autoclicker will handle any dialogs)
                    bool result = await InstallExeAsync(appName, installerPath, silentArgs);
                    
                    // Clean up temp folder
                    try { Directory.Delete(tempExtractPath, recursive: true); } catch { }
                    
                    return result;
                }
            }
            else
            {
                // No installer found - treat as portable app, move to final destination
                LogMessage($"  No installer found, treating as portable application", Color.Yellow);
                
                if (string.IsNullOrEmpty(extractPath))
                {
                    extractPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), appName);
                }
                
                // Move files to destination
                if (Directory.Exists(extractPath))
                {
                    Directory.Delete(extractPath, recursive: true);
                }
                Directory.Move(tempExtractPath, extractPath);
                
                LogMessage($"  ✓ Installed to: {extractPath}", Color.Green);
                LogMessage($"✓ {appName} installed successfully", Color.Green);
                return true;
            }
        }
        catch (Exception ex)
        {
            LogMessage($"✗ Error processing {appName}: {ex.Message}", Color.Red);
            LogMessage($"  Details: {ex.GetType().Name}", Color.Gray);
            return false;
        }
    }

    private async Task<bool> InstallMsiAsync(string appName, string msiFile, string installArgs)
    {
        try
        {
            LogMessage($"  Installing {appName} (MSI)...", Color.Yellow);
            BeginInvoke(() => lblStatus.Text = $"Installing {appName}...");

            // Default MSI arguments if none provided
            if (string.IsNullOrEmpty(installArgs))
            {
                installArgs = "/qn"; // Quiet, no UI
            }

            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "msiexec.exe",
                    Arguments = $"/i \"{msiFile}\" {installArgs}",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                }
            };

            process.Start();
            await process.WaitForExitAsync();

            // Clean up MSI file
            try
            {
                if (File.Exists(msiFile))
                {
                    File.Delete(msiFile);
                }
            }
            catch { }

            if (process.ExitCode == 0)
            {
                LogMessage($"✓ {appName} installed successfully", Color.Green);
                return true;
            }
            else if (process.ExitCode == 3010)
            {
                LogMessage($"✓ {appName} installed successfully (reboot required)", Color.Yellow);
                return true;
            }
            else
            {
                LogMessage($"✗ {appName} installation failed (Exit code: {process.ExitCode})", Color.Red);
                return false;
            }
        }
        catch (Exception ex)
        {
            LogMessage($"✗ Error installing {appName}: {ex.Message}", Color.Red);
            return false;
        }
    }

    private async Task<bool> InstallExeAsync(string appName, string exeFile, string installArgs)
    {
        try
        {
            LogMessage($"  Installing {appName}...", Color.Yellow);
            BeginInvoke(() => lblStatus.Text = $"Installing {appName}...");

            // Determine timeout based on app - Audio Architect needs longer due to InstallAware delays
            int timeoutMinutes = appName.Contains("Audio Architect") ? 15 : 10;

            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = exeFile,
                    Arguments = installArgs,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                }
            };

            process.Start();
            
            // Wait for installation to complete (deployment-wide autoclicker handles all dialogs)
            await process.WaitForExitAsync();
            
            // Special handling for Audio Architect - the installer spawns background processes
            // Wait for the actual installation to complete by monitoring AudioArchitect processes
            if (appName.Contains("Audio Architect"))
            {
                LogMessage($"  Waiting for Audio Architect installation to complete...", Color.Yellow);
                
                // Wait up to 5 minutes for installation processes to finish
                var installCompleteTime = DateTime.Now.AddMinutes(5);
                bool stillInstalling = true;
                
                while (stillInstalling && DateTime.Now < installCompleteTime)
                {
                    await Task.Delay(2000); // Check every 2 seconds
                    
                    // Check if any AudioArchitect installer processes are still running
                    var audioProcs = Process.GetProcessesByName("AudioArchitect");
                    var setupProcs = Process.GetProcesses()
                        .Where(p => p.ProcessName.Contains("setup", StringComparison.OrdinalIgnoreCase) ||
                                   p.ProcessName.Contains("install", StringComparison.OrdinalIgnoreCase))
                        .Where(p => {
                            try { return p.MainWindowTitle.Contains("Audio Architect", StringComparison.OrdinalIgnoreCase); }
                            catch { return false; }
                        });
                    
                    if (!audioProcs.Any() && !setupProcs.Any())
                    {
                        // Wait an extra 3 seconds to be sure
                        await Task.Delay(3000);
                        stillInstalling = false;
                        LogMessage($"  ✓ Audio Architect installation processes completed", Color.Green);
                    }
                }
                
                if (stillInstalling)
                {
                    LogMessage($"  ⚠ Timeout waiting for Audio Architect to complete (continuing anyway)", Color.Yellow);
                }
            }

            // Clean up installer file
            try
            {
                if (File.Exists(exeFile))
                {
                    File.Delete(exeFile);
                }
            }
            catch { }

            if (process.ExitCode == 0)
            {
                LogMessage($"✓ {appName} installed successfully", Color.Green);
                return true;
            }
            else if (process.ExitCode == 3010)
            {
                LogMessage($"✓ {appName} installed successfully (reboot required)", Color.Yellow);
                return true;
            }
            else
            {
                LogMessage($"✗ {appName} installation failed (Exit code: {process.ExitCode})", Color.Red);
                return false;
            }
        }
        catch (Exception ex)
        {
            LogMessage($"✗ Error installing {appName}: {ex.Message}", Color.Red);
            return false;
        }
    }

    private async Task AutoClickDialogsAsync(string appName, CancellationToken cancellationToken)
    {
        Process? process = null;
        string? tempScriptPath = null;
        
        try
        {
            LogMessage($"  Auto-clicker active for deployment - will scan for installer windows...", Color.Gray);
            
            // Run indefinitely until cancelled (deployment completes)
            // Use PowerShell to automatically click through dialogs
            string script = $@"
                try {{
                    Write-Host ""===== Deployment-Wide Auto-Click Script Started ====="" -ForegroundColor Green
                    Write-Host ""Will run continuously until deployment completes..."" -ForegroundColor Cyan
                    Write-Host ""Loading assemblies..."" -ForegroundColor Yellow
                    
                    Add-Type -AssemblyName System.Windows.Forms
                    Write-Host ""  - System.Windows.Forms loaded"" -ForegroundColor Gray
                    Add-Type -AssemblyName UIAutomationClient
                    Write-Host ""  - UIAutomationClient loaded"" -ForegroundColor Gray
                    Add-Type -AssemblyName UIAutomationTypes
                    Write-Host ""  - UIAutomationTypes loaded"" -ForegroundColor Gray
                    
                    # Add Win32 API to enumerate ALL windows (not just main windows)
                    Write-Host ""  - Loading Win32 API..."" -ForegroundColor Gray
                    Add-Type @""
                    using System;
                    using System.Runtime.InteropServices;
                    using System.Text;
                    public class Win32 {{
                        [DllImport(""user32.dll"")]
                        public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);
                        
                        [DllImport(""user32.dll"")]
                        public static extern bool EnumChildWindows(IntPtr hWndParent, EnumWindowsProc lpEnumFunc, IntPtr lParam);
                        
                        [DllImport(""user32.dll"")]
                        public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
                        
                        [DllImport(""user32.dll"")]
                        public static extern bool IsWindowVisible(IntPtr hWnd);
                        
                        [DllImport(""user32.dll"")]
                        public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
                        
                        [DllImport(""user32.dll"")]
                        public static extern IntPtr FindWindowEx(IntPtr parentHandle, IntPtr childAfter, string className, string windowTitle);
                        
                        [DllImport(""user32.dll"")]
                        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
                        
                        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
                        
                        public const uint BM_CLICK = 0x00F5;
                        public const uint WM_LBUTTONDOWN = 0x0201;
                        public const uint WM_LBUTTONUP = 0x0202;
                    }}
""@
                    
                    Write-Host ""Assemblies loaded successfully"" -ForegroundColor Green
                    Write-Host ""Starting main loop..."" -ForegroundColor Yellow
                    Write-Host ""Press Ctrl+C to stop (or will be stopped when deployment completes)"" -ForegroundColor Cyan
                    Write-Host """" -ForegroundColor White
                
                }} catch {{
                    Write-Host ""ERROR loading assemblies: $_"" -ForegroundColor Red
                    Write-Host ""Stack trace: $($_.ScriptStackTrace)"" -ForegroundColor Red
                    Read-Host ""Press Enter to exit""
                    exit 1
                }}
                
                # Run indefinitely - no timeout, will be stopped externally
                $clickCount = 0
                $lastClickTime = $null
                
                $loopCount = 0
                while ($true) {{
                    try {{
                        $loopCount++
                        
                        # Every 10 iterations (3 seconds), show we're still looking
                        if ($loopCount % 10 -eq 1) {{
                            Write-Host ""Still scanning for installer windows... (Clicks so far: $clickCount)"" -ForegroundColor Cyan
                            
                            # Show all processes with windows for debugging
                            $allWindows = Get-Process | Where-Object {{ $_.MainWindowTitle -ne '' }}
                            if ($allWindows) {{
                                Write-Host ""Current processes with windows:"" -ForegroundColor Yellow
                                $allWindows | ForEach-Object {{ Write-Host ""  - $($_.ProcessName): $($_.MainWindowTitle)"" -ForegroundColor Gray }}
                            }} else {{
                                Write-Host ""No processes with MainWindowTitle found"" -ForegroundColor Red
                            }}
                            
                            # Also check for specific installer process names
                            $installerProcesses = Get-Process | Where-Object {{ $_.ProcessName -match 'setup|install|wizard|msi' }}
                            if ($installerProcesses) {{
                                Write-Host ""Installer-like processes (by name):"" -ForegroundColor Yellow
                                $installerProcesses | ForEach-Object {{ 
                                    Write-Host ""  - $($_.ProcessName) (ID: $($_.Id), Title: '$($_.MainWindowTitle)')"" -ForegroundColor Gray 
                                }}
                            }}
                        }}
                        
                        # Re-initialize $foundWindows on each loop iteration
                        $foundWindows = @()
                        
                        # Method 1: Try Get-Process approach - get ALL matching windows
                        $candidateWindows = @()
                        
                        # Special handling for AudioArchitect - check ALL instances
                        $audioProcs = Get-Process -Name 'AudioArchitect' -ErrorAction SilentlyContinue
                        if ($audioProcs) {{
                            Write-Host ""Found $($audioProcs.Count) AudioArchitect processes"" -ForegroundColor Cyan
                            foreach ($proc in $audioProcs) {{
                                if ($proc.MainWindowHandle -ne 0) {{
                                    Write-Host ""  Process ID $($proc.Id): Handle=$($proc.MainWindowHandle), Title='$($proc.MainWindowTitle)'"" -ForegroundColor Yellow
                                    $candidateWindows += [PSCustomObject]@{{ 
                                        Handle = $proc.MainWindowHandle
                                        Title = $proc.MainWindowTitle
                                        ProcessId = $proc.Id
                                    }}
                                }}
                            }}
                        }}
                        
                        # Also check other installer windows
                        $processes = Get-Process | Where-Object {{ 
                            $_.ProcessName -ne 'AudioArchitect' -and
                            $_.MainWindowTitle -ne '' -and 
                            ($_.MainWindowTitle -match 'Setup|Wizard|Araneo|Luminet|LumiNet|Luminex|Network Intelligence|License|Welcome|Complete|InstallAware|Agree|ATEM|Blackmagic|Browse|Select|Choose|Open|Click|Disagree|cancel the installation|NovaLCT|Nova|Driver|Success|Silicon|CP210x|UART|Windows Security|Security') 
                        }}
                        
                        foreach ($proc in $processes) {{
                            $candidateWindows += [PSCustomObject]@{{ 
                                Handle = $proc.MainWindowHandle
                                Title = $proc.MainWindowTitle
                                ProcessId = $proc.Id
                            }}
                        }}
                        
                        # Method 2: If not found by title, try by process name
                        if ($candidateWindows.Count -eq 0) {{
                            $processes = Get-Process | Where-Object {{ 
                                $_.MainWindowTitle -ne '' -and
                                ($_.ProcessName -match 'setup|install|wizard|audio')
                            }}
                            foreach ($proc in $processes) {{
                                $candidateWindows += [PSCustomObject]@{{ 
                                    Handle = $proc.MainWindowHandle
                                    Title = $proc.MainWindowTitle
                                }}
                            }}
                        }}
                        
                        # Method 3: ALWAYS use Win32 API to find ALL installer windows (including popups/child windows)
                        # This catches dialogs that don't appear as MainWindow
                        $allVisibleWindows = @()
                        $callback = {{
                            param($h, $lParam)
                            if ([Win32]::IsWindowVisible($h)) {{
                                $sb = New-Object System.Text.StringBuilder 256
                                [Win32]::GetWindowText($h, $sb, $sb.Capacity) | Out-Null
                                $title = $sb.ToString().Trim()
                                if ($title -ne '') {{
                                    $script:allVisibleWindows += [PSCustomObject]@{{ Handle = $h; Title = $title }}
                                }}
                                # Match ANY installer/setup window, security dialogs, or confirmation popups
                                if ($title -match '(?i)Setup|Install|Wizard|Security|Windows Security|Warning|User Account Control|Publisher|License|Welcome|Complete|Agree|Browse|Select|Choose|Folder|Confirm|Question|Exists|Overwrite|Replace|Click|Success|Driver|NovaLCT|Nova|Silicon|CP210x|UART|Completing') {{
                                    # Check if this window is already in candidateWindows (avoid duplicates)
                                    $isDuplicate = $false
                                    foreach ($existing in $script:candidateWindows) {{
                                        if ($existing.Handle -eq $h) {{
                                            $isDuplicate = $true
                                            break
                                        }}
                                    }}
                                    if (-not $isDuplicate) {{
                                        $script:candidateWindows += [PSCustomObject]@{{ 
                                            Handle = $h
                                            Title = $title
                                        }}
                                    }}
                                }}
                            }}
                            return $true
                        }}
                        [Win32]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null
                        
                        # Method 4: Get all rundll32 process IDs, then find ALL windows belonging to them
                        # This catches Windows Security dialogs even when rundll32 has no MainWindowHandle
                        $rundllProcesses = Get-Process -Name 'rundll32' -ErrorAction SilentlyContinue
                        if ($rundllProcesses) {{
                            $script:rundllPIDs = $rundllProcesses | ForEach-Object {{ $_.Id }}
                            Write-Host ""Found $($rundllProcesses.Count) rundll32 processes: PIDs $($script:rundllPIDs -join ', ')"" -ForegroundColor Cyan
                            
                            # Now enumerate ALL windows and check which belong to rundll32
                            $rundllCallback = {{
                                param($h, $lParam)
                                if ([Win32]::IsWindowVisible($h)) {{
                                    # Get the process ID for this window (use windowPid to avoid conflict with $pid built-in variable)
                                    $windowPid = 0
                                    [Win32]::GetWindowThreadProcessId($h, [ref]$windowPid) | Out-Null
                                    
                                    # Check if this window belongs to a rundll32 process
                                    if ($script:rundllPIDs -contains $windowPid) {{
                                        $sb = New-Object System.Text.StringBuilder 256
                                        [Win32]::GetWindowText($h, $sb, $sb.Capacity) | Out-Null
                                        $title = $sb.ToString().Trim()
                                        
                                        if ($title -ne '') {{
                                            Write-Host ""  [RUNDLL32 PID:$windowPid] Window: '$title' (Handle: $h)"" -ForegroundColor Magenta
                                            $script:allVisibleWindows += [PSCustomObject]@{{ Handle = $h; Title = $title; ProcessId = $windowPid }}
                                            
                                            # Add to candidates if it matches security/driver patterns
                                            if ($title -match '(?i)Security|Install|Driver|Device|Would you like') {{
                                                $isDuplicate = $false
                                                foreach ($existing in $script:candidateWindows) {{
                                                    if ($existing.Handle -eq $h) {{
                                                        $isDuplicate = $true
                                                        break
                                                    }}
                                                }}
                                                if (-not $isDuplicate) {{
                                                    Write-Host ""  >> FOUND RUNDLL32 DIALOG: '$title' - Adding to candidates!"" -ForegroundColor Green
                                                    $script:candidateWindows += [PSCustomObject]@{{ 
                                                        Handle = $h
                                                        Title = $title
                                                        ProcessId = $windowPid
                                                    }}
                                                }}
                                            }}
                                        }}
                                    }}
                                }}
                                return $true
                            }}
                            [Win32]::EnumWindows($rundllCallback, [IntPtr]::Zero) | Out-Null
                        }}
                        
                        # Debug: Show ALL visible windows every 5 iterations (increased frequency to catch transient dialogs)
                        if ($loopCount % 5 -eq 1) {{
                            Write-Host ""=== SCAN #$loopCount - All visible windows ($($allVisibleWindows.Count) total) ==="" -ForegroundColor Yellow
                            # Show ALL windows, not just filtered ones, to debug detection issues
                            $allVisibleWindows | ForEach-Object {{
                                $color = 'Gray'
                                if ($_.Title -match '(?i)Windows Security') {{ $color = 'Magenta' }}
                                elseif ($_.Title -match '(?i)Security') {{ $color = 'Cyan' }}
                                elseif ($_.Title -match '(?i)Nova|Driver|Install') {{ $color = 'Yellow' }}
                                Write-Host ""  [$color] '$($_.Title)' (Handle: $($_.Handle))"" -ForegroundColor $color
                            }}
                            Write-Host ""=== End of window list ==="" -ForegroundColor Yellow
                        }}
                        
                        # Debug: Show all candidate windows found
                        if ($candidateWindows.Count -gt 0) {{
                            Write-Host ""Found $($candidateWindows.Count) candidate window(s):"" -ForegroundColor Cyan
                            foreach ($cw in $candidateWindows) {{
                                Write-Host ""  - '$($cw.Title)' (Handle: $($cw.Handle))"" -ForegroundColor Gray
                            }}
                        }} else {{
                            if ($loopCount % 10 -eq 1) {{
                                Write-Host ""No candidate windows found in this iteration"" -ForegroundColor Yellow
                            }}
                        }}
                        
                        # Process ALL candidate windows in this iteration (not just the first one)
                        # This ensures we handle both main installer and popup dialogs in the same pass
                        $clickedInThisIteration = $false
                        $processedHandles = @()  # Track which windows we've already processed
                        foreach ($candidate in $candidateWindows) {{
                            $hwnd = $candidate.Handle
                            $windowTitle = $candidate.Title
                            $processId = if ($candidate.ProcessId) {{ $candidate.ProcessId }} else {{ 'unknown' }}
                            
                            # Track this handle as processed
                            $processedHandles += $hwnd
                            
                            Write-Host ""Checking window: '$windowTitle' (PID: $processId, Handle: $hwnd)"" -ForegroundColor Green
                            
                            # Special handling for UAC (User Account Control) and Windows Security dialogs
                            # Try to click buttons first (for driver installation dialogs), then fall back to keyboard automation (for real UAC)
                            if ($windowTitle -match '(?i)User Account Control|consent.exe|Windows Security') {{
                                Write-Host ""  >> Detected UAC/Windows Security dialog"" -ForegroundColor Magenta
                                
                                # First attempt: Try to find and click buttons using UI Automation
                                # This works for Windows Security driver installation dialogs
                                $buttonClicked = $false
                                try {{
                                    $automation = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
                                    if ($automation) {{
                                        Write-Host ""  >> Attempting to find clickable buttons..."" -ForegroundColor Cyan
                                        
                                        # Look for buttons
                                        $buttonCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
                                        $buttons = $automation.FindAll([System.Windows.Automation.TreeScope]::Descendants, $buttonCondition)
                                        
                                        # Also check panes that might be buttons (Windows Security uses CCPushButton as Panes!)
                                        $paneCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Pane)
                                        $panes = $automation.FindAll([System.Windows.Automation.TreeScope]::Descendants, $paneCondition)
                                        
                                        $allControls = @()
                                        foreach ($btn in $buttons) {{ $allControls += $btn }}
                                        foreach ($pane in $panes) {{
                                            $pClass = $pane.Current.ClassName
                                            $pName = $pane.Current.Name
                                            # Include CCPushButton (Windows Security), TButton/TNewButton (Inno Setup), and button-like names
                                            if ($pClass -eq 'CCPushButton' -or $pClass -eq 'TButton' -or $pClass -eq 'TNewButton' -or $pClass -eq 'Button' -or $pName -match '(?i)^(Install|Yes|Allow|OK)$') {{
                                                $allControls += $pane
                                            }}
                                        }}
                                        
                                        Write-Host ""  >> Found $($allControls.Count) controls"" -ForegroundColor Gray
                                        
                                        foreach ($control in $allControls) {{
                                            $controlName = $control.Current.Name
                                            $controlEnabled = $control.Current.IsEnabled
                                            Write-Host ""  >>   - '$controlName' (Enabled: $controlEnabled)"" -ForegroundColor Gray
                                            
                                            # Look for Install, Yes, Allow, or other positive action buttons
                                            if ($controlEnabled -and 
                                                $controlName -match '(?i)^(Install|Yes|Allow|Permit|Grant|Authorize|OK)' -and
                                                $controlName -notmatch '(?i)(No|Cancel|Deny|Block|Don.t)') {{
                                                Write-Host ""  >> Found button to click: $controlName"" -ForegroundColor Green
                                                
                                                try {{
                                                    # Try Win32 SendMessage first (most reliable)
                                                    $nativeHandle = $control.Current.NativeWindowHandle
                                                    if ($nativeHandle -ne 0) {{
                                                        [Win32]::SendMessage([IntPtr]$nativeHandle, [Win32]::BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
                                                        Write-Host ""  >> Successfully clicked '$controlName' button!"" -ForegroundColor Green
                                                        $buttonClicked = $true
                                                        $clickCount++
                                                        $lastClickTime = Get-Date
                                                        $clickedInThisIteration = $true
                                                        Start-Sleep -Milliseconds 1500
                                                        break
                                                    }}
                                                }} catch {{
                                                    Write-Host ""  >> Failed to click button: $_"" -ForegroundColor Yellow
                                                }}
                                            }}
                                        }}
                                    }}
                                }} catch {{
                                    Write-Host ""  >> UI Automation failed: $_"" -ForegroundColor Yellow
                                }}
                                
                                # Second attempt: If no button was clicked, fall back to keyboard automation
                                # This is needed for real UAC prompts that run on secure desktop
                                if (-not $buttonClicked) {{
                                    Write-Host ""  >> No buttons found or clicked, falling back to keyboard automation"" -ForegroundColor Yellow
                                    try {{
                                        # Load Windows Forms for SendKeys
                                        Add-Type -AssemblyName System.Windows.Forms
                                        
                                        # Wait a moment for the window to fully load and focus
                                        Start-Sleep -Milliseconds 1000
                                        
                                        # Tab to the Yes button, then Enter
                                        [System.Windows.Forms.SendKeys]::SendWait(""{{TAB}}"")
                                        Start-Sleep -Milliseconds 200
                                        [System.Windows.Forms.SendKeys]::SendWait(""{{ENTER}}"")
                                        Write-Host ""  >> Sent Tab+Enter to UAC dialog"" -ForegroundColor Green
                                        
                                        $clickCount++
                                        $lastClickTime = Get-Date
                                        $clickedInThisIteration = $true
                                        Start-Sleep -Milliseconds 1500
                                    }} catch {{
                                        Write-Host ""  >> Keyboard automation also failed: $_"" -ForegroundColor Red
                                    }}
                                }}
                                
                                continue
                            }}
                            
                            # Detect InstallAware Wizard - needs longer delays for reloads
                            $isInstallAware = $windowTitle -match 'InstallAware'
                            $buttonDelay = 500
                            
                            $automation = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
                            
                            if ($automation) {{
                                # FIRST: Untick any ""Launch"" or ""Open"" checkboxes to prevent auto-launch
                                $checkboxCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::CheckBox)
                                $checkboxes = $automation.FindAll([System.Windows.Automation.TreeScope]::Descendants, $checkboxCondition)
                                
                                foreach ($checkbox in $checkboxes) {{
                                    $checkboxName = $checkbox.Current.Name
                                    # Untick Launch/Open checkboxes
                                    if ($checkboxName -match '(?i)launch|open|run|start') {{
                                        try {{
                                            $togglePattern = $checkbox.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
                                            $currentState = $togglePattern.Current.ToggleState
                                            if ($currentState -eq [System.Windows.Automation.ToggleState]::On) {{
                                                Write-Host ""  >> Unticking Launch checkbox: '$checkboxName'"" -ForegroundColor Cyan
                                                $togglePattern.Toggle()
                                                Start-Sleep -Milliseconds 300
                                            }}
                                        }} catch {{
                                            Write-Host ""  >> Could not untick checkbox: $_"" -ForegroundColor Yellow
                                        }}
                                    }}
                                }}
                                
                                # SECOND: Check for and select any 'I accept/agree' radio buttons (for Inno Setup installers like COEX)
                                # Note: Inno Setup's TNewRadioButton appears as Pane in UI Automation, not RadioButton
                                $radioCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::RadioButton)
                                $radioButtons = $automation.FindAll([System.Windows.Automation.TreeScope]::Descendants, $radioCondition)
                                
                                # Also check Panes that look like radio buttons (TNewRadioButton from Inno Setup)
                                $paneCondition2 = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Pane)
                                $panes2 = $automation.FindAll([System.Windows.Automation.TreeScope]::Descendants, $paneCondition2)
                                
                                # Combine radio buttons and panes that might be radio buttons
                                $allRadioControls = @()
                                foreach ($r in $radioButtons) {{ $allRadioControls += $r }}
                                foreach ($p in $panes2) {{
                                    $pClass = $p.Current.ClassName
                                    if ($pClass -eq 'TNewRadioButton') {{ $allRadioControls += $p }}
                                }}
                                
                                foreach ($radio in $allRadioControls) {{
                                    $radioName = $radio.Current.Name
                                    Write-Host ""  >> Checking control: '$radioName' (Class: $($radio.Current.ClassName))"" -ForegroundColor Gray
                                    
                                    # Match positive agreement only - exclude do not patterns
                                    if ($radioName -match '(?i)^I accept|^I agree' -and $radioName -notmatch '(?i)do not') {{
                                        try {{
                                            Write-Host ""  >> Found agreement control: '$radioName'"" -ForegroundColor Cyan
                                            # Try clicking directly with Win32 (most reliable for Inno Setup)
                                            $nativeHandle = $radio.Current.NativeWindowHandle
                                            if ($nativeHandle -ne 0) {{
                                                Write-Host ""  >> Clicking via Win32 BM_CLICK..."" -ForegroundColor Green
                                                [Win32]::SendMessage([IntPtr]$nativeHandle, [Win32]::BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
                                                Write-Host ""  >> Radio button clicked! Waiting 2 seconds for Next button to enable..."" -ForegroundColor Green
                                                Start-Sleep -Milliseconds 2000
                                                
                                                # Refresh the automation tree to get updated control states
                                                $automation = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
                                                Write-Host ""  >> Automation tree refreshed"" -ForegroundColor Green
                                            }} else {{
                                                Write-Host ""  >> No native handle available"" -ForegroundColor Yellow
                                            }}
                                        }} catch {{
                                            Write-Host ""  >> Failed to select radio button: $_"" -ForegroundColor Yellow
                                        }}
                                    }}
                                }}
                                
                                # After clicking radio buttons, re-scan the window for buttons
                                # (This ensures we get updated enabled states after radio selection)
                                # Look for buttons - check both Button and Pane control types
                                # (InstallAware uses TButton which appears as Pane in UI Automation)
                                $buttonCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
                                $paneCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Pane)
                                
                                $buttons = $automation.FindAll([System.Windows.Automation.TreeScope]::Descendants, $buttonCondition)
                                $panes = $automation.FindAll([System.Windows.Automation.TreeScope]::Descendants, $paneCondition)
                                
                                # Combine buttons and panes that look like buttons
                                $allClickableControls = @()
                                foreach ($btn in $buttons) {{ $allClickableControls += $btn }}
                                foreach ($pane in $panes) {{
                                    $paneName = $pane.Current.Name
                                    $paneClass = $pane.Current.ClassName
                                    # Include panes that are TButton, TNewButton, Button class, or have button-like names
                                    if ($paneClass -eq 'TButton' -or $paneClass -eq 'TNewButton' -or $paneClass -eq 'Button' -or $paneName -match '(?i)^(Next|Install|Accept|I Agree|Agree|Continue|OK|Yes|Finish|Close|Done|Back|Cancel)$') {{
                                        $allClickableControls += $pane
                                    }}
                                }}
                                
                                # Debug: List all clickable controls found in this window
                                if ($allClickableControls.Count -gt 0) {{
                                    Write-Host ""  Found $($allClickableControls.Count) clickable controls in window:"" -ForegroundColor Cyan
                                    foreach ($ctrl in $allClickableControls) {{
                                        $ctrlName = $ctrl.Current.Name
                                        $ctrlEnabled = $ctrl.Current.IsEnabled
                                        $ctrlType = $ctrl.Current.ControlType.ProgrammaticName
                                        $ctrlClass = $ctrl.Current.ClassName
                                        Write-Host ""    - '$ctrlName' (Type: $ctrlType, Class: $ctrlClass, Enabled: $ctrlEnabled)"" -ForegroundColor Gray
                                    }}
                                }} else {{
                                    Write-Host ""  No clickable controls found in this window"" -ForegroundColor Yellow
                                }}
                                
                                # Sort controls by priority: Agree/Accept first, then Next/Continue, then others
                                # This ensures license agreements are accepted before trying to continue
                                $sortedControls = $allClickableControls | Sort-Object {{
                                    $name = $_.Current.Name
                                    if ($name -match '(?i)^(Agree|Accept|I Agree)$') {{ return 1 }}
                                    elseif ($name -match '(?i)^(Next|Continue|Install)$') {{ return 2 }}
                                    elseif ($name -match '(?i)^(OK|Yes)$') {{ return 3 }}
                                    elseif ($name -match '(?i)^(Finish|Close|Done)$') {{ return 4 }}
                                    else {{ return 5 }}
                                }}
                                
                                $clickedButton = $false
                                foreach ($control in $sortedControls) {{
                                    $controlName = $control.Current.Name
                                    $controlEnabled = $control.Current.IsEnabled
                                    
                                    # Check for clickable controls - very flexible matching for installer buttons
                                    # Match any positive action button, allow Windows Security ""Yes"" buttons
                                    # Skip Back, Cancel, No, and Disagree buttons
                                    if ($controlEnabled -and 
                                        $controlName -match '(?i)(Next|Install|Accept|Agree|Continue|OK|Yes|Finish|Close|Done|Open|Select|Choose|Allow|Permit|Grant|Authorize)' -and 
                                        $controlName -notmatch '(?i)(Back|Cancel|Disagree|No|Deny|Block|Don.t)') {{
                                        Write-Host ""  >> Attempting to click control: $controlName (Enabled: $controlEnabled)"" -ForegroundColor Green
                                        
                                        # If clicking Continue/Next/Install, launch background popup clicker BEFORE the click
                                        # This prevents hanging if the main window becomes unresponsive during click
                                        if ($controlName -match '(?i)(Next|Install|Continue)') {{
                                            Write-Host ""  >> Launching background popup clicker BEFORE click attempt..."" -ForegroundColor Yellow
                                            
                                            # Create a temp file for the popup clicker script
                                            $popupScriptFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), ""popup-clicker-$([Guid]::NewGuid().ToString()).ps1"")
                                            
                                            # Write the script content as multi-line string
                                            $scriptContent = @""
try {{
    Write-Host '[Popup Clicker] Initializing...' -ForegroundColor Cyan
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    
    # Define Win32 API
    `$signature = '
[DllImport(`""user32.dll`"")]
public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

[DllImport(`""user32.dll`"")]
public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

[DllImport(`""user32.dll`"")]
public static extern bool IsWindowVisible(IntPtr hWnd);

[DllImport(`""user32.dll`"")]
public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
public const uint BM_CLICK = 0x00F5;
'
    
    Add-Type -MemberDefinition `$signature -Name Win32API -Namespace PInvoke -UsingNamespace System.Text
    
    Write-Host '[Popup Clicker] Watching for Click Agree dialog for 30 seconds...' -ForegroundColor Magenta
    `$endTime = (Get-Date).AddSeconds(30)
    `$iteration = 0
    while ((Get-Date) -lt `$endTime) {{
        `$iteration++
        if (`$iteration % 5 -eq 1) {{ Write-Host ""[Popup Clicker] Scan #`$iteration"" -ForegroundColor Gray }}
        
        `$foundWindows = @()
        `$callback = {{
            param(`$h, `$lParam)
            if ([PInvoke.Win32API]::IsWindowVisible(`$h)) {{
                `$sb = New-Object System.Text.StringBuilder 256
                [PInvoke.Win32API]::GetWindowText(`$h, `$sb, `$sb.Capacity) | Out-Null
                `$title = `$sb.ToString().Trim()
                # Match ANY setup, installer, or confirmation dialog - be very aggressive
                if (`$title -match '(?i)Setup|Install|Wizard|Click|Agree|Disagree|License|Folder|Confirm|Warning|Question|Exists|Overwrite|Replace|Security|User Account Control|Publisher|Allow|Permission') {{
                    `$script:foundWindows += [PSCustomObject]@{{ Handle = `$h; Title = `$title }}
                }}
            }}
            return `$true
        }}
        [PInvoke.Win32API]::EnumWindows(`$callback, [IntPtr]::Zero) | Out-Null
        
        if (`$foundWindows.Count -gt 0) {{
            foreach (`$win in `$foundWindows) {{
                Write-Host ""[Popup Clicker] Found: '`$(`$win.Title)'"" -ForegroundColor Green
                try {{
                    `$automation = [System.Windows.Automation.AutomationElement]::FromHandle(`$win.Handle)
                    if (`$automation) {{
                        # First: Untick any Launch/Open checkboxes
                        `$checkboxCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::CheckBox)
                        `$checkboxes = `$automation.FindAll([System.Windows.Automation.TreeScope]::Descendants, `$checkboxCondition)
                        
                        foreach (`$checkbox in `$checkboxes) {{
                            `$checkboxName = `$checkbox.Current.Name
                            Write-Host ""[Popup Clicker] Found checkbox: '`$checkboxName'"" -ForegroundColor Cyan
                            
                            # Untick Launch/Open checkboxes
                            if (`$checkboxName -match '(?i)launch|open|run|start') {{
                                try {{
                                    `$togglePattern = `$checkbox.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
                                    `$currentState = `$togglePattern.Current.ToggleState
                                    
                                    if (`$currentState -eq [System.Windows.Automation.ToggleState]::On) {{
                                        Write-Host '[Popup Clicker] Unticking Launch/Open checkbox!' -ForegroundColor Green
                                        `$togglePattern.Toggle()
                                        Start-Sleep -Milliseconds 300
                                    }}
                                }} catch {{
                                    Write-Host ""[Popup Clicker] Could not untick checkbox: `$_"" -ForegroundColor Yellow
                                }}
                            }}
                            
                            # Check agreement checkboxes
                            if (`$checkboxName -match '(?i)agree|accept') {{
                                try {{
                                    `$togglePattern = `$checkbox.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
                                    `$currentState = `$togglePattern.Current.ToggleState
                                    Write-Host ""[Popup Clicker] Checkbox state: `$currentState"" -ForegroundColor Gray
                                    
                                    if (`$currentState -eq [System.Windows.Automation.ToggleState]::Off) {{
                                        Write-Host '[Popup Clicker] Checking the agreement checkbox!' -ForegroundColor Green
                                        `$togglePattern.Toggle()
                                        Start-Sleep -Milliseconds 500
                                    }}
                                }} catch {{
                                    Write-Host ""[Popup Clicker] Could not toggle checkbox: `$_"" -ForegroundColor Yellow
                                }}
                            }}
                        }}
                        
                        # Also check for radio buttons (like Inno Setup's TNewRadioButton)
                        `$radioCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::RadioButton)
                        `$radioButtons = `$automation.FindAll([System.Windows.Automation.TreeScope]::Descendants, `$radioCondition)
                        
                        foreach (`$radio in `$radioButtons) {{
                            `$radioName = `$radio.Current.Name
                            Write-Host ""[Popup Clicker] Found radio button: '`$radioName'"" -ForegroundColor Cyan
                            
                            if (`$radioName -match '(?i)agree|accept') {{
                                try {{
                                    Write-Host '[Popup Clicker] Clicking agreement radio button!' -ForegroundColor Green
                                    # Try SelectionItemPattern first
                                    try {{
                                        `$selectPattern = `$radio.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
                                        `$selectPattern.Select()
                                        Write-Host '[Popup Clicker] Used SelectionItemPattern' -ForegroundColor Gray
                                    }} catch {{
                                        # Fallback to TogglePattern
                                        try {{
                                            `$togglePattern = `$radio.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
                                            `$togglePattern.Toggle()
                                            Write-Host '[Popup Clicker] Used TogglePattern' -ForegroundColor Gray
                                        }} catch {{
                                            # Last resort: send click message
                                            `$nativeHandle = `$radio.Current.NativeWindowHandle
                                            if (`$nativeHandle -ne 0) {{
                                                [PInvoke.Win32API]::SendMessage([IntPtr]`$nativeHandle, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
                                                Write-Host '[Popup Clicker] Used Win32 BM_CLICK' -ForegroundColor Gray
                                            }}
                                        }}
                                    }}
                                    Start-Sleep -Milliseconds 500
                                }} catch {{
                                    Write-Host ""[Popup Clicker] Could not click radio button: `$_"" -ForegroundColor Yellow
                                }}
                            }}
                        }}
                        
                        # Now look for clickable buttons (Yes, OK, Agree, Continue, Next, etc.)
                        `$buttonCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
                        `$buttons = `$automation.FindAll([System.Windows.Automation.TreeScope]::Descendants, `$buttonCondition)
                        
                        `$paneCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Pane)
                        `$panes = `$automation.FindAll([System.Windows.Automation.TreeScope]::Descendants, `$paneCondition)
                        
                        # Combine buttons and panes
                        `$allControls = @()
                        foreach (`$btn in `$buttons) {{ `$allControls += `$btn }}
                        foreach (`$pane in `$panes) {{
                            `$pClass = `$pane.Current.ClassName
                            if (`$pClass -eq 'TButton' -or `$pClass -eq 'TNewButton' -or `$pClass -eq 'Button') {{
                                `$allControls += `$pane
                            }}
                        }}
                        
                        foreach (`$control in `$allControls) {{
                            `$ctrlName = `$control.Current.Name
                            `$ctrlEnabled = `$control.Current.IsEnabled
                            # Very flexible button matching - include Windows Security ""Yes"", ""Allow"" buttons
                            if (`$ctrlEnabled -and 
                                `$ctrlName -match '(?i)^(Yes|OK|Agree|Continue|Next|Install|Accept|Allow|Permit|Grant|Authorize)' -and
                                `$ctrlName -notmatch '(?i)(No|Cancel|Deny|Block|Don.t)') {{
                                Write-Host ""[Popup Clicker] Clicking button: `$ctrlName"" -ForegroundColor Green
                                `$nativeHandle = `$control.Current.NativeWindowHandle
                                if (`$nativeHandle -ne 0) {{
                                    [PInvoke.Win32API]::SendMessage([IntPtr]`$nativeHandle, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
                                    Write-Host '[Popup Clicker] SUCCESS!' -ForegroundColor Green
                                    Start-Sleep -Seconds 1
                                    break
                                }}
                            }}
                        }}
                    }}
                }} catch {{
                    Write-Host ""[Popup Clicker] Error: `$_"" -ForegroundColor Red
                }}
            }}
        }}
        Start-Sleep -Milliseconds 500
    }}
    Write-Host '[Popup Clicker] Timeout - no dialog found' -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}} catch {{
    Write-Host ""[Popup Clicker] FATAL ERROR: `$_"" -ForegroundColor Red
    Start-Sleep -Seconds 5
}}
""@
                                            
                                            Set-Content -Path $popupScriptFile -Value $scriptContent
                                            Start-Process powershell -ArgumentList ""-NoProfile"", ""-File"", $popupScriptFile -WindowStyle Hidden
                                            Write-Host ""  >> Background popup clicker launched"" -ForegroundColor Green
                                        }}
                                        
                                        # Track that we ATTEMPTED a click, regardless of success
                                        # This ensures we re-scan for dialogs even if click methods fail
                                        $clickedInThisIteration = $true
                                        Write-Host ""  >> Set clickedInThisIteration = TRUE"" -ForegroundColor Cyan
                                        
                                        try {{
                                            # Try InvokePattern first
                                            try {{
                                                $invokePattern = $control.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                                                $invokePattern.Invoke()
                                                Write-Host ""  Success: InvokePattern"" -ForegroundColor Cyan
                                            }} catch {{
                                                # If InvokePattern fails, try LegacyIAccessiblePattern (for TButton controls)
                                                try {{
                                                    $legacyPattern = $control.GetCurrentPattern([System.Windows.Automation.LegacyIAccessiblePattern]::Pattern)
                                                    $legacyPattern.DoDefaultAction()
                                                    Write-Host ""  Success: LegacyIAccessiblePattern"" -ForegroundColor Cyan
                                                }} catch {{
                                                    # Try Win32 SendMessage to the native handle
                                                    try {{
                                                        $nativeHandle = $control.Current.NativeWindowHandle
                                                        if ($nativeHandle -ne 0) {{
                                                            $hwnd = [IntPtr]$nativeHandle
                                                            # Try BM_CLICK first (standard button message)
                                                            [Win32]::SendMessage($hwnd, [Win32]::BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
                                                            Write-Host ""  Success: Win32 BM_CLICK"" -ForegroundColor Cyan
                                                        }} else {{
                                                            throw ""No native window handle available""
                                                        }}
                                                    }} catch {{
                                                        # Last resort: try mouse click messages
                                                        try {{
                                                            $nativeHandle = $control.Current.NativeWindowHandle
                                                            if ($nativeHandle -ne 0) {{
                                                                $hwnd = [IntPtr]$nativeHandle
                                                                [Win32]::SendMessage($hwnd, [Win32]::WM_LBUTTONDOWN, [IntPtr]1, [IntPtr]0) | Out-Null
                                                                [Win32]::SendMessage($hwnd, [Win32]::WM_LBUTTONUP, [IntPtr]0, [IntPtr]0) | Out-Null
                                                                Write-Host ""  Success: Win32 mouse click"" -ForegroundColor Cyan
                                                            }} else {{
                                                                throw ""No native window handle for mouse click""
                                                            }}
                                                        }} catch {{
                                                            Write-Host ""  All click methods failed for $controlName : $_"" -ForegroundColor Red
                                                            # Don't continue - still wait and re-scan since dialog might appear anyway
                                                        }}
                                                    }}
                                                }}
                                            }}
                                            
                                            $clickCount++
                                            $lastClickTime = Get-Date
                                            $clickedButton = $true
                                            
                                            # Wait for UI to respond, even if click failed
                                            # Use longer delay for InstallAware wizards
                                            $delayMs = if ($isInstallAware) {{ 500 }} else {{ 200 }}
                                            Write-Host ""  Starting sleep $delayMs ms..."" -ForegroundColor DarkGray
                                            Start-Sleep -Milliseconds $delayMs
                                            Write-Host ""  Sleep complete"" -ForegroundColor DarkGray
                                            
                                            # Give popup dialogs time to appear (whether click succeeded or not)
                                            # Increased delay for slower machines (especially NovaLCT driver dialogs)
                                            Write-Host ""  Waiting for potential popup dialogs..."" -ForegroundColor Gray
                                            Write-Host ""  Starting sleep 1500ms..."" -ForegroundColor DarkGray
                                            Start-Sleep -Milliseconds 1500
                                            Write-Host ""  Sleep complete, breaking from control loop"" -ForegroundColor DarkGray
                                            break
                                        }} catch {{
                                            Write-Host ""  Failed to click $controlName : $_"" -ForegroundColor Red
                                            # Still wait for popup even on failure
                                            Start-Sleep -Milliseconds 1500
                                        }}
                                    }}
                                }}
                                
                                # If no button was clicked and window contains 'Complete' or 'Finish', try SendKeys as fallback
                                if (-not $clickedButton -and $windowTitle -match '(?i)Complete|Finish') {{
                                    Write-Host ""  Using SendKeys fallback for: $windowTitle"" -ForegroundColor Yellow
                                    [System.Windows.Forms.SendKeys]::SendWait('{{ENTER}}')
                                    $clickCount++
                                    $clickedButton = $true
                                    Start-Sleep -Milliseconds 1000
                                }}
                            }}
                        }}
                        
                        # After processing all windows, if we clicked any button in THIS iteration, just sleep briefly
                        # The background popup clicker was already launched before the click attempt
                        Write-Host ""Checking re-scan condition: clickedInThisIteration = $clickedInThisIteration"" -ForegroundColor Cyan
                        if ($clickedInThisIteration) {{
                            Write-Host ""  Sleeping 600ms before next iteration..."" -ForegroundColor Yellow
                            Start-Sleep -Milliseconds 600
                        }}
                        
                        # Sleep briefly before next iteration - increased for slower machines
                        Start-Sleep -Milliseconds 300
                        
                        # No inactivity timeout - continue until deployment completes
                    }} catch {{
                        Write-Host ""ERROR in main loop iteration: $_"" -ForegroundColor Red
                        Start-Sleep -Milliseconds 1000
                    }}
                }}
                
                Write-Host ""Auto-click script terminating."" -ForegroundColor Yellow
            ";
            
            // Write script to temp file
            tempScriptPath = Path.Combine(Path.GetTempPath(), $"autoclicker_{Guid.NewGuid()}.ps1");
            File.WriteAllText(tempScriptPath, script);
            
            // Start PowerShell process directly so we can kill it on cancellation
            process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = $"-NoProfile -ExecutionPolicy Bypass -File \"{tempScriptPath}\"",
                    UseShellExecute = true,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden,
                    Verb = "runas" // Elevate to see elevated installer windows
                }
            };
            
            process.Start();
            autoClickerProcess = process; // Store so we can kill it on cancellation
            
            // Wait for process to exit or cancellation
            while (!process.HasExited && !cancellationToken.IsCancellationRequested)
            {
                await Task.Delay(500, cancellationToken);
            }
            
            // If cancelled, kill the process
            if (cancellationToken.IsCancellationRequested && !process.HasExited)
            {
                try
                {
                    process.Kill(entireProcessTree: true);
                    LogMessage($"  Auto-click process terminated", Color.Gray);
                }
                catch { }
            }
            
            LogMessage($"  Auto-click stopped", Color.Gray);
        }
        catch (OperationCanceledException)
        {
            LogMessage($"  Auto-click cancelled", Color.Gray);
            if (process != null && !process.HasExited)
            {
                try { process.Kill(entireProcessTree: true); } catch { }
            }
        }
        catch (Exception ex)
        {
            LogMessage($"  Auto-click error: {ex.Message}", Color.Gray);
        }
        finally
        {
            // Clean up temp file
            if (tempScriptPath != null && File.Exists(tempScriptPath))
            {
                try { File.Delete(tempScriptPath); } catch { }
            }
            
            if (process != null)
            {
                try { process.Dispose(); } catch { }
            }
            
            autoClickerProcess = null;
        }
    }

    private async Task LaunchDriverWizardWatcherAsync()
    {
        try
        {
            LogMessage("  Launching Device Driver Wizard watcher...", Color.Cyan);
            
            string script = @"
                Add-Type -AssemblyName UIAutomationClient
                Add-Type -AssemblyName UIAutomationTypes
                
                Add-Type @""
                using System;
                using System.Runtime.InteropServices;
                using System.Text;
                
                public class Win32 {
                    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
                    
                    [DllImport(""user32.dll"")]
                    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);
                    
                    [DllImport(""user32.dll"")]
                    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
                    
                    [DllImport(""user32.dll"")]
                    public static extern bool IsWindowVisible(IntPtr hWnd);
                    
                    [DllImport(""user32.dll"")]
                    public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
                    
                    public const uint BM_CLICK = 0x00F5;
                }
""@
                
                Write-Host '===== Device Driver Wizard Watcher Started =====' -ForegroundColor Green
                Write-Host 'Watching for Device Driver Installation Wizard...' -ForegroundColor Cyan
                
                $endTime = (Get-Date).AddSeconds(300) # Watch for 5 minutes
                $foundWizard = $false
                $iteration = 0
                
                while ((Get-Date) -lt $endTime -and -not $foundWizard) {
                    $iteration++
                    Write-Host ""[Watcher] Iteration $iteration - Scanning for wizard..."" -ForegroundColor DarkCyan
                    
                    $callback = {
                        param($h, $lParam)
                        if ([Win32]::IsWindowVisible($h)) {
                            $sb = New-Object System.Text.StringBuilder 256
                            [Win32]::GetWindowText($h, $sb, $sb.Capacity) | Out-Null
                            $title = $sb.ToString().Trim()
                            
                            if ($title) {
                                Write-Host ""  Checking window: '$title'"" -ForegroundColor DarkGray
                            }
                            
                            if ($title -match '(?i)Device.*Driver|DPInst|Driver.*Install') {
                                Write-Host ""  >>> WIZARD FOUND: '$title'"" -ForegroundColor Green
                                $script:wizardHandle = $h
                                $script:foundWizard = $true
                            }
                        }
                        return $true
                    }
                    [Win32]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null
                    
                    if ($foundWizard) {
                        Write-Host '[Watcher] ===== WIZARD DETECTED! Starting autoclicker... =====' -ForegroundColor Yellow
                        
                        # Keep clicking through wizard until it closes
                        $wizardTimeout = (Get-Date).AddSeconds(120)
                        while ((Get-Date) -lt $wizardTimeout) {
                            # Check if wizard still exists
                            if (-not [Win32]::IsWindowVisible($wizardHandle)) {
                                Write-Host '[Watcher] Wizard closed!' -ForegroundColor Green
                                break
                            }
                            
                            try {
                                $automation = [System.Windows.Automation.AutomationElement]::FromHandle($wizardHandle)
                                if ($automation) {
                                    Write-Host ""[Watcher] Scanning wizard for controls..."" -ForegroundColor Yellow
                                    
                                    # Find all controls (not just buttons)
                                    $allCondition = [System.Windows.Automation.Condition]::TrueCondition
                                    $allControls = $automation.FindAll([System.Windows.Automation.TreeScope]::Descendants, $allCondition)
                                    Write-Host ""[Watcher] Found $($allControls.Count) total controls"" -ForegroundColor DarkCyan
                                    
                                    $clickedButton = $false
                                    
                                    # Look through all controls for buttons
                                    foreach ($ctrl in $allControls) {
                                        $ctrlName = $ctrl.Current.Name
                                        $ctrlClass = $ctrl.Current.ClassName
                                        $ctrlType = $ctrl.Current.ControlType.ProgrammaticName
                                        $ctrlEnabled = $ctrl.Current.IsEnabled
                                        
                                        # Look for actual button controls (Win32 Button class or buttons by name)
                                        if ($ctrlClass -match '(?i)button' -or $ctrlType -match '(?i)button') {
                                            Write-Host ""[Watcher]   Found button: Name='$ctrlName', Class='$ctrlClass', Type='$ctrlType', Enabled=$ctrlEnabled"" -ForegroundColor Cyan
                                            
                                            if ($ctrlEnabled -and $ctrlName -match '(?i)^(Next|Finish|Install|OK|Yes|Continue|Accept)') {
                                                Write-Host ""[Watcher] >>> CLICKING: $ctrlName"" -ForegroundColor Green
                                                $handle = $ctrl.Current.NativeWindowHandle
                                                if ($handle -ne 0) {
                                                    [Win32]::SendMessage([IntPtr]$handle, [Win32]::BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
                                                    $clickedButton = $true
                                                    Start-Sleep -Milliseconds 1500
                                                    break
                                                }
                                            }
                                        }
                                    }
                                    
                                    if (-not $clickedButton) {
                                        Write-Host ""[Watcher] No clickable buttons found this iteration"" -ForegroundColor Yellow
                                    }
                                }
                            } catch {
                                Write-Host ""[Watcher] Error: $_"" -ForegroundColor Red
                            }
                            
                            Start-Sleep -Milliseconds 500
                        }
                    }
                    
                    Start-Sleep -Milliseconds 2000
                }
                
                Write-Host '===== Device Driver Wizard Watcher Ended =====' -ForegroundColor Green
            ";
            
            await RunPowerShellScriptAsync(script, 300000, showWindow: false); // 5 minute timeout
        }
        catch (Exception ex)
        {
            LogMessage($"  Driver wizard watcher error: {ex.Message}", Color.Yellow);
        }
    }

    private void LogMessage(string message, Color? color = null)
    {
        if (txtLog.InvokeRequired)
        {
            txtLog.Invoke(() => LogMessage(message, color));
            return;
        }

        txtLog.SelectionStart = txtLog.TextLength;
        txtLog.SelectionLength = 0;
        txtLog.SelectionColor = color ?? Color.White;
        txtLog.AppendText(message + Environment.NewLine);
        txtLog.SelectionColor = txtLog.ForeColor;
        txtLog.ScrollToCaret();
    }

    private bool IsAdministrator()
    {
        var identity = System.Security.Principal.WindowsIdentity.GetCurrent();
        var principal = new System.Security.Principal.WindowsPrincipal(identity);
        return principal.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
    }

    private void StartFriendlyMessages()
    {
        currentMessageIndex = 0;
        statusMessageTimer = new System.Windows.Forms.Timer();
        statusMessageTimer.Interval = 8000; // Change message every 8 seconds
        statusMessageTimer.Tick += (s, e) =>
        {
            currentMessageIndex = (currentMessageIndex + 1) % friendlyMessages.Length;
            BeginInvoke(() => 
            {
                // Update the summary panel title with friendly messages
                lblSummaryTitle.Text = friendlyMessages[currentMessageIndex];
                lblSummaryTitle.ForeColor = Color.FromArgb(0, 120, 212); // Friendly blue color
            });
        };
        lblSummaryTitle.Text = friendlyMessages[0];
        lblSummaryTitle.ForeColor = Color.FromArgb(0, 120, 212);
        statusMessageTimer.Start();
    }
    
    private void StopFriendlyMessages()
    {
        if (statusMessageTimer != null)
        {
            statusMessageTimer.Stop();
            statusMessageTimer.Dispose();
            statusMessageTimer = null;
        }
        
        // Restore original title
        BeginInvoke(() =>
        {
            lblSummaryTitle.Text = "Deployment Complete! ✓";
            lblSummaryTitle.ForeColor = Color.Green;
        });
    }

    private async Task CheckNetworkConnectionAsync()
    {
        // Don't check network during deployment (status is managed elsewhere)
        if (isDeploying) return;
        
        try
        {
            // Check if network interface is available
            bool networkAvailable = NetworkInterface.GetIsNetworkAvailable();
            
            if (!networkAvailable)
            {
                isNetworkAvailable = false;
                UpdateDeployButtonState();
                return;
            }

            // Try to ping a reliable host (Google DNS)
            using var ping = new Ping();
            try
            {
                var reply = await ping.SendPingAsync("8.8.8.8", 3000);
                
                if (reply.Status == IPStatus.Success)
                {
                    isNetworkAvailable = true;
                }
                else
                {
                    isNetworkAvailable = false;
                }
            }
            catch
            {
                isNetworkAvailable = false;
            }
        }
        catch (Exception ex)
        {
            isNetworkAvailable = false;
            LogMessage($"Network check error: {ex.Message}", Color.Orange);
        }
        
        UpdateDeployButtonState();
    }

    private void UpdateDeployButtonState()
    {
        if (InvokeRequired)
        {
            BeginInvoke(() => UpdateDeployButtonState());
            return;
        }
        
        // Don't update during deployment
        if (isDeploying) return;
        
        // Check if anything is selected
        bool hasSelection = HasCheckedApplications() || chkPCStandardization.Checked;
        
        // Determine button state and status message
        if (!isNetworkAvailable)
        {
            btnInstall.Enabled = false;
            lblStatus.Text = "Network connection required";
            lblStatus.ForeColor = Color.Red;
        }
        else if (!hasSelection)
        {
            btnInstall.Enabled = false;
            lblStatus.Text = "Select applications to deploy";
            lblStatus.ForeColor = Color.Gray;
        }
        else
        {
            btnInstall.Enabled = true;
            lblStatus.Text = "Ready to deploy";
            lblStatus.ForeColor = Color.Gray;
        }
    }
    
    private void UpdateDeployButtonAppearance()
    {
        if (btnInstall.Enabled)
        {
            // Enabled state - vibrant blue
            btnInstall.BackColor = Color.FromArgb(0, 120, 212);
            btnInstall.ForeColor = Color.White;
            btnInstall.Cursor = Cursors.Hand;
        }
        else
        {
            // Disabled state - subtle greyed out version with same text color
            btnInstall.BackColor = Color.FromArgb(180, 180, 180);
            btnInstall.ForeColor = Color.White;
            btnInstall.Cursor = Cursors.Default;
        }
    }

    private void ShowNetworkWarning(string message)
    {
        // Network warnings are now shown in the status label instead of a popup
        LogMessage($"⚠️ Network Warning: {message}", Color.Orange);
        LogMessage("  Application deployments require internet connection", Color.Orange);
    }
    
    private void InitializeDeploymentTasks()
    {
        deploymentTasks.Clear();
        
        // Add PC Standardization if checked
        if (chkPCStandardization.Checked)
        {
            deploymentTasks.Add(new DeploymentTask { Name = "PC Standardization" });
        }
        
        // Add selected applications
        var apps = GetCheckedApplications();
        foreach (var app in apps)
        {
            deploymentTasks.Add(new DeploymentTask { Name = app.Key });
        }
    }
    
    private void UpdateSummaryDisplay()
    {
        if (txtSummary.InvokeRequired)
        {
            txtSummary.Invoke(() => UpdateSummaryDisplay());
            return;
        }
        
        txtSummary.Clear();
        
        foreach (var task in deploymentTasks)
        {
            txtSummary.SelectionStart = txtSummary.TextLength;
            
            // Add status icon with larger font
            txtSummary.SelectionFont = new Font("Segoe UI", 14);
            txtSummary.SelectionColor = task.StatusColor;
            txtSummary.AppendText($"{task.Status}  ");
            
            // Add task name
            txtSummary.SelectionFont = new Font("Segoe UI", 10, FontStyle.Bold);
            txtSummary.SelectionColor = Color.Black;
            txtSummary.AppendText($"{task.Name}");
            
            // Add details on same line
            txtSummary.SelectionFont = new Font("Segoe UI", 9);
            txtSummary.SelectionColor = Color.Gray;
            txtSummary.AppendText($" - {task.Details}\n");
        }
    }
    
    private void UpdateTaskStatus(string taskName, string status, string details, Color color)
    {
        var task = deploymentTasks.FirstOrDefault(t => t.Name == taskName);
        if (task != null)
        {
            task.Status = status;
            task.Details = details;
            task.StatusColor = color;
            UpdateSummaryDisplay();
        }
    }

    private async Task CloseAppWindowsAsync(string appName, int delayMs = 15000, params string[] processNames)
    {
        try
        {
            // Wait a moment for the app to launch
            await Task.Delay(delayMs);
            
            LogMessage($"  Checking for auto-launched {appName} windows...", Color.Gray);
            
            foreach (string processName in processNames)
            {
                string script = $@"
                    $processName = '{processName}'
                    $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
                    
                    if ($processes) {{
                        foreach ($proc in $processes) {{
                            try {{
                                $proc.Kill()
                                Write-Host ""Closed $processName (PID: $($proc.Id))""
                            }} catch {{
                                Write-Host ""Could not close $processName : $_""
                            }}
                        }}
                    }}
                ";
                
                await RunPowerShellScriptAsync(script, 5000, showWindow: false);
            }
            
            LogMessage($"  ✓ Closed auto-launched {appName} windows", Color.Green);
        }
        catch (Exception ex)
        {
            LogMessage($"  Note: Could not close {appName} windows: {ex.Message}", Color.Yellow);
        }
    }
}


