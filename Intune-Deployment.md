# Deployment Guide – Intune-StuckSync-Fixer

## Overview
This document explains how to deploy **Intune-StuckSync-Fixer** using Microsoft Intune
Proactive Remediations for Windows 10/11 devices.

The solution consists of:
- A Detection script
- A Remediation script (runs only when detection fails)
---
## Prerequisites
- Microsoft Intune
- Windows 10 or Windows 11 devices
- Intune Proactive Remediations enabled
- Devices running PowerShell 5.1 (default on Windows)
---
Azure (Optional – for Log Analytics Integration)

If you choose to enable centralized logging, the remediation script can send execution results to Azure Log Analytics.
To configure Log Analytics:
⚙️ Script Configuration (Optional)
If Log Analytics upload is enabled, update the following values in the remediation script:

$EnableLogAnalyticsUpload = $false
$EnableToast             = $false

$LogAnalyticsWorkspaceId = "<Your Workspace ID>"
$LogAnalyticsSharedKey   = "<Your Primary Key>"
$LA_CustomLogName        = "IntuneSyncFixer_CL"

## Step 1: Create Proactive Remediation
1. Go to **Intune Admin Center**
2. Navigate to **Devices → Scripts → Proactive remediations**
3. Select **Create script package**

---

## Step 2: Configure Detection Script
- Upload: `Detect-IntuneStuckSync.ps1`
- Run script using logged-on credentials: **No**
- Script frequency: **Once per day**
- Detection logic:
  - Exit `0` → Device healthy
  - Exit `1` → Device unhealthy

---

## Step 3: Configure Remediation Script
- Upload: `Remediate-IntuneStuckSync.ps1`
- Run script using logged-on credentials: **No**
- Remediation runs only when detection returns Exit `1`

---

## Step 4: Assignment
- Assign to a **pilot device group** first
- Monitor results for several days
- Gradually expand to broader device groups

---

## Step 5: Monitoring & Validation
- Review results under:
  **Devices → Scripts → Proactive remediations → Device status**
- Check remediation output for:
  - IME restart confirmation
  - Sync trigger confirmation
  - Warnings (if any)

---

## Optional Configuration
- Enable Log Analytics upload inside the remediation script
- Enable user toast notifications (automatically skipped if no user session)

---

## Rollback
- Disable or unassign the Proactive Remediation package
- No device changes persist beyond service restart and sync trigger
