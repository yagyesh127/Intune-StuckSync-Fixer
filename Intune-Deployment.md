# Deployment Guide – Intune Stuck Sync Fixer

This document explains how to deploy the solution using
**Endpoint Analytics Proactive Remediations**.

---

## Prerequisites

### Microsoft Intune
- Windows devices enrolled
- Endpoint Analytics enabled

### Azure
- Log Analytics Workspace
- Workspace ID and Primary Key

### Permissions
- Intune Administrator (or equivalent)

---

## Step 1 – Prepare Scripts

You must have the following files:

detection/Detect-Intune-StuckSync.ps1
remediation/Remediate-Intune-StuckSync.ps1

Edit the remediation script and configure:

```powershell
$WorkspaceId = "<Your Workspace ID>"
$SharedKey  = "<Your Primary Key>"
