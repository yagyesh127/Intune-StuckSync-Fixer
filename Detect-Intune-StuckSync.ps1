<#
.SYNOPSIS
End-to-end Intune Windows device health detection.

.DESCRIPTION
Evaluates Intune health using supported, documented signals only:
1. DmWapPushService (MDM transport layer)
2. IntuneManagementExtension service (IME)
3. IME log activity freshness

Exit code:
  0 = Healthy
  1 = Unhealthy (transport / IME / stale activity)

Designed for Intune Proactive Remediation (PowerShell 5.1).

#.REFERENCES
- IME logs & behavior: https://learn.microsoft.com/intune/intune-service/apps/intune-management-extension
- IME log catalog: https://www.prajwaldesai.com/microsoft-intune-management-extension-logs/
- DmWapPushService requirement: https://learn.microsoft.com/troubleshoot/mem/intune/device-management/cannot-sync-windows-10-devices
- Transport failure cases: https://call4cloud.nl/intune-sync-issue-dmwappushservice-missing/
#>

[CmdletBinding()]
param(
    [int]$ThresholdHours = 24,
    [bool]$RequireIME    = $true,
    [switch]$OutputJson,
    [int]$TailLines      = 300
)

# -------------------------------------------------
# Constants
# -------------------------------------------------
$NowUtc         = (Get-Date).ToUniversalTime()
$LogsRoot       = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$ImeServiceName = "IntuneManagementExtension"
$DmServiceName  = "DmWapPushService"

$CandidateLogs = @(
    "IntuneManagementExtension.log",
    "AgentExecutor.log",
    "AppWorkload.log",
    "HealthScripts.log",
    "DeviceHealthMonitoring.log",
    "Win32AppInventory.log",
    "AppActionProcessor.log",
    "ClientCertCheck.log",
    "Sensor.log"
) | ForEach-Object { Join-Path $LogsRoot $_ }

# -------------------------------------------------
# Helpers
# -------------------------------------------------

function Get-ServiceInfo {
    param([Parameter(Mandatory)][string]$Name)

    $svc = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
    if (-not $svc) { return $null }

    [PSCustomObject]@{
        Name      = $svc.Name
        State     = $svc.State        # Running | Stopped
        StartMode = $svc.StartMode    # Auto | Manual | Disabled
    }
}

function Parse-CMTraceTimestamp {
    param([string]$Line)

    # CMTrace pattern: time="HH:MM:SS.fff" date="YYYY-MM-DD"
    $t = [regex]::Match($Line, 'time="(?<t>\d{1,2}:\d{2}:\d{2}(\.\d{1,3})?)"')
    $d = [regex]::Match($Line, 'date="(?<d>\d{4}[-/]\d{1,2}[-/]\d{1,2})"')

    if ($t.Success -and $d.Success) {
        $dt = $null
        if ([datetime]::TryParse("$($d.Groups['d'].Value) $($t.Groups['t'].Value)", [ref]$dt)) {
            return $dt.ToUniversalTime()
        }
    }

    # Generic fallback: YYYY-MM-DD HH:MM:SS anywhere
    $g = [regex]::Match($Line, '(?<d>\d{4}[-/]\d{1,2}[-/]\d{1,2}).*(?<t>\d{1,2}:\d{2}:\d{2})')
    if ($g.Success) {
        $dt = $null
        if ([datetime]::TryParse("$($g.Groups['d'].Value) $($g.Groups['t'].Value)", [ref]$dt)) {
            return $dt.ToUniversalTime()
        }
    }

    return $null
}

function Get-LastLogTimestamp {
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$Tail = 200
    )

    if (-not (Test-Path -LiteralPath $Path)) { return $null }

    try {
        $tail = Get-Content -LiteralPath $Path -Tail $Tail -ErrorAction Stop
        for ($i = $tail.Count - 1; $i -ge 0; $i--) {
            $dt = Parse-CMTraceTimestamp -Line $tail[$i]
            if ($dt) { return $dt }
        }
    }
    catch {
        # ignore and fall back
    }

    (Get-Item -LiteralPath $Path).LastWriteTimeUtc
}

# -------------------------------------------------
# 0) MDM Transport – DmWapPushService
# -------------------------------------------------
$issues = New-Object System.Collections.Generic.List[string]

$dmSvc = Get-ServiceInfo -Name $DmServiceName
if (-not $dmSvc) {
    $issues.Add("MDM transport missing: DmWapPushService")
}
else {
    if ($dmSvc.StartMode -ne "Auto") {
        $issues.Add("MDM transport misconfigured: StartMode=$($dmSvc.StartMode)")
    }
    elseif ($dmSvc.State -ne "Running") {
        $issues.Add("MDM transport not running: State=$($dmSvc.State)")
    }
}

# -------------------------------------------------
# 1) IME Service
# -------------------------------------------------
$imeSvc = Get-ServiceInfo -Name $ImeServiceName
if ($RequireIME) {
    if (-not $imeSvc) {
        $issues.Add("IntuneManagementExtension not installed")
    }
    else {
        if ($imeSvc.StartMode -ne "Auto") {
            $issues.Add("IME service misconfigured: StartMode=$($imeSvc.StartMode)")
        }
        elseif ($imeSvc.State -ne "Running") {
            $issues.Add("IME service not running: State=$($imeSvc.State)")
        }
    }
}

# -------------------------------------------------
# 2) IME Log Activity (only if IME exists)
# -------------------------------------------------
$logInfo = $null

if ($RequireIME -and $imeSvc -and (Test-Path $LogsRoot)) {
    $timestamps = foreach ($log in $CandidateLogs) {
        $ts = Get-LastLogTimestamp -Path $log -Tail $TailLines
        if ($ts) {
            [PSCustomObject]@{ Path = $log; Time = $ts }
        }
    }

    if ($timestamps -and $timestamps.Count -gt 0) {
        $latest   = $timestamps | Sort-Object Time -Descending | Select-Object -First 1
        $ageHours = [math]::Round(($NowUtc - $latest.Time).TotalHours, 1)

        $logInfo = [PSCustomObject]@{
            NewestLog  = [IO.Path]::GetFileName($latest.Path)
            NewestTime = $latest.Time
            AgeHours   = $ageHours
        }

        if ($ageHours -gt $ThresholdHours) {
            $issues.Add("IME activity stale ($ageHours h > $ThresholdHours h)")
        }
    }
    # NOTE: no logs yet is NOT a failure (new / idle device)
}

# -------------------------------------------------
# Final Decision
# -------------------------------------------------
$healthy = ($issues.Count -eq 0)

$result = [PSCustomObject]@{
    Health         = $(if ($healthy) { "Healthy" } else { "Unhealthy" })
    ThresholdHours = $ThresholdHours
    DmWapPush      = $dmSvc
    IMEService     = $imeSvc
    IMEActivity    = $logInfo
    Issues         = $issues
    TimestampUtc   = $NowUtc
}

if ($OutputJson) {
    $result | ConvertTo-Json -Depth 5
}
else {
    if ($healthy) {
        Write-Output "Healthy | Intune transport + IME OK"
        if ($logInfo) {
            Write-Output "Last IME activity: $($logInfo.NewestLog) ($($logInfo.AgeHours)h ago)"
        }
    }
    else {
        $issues | ForEach-Object { Write-Output $_ }
    }
}

exit ($(if ($healthy) { 0 } else { 1 }))
