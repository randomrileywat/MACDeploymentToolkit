# Supabase Package Index — Architecture & Handoff Guide

This document summarizes the data-driven package index system built for the PC Deployment Toolkit and provides everything needed to replicate it in the Mac Deployment Toolkit.

---

## Supabase Connection Info

| Key | Value |
|---|---|
| **Project URL** | `https://incdoepqrbwaagatikgb.supabase.co` |
| **Service Key** | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImluY2RvZXBxcmJ3YWFnYXRpa2diIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjkwNzA0OSwiZXhwIjoyMDc4NDgzMDQ5fQ.5qjYJq7OGWAdBIVZqzpRE71aJEEOvbko9m3VDVJuQQA` |
| **Storage Bucket** | `installers` (already hosts .exe/.zip/.msi files with signed URLs) |

---

## Table Schema: `packages`

The `packages` table is the single source of truth for all deployable software. It already exists and is seeded with all 28 PC packages. Mac packages are added as **new rows** — no migration needed, just INSERT statements.

```sql
CREATE TABLE packages (
    id                          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name                        TEXT NOT NULL,
    version                     TEXT,
    category                    TEXT NOT NULL,         -- 'Audio', 'Video', 'Lighting', etc.
    platforms                   TEXT[] NOT NULL DEFAULT '{pc}',
    -- ↑ Array of: 'pc', 'mac_intel', 'mac_apple_silicon'
    -- A package can target multiple platforms: '{pc,mac_apple_silicon}'

    -- Installation
    install_method              TEXT NOT NULL DEFAULT 'direct_download',
    -- Values: 'winget', 'direct_download', 'extract_to_desktop'
    -- For Mac, you'd add: 'brew', 'dmg', 'pkg', 'app_bundle', etc.
    winget_id                   TEXT,                  -- PC only (winget package ID)
    download_url                TEXT,                  -- Direct download link or Supabase storage signed URL
    install_args                TEXT DEFAULT '/S',     -- Installer CLI arguments

    -- Detection (how to check if already installed)
    detection_method            TEXT NOT NULL DEFAULT 'registry_name',
    -- Values: 'winget', 'registry_name', 'file_path', 'file_paths', 'none'
    -- For Mac, you'd use: 'file_path', 'app_bundle', 'brew', 'none'
    detection_value             TEXT,
    -- For file_paths: pipe-delimited list of paths to check

    -- Post-install behavior
    post_install_close_windows  TEXT[] DEFAULT '{}',   -- Window titles to close after install
    post_install_close_delay_ms INTEGER DEFAULT 15000, -- Wait before closing windows
    pin_to_taskbar              BOOLEAN DEFAULT FALSE,
    also_install_winget_id      TEXT,                  -- Companion winget package (e.g. VLC for video content)
    launch_driver_watcher       BOOLEAN DEFAULT FALSE, -- Special handler for NovaLCT driver wizard

    -- Fallback (if primary install fails, try a direct download)
    fallback_download_url       TEXT,
    fallback_install_args       TEXT,

    -- Metadata
    enabled                     BOOLEAN DEFAULT TRUE,
    sort_order                  INTEGER DEFAULT 0,     -- Controls display order in the UI
    created_at                  TIMESTAMPTZ DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ DEFAULT NOW()
);
```

### Indexes
- **GIN** on `platforms` — enables fast array-contains queries (`cs.{mac_apple_silicon}`)
- **B-tree** on `category` and `enabled`

### Row-Level Security
- Public read is allowed (SELECT for all)
- Write access restricted to `service_role`

### Trigger
- `update_packages_updated_at` automatically sets `updated_at = NOW()` on every row update

---

## PostgREST API — How to Query Packages

The toolkit fetches packages via Supabase's PostgREST API (no client SDK needed — just HTTP).

### Request

```
GET {SUPABASE_URL}/rest/v1/packages?enabled=eq.true&platforms=cs.{PLATFORM}&order=sort_order.asc&select=*
```

### Headers

```
apikey: {SUPABASE_SERVICE_KEY}
Authorization: Bearer {SUPABASE_SERVICE_KEY}
```

### Platform Filter Values

| Platform | `platforms=cs.{...}` filter |
|---|---|
| Windows PC | `platforms=cs.{pc}` |
| Intel Mac | `platforms=cs.{mac_intel}` |
| Apple Silicon Mac | `platforms=cs.{mac_apple_silicon}` |

The `cs.` operator means "contains" — it checks if the row's `platforms` array contains the specified value. A package with `platforms = '{pc,mac_apple_silicon}'` will appear in both PC and Apple Silicon Mac queries.

### Example cURL (Mac Apple Silicon)

```bash
curl "https://incdoepqrbwaagatikgb.supabase.co/rest/v1/packages?enabled=eq.true&platforms=cs.{mac_apple_silicon}&order=sort_order.asc&select=*" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImluY2RvZXBxcmJ3YWFnYXRpa2diIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjkwNzA0OSwiZXhwIjoyMDc4NDgzMDQ5fQ.5qjYJq7OGWAdBIVZqzpRE71aJEEOvbko9m3VDVJuQQA" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImluY2RvZXBxcmJ3YWFnYXRpa2diIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjkwNzA0OSwiZXhwIjoyMDc4NDgzMDQ5fQ.5qjYJq7OGWAdBIVZqzpRE71aJEEOvbko9m3VDVJuQQA"
```

### Response Format (JSON array)

```json
[
  {
    "id": "abc-123",
    "name": "Dante Controller",
    "version": null,
    "category": "Audio",
    "platforms": ["mac_apple_silicon"],
    "install_method": "dmg",
    "winget_id": null,
    "download_url": "https://...",
    "install_args": null,
    "detection_method": "app_bundle",
    "detection_value": "/Applications/Dante Controller.app",
    "post_install_close_windows": [],
    "post_install_close_delay_ms": 15000,
    "pin_to_taskbar": false,
    "also_install_winget_id": null,
    "fallback_download_url": null,
    "fallback_install_args": null,
    "launch_driver_watcher": false,
    "enabled": true,
    "sort_order": 101
  }
]
```

---

## Data Model: PackageInfo

Each row maps to a `PackageInfo` object. JSON keys use **snake_case** matching the Supabase column names.

| Property | JSON Key | Type | Purpose |
|---|---|---|---|
| `Id` | `id` | string (UUID) | Row identifier |
| `Name` | `name` | string | Display name — "Dante Controller" |
| `Version` | `version` | string? | Optional version — "10.2" |
| `Category` | `category` | string | Grouping — "Audio", "Video", etc. |
| `Platforms` | `platforms` | string[] | `["pc"]`, `["mac_apple_silicon"]`, or both |
| `InstallMethod` | `install_method` | string | How to install (see below) |
| `WingetId` | `winget_id` | string? | Winget package ID (PC only) |
| `DownloadUrl` | `download_url` | string? | Direct download URL |
| `InstallArgs` | `install_args` | string? | CLI flags for the installer |
| `DetectionMethod` | `detection_method` | string | How to check if already installed |
| `DetectionValue` | `detection_value` | string? | Detection-specific value |
| `PostInstallCloseWindows` | `post_install_close_windows` | string[]? | Window titles to close after install |
| `PostInstallCloseDelayMs` | `post_install_close_delay_ms` | int | Delay before closing (ms) |
| `PinToTaskbar` | `pin_to_taskbar` | bool | Pin to taskbar/dock after install |
| `AlsoInstallWingetId` | `also_install_winget_id` | string? | Companion package to also install |
| `FallbackDownloadUrl` | `fallback_download_url` | string? | Backup download URL |
| `FallbackInstallArgs` | `fallback_install_args` | string? | Flags for fallback installer |
| `LaunchDriverWatcher` | `launch_driver_watcher` | bool | Launch special driver wizard handler |
| `Enabled` | `enabled` | bool | Whether to show in UI |
| `SortOrder` | `sort_order` | int | Display ordering (lower = higher) |

Computed: `DisplayName` = `"{Name} {Version}"` or just `"{Name}"` if version is null.

---

## 3-Tier Fallback Pattern

The toolkit never fails to populate its UI. It tries three sources in order:

```
1. Supabase REST API  →  (success) → cache locally & use
       ↓ (fail)
2. Local JSON cache   →  (success) → filter by platform & use
       ↓ (fail)
3. Hardcoded defaults →  always available, compiled into the app
```

### Implementation (PC version in C#)

```csharp
public async Task<List<PackageInfo>> GetPackagesAsync(string platform = "pc")
{
    // 1. Try Supabase
    try {
        var packages = await FetchFromSupabaseAsync(platform);
        if (packages.Count > 0) {
            await CachePackagesAsync(packages);  // save to local file
            return packages;
        }
    } catch { /* fall through */ }

    // 2. Try cache
    try {
        var cached = await LoadCachedPackagesAsync();
        if (cached.Count > 0)
            return cached.Where(p => p.Platforms.Contains(platform)).ToList();
    } catch { /* fall through */ }

    // 3. Hardcoded fallback
    return GetHardcodedPackages(platform);
}
```

### Cache Location
- **PC**: `%LOCALAPPDATA%\PCDeploymentToolkit\package_cache.json`
- **Mac (suggested)**: `~/Library/Application Support/MacDeploymentToolkit/package_cache.json`

---

## Install Methods — PC vs Mac Mapping

| PC Install Method | Mac Equivalent | Notes |
|---|---|---|
| `winget` | `brew` | Homebrew cask for GUI apps |
| `direct_download` (.exe) | `dmg` or `pkg` | Mount DMG → copy .app, or run .pkg installer |
| `extract_to_desktop` (.zip) | `extract_to_desktop` | Same — unzip to ~/Desktop |

### Suggested Mac Install Methods (new values for `install_method`)
- `brew` — `brew install --cask {brew_id}`
- `dmg` — Download .dmg, mount, copy .app to /Applications
- `pkg` — Download .pkg, run `installer -pkg ... -target /`
- `direct_download` — Generic download + platform-appropriate install
- `extract_to_desktop` — Unzip to ~/Desktop (same as PC)

---

## Detection Methods — PC vs Mac Mapping

| PC Detection Method | Mac Equivalent | Detection Value Example |
|---|---|---|
| `winget` | `brew` | Cask name — `wireshark` |
| `registry_name` | `app_bundle` | `/Applications/Dante Controller.app` |
| `file_path` | `file_path` | `/Applications/Some.app/Contents/MacOS/binary` |
| `file_paths` (pipe-delimited) | `file_paths` | `/Applications/A.app|/opt/homebrew/bin/a` |
| `none` | `none` | Always install (test content) |

---

## Adding Mac Packages to Supabase

No schema changes needed. Just INSERT new rows with the Mac platform. Example:

```sql
-- Mac-specific package
INSERT INTO packages (name, category, platforms, install_method, download_url, detection_method, detection_value, sort_order)
VALUES ('Dante Controller', 'Audio', '{mac_apple_silicon}', 'dmg',
    'https://your-download-url/DanteController-mac-arm64.dmg',
    'app_bundle', '/Applications/Dante Controller.app', 101);

-- Cross-platform package (shows up on PC AND Mac)
INSERT INTO packages (name, category, platforms, install_method, download_url, detection_method, detection_value, sort_order)
VALUES ('Wireshark', 'Networking', '{pc,mac_apple_silicon,mac_intel}', 'brew',
    NULL, 'brew', 'wireshark', 404);
```

You can also **update existing PC rows** to add Mac support:

```sql
UPDATE packages SET platforms = '{pc,mac_apple_silicon}' WHERE name = 'Wireshark';
```

---

## Supabase Storage — Hosting Installers

Installers that aren't available from a public vendor URL are stored in Supabase Storage in the `installers` bucket, organized by vendor folder:

```
installers/
├── Blackmagic Design/
├── Luminex/
├── Netgear/
├── Q-SYS/
├── Ross Video/
├── Shure/
├── Utilities/
└── Video Test Content/
```

### Signed URLs
Files use long-lived signed tokens (expiry ~100 years). The URL pattern:
```
https://incdoepqrbwaagatikgb.supabase.co/storage/v1/object/sign/installers/{path}?token={JWT}
```

To add a Mac installer:
1. Upload to the `installers` bucket (e.g. `installers/Audinate/DanteController-mac-arm64.dmg`)
2. Generate a signed URL from the Supabase dashboard
3. Use that URL as the `download_url` in the packages table

---

## Key Architecture Changes Made to PC Toolkit

### What was removed
- ~60 hardcoded TreeNode lines building the app list
- ~150-line `if/else` chain for detecting installed apps
- ~200-line `switch` statement in `InstallCustomAppAsync` for routing installs

### What replaced it
1. **`PopulateTreeFromPackages(List<PackageInfo>)`** — Groups packages by category, builds TreeView dynamically. Each TreeNode's `.Tag` = the `PackageInfo` object.

2. **`CheckIfInstalledAsync(PackageInfo pkg)`** — Data-driven detection:
   ```
   switch (pkg.DetectionMethod)
       "winget"       → IsWingetAppInstalledAsync(pkg.DetectionValue)
       "registry_name"→ IsAppInstalledAsync(pkg.DetectionValue)
       "file_path"    → File.Exists(pkg.DetectionValue)
       "file_paths"   → pkg.DetectionValue.Split('|').Any(File.Exists)
       "none"         → false (always install)
   ```

3. **`InstallPackageAsync(PackageInfo pkg)`** — Data-driven installation:
   ```
   switch (pkg.InstallMethod)
       "winget"           → InstallWingetAppAsync(pkg.WingetId)
                            → fallback to FallbackDownloadUrl if winget fails
       "direct_download"  → InstallDirectDownloadAsync(pkg.DownloadUrl, pkg.InstallArgs)
       "extract_to_desktop"→ DownloadAndExtractToDesktopAsync(pkg.DownloadUrl)
   ```

4. **`GetCheckedApplications()`** — Returns `List<PackageInfo>` from checked TreeView nodes.

5. **Deploy loop** — Iterates `List<PackageInfo>`, calls `CheckIfInstalledAsync` → `InstallPackageAsync` → post-install actions (close windows, pin to taskbar, install companion packages) — all driven by the PackageInfo data.

---

## For the Mac Toolkit — Implementation Checklist

1. **No Supabase migration needed** — the `packages` table already exists with the right schema
2. **INSERT Mac package rows** — use `platforms = '{mac_apple_silicon}'` or `'{mac_intel}'` or both
3. **Upload Mac installers** to the `installers` Supabase Storage bucket
4. **Create a PackageInfo model** matching the JSON keys above (Swift struct, Python dataclass, etc.)
5. **Create a PackageIndexService** with the same 3-tier fallback (Supabase → cache → hardcoded)
6. **Query with the correct platform filter**: `platforms=cs.{mac_apple_silicon}`
7. **Implement Mac-specific install methods**: `brew`, `dmg`, `pkg`
8. **Implement Mac-specific detection**: `app_bundle` (check for .app existence), `brew` (check brew list), `file_path`
9. **Sort order convention**: Use the same sort_order values (100s = Audio, 200s = Video, etc.) so categories align across platforms
