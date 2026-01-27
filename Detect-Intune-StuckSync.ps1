<<<<<<< HEAD
<#
.SYNOPSIS
Detects stale Intune device sync.

.DESCRIPTION
Checks last Intune Management Extension sync time.
Returns Exit 1 if stale beyond threshold.

.AUTHOR
Intune Automation
#>

$ThresholdHours = 24
$RegPath = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension"

try {
    if (-not (Test-Path $RegPath)) {
        Write-Output "IME registry not found"
        exit 1
    }

    $lastSync = (Get-ItemProperty $RegPath).LastSyncTime
    if (-not $lastSync) { exit 1 }

    $hours = (New-TimeSpan -Start $lastSync -End (Get-Date)).TotalHours

    if ($hours -gt $ThresholdHours) {
        Write-Output "Sync stale: $([math]::Round($hours,1)) hours"
        exit 1
    }

    Write-Output "Sync healthy"
    exit 0
}
catch {
    Write-Output "Detection error: $_"
    exit 1
}
=======
<#
.SYNOPSIS
Detects stale Intune device sync.

.DESCRIPTION
Checks last Intune Management Extension sync time.
Returns Exit 1 if stale beyond threshold.

.AUTHOR
Intune Automation
#>

$ThresholdHours = 24
$RegPath = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension"

try {
    if (-not (Test-Path $RegPath)) {
        Write-Output "IME registry not found"
        exit 1
    }

    $lastSync = (Get-ItemProperty $RegPath).LastSyncTime
    if (-not $lastSync) { exit 1 }

    $hours = (New-TimeSpan -Start $lastSync -End (Get-Date)).TotalHours

    if ($hours -gt $ThresholdHours) {
        Write-Output "Sync stale: $([math]::Round($hours,1)) hours"
        exit 1
    }

    Write-Output "Sync healthy"
    exit 0
}
catch {
    Write-Output "Detection error: $_"
    exit 1
}
>>>>>>> 70d22c1cf5aed302ea4cac45461c88a2f33284f6
