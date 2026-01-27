<#
.SYNOPSIS
  Remediation script for stale Intune Management Extension (IME) sync.

.DESCRIPTION
  - Sets process-scoped execution policy bypass and TLS 1.2.
  - Ensures basic module providers are available.
  - Optionally installs/imports BurntToast for user toasts when running in an interactive user session.
  - Checks last IME sync time and restarts IME if older than $ThresholdHours.
  - Sends logs to Azure Log Analytics (non-blocking).
#>

# ----------------- SAFE ENVIRONMENT SETUP -----------------
# Use a process-scoped execution policy bypass so this script can run without changing machine policy.
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
} catch {
    Write-Output "Could not set process execution policy: $($_.Exception.Message)"
}

# Ensure TLS 1.2 for secure REST calls
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Ensure NuGet provider and PowerShellGet are available for Install-Module (best-effort, non-fatal)
try {
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -ErrorAction Stop
    }
    if (-not (Get-Module -ListAvailable -Name PowerShellGet)) {
        Install-Module -Name PowerShellGet -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
    }
} catch {
    Write-Output "Package provider / PowerShellGet check failed: $($_.Exception.Message)"
}
# ----------------------------------------------------------

# ----------------- CONFIGURATION -----------------
$WorkspaceId    = "<YOUR_WORKSPACE_ID>"
$SharedKey      = "<YOUR_PRIMARY_KEY>"
$LogType        = "IntuneSyncFixer"
$ThresholdHours = 24
$ToastAppId     = "Microsoft.CompanyPortal"
# -------------------------------------------------

# ---------- OPTIONAL: Install or import BurntToast for nicer toasts ----------
# Only attempt to install BurntToast when running in an interactive user context.
# When running as SYSTEM (typical for Intune remediation), skip installation.
$canInstallBurntToast = $false
try {
    $isSystem = ($env:USERNAME -eq "SYSTEM")
    if (-not $isSystem) {
        # Try to import first; if not present, attempt install (CurrentUser scope)
        if (Get-Module -ListAvailable -Name BurntToast) {
            Import-Module BurntToast -ErrorAction SilentlyContinue
            $canInstallBurntToast = $true
        } else {
            try {
                Install-Module -Name BurntToast -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
                Import-Module BurntToast -ErrorAction SilentlyContinue
                $canInstallBurntToast = (Get-Module -ListAvailable -Name BurntToast) -ne $null
            } catch {
                Write-Output "BurntToast install skipped or failed: $($_.Exception.Message)"
                $canInstallBurntToast = $false
            }
        }
    } else {
        Write-Output "Running as SYSTEM; skipping BurntToast install."
    }
} catch {
    Write-Output "BurntToast check failed: $($_.Exception.Message)"
    $canInstallBurntToast = $false
}
# ---------------------------------------------------------------------------

function Send-LogAnalytics {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")] [string]$Level = "INFO"
    )

    try {
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
        Write-Output "Log Analytics send failed: $($_.Exception.Message)"
    }
}

function Show-Toast {
    param([string]$Message)

    # If BurntToast is available and imported, use it (simpler and more reliable in user sessions)
    if ($canInstallBurntToast -and (Get-Module -Name BurntToast -ListAvailable)) {
        try {
            # BurntToast uses New-BurntToastNotification
            New-BurntToastNotification -Text "Intune Sync Refreshed", $Message -AppLogo (Get-Command powershell.exe).Source -ErrorAction Stop
            return
        } catch {
            Write-Output "BurntToast toast failed: $($_.Exception.Message)"
            # fall through to fallback method
        }
    }

    # Fallback: use Windows Runtime API (may not show when running as SYSTEM)
    try {
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
    $lastSyncRaw = $props.LastSyncTime
    if (-not $lastSyncRaw) {
        Send-LogAnalytics -Message "LastSyncTime not present in registry" -Level "ERROR"
        exit 0
    }

    $lastSync = $null
    if ($lastSyncRaw -is [DateTime]) {
        $lastSync = $lastSyncRaw
    } else {
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

    $svcName = "IntuneManagementExtension"
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if (-not $svc) {
        Send-LogAnalytics -Message "Service $svcName not found on this machine." -Level "ERROR"
        exit 0
    }

    try {
        if ($svc.Status -eq 'Running') {
            Restart-Service -Name $svcName -Force -ErrorAction Stop
        } else {
            Start-Service -Name $svcName -ErrorAction Stop
        }

        Start-Sleep -Seconds 10
        Send-LogAnalytics -Message "IME service restarted or started successfully." -Level "INFO"

        # Attempt to notify user. If running as SYSTEM, toasts may not appear.
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