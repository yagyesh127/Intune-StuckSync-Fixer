<#
.SYNOPSIS
Intune-StuckSync-Fixer – Safe Remediation Script

.DESCRIPTION
Runs only when Detection = Unhealthy.

Performs safe, supported remediation actions:
1. Validates MDM transport (DmWapPushService) – NO auto-fix
2. Restarts IntuneManagementExtension (IME) when present
3. Triggers Intune device sync using supported scheduled tasks
4. Optionally uploads remediation logs to Log Analytics
5. Optionally shows a user toast notification

Designed for Intune Proactive Remediation (SYSTEM, PowerShell 5.1).

.AUTHOR:: Yagyesh Agarwal
Intune Automation
#>

# ============================================================
# CONFIGURATION
# ============================================================

$EnableLogAnalyticsUpload = $false
$EnableToast             = $false

# ============================================================
# CUSTOM LOGGING CONFIG
# ============================================================

$CustomLogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Intune-StuckSync-Fixer.log"


# Log Analytics (only used if enabled)
$LogAnalyticsWorkspaceId = ""
$LogAnalyticsSharedKey   = ""
$LA_CustomLogName        = "IntuneSyncFixer_CL"

# ============================================================
# HELPERS
# ============================================================

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $entry = "[$timestamp] [$Level] [IntuneSyncFixer] $Message"

    # Always emit to PR output
    Write-Output $entry

    # Best-effort local logging (never fail remediation)
    try {
        Add-Content -Path $CustomLogPath -Value $entry -Encoding UTF8
    }
    catch {
        # Intentionally suppressed
    }
}

function Get-ServiceInfo {
    param([string]$Name)
    Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
}

# ============================================================
# 1. TRANSPORT SANITY CHECK (NO REPAIR)
# ============================================================

Write-Log "Validating MDM transport (DmWapPushService)..."

$dmSvc = Get-ServiceInfo -Name "DmWapPushService"

if (-not $dmSvc) {
    Write-Log "MDM transport missing. Remediation skipped (manual investigation required)."
    exit 0
}

if ($dmSvc.StartMode -ne "Auto" -or $dmSvc.State -ne "Running") {
    Write-Log "MDM transport unhealthy (StartMode=$($dmSvc.StartMode), State=$($dmSvc.State)). No auto-remediation performed."
    exit 0
}

Write-Log "MDM transport healthy."

# ============================================================
# 2. IME SERVICE RESTART (SAFE)
# ============================================================

Write-Log "Checking IntuneManagementExtension (IME) service..."

$imeSvc = Get-ServiceInfo -Name "IntuneManagementExtension"

if (-not $imeSvc) {
    Write-Log "IME service not installed. Nothing to remediate."
    exit 0
}

try {
    if ($imeSvc.State -eq "Running") {
        Write-Log "Restarting IME service..."
        Restart-Service -Name "IntuneManagementExtension" -Force -ErrorAction Stop
    }
    else {
        Write-Log "IME service stopped. Starting service..."
        Start-Service -Name "IntuneManagementExtension" -ErrorAction Stop
    }

    # Allow service to stabilize
    Start-Sleep -Seconds 10

    # 🔎 VERIFY IME SERVICE STATE (ADD HERE)
    $imeSvcCheck = Get-Service -Name "IntuneManagementExtension" -ErrorAction SilentlyContinue
    if ($imeSvcCheck -and $imeSvcCheck.Status -eq "Running") {
        Write-Log "IME service state confirmed: Running"
    }
    else {
        $state = if ($imeSvcCheck) { $imeSvcCheck.Status } else { "ServiceNotFound" }
        Write-Log "WARNING: IME service not running after restart (State=$state)"
    }

    Write-Log "IME service recovery completed."
}
catch {
    Write-Log "ERROR restarting IME service: $($_.Exception.Message)"
    exit 1
}

# ============================================================
# 3. TRIGGER INTUNE DEVICE SYNC (ROBUST ENUMERATION)
# ============================================================

Write-Log "Triggering Intune device sync via EnterpriseMgmt tasks..."

try 
{
    # Enumerate all EnterpriseMgmt tasks (handles GUID subfolders)
$mgmtTasks = Get-ScheduledTask | Where-Object {
    $_.TaskPath -like "\Microsoft\Windows\EnterpriseMgmt\*" -and
    $_.TaskName -match "(?i)Push|Schedule"
}

    if ($mgmtTasks) {
        foreach ($t in $mgmtTasks) {
            try {
                # Ensure TaskPath ends with backslash for Start-ScheduledTask
                $tp = if ($t.TaskPath.EndsWith("\")) { $t.TaskPath } else { $t.TaskPath + "\" }
                Start-ScheduledTask -TaskPath $tp -TaskName $t.TaskName -ErrorAction Stop
                Write-Log "Triggered: $($tp)$($t.TaskName)"
            }
            catch {
                Write-Log "Failed to trigger: $($t.TaskPath)$($t.TaskName) -- $($_.Exception.Message)"
            }
        }
    }
    else {
        Write-Log "No EnterpriseMgmt tasks found to trigger (device may be MDM‑broken)."
    }
}
catch {
    Write-Log "Scheduled tasks enumeration failed: $($_.Exception.Message)"
}

# ============================================================
# 4. LOG ANALYTICS (OPTIONAL)
# ============================================================

function Send-LogAnalytics {
    param([string]$Message)

    if (-not $EnableLogAnalyticsUpload) { return }

    if (-not ($LogAnalyticsWorkspaceId -and $LogAnalyticsSharedKey)) {
        Write-Log "Log Analytics not configured."
        return
    }

    try {
        $payload = @{
            Message      = $Message
            Computer     = $env:COMPUTERNAME
            TimestampUtc = (Get-Date).ToUniversalTime()
        } | ConvertTo-Json

        $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
        $date  = (Get-Date).ToUniversalTime().ToString("r")

        $stringToSign = "POST`n$($bytes.Length)`napplication/json`nx-ms-date:$date`n/api/logs"
        $keyBytes = [Convert]::FromBase64String($LogAnalyticsSharedKey)
        $hmac = New-Object System.Security.Cryptography.HMACSHA256
        $hmac.Key = $keyBytes
        $signature = [Convert]::ToBase64String($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign)))

        $headers = @{
    "Authorization" = "SharedKey ${LogAnalyticsWorkspaceId}:$signature"
    "Log-Type"      = $LA_CustomLogName
    "x-ms-date"     = $date
    "time-generated-field"   = "TimestampUtc"
    }

        Invoke-RestMethod `
            -Uri "https://$LogAnalyticsWorkspaceId.ods.opinsights.azure.com/api/logs?api-version=2016-04-01" `
            -Method Post `
            -Headers $headers `
            -Body $bytes `
            -ContentType "application/json"

        Write-Log "Remediation log uploaded to Log Analytics."
    }
    catch {
        Write-Log "ERROR uploading to Log Analytics: $($_.Exception.Message)"
    }
}

Send-LogAnalytics -Message "IME restarted and Intune sync triggered"

# ============================================================
# 5. USER TOAST (OPTIONAL)
# ============================================================

# Guard: toast requires interactive user session
$hasUser = Get-Process -Name explorer -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $hasUser) {
    Write-Log "No interactive user session detected; skipping toast."
    $EnableToast = $false
}

function Show-Toast {
    param([string]$Message)

    if (-not $EnableToast) { return }

    try {
        $xml = @"
<toast>
  <visual>
    <binding template='ToastGeneric'>
      <text>Device Sync Refreshed</text>
      <text>$Message</text>
    </binding>
  </visual>
</toast>
"@

        $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
        $doc.LoadXml($xml)

        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("IntuneSyncFixer").Show(
            [Windows.UI.Notifications.ToastNotification]::new($doc)
        )
    }
    catch {
        Write-Log "Toast notification failed."
    }
}

Show-Toast -Message "Your device was refreshed to ensure Intune policies stay up to date."


# ============================================================
# COMPLETE
# ============================================================

Write-Log "Remediation completed successfully."
exit 0
