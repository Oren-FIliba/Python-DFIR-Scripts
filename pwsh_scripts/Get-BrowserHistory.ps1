# Function to check if a browser is installed
function Test-BrowserInstalled {
    param (
        [string]$BrowserName
    )
    
    Write-Host "Checking for $BrowserName installation..." -ForegroundColor Yellow
    
    switch ($BrowserName) {
        "Chrome" { 
            $paths = @(
                "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
                "$env:PROGRAMFILES\Google\Chrome\Application\chrome.exe",
                "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
            )
            foreach ($path in $paths) {
                Write-Host "Checking Chrome path: $path" -ForegroundColor Gray
                if (Test-Path $path) {
                    Write-Host "Chrome found at: $path" -ForegroundColor Green
                    return $true
                }
            }
            return $false
        }
        "Edge" { 
            $paths = @(
                "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe",
                "$env:PROGRAMFILES\Microsoft\Edge\Application\msedge.exe",
                "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
                "$env:PROGRAMFILES\Microsoft\Edge Beta\Application\msedge.exe",
                "${env:ProgramFiles(x86)}\Microsoft\Edge Beta\Application\msedge.exe",
                "$env:PROGRAMFILES\Microsoft\Edge Dev\Application\msedge.exe",
                "${env:ProgramFiles(x86)}\Microsoft\Edge Dev\Application\msedge.exe",
                "$env:PROGRAMFILES\Microsoft\Edge Canary\Application\msedge.exe",
                "${env:ProgramFiles(x86)}\Microsoft\Edge Canary\Application\msedge.exe",
                "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History"
            )
            foreach ($path in $paths) {
                Write-Host "Checking Edge path: $path" -ForegroundColor Gray
                if (Test-Path $path) {
                    Write-Host "Edge found at: $path" -ForegroundColor Green
                    return $true
                }
            }
            # Additional check for Edge in Windows Store location
            $edgeStorePath = "$env:LOCALAPPDATA\Packages\Microsoft.MicrosoftEdge.Stable_8wekyb3d8bbwe\SystemAppData\msedge.exe"
            Write-Host "Checking Edge Store path: $edgeStorePath" -ForegroundColor Gray
            if (Test-Path $edgeStorePath) {
                Write-Host "Edge found at: $edgeStorePath" -ForegroundColor Green
                return $true
            }
            return $false
        }
        "Firefox" { 
            $paths = @(
                "$env:PROGRAMFILES\Mozilla Firefox\firefox.exe",
                "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
            )
            foreach ($path in $paths) {
                Write-Host "Checking Firefox path: $path" -ForegroundColor Gray
                if (Test-Path $path) {
                    Write-Host "Firefox found at: $path" -ForegroundColor Green
                    return $true
                }
            }
            return $false
        }
        "Opera" { 
            $paths = @(
                "$env:LOCALAPPDATA\Opera\launcher.exe",
                "$env:PROGRAMFILES\Opera\launcher.exe",
                "${env:ProgramFiles(x86)}\Opera\launcher.exe"
            )
            foreach ($path in $paths) {
                Write-Host "Checking Opera path: $path" -ForegroundColor Gray
                if (Test-Path $path) {
                    Write-Host "Opera found at: $path" -ForegroundColor Green
                    return $true
                }
            }
            return $false
        }
        "Brave" { 
            $paths = @(
                "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe",
                "$env:PROGRAMFILES\BraveSoftware\Brave-Browser\Application\brave.exe",
                "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser\Application\brave.exe"
            )
            foreach ($path in $paths) {
                Write-Host "Checking Brave path: $path" -ForegroundColor Gray
                if (Test-Path $path) {
                    Write-Host "Brave found at: $path" -ForegroundColor Green
                    return $true
                }
            }
            return $false
        }
        default { return $false }
    }
}

# Function to check if browser is running
function Test-BrowserRunning {
    param (
        [string]$BrowserName
    )
    
    switch ($BrowserName) {
        "Chrome" { return Get-Process "chrome" -ErrorAction SilentlyContinue }
        "Edge" { return Get-Process "msedge" -ErrorAction SilentlyContinue }
        "Firefox" { return Get-Process "firefox" -ErrorAction SilentlyContinue }
        "Opera" { return Get-Process "opera" -ErrorAction SilentlyContinue }
        "Brave" { return Get-Process "brave" -ErrorAction SilentlyContinue }
        default { return $false }
    }
}

# Function to get all user profiles
function Get-UserProfiles {
    $profiles = @()
    $users = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') }
    foreach ($user in $users) {
        $profiles += @{
            Name = $user.Name
            Path = $user.FullName
            LocalAppData = Join-Path $user.FullName "AppData\Local"
            AppData = Join-Path $user.FullName "AppData\Roaming"
        }
    }
    return $profiles
}

# Function to get Chrome/Edge/Brave history
function Get-ChromiumHistory {
    param (
        [string]$BrowserName,
        [string]$HistoryPath,
        [string]$ProfileName,
        [string]$UserName
    )
    
    try {
        Write-Host "Checking history path: $HistoryPath" -ForegroundColor Yellow
        
        if (-not (Test-Path $HistoryPath)) {
            Write-Warning "History file not found at: $HistoryPath"
            return @()
        }
        
        $tempFile = "$env:TEMP\${BrowserName}_${ProfileName}_history.db"
        Write-Host "Copying history file to: $tempFile" -ForegroundColor Yellow
        
        try {
            # Create a temporary copy of the history file
            Copy-Item $HistoryPath $tempFile -Force -ErrorAction SilentlyContinue
            
            # Wait a moment to ensure the file is fully copied
            Start-Sleep -Seconds 1
            
            # Check if sqlite.exe exists in the current directory
            $sqliteExe = ".\sqlite3.exe"
            if (-not (Test-Path $sqliteExe)) {
                Write-Warning "sqlite.exe not found in the current directory. Please download it and place it in the same directory as this script."
                return @()
            }
            
            Write-Host "Querying history database..." -ForegroundColor Yellow
            
            # Create a temporary file for the SQL query
            $queryFile = "$env:TEMP\query.sql"
            @"
.headers on
.mode csv
SELECT url, title, datetime(last_visit_time/1000000-11644473600,'unixepoch','localtime') as last_visit_time 
FROM urls 
ORDER BY last_visit_time DESC 
LIMIT 1000;
"@ | Out-File -FilePath $queryFile -Encoding ASCII
            
            # Execute the query and capture the output
            $csvOutput = & $sqliteExe $tempFile ".read $queryFile" | ConvertFrom-Csv
            
            $result = @()
            foreach ($row in $csvOutput) {
                $result += [PSCustomObject]@{
                    User = $UserName
                    Browser = $BrowserName
                    Profile = $ProfileName
                    URL = $row.url
                    Title = $row.title
                    LastVisitTime = $row.last_visit_time
                }
            }
            
            if ($result.Count -eq 0) {
                Write-Warning "No history entries found in the database"
            }
            else {
                Write-Host "Found $($result.Count) history entries" -ForegroundColor Green
            }
            
            return $result
        }
        finally {
            # Clean up the temporary files
            if (Test-Path $tempFile) {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
            if (Test-Path $queryFile) {
                Remove-Item $queryFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        Write-Warning "Error getting $BrowserName history: $_"
    }
    return @()
}

# Function to get Firefox history
function Get-FirefoxHistory {
    param (
        [string]$ProfilePath,
        [string]$ProfileName,
        [string]$UserName
    )
    
    try {
        Write-Host "Checking Firefox profile path: $ProfilePath" -ForegroundColor Yellow
        
        if (-not (Test-Path $ProfilePath)) {
            Write-Warning "Firefox profile file not found at: $ProfilePath"
            return @()
        }
        
        $tempFile = "$env:TEMP\firefox_${ProfileName}_history.db"
        Write-Host "Copying Firefox history file to: $tempFile" -ForegroundColor Yellow
        
        try {
            # Create a temporary copy of the history file
            Copy-Item $ProfilePath $tempFile -Force -ErrorAction SilentlyContinue
            
            # Wait a moment to ensure the file is fully copied
            Start-Sleep -Seconds 1
            
            # Check if sqlite.exe exists in the current directory
            $sqliteExe = ".\sqlite.exe"
            if (-not (Test-Path $sqliteExe)) {
                Write-Warning "sqlite.exe not found in the current directory. Please download it and place it in the same directory as this script."
                return @()
            }
            
            Write-Host "Querying Firefox history database..." -ForegroundColor Yellow
            
            # Create a temporary file for the SQL query
            $queryFile = "$env:TEMP\query.sql"
            @"
.headers on
.mode csv
SELECT url, title, datetime(last_visit_date/1000000,'unixepoch','localtime') as last_visit_time 
FROM moz_places 
ORDER BY last_visit_date DESC 
LIMIT 1000;
"@ | Out-File -FilePath $queryFile -Encoding ASCII
            
            # Execute the query and capture the output
            $csvOutput = & $sqliteExe $tempFile ".read $queryFile" | ConvertFrom-Csv
            
            $result = @()
            foreach ($row in $csvOutput) {
                $result += [PSCustomObject]@{
                    User = $UserName
                    Browser = "Firefox"
                    Profile = $ProfileName
                    URL = $row.url
                    Title = $row.title
                    LastVisitTime = $row.last_visit_time
                }
            }
            
            if ($result.Count -eq 0) {
                Write-Warning "No history entries found in the Firefox database"
            }
            else {
                Write-Host "Found $($result.Count) history entries" -ForegroundColor Green
            }
            
            return $result
        }
        finally {
            # Clean up the temporary files
            if (Test-Path $tempFile) {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
            if (Test-Path $queryFile) {
                Remove-Item $queryFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        Write-Warning "Error getting Firefox history: $_"
    }
    return @()
}

# Main script
Write-Host "Starting browser history extraction..." -ForegroundColor Green
Write-Host "Please make sure all browsers are closed before proceeding." -ForegroundColor Yellow
Write-Host "Note: Make sure sqlite.exe is in the same directory as this script." -ForegroundColor Yellow

# Create a temporary directory for our work
$tempDir = "$env:TEMP\BrowserHistory_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    $allHistory = @()
    $userProfiles = Get-UserProfiles
    
    foreach ($user in $userProfiles) {
        Write-Host "`nProcessing user: $($user.Name)" -ForegroundColor Green
        
        # Chrome profiles
        $chromeProfiles = Get-ChildItem "$($user.LocalAppData)\Google\Chrome\User Data" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "System Profile" }
        foreach ($profile in $chromeProfiles) {
            Write-Host "Processing Chrome profile: $($profile.Name)" -ForegroundColor Yellow
            $historyPath = Join-Path $profile.FullName "History"
            if (Test-Path $historyPath) {
                $allHistory += Get-ChromiumHistory "Chrome" $historyPath $profile.Name $user.Name
            }
        }
        
        # Edge profiles
        $edgeProfiles = Get-ChildItem "$($user.LocalAppData)\Microsoft\Edge\User Data" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "System Profile" }
        foreach ($profile in $edgeProfiles) {
            Write-Host "Processing Edge profile: $($profile.Name)" -ForegroundColor Yellow
            $historyPath = Join-Path $profile.FullName "History"
            if (Test-Path $historyPath) {
                $allHistory += Get-ChromiumHistory "Edge" $historyPath $profile.Name $user.Name
            }
        }
        
        # Firefox profiles
        $firefoxProfiles = Get-ChildItem "$($user.AppData)\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue
        foreach ($profile in $firefoxProfiles) {
            Write-Host "Processing Firefox profile: $($profile.Name)" -ForegroundColor Yellow
            $placesPath = Join-Path $profile.FullName "places.sqlite"
            if (Test-Path $placesPath) {
                $allHistory += Get-FirefoxHistory $placesPath $profile.Name $user.Name
            }
        }
        
        # Opera profiles
        $operaProfiles = Get-ChildItem "$($user.AppData)\Opera Software\Opera Stable" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "System Profile" }
        foreach ($profile in $operaProfiles) {
            Write-Host "Processing Opera profile: $($profile.Name)" -ForegroundColor Yellow
            $historyPath = Join-Path $profile.FullName "History"
            if (Test-Path $historyPath) {
                $allHistory += Get-ChromiumHistory "Opera" $historyPath $profile.Name $user.Name
            }
        }
        
        # Brave profiles
        $braveProfiles = Get-ChildItem "$($user.LocalAppData)\BraveSoftware\Brave-Browser\User Data" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "System Profile" }
        foreach ($profile in $braveProfiles) {
            Write-Host "Processing Brave profile: $($profile.Name)" -ForegroundColor Yellow
            $historyPath = Join-Path $profile.FullName "History"
            if (Test-Path $historyPath) {
                $allHistory += Get-ChromiumHistory "Brave" $historyPath $profile.Name $user.Name
            }
        }
    }

    if ($allHistory.Count -eq 0) {
        Write-Warning "`nNo browser history was found. Please check the following:"
        Write-Warning "1. Make sure all browsers are closed"
        Write-Warning "2. Run PowerShell as Administrator"
        Write-Warning "3. Check if you have any browsing history"
        exit
    }

    # Export results
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $outputPath = "$env:USERPROFILE\BrowserHistory_$timestamp"

    # Create JSON output
    $allHistory | ConvertTo-Json -Depth 10 | Out-File "$outputPath.json"

    # Create CSV output
    $allHistory | Export-Csv "$outputPath.csv" -NoTypeInformation

    Write-Host "`nHistory has been exported to:" -ForegroundColor Green
    Write-Host "JSON: $outputPath.json" -ForegroundColor Cyan
    Write-Host "CSV: $outputPath.csv" -ForegroundColor Cyan

    # Display results in a table
    $allHistory | Format-Table -AutoSize
}
finally {
    # Clean up temporary directory
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
