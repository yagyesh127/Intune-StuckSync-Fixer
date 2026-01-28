# Intune-StuckSync-Fixer
Intune proactive remediation for stuck device sync

## Features
- Detection + Remediation split
- Safe IME restart
- Log Analytics integration
- User toast notification
- Idempotent and automation-ready

## Detection Script
   └─ Checks last sync time
   └─ Outputs Exit 0 (Healthy) / Exit 1 (Stale)

## Remediation Script (runs only if Exit 1)
   ├─ Restart IME safely
   ├─ Trigger sync
   ├─ Push logs to Log Analytics
   └─ Notify user (toast)

## Deployment
See /docs/Intune-Deployment.md

## Requirements
- Microsoft Intune
- Log Analytics Workspace
- Windows 10/11

## Author
Yagyesh Agarwal
