# Get-DeletedFiles.ps1
# This script retrieves and displays files that were deleted within a specified timeframe
# Author: System Administrator
# Date: Current

function Get-DeletedFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$TimeRange = "24h",

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputFormat = "Table"
    )

    try {
        # Convert time range to DateTime
        $endTime = Get-Date
        $startTime = switch ($TimeRange.ToLower()) {
            "1h" { $endTime.AddHours(-1) }
            "24h" { $endTime.AddHours(-24) }
            "7d" { $endTime.AddDays(-7) }
            "30d" { $endTime.AddDays(-30) }
            default {
                if ($TimeRange -match '^\d+[hd]$') {
                    $value = [int]($TimeRange -replace '\D', '')
                    $unit = $TimeRange -replace '\d', ''
                    switch ($unit) {
                        'h' { $endTime.AddHours(-$value) }
                        'd' { $endTime.AddDays(-$value) }
                        default { throw "Invalid time unit. Use 'h' for hours or 'd' for days." }
                    }
                } else {
                    throw "Invalid time range format. Use format like '24h' or '7d'"
                }
            }
        }

        Write-Verbose "Searching for deleted files between $startTime and $endTime"

        # Get deleted files from the Recycle Bin
        $deletedFiles = Get-ChildItem -Path $env:RecycleBinFolder -Recurse -Force |
            Where-Object { $_.LastWriteTime -ge $startTime -and $_.LastWriteTime -le $endTime } |
            Select-Object @{
                Name = 'FileName'
                Expression = { $_.Name }
            },
            @{
                Name = 'OriginalPath'
                Expression = { $_.FullName }
            },
            @{
                Name = 'DeletedTime'
                Expression = { $_.LastWriteTime }
            },
            @{
                Name = 'Size'
                Expression = { 
                    if ($_.Length -ge 1GB) { "{0:N2} GB" -f ($_.Length / 1GB) }
                    elseif ($_.Length -ge 1MB) { "{0:N2} MB" -f ($_.Length / 1MB) }
                    elseif ($_.Length -ge 1KB) { "{0:N2} KB" -f ($_.Length / 1KB) }
                    else { "{0:N2} B" -f $_.Length }
                }
            }

        if (-not $deletedFiles) {
            Write-Warning "No deleted files found between $startTime and $endTime"
            return
        }

        # Output the results based on specified format
        switch ($OutputFormat.ToLower()) {
            "table" {
                $deletedFiles | Format-Table -AutoSize
            }
            "list" {
                $deletedFiles | Format-List
            }
            "csv" {
                $deletedFiles | Export-Csv -Path "DeletedFiles_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation
                Write-Host "Results exported to DeletedFiles_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            }
            default {
                throw "Invalid output format. Use 'Table', 'List', or 'CSV'"
            }
        }

        Write-Host "`nTotal deleted files found: $($deletedFiles.Count)"
    }
    catch {
        Write-Error "An error occurred: $_"
    }
}

# Example usage:
# Get-DeletedFiles -TimeRange "24h" -OutputFormat "Table"
# Get-DeletedFiles -TimeRange "7d" -OutputFormat "List"
# Get-DeletedFiles -TimeRange "30d" -OutputFormat "CSV" 