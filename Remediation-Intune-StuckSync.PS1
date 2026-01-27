<<<<<<< HEAD
<#
.SYNOPSIS
  Remediation script for stale Intune Management Extension (IME) sync.

.DESCRIPTION
  - Checks last IME sync time from registry.
  - If sync is older than $ThresholdHours, restarts the IME service.
  - Sends simple logs to Azure Log Analytics (non-blocking).
  - Attempts a user toast notification (may not show when running as SYSTEM).

USAGE
  - Paste this as the Remediation script in Intune Proactive Remediations.
  - Set $WorkspaceId and $SharedKey securely (see notes).
#>

# ----------------- CONFIGURATION -----------------
# Replace these with your workspace values or inject them securely via Intune
$WorkspaceId    = "<YOUR_WORKSPACE_ID>"
$SharedKey      = "<YOUR_PRIMARY_KEY>"
$LogType        = "IntuneSyncFixer"

# How old (in hours) a sync must be to trigger remediation
$ThresholdHours = 24

# Toast AppId (safe default). Toasts may not appear when running as SYSTEM.
$ToastAppId     = "Microsoft.CompanyPortal"
# -------------------------------------------------

function Send-LogAnalytics {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")] [string]$Level = "INFO"
    )

    try {
        # Build a simple JSON payload
        $payload = @{
            TimeGenerated = (Get-Date).ToString("o")
            Computer      = $env:COMPUTERNAME
            Level         = $Level
            Message       = $Message
        } | ConvertTo-Json -Depth 3

        $rfc1123date = (Get-Date).ToUniversalTime().ToString("r")
        $contentLength = [Text.Encoding]::UTF8.GetByteCount($payload)
        $stringToSign = "POST`n$contentLength`napplication/json`nx-ms-date:$rfc1123date`n/api/logs"

        $keyBytes = [Convert]::FromBase64String($SharedKey)
        $hmac = New-Object System.Security.Cryptography.HMACSHA256
        $hmac.Key = $keyBytes
        $signature = [Convert]::ToBase64String($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign)))

        $headers = @{
            "Authorization" = "SharedKey $WorkspaceId:$signature"
            "Log-Type"      = $LogType
            "x-ms-date"     = $rfc1123date
            "Content-Type"  = "application/json"
        }

        $uri = "https://$WorkspaceId.ods.opinsights.azure.com/api/logs?api-version=2016-04-01"
        Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $payload -ErrorAction Stop
    }
    catch {
        # Logging must not stop remediation; write to host for troubleshooting
        Write-Output "Log Analytics send failed: $($_.Exception.Message)"
    }
}

function Show-Toast {
    param([string]$Message)

    try {
        # Simple toast XML. This uses Windows Runtime APIs and may not show when running as SYSTEM.
        $toastXml = @"
<toast>
  <visual>
    <binding template='ToastGeneric'>
      <text>Intune Sync Refreshed</text>
      <text>$Message</text>
    </binding>
  </visual>
</toast>
"@

        $xml = New-Object -TypeName "Windows.Data.Xml.Dom.XmlDocument"
        $xml.LoadXml($toastXml)

        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($ToastAppId)
        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
        $notifier.Show($toast)
    }
    catch {
        # Expected in many SYSTEM contexts; keep silent but log for diagnostics
        Write-Output "Toast skipped or failed: $($_.Exception.Message)"
    }
}

# ----------------- MAIN -----------------
try {
    $regPath = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension"

    if (-not (Test-Path -Path $regPath)) {
        Send-LogAnalytics -Message "IME registry path not found: $regPath" -Level "ERROR"
        exit 0
    }

    $props = Get-ItemProperty -Path $regPath -ErrorAction Stop

    # LastSyncTime may be a string or DateTime; try to parse defensively
    $lastSyncRaw = $props.LastSyncTime
    if (-not $lastSyncRaw) {
        Send-LogAnalytics -Message "LastSyncTime not present in registry" -Level "ERROR"
        exit 0
    }

    # Attempt to convert to DateTime
    $lastSync = $null
    if ($lastSyncRaw -is [DateTime]) {
        $lastSync = $lastSyncRaw
    }
    else {
        [DateTime]::TryParse($lastSyncRaw, [ref]$lastSync) | Out-Null
    }

    if (-not $lastSync) {
        Send-LogAnalytics -Message "Unable to parse LastSyncTime: $lastSyncRaw" -Level "ERROR"
        exit 0
    }

    $hoursSinceSync = (New-TimeSpan -Start $lastSync -End (Get-Date)).TotalHours
    $hoursRounded = [math]::Round($hoursSinceSync, 1)

    Send-LogAnalytics -Message "Hours since last IME sync: $hoursRounded" -Level "WARN"

    if ($hoursSinceSync -lt $ThresholdHours) {
        Send-LogAnalytics -Message "Sync is recent (< $ThresholdHours hours). No action required." -Level "INFO"
        exit 0
    }

    # Check service existence
    $svcName = "IntuneManagementExtension"
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if (-not $svc) {
        Send-LogAnalytics -Message "Service $svcName not found on this machine." -Level "ERROR"
        exit 0
    }

    # Restart service safely
    try {
        if ($svc.Status -eq 'Running') {
            Restart-Service -Name $svcName -Force -ErrorAction Stop
        }
        else {
            Start-Service -Name $svcName -ErrorAction Stop
        }

        Start-Sleep -Seconds 10
        Send-LogAnalytics -Message "IME service restarted or started successfully." -Level "INFO"

        # Attempt to notify user. Note: toasts often do not appear when script runs as SYSTEM.
        Show-Toast -Message "Your device sync was refreshed to keep policies up to date."
    }
    catch {
        Send-LogAnalytics -Message "Failed to restart/start IME service: $($_.Exception.Message)" -Level "ERROR"
    }
}
catch {
    Send-LogAnalytics -Message "Remediation script failed: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
=======
//🔹 CONFIGURATION BLOCK (EDIT THIS)//
$WorkspaceId = "<LOG_ANALYTICS_WORKSPACE_ID>"
$SharedKey  = "<PRIMARY_KEY>"
$LogType    = "IntuneSyncFixer"

$ToastAppId = "Microsoft.CompanyPortal"
$ThresholdHours = 24

//🔹 LOG ANALYTICS FUNCTION//
function Send-LogAnalytics {
    param (
        [string]$Message,
        [string]$Level
    )

    $time = (Get-Date).ToUniversalTime().ToString("r")
    $body = @{
        TimeGenerated = (Get-Date).ToString("o")
        Level         = $Level
        Message       = $Message
        Computer      = $env:COMPUTERNAME
    } | ConvertTo-Json

    $bytes = [Text.Encoding]::UTF8.GetBytes($body)
    $stringToSign = "POST`n$($bytes.Length)`napplication/json`nx-ms-date:$time`n/api/logs"
    $keyBytes = [Convert]::FromBase64String($SharedKey)
    $hash = New-Object Security.Cryptography.HMACSHA256
    $hash.Key = $keyBytes
    $signature = [Convert]::ToBase64String($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign)))
    $auth = "SharedKey $WorkspaceId:$signature"

    $headers = @{
        "Authorization"        = $auth
        "Log-Type"             = $LogType
        "x-ms-date"            = $time
        "Content-Type"         = "application/json"
    }

    Invoke-RestMethod -Uri "https://$WorkspaceId.ods.opinsights.azure.com/api/logs?api-version=2016-04-01" `
        -Method Post -Headers $headers -Body $bytes -ErrorAction Stop
}

//🔹 TOAST NOTIFICATION FUNCTION//
function Show-Toast {
    param ([string]$Message)

    $xml = @"
<toast>
  <visual>
    <binding template='ToastGeneric'>
      <text>Intune Sync Fix Applied</text>
      <text>$Message</text>
    </binding>
  </visual>
</toast>
"@

    $toastXml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $toastXml.LoadXml($xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($ToastAppId).Show(
        [Windows.UI.Notifications.ToastNotification]::new($toastXml)
    )
}

//🔹MAIN REMEDIATION LOGIC//
try {
    $reg = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension"
    $lastSync = (Get-ItemProperty $reg).LastSyncTime
    $hours = (New-TimeSpan -Start $lastSync -End (Get-Date)).TotalHours

    Send-LogAnalytics "Detected stale sync: $([math]::Round($hours,1)) hours" "WARN"

    Restart-Service IntuneManagementExtension -Force -ErrorAction Stop
    Start-Sleep -Seconds 10

    Send-LogAnalytics "IME service restarted successfully" "INFO"

    Show-Toast "Your device sync was refreshed to ensure policies stay up to date."
}
catch {
    Send-LogAnalytics "Remediation failed: $_" "ERROR"
    throw
}
>>>>>>> 70d22c1cf5aed302ea4cac45461c88a2f33284f6
