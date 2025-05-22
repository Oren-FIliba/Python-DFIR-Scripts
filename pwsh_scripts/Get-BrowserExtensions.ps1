# Get-BrowserExtensions.ps1
# Script to detect installed browsers and their extensions across all user profiles

# Set error action preference
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Function to write formatted error messages
function Write-ErrorLog {
    param (
        [string]$Message,
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $errorMessage = "[$timestamp] ERROR: $Message"
    if ($ErrorRecord) {
        $errorMessage += "`nException: $($ErrorRecord.Exception.Message)"
        $errorMessage += "`nStack Trace: $($ErrorRecord.ScriptStackTrace)"
    }
    Write-Error $errorMessage
    Add-Content -Path "browser_extensions_errors.log" -Value $errorMessage
}

# Check if running as administrator
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        throw "This script requires administrative privileges to access all user profiles."
    }
}
catch {
    Write-ErrorLog -Message "Failed to check administrative privileges" -ErrorRecord $_
    exit 1
}

# Function to find all Chrome/Edge profiles
function Get-BrowserProfiles {
    param (
        [string]$UserPath,
        [string]$BrowserName
    )
    
    $profiles = @()
    $basePath = $null
    
    try {
        switch ($BrowserName) {
            "Chrome" {
                $basePath = Join-Path $UserPath "AppData\Local\Google\Chrome\User Data"
            }
            "Edge" {
                $basePath = Join-Path $UserPath "AppData\Local\Microsoft\Edge\User Data"
            }
            default {
                throw "Unsupported browser: $BrowserName"
            }
        }
        
        if (Test-Path $basePath) {
            Write-Verbose "Found $BrowserName base directory: $basePath"
            $profiles += "Default"  # Always check Default profile
            
            # Get all profile directories
            $profileDirs = Get-ChildItem -Path $basePath -Directory -ErrorAction Stop | 
                          Where-Object { $_.Name -match '^Profile \d+$' -or $_.Name -match '^[a-zA-Z0-9]+$' }
            foreach ($dir in $profileDirs) {
                $profiles += $dir.Name
            }
            Write-Verbose "Found $($profiles.Count) $BrowserName profiles: $($profiles -join ', ')"
        }
        else {
            Write-Verbose "$BrowserName base directory not found: $basePath"
        }
    }
    catch {
        Write-ErrorLog -Message "Failed to get $BrowserName profiles for user $UserPath" -ErrorRecord $_
        return @()
    }
    
    return $profiles
}

# Function to get Chrome/Edge/Opera extensions
function Get-ChromiumExtensions {
    param (
        [string]$BrowserName,
        [string]$ExtensionsPath
    )
    
    $extensions = @()
    Write-Verbose "Checking $BrowserName extensions in: $ExtensionsPath"
    
    if (-not (Test-Path $ExtensionsPath)) {
        Write-Verbose "$BrowserName extensions directory not found: $ExtensionsPath"
        return $extensions
    }
    
    try {
        $extensionFolders = Get-ChildItem -Path $ExtensionsPath -Directory -ErrorAction Stop
        Write-Verbose "Found $($extensionFolders.Count) extension folders in $ExtensionsPath"
        
        foreach ($folder in $extensionFolders) {
            try {
                # Skip the Temp folder
                if ($folder.Name -eq "Temp") {
                    continue
                }
                
                # Look for version folders inside the extension folder
                $versionFolders = Get-ChildItem -Path $folder.FullName -Directory -ErrorAction Stop
                foreach ($versionFolder in $versionFolders) {
                    try {
                        # Check for manifest.json or manifest_*.json files
                        $manifestFiles = Get-ChildItem -Path $versionFolder.FullName -Filter "manifest*.json" -ErrorAction Stop
                        
                        foreach ($manifestFile in $manifestFiles) {
                            try {
                                $manifestContent = Get-Content $manifestFile.FullName -Raw -ErrorAction Stop
                                $manifest = $manifestContent | ConvertFrom-Json -ErrorAction Stop
                                
                                # Handle cases where name might be an object (for localized names)
                                $extensionName = if ($manifest.name -is [PSCustomObject]) {
                                    $manifest.name.message
                                } else {
                                    $manifest.name
                                }
                                
                                # Get background scripts
                                $backgroundScripts = @()
                                if ($manifest.background) {
                                    if ($manifest.background.scripts) {
                                        $backgroundScripts = $manifest.background.scripts
                                    }
                                    elseif ($manifest.background.page) {
                                        $backgroundScripts = @($manifest.background.page)
                                    }
                                }
                                
                                # Get content scripts
                                $contentScripts = @()
                                if ($manifest.content_scripts) {
                                    $contentScripts = $manifest.content_scripts | ForEach-Object {
                                        @{
                                            matches = $_.matches
                                            js = $_.js
                                            css = $_.css
                                        }
                                    }
                                }
                                
                                # Get permissions
                                $permissions = if ($manifest.permissions) { $manifest.permissions } else { @() }
                                
                                # Get content security policy
                                $contentSecurityPolicy = if ($manifest.content_security_policy) { $manifest.content_security_policy } else { "" }
                                
                                # Get web accessible resources
                                $webAccessibleResources = if ($manifest.web_accessible_resources) { $manifest.web_accessible_resources } else { @() }
                                
                                $extension = [PSCustomObject]@{
                                    Browser = $BrowserName
                                    ExtensionID = $folder.Name
                                    Name = $extensionName
                                    Version = $manifest.version
                                    Description = if ($manifest.description) { $manifest.description } else { "" }
                                    Path = $versionFolder.FullName
                                    BackgroundScripts = $backgroundScripts
                                    ContentScripts = $contentScripts
                                    Permissions = $permissions
                                    ContentSecurityPolicy = $contentSecurityPolicy
                                    WebAccessibleResources = $webAccessibleResources
                                }
                                $extensions += $extension
                                Write-Verbose "Found $BrowserName extension: $extensionName (ID: $($folder.Name), Version: $($manifest.version))"
                                break  # Found a valid manifest, move to next extension
                            }
                            catch {
                                Write-ErrorLog -Message "Failed to parse manifest file for extension $($folder.Name) version $($versionFolder.Name)" -ErrorRecord $_
                                Write-Verbose "Manifest content:"
                                try {
                                    Get-Content $manifestFile.FullName -Raw | Out-Host
                                }
                                catch {
                                    Write-Verbose "Could not read manifest file"
                                }
                            }
                        }
                    }
                    catch {
                        Write-ErrorLog -Message "Failed to process version folder $($versionFolder.Name) for extension $($folder.Name)" -ErrorRecord $_
                    }
                }
            }
            catch {
                Write-ErrorLog -Message "Failed to process extension folder $($folder.Name)" -ErrorRecord $_
            }
        }
    }
    catch {
        Write-ErrorLog -Message "Failed to access $BrowserName extensions directory" -ErrorRecord $_
    }
    
    return $extensions
}

# Function to get Firefox extensions
function Get-FirefoxExtensions {
    param (
        [string]$ProfilePath
    )
    
    $extensions = @()
    Write-Host "Checking Firefox extensions in: $ProfilePath"
    
    if (Test-Path $ProfilePath) {
        try {
            # Check for extensions.json which contains installed extensions
            $extensionsJsonPath = Join-Path $ProfilePath "extensions.json"
            if (Test-Path $extensionsJsonPath) {
                $extensionsData = Get-Content $extensionsJsonPath -Raw -ErrorAction Stop | ConvertFrom-Json
                
                # Check addons section
                if ($extensionsData.addons) {
                    foreach ($addon in $extensionsData.addons) {
                        $extension = [PSCustomObject]@{
                            Browser = "Firefox"
                            ExtensionID = $addon.id
                            Name = $addon.name
                            Version = $addon.version
                            Description = if ($addon.description) { $addon.description } else { "" }
                            Path = $addon.path
                        }
                        $extensions += $extension
                        Write-Host "Found Firefox extension: $($addon.name) (ID: $($addon.id))"
                    }
                }
            }
            
            # Also check the extensions directory for .xpi files
            $extensionsPath = Join-Path $ProfilePath "extensions"
            if (Test-Path $extensionsPath) {
                $extensionFiles = Get-ChildItem -Path $extensionsPath -Filter "*.xpi" -ErrorAction Stop
                foreach ($file in $extensionFiles) {
                    $extension = [PSCustomObject]@{
                        Browser = "Firefox"
                        ExtensionID = $file.Name
                        Name = $file.Name
                        Version = "Unknown"
                        Description = "Firefox Extension"
                        Path = $file.FullName
                    }
                    $extensions += $extension
                    Write-Host "Found Firefox extension: $($file.Name)"
                }
            }
        }
        catch {
            Write-Warning "Failed to access Firefox extensions directory: $_"
        }
    }
    else {
        Write-Host "Firefox profile directory not found: $ProfilePath"
    }
    return $extensions
}

# Main script
Write-Host "Starting browser extension detection..."
$allExtensions = @()
$totalExtensionsFound = 0

try {
    # Create or clear the error log file
    "" | Out-File -FilePath "browser_extensions_errors.log" -Force
    
    # Get all user profiles
    $userProfiles = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction Stop
    Write-Host "Found $($userProfiles.Count) user profiles"

    foreach ($user in $userProfiles) {
        try {
            $userName = $user.Name
            Write-Host "`nChecking extensions for user: $userName"
            
            # Chrome Extensions
            $chromeProfiles = Get-BrowserProfiles -UserPath $user.FullName -BrowserName "Chrome"
            foreach ($profile in $chromeProfiles) {
                try {
                    $chromePath = Join-Path $user.FullName "AppData\Local\Google\Chrome\User Data\$profile\Extensions"
                    if (Test-Path $chromePath) {
                        $extensions = Get-ChromiumExtensions -BrowserName "Chrome" -ExtensionsPath $chromePath
                        $allExtensions += $extensions
                        $totalExtensionsFound += $extensions.Count
                    }
                }
                catch {
                    Write-ErrorLog -Message "Failed to process Chrome profile $profile for user $userName" -ErrorRecord $_
                }
            }
            
            # Edge Extensions
            $edgeProfiles = Get-BrowserProfiles -UserPath $user.FullName -BrowserName "Edge"
            foreach ($profile in $edgeProfiles) {
                try {
                    $edgePath = Join-Path $user.FullName "AppData\Local\Microsoft\Edge\User Data\$profile\Extensions"
                    if (Test-Path $edgePath) {
                        $extensions = Get-ChromiumExtensions -BrowserName "Edge" -ExtensionsPath $edgePath
                        $allExtensions += $extensions
                        $totalExtensionsFound += $extensions.Count
                    }
                }
                catch {
                    Write-ErrorLog -Message "Failed to process Edge profile $profile for user $userName" -ErrorRecord $_
                }
            }
            
            # Opera Extensions
            try {
                $operaPath = Join-Path $user.FullName "AppData\Roaming\Opera Software\Opera Stable\Extensions"
                if (Test-Path $operaPath) {
                    $extensions = Get-ChromiumExtensions -BrowserName "Opera" -ExtensionsPath $operaPath
                    $allExtensions += $extensions
                    $totalExtensionsFound += $extensions.Count
                }
            }
            catch {
                Write-ErrorLog -Message "Failed to process Opera extensions for user $userName" -ErrorRecord $_
            }
            
            # Firefox Extensions
            try {
                $firefoxProfilesPath = Join-Path $user.FullName "AppData\Roaming\Mozilla\Firefox\Profiles"
                if (Test-Path $firefoxProfilesPath) {
                    $firefoxProfiles = Get-ChildItem -Path $firefoxProfilesPath -Directory -ErrorAction Stop
                    foreach ($profile in $firefoxProfiles) {
                        try {
                            $extensions = Get-FirefoxExtensions -ProfilePath $profile.FullName
                            $allExtensions += $extensions
                            $totalExtensionsFound += $extensions.Count
                        }
                        catch {
                            Write-ErrorLog -Message "Failed to process Firefox profile $($profile.Name) for user $userName" -ErrorRecord $_
                        }
                    }
                }
            }
            catch {
                Write-ErrorLog -Message "Failed to process Firefox profiles for user $userName" -ErrorRecord $_
            }
        }
        catch {
            Write-ErrorLog -Message "Failed to process user profile $userName" -ErrorRecord $_
        }
    }

    Write-Host "`nTotal extensions found during scan: $totalExtensionsFound"
    Write-Host "Total extensions in collection: $($allExtensions.Count)"

    if ($allExtensions.Count -eq 0) {
        Write-Warning "No browser extensions were found on the system."
    }
    else {
        Write-Host "`nFound $($allExtensions.Count) total extensions across all browsers"
        
        try {
            # Convert arrays to strings for CSV export
            $csvExtensions = $allExtensions | ForEach-Object {
                $extension = $_.PSObject.Copy()
                
                # Convert arrays to semicolon-separated strings
                $extension.BackgroundScripts = if ($_.BackgroundScripts) { $_.BackgroundScripts -join ';' } else { "" }
                
                # Convert content scripts array to string
                $contentScriptsStr = @()
                if ($_.ContentScripts) {
                    foreach ($cs in $_.ContentScripts) {
                        $matches2 = if ($cs.matches) { $cs.matches -join ',' } else { "" }
                        $js = if ($cs.js) { $cs.js -join ',' } else { "" }
                        $css = if ($cs.css) { $cs.css -join ',' } else { "" }
                        $contentScriptsStr += "matches:$matches2|js:$js|css:$css"
                    }
                }
                $extension.ContentScripts = $contentScriptsStr -join ';'
                
                # Convert other arrays to semicolon-separated strings
                $extension.Permissions = if ($_.Permissions) { $_.Permissions -join ';' } else { "" }
                $extension.WebAccessibleResources = if ($_.WebAccessibleResources) { $_.WebAccessibleResources -join ';' } else { "" }
                
                $extension
            }
            
            # Output to JSON (with original array format)
            $jsonOutput = $allExtensions | ConvertTo-Json -Depth 10
            $jsonOutput | Out-File -FilePath "browser_extensions.json" -Encoding UTF8 -Force
            Write-Host "JSON output saved to browser_extensions.json"

            # Output to CSV (with string-formatted arrays)
            $csvExtensions | Export-Csv -Path "browser_extensions.csv" -NoTypeInformation -Encoding UTF8 -Force
            Write-Host "CSV output saved to browser_extensions.csv"
        }
        catch {
            Write-ErrorLog -Message "Failed to export extension data to JSON/CSV" -ErrorRecord $_
        }
    }
}
catch {
    Write-ErrorLog -Message "An error occurred while running the script" -ErrorRecord $_
}
