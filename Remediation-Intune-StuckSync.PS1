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
