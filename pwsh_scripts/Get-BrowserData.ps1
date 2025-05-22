param(
    [Parameter(Mandatory=$true)]
    [string]$url
)

# Get the script's directory - handle both direct execution and file execution
if ($MyInvocation.MyCommand.Path) {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    $scriptPath = Get-Location
}

# Check for sqlite3.exe-
$sqliteExe = Join-Path $scriptPath "sqlite3.exe"
if (-not (Test-Path $sqliteExe)) {
    Write-Host "sqlite3.exe not found at: $sqliteExe" -ForegroundColor Red
    Write-Host "Please download sqlite3.exe from:" -ForegroundColor Yellow
    Write-Host "https://www.sqlite.org/download.html" -ForegroundColor Yellow
    Write-Host "Download the 'sqlite-tools-win-x64-*.zip' file, extract sqlite3.exe, and place it in the same directory as this script." -ForegroundColor Yellow
    return
}

# Fetch data from S3 bucket
try {
    $s3Data = Invoke-RestMethod -Uri $url -Method Get
    Write-Host "Successfully fetched data from S3 bucket" -ForegroundColor Green
} catch {
    Write-Host "Failed to fetch data from S3 bucket: $_" -ForegroundColor Red
    $s3Data = $null
}

# Function to check if a URL matches any of the allowed domains
function Test-AllowedDomain {
    param (
        [string]$url
    )
    
    if ($null -eq $s3Data) {
        Write-Host "No domain list available from S3 bucket" -ForegroundColor Red
        return $false
    }

    try {
        $uri = [System.Uri]$url
        $hostName = $uri.Host.ToLower()
        
        # Check if the host matches any of the domains in the list
        foreach ($domain in $s3Data) {
            if ($hostName -eq $domain -or $hostName.EndsWith(".$domain")) {
                return $true
            }
        }
        return $false
    } catch {
        Write-Host "Error checking domain for URL $url : $_" -ForegroundColor Red
        return $false
    }
}

# Get all user profiles from C:\Users\
$users = Get-ChildItem -Path "C:\Users\" -Directory | Select-Object -ExpandProperty Name
#$allResults = @()
$hostname = hostname
$ws1_registredon = ""
$os_type = "Windows"
$loggedInUsers = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName
#$hostname_json = @{hostname = $hostname; ws1_registredon = $ws1_registredon; current_logged_in_user = $loggedInUsers; os_type = $os_type}
$out = @()

function Convert-ChromeTimestamp {
    param (
        [string]$timestamp
    )
    if ([string]::IsNullOrEmpty($timestamp)) { return "" }
    try {
        # Chrome timestamps are in microseconds since 1601-01-01
        $epoch = [DateTime]::FromFileTimeUtc([long]$timestamp * 10)
        return $epoch.ToString("yyyy-MM-dd HH:mm:ss")
    } catch {
        return ""
    }
}

function Convert-FirefoxTimestamp {
    param (
        [long]$timestamp
    )
    # Firefox timestamps are in milliseconds since 1970-01-01
    $epoch = [DateTimeOffset]::FromUnixTimeMilliseconds($timestamp).DateTime
    return $epoch.ToString("yyyy-MM-dd HH:mm:ss")
}

function Get-BrowserData {
    param (
        [string]$user,
        [string]$browserType,
        [string]$basePath,
        [string]$dbFileName
    )
    
    if (Test-Path -Path $basePath) {
        # Get all profiles (Default + custom profiles)
        $profiles = Get-ChildItem -Path $basePath -Directory | Where-Object { $_.Name -match "^(Default|Profile \d+)$" }

        foreach ($profile in $profiles) {
            $dbPath = "$basePath\$profile\$dbFileName"
            Write-Host "Processing $browserType profile: $($profile.Name)"

            if (Test-Path -Path $dbPath) {
                try {
                    # Copy database to Temp folder
                    $tempDbPath = "$env:TEMP\LoginData_${browserType}_$user_$($profile.Name).db"
                    Copy-Item -Path $dbPath -Destination $tempDbPath -Force

                    if (Test-Path -Path $tempDbPath) {
                        # Use sqlite3.exe to query the database with headers and CSV mode
                        $query = @"
.mode csv
.headers on
SELECT origin_url, username_value, date_last_used, action_url, date_created 
FROM logins 
WHERE username_value IS NOT NULL AND username_value != '';
"@
                        $result = $query | & $sqliteExe $tempDbPath

                        # Process each row from the CSV output
                        if ($result) {
                            $result | ConvertFrom-Csv | ForEach-Object {
                                if ($_.username_value -ne "" -and (Test-AllowedDomain $_.origin_url)) {
                                    $row = New-Object psobject
                                    $row | Add-Member -Name hostname -MemberType NoteProperty -Value ($hostname)
                                    $row | Add-Member -Name origin_url -MemberType NoteProperty -Value ($_.origin_url)
                                    $row | Add-Member -Name username_value -MemberType NoteProperty -Value ($_.username_value)
                                    $row | Add-Member -Name browser_profile -MemberType NoteProperty -Value ($profile.Name)
                                    $row | Add-Member -Name username_dir -MemberType NoteProperty -Value ($user)
                                    $row | Add-Member -Name action_url -MemberType NoteProperty -Value ($_.action_url)
                                    $row | Add-Member -Name date_created -MemberType NoteProperty -Value (Convert-ChromeTimestamp $_.date_created)
                                    $row | Add-Member -Name date_last_used -MemberType NoteProperty -Value (Convert-ChromeTimestamp $_.date_last_used)
                                    $row | Add-Member -Name browser -MemberType NoteProperty -Value ($browserType)
                                    $script:out = $script:out + $row
                                }
                            }
                        }

                        Remove-Item -Path $tempDbPath -Force
                    }
                } catch {
                    Write-Host "Error processing $browserType profile $($profile.Name): $_" -ForegroundColor Red
                    if (Test-Path -Path $tempDbPath) { Remove-Item -Path $tempDbPath -Force }
                }
            }
        }
    }
}

foreach ($user in $users) {
    # Chrome
    $chromeBasePath = "C:\Users\$user\AppData\Local\Google\Chrome\User Data"
    Get-BrowserData -user $user -browserType "Chrome" -basePath $chromeBasePath -dbFileName "Login Data"

    # Edge
    $edgeBasePath = "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data"
    Get-BrowserData -user $user -browserType "Edge" -basePath $edgeBasePath -dbFileName "Login Data"

    # Firefox
    $firefoxBasePath = "C:\Users\$user\AppData\Roaming\Mozilla\Firefox\Profiles"
    if (Test-Path -Path $firefoxBasePath) {
        $firefoxProfiles = Get-ChildItem -Path $firefoxBasePath -Directory
        foreach ($profile in $firefoxProfiles) {
            $firefoxDbPath = "$firefoxBasePath\$profile\logins.json"
            if (Test-Path -Path $firefoxDbPath) {
                $firefoxData = Get-Content -Path $firefoxDbPath -Raw | ConvertFrom-Json
                foreach ($login in $firefoxData.logins) {
                    if (Test-AllowedDomain $login.hostname) {
                        $row = New-Object psobject
                        $row | Add-Member -Name origin_url -MemberType NoteProperty -Value ($login.hostname)
                        $row | Add-Member -Name hostname -MemberType NoteProperty -Value ($hostname)
                        $row | Add-Member -Name username_value -MemberType NoteProperty -Value ($login.encryptedUsername)
                        $row | Add-Member -Name browser_profile -MemberType NoteProperty -Value ($profile.Name)
                        $row | Add-Member -Name username_dir -MemberType NoteProperty -Value ($user)
                        $row | Add-Member -Name action_url -MemberType NoteProperty -Value ($login.formSubmitURL)
                        $row | Add-Member -Name date_created -MemberType NoteProperty -Value (Convert-FirefoxTimestamp $login.timeCreated)
                        $row | Add-Member -Name date_last_used -MemberType NoteProperty -Value (Convert-FirefoxTimestamp $login.timeLastUsed)
                        $row | Add-Member -Name browser -MemberType NoteProperty -Value ("Firefox")
                        $script:out = $script:out + $row
                    }
                }
            }
        }
    }
}

# Display the final JSON structure

$output = @{
    data = @{
        login_data = $out
        hostname = $hostnameD
        ws1_registredon = $ws1_registredon
        current_logged_in_user = $loggedInUsers
        os_type = $os_type
    }
}

$jsonData = $output | ConvertTo-Json -Depth 3
$webhookURL = ""  # Replace with your actual webhook URL
Invoke-RestMethod -Uri $webhookURL -Method Post -Body $jsonData -ContentType "application/json"
