# Intune-StuckSync-Fixer
An Intune Proactive Remediation that detects stuck device sync by validating MDM transport, IME execution health, and IME activity freshness — and safely remediates only when appropriate.

## Features
- Detection + Remediation split
- Safe IME restart
- Log Analytics integration
- User toast notification
- Idempotent and automation-ready

## Detection Script
Check MDM transport (DmWapPushService)
_AND_
Check IME service health
_AND_
Check IME log activity freshness
→ if any blocking/stale → Exit 1


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
